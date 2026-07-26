import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation_model.dart';
import 'providers.dart';

/// Pending received connection requests (Accept/Reject inbox).
class PendingRequestsNotifier
    extends StateNotifier<AsyncValue<List<ConversationModel>>> {
  PendingRequestsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }
  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state =
          AsyncValue.data(await _ref.read(connectionServiceProvider).pending());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> accept(String connId) async {
    await _ref.read(connectionServiceProvider).accept(connId);
    await load();
  }

  Future<void> reject(String connId) async {
    await _ref.read(connectionServiceProvider).reject(connId);
    await load();
  }
}

final pendingRequestsProvider = StateNotifierProvider<PendingRequestsNotifier,
    AsyncValue<List<ConversationModel>>>(
  (ref) => PendingRequestsNotifier(ref),
);
