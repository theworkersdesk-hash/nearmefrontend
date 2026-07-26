import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/connection_provider.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/avatar.dart';

/// Incoming connection requests with Accept/Reject actions.
class PendingRequestsScreen extends ConsumerWidget {
  const PendingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingRequestsProvider);
    final notifier = ref.read(pendingRequestsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Connection Requests')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Text('No pending requests',
                  style: TextStyle(color: AppColors.mutedText)),
            );
          }
          return RefreshIndicator(
            onRefresh: notifier.load,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = requests[i];
                return ListTile(
                  leading: Avatar(url: r.otherUserPhoto, name: r.otherUserName),
                  title: Text(r.otherUserName ?? 'Someone'),
                  subtitle: const Text('wants to connect'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle,
                            color: AppColors.success),
                        onPressed: () => runWithFeedback(
                          context,
                          () => notifier.accept(r.id),
                          successMessage: 'Connection accepted',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: AppColors.error),
                        onPressed: () => runWithFeedback(
                            context, () => notifier.reject(r.id)),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
