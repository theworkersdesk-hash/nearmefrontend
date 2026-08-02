import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/avatar_uploader.dart';
import '../../widgets/common/vibe_button.dart';
import '../support/help_support_screen.dart';
import 'edit_profile_screen.dart';

/// The "Me" tab — profile card + interests + account actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final gen = switch (user.generationCategory) {
      'gen_z' => 'Gen Z',
      'millennial' => 'Millennial',
      'gen_x' => 'Gen X',
      _ => null,
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('My Profile',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 26)),
                const Spacer(),
                Material(
                  color: AppColors.tertiary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _confirmLogout(context, ref),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.logout,
                          color: AppColors.primaryDark, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Profile card.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF3E9FB), AppColors.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  const AvatarUploader(radius: 46),
                  const SizedBox(height: 14),
                  Text(
                    '${user.fullName ?? 'You'}${user.age != null ? ', ${user.age}' : ''}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (gen != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Chip(label: Text(gen)),
                    ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(user.bio!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 200,
                    child: VibeButton(
                      label: 'Edit Profile',
                      height: 48,
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const EditProfileScreen())),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.interests_outlined,
                    size: 20, color: AppColors.primaryDark),
                const SizedBox(width: 6),
                Text('My Interests',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            if (user.interests.isEmpty)
              Text('Add interests from Edit Profile',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < user.interests.length; i++)
                    _InterestChip(label: user.interests[i], index: i),
                ],
              ),
            const SizedBox(height: 28),
            Text('Support', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.help_outline,
              label: 'Help & Support',
              subtitle: 'FAQs and your requests',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Log out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(authProvider.notifier).logout();
  }
}

/// A tappable settings-style row (icon + label + chevron).
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppShapes.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShapes.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    color: AppColors.tertiary,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interest chip with a rotating pastel palette (design's colorful chips).
class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label, required this.index});
  final String label;
  final int index;

  static const _palette = [
    (bg: Color(0xFFDDEEFF), fg: Color(0xFF2A6FB0)),
    (bg: Color(0xFFFCE0DA), fg: Color(0xFFB0492A)),
    (bg: Color(0xFFFDEFD6), fg: Color(0xFFB08A2A)),
    (bg: Color(0xFFEDE0FB), fg: Color(0xFF7B2D8E)),
    (bg: Color(0xFFE0F5E4), fg: Color(0xFF2A8B45)),
  ];

  @override
  Widget build(BuildContext context) {
    final c = _palette[index % _palette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: c.bg, borderRadius: BorderRadius.circular(AppShapes.pill)),
      child: Text(label,
          style: TextStyle(
              color: c.fg, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}
