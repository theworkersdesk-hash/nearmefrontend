import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/discover_user_model.dart';
import '../../providers/discover_provider.dart';
import '../../providers/providers.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/vibe_button.dart';

/// Full profile shown when a discover card is tapped.
class UserProfileView extends ConsumerWidget {
  const UserProfileView({super.key, required this.user});
  final DiscoverUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reflect live status changes (e.g. after tapping Connect here).
    final live = ref.watch(discoverProvider).users.firstWhere(
          (u) => u.id == user.id,
          orElse: () => user,
        );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'block') _confirmBlock(context, ref, live.id);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'block',
                    child:
                        Text('Block', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: live.profilePhotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: live.profilePhotoUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.tertiary,
                      child: const Icon(Icons.person,
                          size: 96, color: AppColors.primaryDark),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${live.fullName ?? 'Someone'}${live.age != null ? ', ${live.age}' : ''}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 16, color: AppColors.mutedText),
                      const SizedBox(width: 4),
                      Text('${live.distanceKm} km away',
                          style: Theme.of(context).textTheme.bodySmall),
                      if (live.generationCategory != null) ...[
                        const SizedBox(width: 12),
                        _GenBadge(label: live.generationCategory!),
                      ],
                    ],
                  ),
                  if (live.bio != null && live.bio!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(live.bio!,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  if (live.interests.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Interests',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: live.interests
                          .map((i) => Chip(label: Text(i)))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _cta(context, ref, live),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBlock(
      BuildContext context, WidgetRef ref, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'They will be removed from your discovery and any connection will be severed.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Block', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await runWithFeedback<bool>(
      context,
      () async {
        await ref.read(connectionServiceProvider).block(userId);
        return true;
      },
      successMessage: 'User blocked',
    );
    if (ok == null) return; // failed — snackbar already shown
    await ref.read(discoverProvider.notifier).refresh();
    if (context.mounted) Navigator.of(context).pop();
  }

  Widget _cta(BuildContext context, WidgetRef ref, DiscoverUser u) {
    switch (u.connectionStatus) {
      case ConnectionStatus.connected:
        return const VibeButton(label: 'Connected', onPressed: null);
      case ConnectionStatus.pendingSent:
        return const VibeButton(label: 'Request Pending', onPressed: null);
      case ConnectionStatus.pendingReceived:
        return VibeButton(
          label: 'Respond in Requests',
          onPressed: () => Navigator.of(context).pop(),
        );
      case ConnectionStatus.none:
        return VibeButton(
          label: 'Connect',
          trailingIcon: Icons.person_add_alt,
          onPressed: () => runWithFeedback(
            context,
            () => ref.read(discoverProvider.notifier).connect(u.id),
            successMessage: 'Connection request sent',
          ),
        );
    }
  }
}

class _GenBadge extends StatelessWidget {
  const _GenBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final pretty = switch (label) {
      'gen_z' => 'Gen Z',
      'millennial' => 'Millennial',
      _ => 'Gen X',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tertiary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(pretty,
          style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
