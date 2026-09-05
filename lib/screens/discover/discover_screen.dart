import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/discover_provider.dart';
import '../../providers/providers.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/discover/user_card.dart';
import '../../widgets/maps/current_location_map.dart';
import 'pending_requests_screen.dart';
import 'user_profile_view.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(discoverProvider.notifier).refresh());
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(discoverProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _categories = [
    (label: 'All', value: null),
    (label: 'Gen Z', value: 'gen_z'),
    (label: 'Millennial', value: 'millennial'),
    (label: 'Gen X', value: 'gen_x'),
  ];

  void _openFilters() {
    final notifier = ref.read(discoverProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, __) {
          final state = ref.watch(discoverProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.place, color: AppColors.primary, size: 20),
                    const SizedBox(width: 6),
                    Text('Showing people within '
                        '${state.filters.radiusKm.round()} km'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Range is fixed at ${AppConstants.defaultRadiusKm.round()} km '
                  'and updates from your current location.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                const CurrentLocationMap(height: 140),
                const SizedBox(height: 16),
                Text('Generation',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _categories.map((c) {
                    final selected = state.filters.category == c.value;
                    return ChoiceChip(
                      label: Text(c.label),
                      selected: selected,
                      onSelected: (_) {
                        notifier.setCategory(c.value);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);
    final notifier = ref.read(discoverProvider.notifier);
    final firstName =
        (ref.watch(authProvider).user?.fullName ?? '').split(' ').first;
    final pending = ref.watch(pendingRequestsProvider).maybeWhen(
          data: (l) => l.length,
          orElse: () => 0,
        );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _header(context, firstName, pending),
              ),
            ),
            if (state.isLoading)
              const SliverToBoxAdapter(child: _DiscoverSkeleton())
            else if (state.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Centered(
                  icon: state.locationDeniedForever
                      ? Icons.location_off
                      : Icons.error_outline,
                  text: state.error!,
                  actionLabel:
                      state.locationDeniedForever ? 'Open Settings' : 'Retry',
                  action: state.locationDeniedForever
                      ? () async {
                          await ref
                              .read(locationServiceProvider)
                              .openSettings();
                        }
                      : notifier.refresh,
                ),
              )
            else if (state.users.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Centered(
                    icon: Icons.person_search,
                    text: 'No one nearby. Try increasing your range.',
                    action: _openFilters),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final user = state.users[i];
                      return UserCard(
                        user: user,
                        onConnect: () => runWithFeedback(
                          context,
                          () => notifier.connect(user.id),
                          successMessage: 'Connection request sent',
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => UserProfileView(user: user)),
                        ),
                      );
                    },
                    childCount: state.users.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String firstName, int pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hey ${firstName.isEmpty ? 'there' : firstName} 👋',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.mutedText)),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(fontSize: 30, height: 1.1),
                      children: const [
                        TextSpan(text: 'Meet real people\n'),
                        TextSpan(
                            text: 'around ',
                            style: TextStyle(color: AppColors.primary)),
                        TextSpan(text: 'you.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Real people. Real connections.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              children: [
                _circleIcon(Icons.tune, _openFilters),
                const SizedBox(height: 10),
                _circleIcon(
                  Icons.notifications_outlined,
                  () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const PendingRequestsScreen()))
                      .then((_) =>
                          ref.read(pendingRequestsProvider.notifier).load()),
                  badge: pending,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Refresh banner.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppShapes.card),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    color: AppColors.tertiary,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.explore,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New people are waiting around you',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text('Refresh to see who\'s new!',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(discoverProvider.notifier).refresh(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppShapes.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Refresh',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('People Nearby', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap, {int badge = 0}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Material(
          color: AppColors.background,
          shape: const CircleBorder(),
          elevation: 1,
          shadowColor: AppColors.primary.withValues(alpha: 0.2),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: AppColors.onSurface, size: 22),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ),
      ],
    );
  }
}

class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.tertiary,
      highlightColor: AppColors.surface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.6,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppShapes.card)),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.text,
    required this.action,
    this.actionLabel = 'Retry',
  });
  final IconData icon;
  final String text;
  final VoidCallback action;
  final String actionLabel;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.mutedText),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(text, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: action, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
