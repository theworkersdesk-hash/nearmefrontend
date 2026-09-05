import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/theme.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../widgets/events/event_card.dart';
import '../../widgets/events/explore_widgets.dart';
import 'event_detail_screen.dart';
import 'event_list_screen.dart';

/// "Explore vibes" — the events discovery screen. A curated, sectioned layout:
/// Offline Experiences (image cards) + Play Arena (online events as game tiles)
/// + Groups Near You (coming soon). Searching collapses to a flat result list.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _search = TextEditingController();
  String _query = '';

  // Static demo groups — "Groups Near You" isn't backed by the API yet, so
  // these mirror the design and show a coming-soon toast when tapped.
  static const _demoGroups = [
    (
      title: 'Chill & Connect',
      description:
          'Meet new people, share conversations, coffee and good vibes.',
      members: 246,
      icon: Icons.people_alt,
      tint: AppColors.primary,
    ),
    (
      title: 'Game On',
      description: 'Play games, compete and win exciting rewards.',
      members: 384,
      icon: Icons.sports_esports,
      tint: Color(0xFFF08E2E),
    ),
    (
      title: 'Creative Circle',
      description: 'Share ideas, art, music and let creativity flow.',
      members: 172,
      icon: Icons.brush,
      tint: Color(0xFFE0518A),
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<EventModel> _filtered(List<EventModel> events) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return events;
    return events
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q) ||
            (e.address ?? '').toLowerCase().contains(q))
        .toList();
  }

  void _openDetail(EventModel e) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)),
      );

  void _comingSoon(String label) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label are coming soon!')),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider);
    final notifier = ref.read(eventsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      // "Create" now lives in the Profile tab (see ProfileScreen) so event
      // creation and its monthly quota are managed in one place.
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontSize: 28),
                          children: const [
                            TextSpan(text: 'Explore '),
                            TextSpan(
                                text: 'vibes',
                                style: TextStyle(color: AppColors.primary)),
                            TextSpan(text: ' ✨'),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: AppColors.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.calendar_today_outlined,
                              color: AppColors.primary, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search experiences, games & more',
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.primary),
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppShapes.pill),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppShapes.pill),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body(state, notifier)),
          ],
        ),
      ),
    );
  }

  Widget _body(EventsState state, EventsNotifier notifier) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!, textAlign: TextAlign.center),
            TextButton(onPressed: notifier.refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    // While searching, collapse the sections into a single result list.
    if (_query.trim().isNotEmpty) {
      return _searchResults(notifier);
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _offlineSection(state.events),
          _playArenaSection(state.events),
          _groupsSection(),
        ],
      ),
    );
  }

  Widget _searchResults(EventsNotifier notifier) {
    final results = _filtered(ref.watch(eventsProvider).events);
    if (results.isEmpty) {
      return Center(
        child: Text('No matches for "$_query"',
            style: const TextStyle(color: AppColors.mutedText)),
      );
    }
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        itemCount: results.length,
        itemBuilder: (_, i) =>
            EventCard(event: results[i], onTap: () => _openDetail(results[i])),
      ),
    );
  }

  Widget _offlineSection(List<EventModel> events) {
    final offline =
        events.where((e) => !e.isOnline).toList(growable: false);
    final position = ref.watch(userPositionProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
          child: SectionHeader(
            title: 'Offline Experiences',
            onSeeAll: offline.isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EventListScreen(
                          title: 'Offline Experiences', mode: 'offline'),
                    )),
          ),
        ),
        if (offline.isEmpty)
          const _EmptyHint('No offline experiences nearby yet.')
        else
          SizedBox(
            height: 232,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: offline.length,
              itemBuilder: (_, i) {
                final e = offline[i];
                return ExperienceCard(
                  event: e,
                  badgeLabel: _distanceLabel(position, e),
                  onTap: () => _openDetail(e),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _playArenaSection(List<EventModel> events) {
    final online = events.where((e) => e.isOnline).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: SectionHeader(
            title: 'Play Arena',
            suffix: '(Online)',
            onSeeAll: online.isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EventListScreen(
                          title: 'Play Arena', mode: 'online'),
                    )),
          ),
        ),
        if (online.isEmpty)
          const _EmptyHint('No online games running right now.')
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: online.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) =>
                  GameTile(event: online[i], onTap: () => _openDetail(online[i])),
            ),
          ),
      ],
    );
  }

  Widget _groupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: SectionHeader(
            title: 'Groups Near You',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tertiary,
                borderRadius: BorderRadius.circular(AppShapes.pill),
              ),
              child: const Text('Coming soon',
                  style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final g in _demoGroups)
                GroupCard(
                  title: g.title,
                  description: g.description,
                  members: g.members,
                  icon: g.icon,
                  tint: g.tint,
                  onJoin: () => _comingSoon('Groups'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// A "450 m"/"1.2 km" badge when we know both positions, else a category
  /// label (e.g. "Food Fest") so the card is never blank.
  String _distanceLabel(Position? me, EventModel e) {
    if (me != null && e.latitude != null && e.longitude != null) {
      final meters = Geolocator.distanceBetween(
          me.latitude, me.longitude, e.latitude!, e.longitude!);
      if (meters < 1000) return '${meters.round()} m';
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return prettyCategory(e.category);
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: Text(text,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
      );
}
