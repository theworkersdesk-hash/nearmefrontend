import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/support_ticket_model.dart';
import '../services/api_exception.dart';
import 'providers.dart';

@immutable
class SupportListState {
  const SupportListState({
    this.tickets = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
  });

  final List<SupportTicket> tickets;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? error;

  SupportListState copyWith({
    List<SupportTicket>? tickets,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? error,
    bool clearError = false,
  }) =>
      SupportListState(
        tickets: tickets ?? this.tickets,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Paginated ticket list for one tab. [arg] is the filter: 'active' | 'closed'.
class SupportListNotifier extends StateNotifier<SupportListState> {
  SupportListNotifier(this._ref, this._filter)
      : super(const SupportListState());
  final Ref _ref;
  final String _filter;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _ref
          .read(supportServiceProvider)
          .list(filter: _filter, page: 1);
      state = state.copyWith(
        tickets: page.tickets,
        isLoading: false,
        hasMore: page.hasMore,
        page: 1,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message, tickets: []);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = state.page + 1;
      final page = await _ref
          .read(supportServiceProvider)
          .list(filter: _filter, page: next);
      state = state.copyWith(
        tickets: [...state.tickets, ...page.tickets],
        isLoadingMore: false,
        hasMore: page.hasMore,
        page: next,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.message);
    }
  }
}

final supportListProvider = StateNotifierProvider.family<SupportListNotifier,
    SupportListState, String>((ref, filter) => SupportListNotifier(ref, filter));
