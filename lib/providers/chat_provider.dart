import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'auth_provider.dart';
import 'providers.dart';

/// Chat list (accepted connections with previews + unread counts).
class ConversationsNotifier
    extends StateNotifier<AsyncValue<List<ConversationModel>>> {
  ConversationsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }
  final Ref _ref;

  static const _cacheKey = 'conversations';

  /// Cache-aside via Hive: show the cached chat list immediately, then refresh
  /// from the network and persist. Falls back to cache when offline.
  Future<void> load() async {
    final cache = _ref.read(localCacheProvider);
    final cached = cache.get<List<dynamic>>(_cacheKey);
    if (cached != null) {
      state = AsyncValue.data(
        cached
            .map((e) =>
                ConversationModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    }
    try {
      final fresh = await _ref.read(chatServiceProvider).conversations();
      state = AsyncValue.data(fresh);
      await cache.put(_cacheKey, fresh.map((c) => c.toJson()).toList(),
          ttl: const Duration(minutes: 5));
    } catch (e, st) {
      if (cached == null) state = AsyncValue.error(e, st);
    }
  }
}

final conversationsProvider = StateNotifierProvider<ConversationsNotifier,
    AsyncValue<List<ConversationModel>>>(
  (ref) => ConversationsNotifier(ref),
);

@immutable
class ChatRoomState {
  const ChatRoomState({
    this.messages = const [],
    this.isLoading = true,
    this.otherTyping = false,
    this.hasMore = true,
  });

  final List<MessageModel> messages; // newest first
  final bool isLoading;
  final bool otherTyping;
  final bool hasMore;

  ChatRoomState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? otherTyping,
    bool? hasMore,
  }) =>
      ChatRoomState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        otherTyping: otherTyping ?? this.otherTyping,
        hasMore: hasMore ?? this.hasMore,
      );
}

/// Owns a single conversation: history pagination + live socket events.
class ChatRoomNotifier extends StateNotifier<ChatRoomState> {
  ChatRoomNotifier(this._ref, this.connectionId)
      : super(const ChatRoomState()) {
    _init();
  }

  final Ref _ref;
  final String connectionId;

  Future<void> _init() async {
    await _connectSocket();
    await loadInitial();
  }

  Future<void> _connectSocket() async {
    final socket = _ref.read(socketServiceProvider);
    await socket.connect();
    socket.joinChat(connectionId);

    socket.on('new_message', (data) {
      final msg = MessageModel.fromJson(Map<String, dynamic>.from(data as Map));
      if (msg.connectionId != connectionId) return;
      // Replace an optimistic pending copy if present, else prepend.
      final withoutPending = state.messages
          .where((m) => !(m.pending && m.content == msg.content))
          .toList();
      state = state.copyWith(messages: [msg, ...withoutPending]);
      _markReadIfInbound(msg);
    });

    socket.on('user_typing', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['connectionId'] == connectionId) {
        state = state.copyWith(otherTyping: true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) state = state.copyWith(otherTyping: false);
        });
      }
    });

    socket.on('message_read_receipt', (data) {
      final id = Map<String, dynamic>.from(data as Map)['messageId'];
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == id ? m.copyWith(isRead: true) : m)
            .toList(),
      );
    });
  }

  void _markReadIfInbound(MessageModel msg) {
    final me = _ref.read(authProvider).user?.id;
    if (me != null && msg.senderId != me) {
      _ref.read(socketServiceProvider).markRead(msg.id);
    }
  }

  Future<void> loadInitial() async {
    try {
      final msgs = await _ref.read(chatServiceProvider).messages(connectionId);
      state = state.copyWith(
          messages: msgs, isLoading: false, hasMore: msgs.length >= 50);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.messages.isEmpty) return;
    final oldest = state.messages.last.createdAt.toUtc().toIso8601String();
    final older = await _ref
        .read(chatServiceProvider)
        .messages(connectionId, before: oldest);
    state = state.copyWith(
        messages: [...state.messages, ...older], hasMore: older.length >= 50);
  }

  void sendTyping() => _ref.read(socketServiceProvider).typing(connectionId);

  /// Optimistic send: show immediately, socket confirms via new_message.
  void send(String content) {
    final me = _ref.read(authProvider).user?.id ?? 'me';
    final optimistic = MessageModel(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      connectionId: connectionId,
      senderId: me,
      content: content,
      isRead: false,
      createdAt: DateTime.now(),
      pending: true,
    );
    state = state.copyWith(messages: [optimistic, ...state.messages]);
    _ref.read(socketServiceProvider).sendMessage(connectionId, content);
  }

  @override
  void dispose() {
    final socket = _ref.read(socketServiceProvider);
    socket.off('new_message');
    socket.off('user_typing');
    socket.off('message_read_receipt');
    super.dispose();
  }
}

final chatRoomProvider =
    StateNotifierProvider.family<ChatRoomNotifier, ChatRoomState, String>(
  (ref, connectionId) => ChatRoomNotifier(ref, connectionId),
);
