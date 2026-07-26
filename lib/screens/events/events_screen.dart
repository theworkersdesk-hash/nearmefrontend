import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../widgets/events/event_card.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(eventsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  List<EventModel> _filtered(List<EventModel> events) {
    if (_query.trim().isEmpty) return events;
    final q = _query.toLowerCase();
    return events
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q) ||
            (e.address ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider);
    final notifier = ref.read(eventsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CreateEventScreen()))
            .then((created) {
          if (created == true) notifier.refresh();
        }),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create', style: TextStyle(color: Colors.white)),
      ),
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
                  const SizedBox(height: 12),
                  SegmentedButton<EventTab>(
                    segments: const [
                      ButtonSegment(value: EventTab.all, label: Text('All')),
                      ButtonSegment(
                          value: EventTab.online, label: Text('Online')),
                      ButtonSegment(
                          value: EventTab.offline, label: Text('Offline')),
                    ],
                    selected: {state.tab},
                    onSelectionChanged: (s) => notifier.setTab(s.first),
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
    final events = _filtered(state.events);
    if (events.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'No events yet. Be the first to create one!'
              : 'No matches for "$_query"',
          style: const TextStyle(color: AppColors.mutedText),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        itemCount: events.length,
        itemBuilder: (_, i) {
          final event = events[i];
          return EventCard(
            event: event,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => EventDetailScreen(eventId: event.id)),
            ),
          );
        },
      ),
    );
  }
}
