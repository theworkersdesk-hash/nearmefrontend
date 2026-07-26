import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/common/avatar.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.connectionId,
    required this.title,
    this.photoUrl,
  });

  final String connectionId;
  final String title;
  final String? photoUrl;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
        ref.read(chatRoomProvider(widget.connectionId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref.read(chatRoomProvider(widget.connectionId).notifier).send(text);
    _input.clear();
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatRoomProvider(widget.connectionId));
    final myId = ref.watch(authProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar(url: widget.photoUrl, name: widget.title, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 16)),
                  if (state.otherTyping)
                    const Text('typing…',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Say hello!',
                            style: TextStyle(color: AppColors.mutedText)))
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true, // newest at bottom
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: state.messages.length,
                        itemBuilder: (_, i) {
                          final m = state.messages[i];
                          return MessageBubble(
                              message: m, isMine: m.senderId == myId);
                        },
                      ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onChanged: (_) => ref
                    .read(chatRoomProvider(widget.connectionId).notifier)
                    .sendTyping(),
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
