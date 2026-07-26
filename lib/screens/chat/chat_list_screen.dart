import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/conversation_model.dart';
import '../../providers/chat_provider.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/avatar.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);
    final notifier = ref.read(conversationsProvider.notifier);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('Messages',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 30)),
                const Spacer(),
                Material(
                  color: AppColors.tertiary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => showSnack(context,
                        'Connect with people in Discover to start chatting'),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.edit_outlined,
                          color: AppColors.primaryDark, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (conversations) {
                if (conversations.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'No conversations yet.\nConnect with people to start chatting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: notifier.load,
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) =>
                        _tile(context, ref, conversations[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, ConversationModel c) {
    final unread = c.unreadCount > 0;
    return Material(
      color: unread
          ? AppColors.tertiary.withValues(alpha: 0.4)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading:
            Avatar(url: c.otherUserPhoto, name: c.otherUserName, radius: 26),
        title: Text(c.otherUserName ?? 'Someone',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          c.lastMessage ?? 'Say hello 👋',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread ? AppColors.onSurface : AppColors.mutedText,
            fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (c.lastMessageAt != null)
              Text(DateFormat('HH:mm').format(c.lastMessageAt!.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            if (unread)
              CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primary,
                child: Text('${c.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              )
            else
              const SizedBox(height: 20),
          ],
        ),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (_) => ChatRoomScreen(
                  connectionId: c.id,
                  title: c.otherUserName ?? 'Chat',
                  photoUrl: c.otherUserPhoto,
                ),
              ))
              .then((_) => ref.read(conversationsProvider.notifier).load());
        },
      ),
    );
  }
}
