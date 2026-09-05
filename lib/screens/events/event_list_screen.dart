import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/event_provider.dart';
import '../../widgets/events/event_card.dart';
import 'event_detail_screen.dart';

/// Full vertical list behind the "See all" links on the Explore screen.
/// Shows every loaded event of a given [mode] ('online' | 'offline').
class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key, required this.title, required this.mode});

  final String title;
  final String mode; // 'online' | 'offline'

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventsProvider);
    final events =
        state.events.where((e) => e.mode == mode).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ref.read(eventsProvider.notifier).refresh,
          child: events.isEmpty
              ? ListView(
                  padding: const EdgeInsets.only(top: 120),
                  children: const [
                    Center(
                      child: Text('Nothing here yet.',
                          style: TextStyle(color: AppColors.mutedText)),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: events.length,
                  itemBuilder: (_, i) => EventCard(
                    event: events[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              EventDetailScreen(eventId: events[i].id)),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
