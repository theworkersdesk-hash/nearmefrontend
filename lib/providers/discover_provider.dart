import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discover_user_model.dart';
import '../services/api_exception.dart';
import '../services/location_service.dart';
import 'providers.dart';

@immutable
class DiscoverFilters {
  const DiscoverFilters({this.category});

  /// Radius is fixed at 5km by the backend; exposed only for display.
  final double radiusKm = 5;
  final String? category; // gen_z | millennial | gen_x | null (All)

  DiscoverFilters copyWith({String? category, bool clearCategory = false}) =>
      DiscoverFilters(
        category: clearCategory ? null : (category ?? this.category),
      );
}

@immutable
class DiscoverState {
  const DiscoverState({
    this.users = const [],
    this.filters = const DiscoverFilters(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
    this.locationDeniedForever = false,
  });

  final List<DiscoverUser> users;
  final DiscoverFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? error;

  /// True when location permission is permanently blocked, so the UI offers
  /// an "Open Settings" action instead of a plain "Retry".
  final bool locationDeniedForever;

  DiscoverState copyWith({
    List<DiscoverUser>? users,
    DiscoverFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? error,
    bool clearError = false,
    bool? locationDeniedForever,
  }) =>
      DiscoverState(
        users: users ?? this.users,
        filters: filters ?? this.filters,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        error: clearError ? null : (error ?? this.error),
        locationDeniedForever:
            locationDeniedForever ?? this.locationDeniedForever,
      );
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  DiscoverNotifier(this._ref) : super(const DiscoverState());
  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(
        isLoading: true, clearError: true, locationDeniedForever: false);

    // Ensure we have (and have pushed) a fresh device location before asking the
    // backend who's nearby. This is what makes the Retry button re-prompt for
    // permission and re-sync coordinates — without it, retrying just repeats the
    // same failed query.
    final outcome = await _ref.read(locationServiceProvider).ensureAndSync();
    if (outcome != LocationOutcome.ok) {
      state = state.copyWith(
        isLoading: false,
        users: [],
        error: _locationMessage(outcome),
        locationDeniedForever: outcome == LocationOutcome.deniedForever,
      );
      return;
    }

    try {
      final page = await _ref.read(discoverServiceProvider).nearby(
            category: state.filters.category,
            page: 1,
          );
      state = state.copyWith(
        users: page.users,
        isLoading: false,
        hasMore: page.hasMore,
        page: 1,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message, users: []);
    }
  }

  String _locationMessage(LocationOutcome outcome) => switch (outcome) {
        LocationOutcome.serviceDisabled =>
          'Location is turned off. Turn on GPS/location and tap Retry.',
        LocationOutcome.deniedForever =>
          'Location permission is blocked. Open Settings to allow location, then come back.',
        _ =>
          'We need your location to find people nearby. Tap Retry and allow location access.',
      };

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = state.page + 1;
      final page = await _ref.read(discoverServiceProvider).nearby(
            category: state.filters.category,
            page: next,
          );
      state = state.copyWith(
        users: [...state.users, ...page.users],
        isLoadingMore: false,
        hasMore: page.hasMore,
        page: next,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.message);
    }
  }

  Future<void> setCategory(String? category) async {
    state = state.copyWith(
      filters: category == null
          ? state.filters.copyWith(clearCategory: true)
          : state.filters.copyWith(category: category),
    );
    await refresh();
  }

  /// Send a connect request and optimistically flip the card state.
  /// Throws [ApiException] on failure so the caller can show a snackbar.
  Future<void> connect(String userId) async {
    await _ref.read(connectionServiceProvider).request(userId);
    state = state.copyWith(
      users: state.users
          .map((u) => u.id == userId
              ? u.copyWith(connectionStatus: ConnectionStatus.pendingSent)
              : u)
          .toList(),
    );
  }
}

final discoverProvider = StateNotifierProvider<DiscoverNotifier, DiscoverState>(
    (ref) => DiscoverNotifier(ref));
