import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/event_model.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import 'providers.dart';

/// Events tab filter: all | online | offline.
enum EventTab { all, online, offline }

extension on EventTab {
  String? get mode => switch (this) {
        EventTab.all => null,
        EventTab.online => 'online',
        EventTab.offline => 'offline',
      };
}

@immutable
class EventsState {
  const EventsState({
    this.events = const [],
    this.tab = EventTab.all,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
  });

  final List<EventModel> events;
  final EventTab tab;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? error;

  EventsState copyWith({
    List<EventModel>? events,
    EventTab? tab,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? error,
    bool clearError = false,
  }) =>
      EventsState(
        events: events ?? this.events,
        tab: tab ?? this.tab,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        error: clearError ? null : (error ?? this.error),
      );
}

class EventsNotifier extends StateNotifier<EventsState> {
  EventsNotifier(this._ref) : super(const EventsState()) {
    refresh();
  }
  final Ref _ref;

  static const _cacheTtl = Duration(minutes: 5);
  String _cacheKey(EventTab tab) => 'events:${tab.name}';

  Future<void> setTab(EventTab tab) async {
    state = state.copyWith(tab: tab);
    await refresh();
  }

  /// Client-side cache-aside: paint the Hive-cached feed instantly, then
  /// refresh from the network and write the fresh page back to Hive. If the
  /// network fails but we have a cache, keep showing it (offline resilience).
  Future<void> refresh() async {
    final cache = _ref.read(localCacheProvider);
    final cached = cache.get<List<dynamic>>(_cacheKey(state.tab));
    if (cached != null) {
      state = state.copyWith(
        events: cached
            .map(
                (e) => EventModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final page = await _ref
          .read(eventServiceProvider)
          .list(mode: state.tab.mode, page: 1);
      state = state.copyWith(
          events: page.events,
          isLoading: false,
          hasMore: page.hasMore,
          page: 1);
      await cache.put(
          _cacheKey(state.tab), page.events.map((e) => e.toJson()).toList(),
          ttl: _cacheTtl);
    } on ApiException catch (e) {
      // Keep any cached events on failure; only surface the error if empty.
      state = state.copyWith(
          isLoading: false, error: state.events.isEmpty ? e.message : null);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = state.page + 1;
      final page = await _ref
          .read(eventServiceProvider)
          .list(mode: state.tab.mode, page: next);
      state = state.copyWith(
        events: [...state.events, ...page.events],
        isLoadingMore: false,
        hasMore: page.hasMore,
        page: next,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.message);
    }
  }

  Future<bool> createEvent(Map<String, dynamic> body) async {
    try {
      await _ref.read(eventServiceProvider).create(body);
      await refresh();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  /// Join/leave an event. Returns true on success; throws [ApiException] on
  /// failure (e.g. event full) so the caller can surface a snackbar.
  Future<bool> toggleJoin(EventModel event, {required bool join}) async {
    final service = _ref.read(eventServiceProvider);
    if (join) {
      await service.join(event.id);
    } else {
      await service.leave(event.id);
    }
    await refresh();
    return true;
  }
}

final eventsProvider = StateNotifierProvider<EventsNotifier, EventsState>(
    (ref) => EventsNotifier(ref));

/// Single-event detail (used by the detail screen).
final eventDetailProvider =
    FutureProvider.family<EventModel, String>((ref, id) async {
  return ref.read(eventServiceProvider).detail(id);
});

/// The current user's monthly event-creation quota. Invalidate after creating
/// an event or upgrading so the profile reflects the new remaining count.
final eventQuotaProvider = FutureProvider<EventQuota>((ref) async {
  return ref.read(eventServiceProvider).quota();
});

/// Current device position (for showing distances on Explore experience cards).
/// Resolves to null when permission is denied or location is unavailable — the
/// UI falls back to a category label in that case.
final userPositionProvider = FutureProvider<Position?>((ref) async {
  return ref.read(locationServiceProvider).getCurrent();
});
