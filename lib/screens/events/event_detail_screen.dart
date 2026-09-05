import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/avatar.dart';
import '../../widgets/common/hloppl_button.dart';
import '../../widgets/maps/static_map_view.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (event) => _detail(context, ref, event),
      ),
    );
  }

  Widget _detail(BuildContext context, WidgetRef ref, EventModel e) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: e.coverImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: e.coverImageUrl!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.tertiary,
                    child: const Icon(Icons.celebration,
                        size: 64, color: AppColors.primaryDark),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(e.isOnline ? 'Online' : 'Offline')),
                    Chip(label: Text(e.category.replaceAll('_', ' '))),
                  ],
                ),
                const SizedBox(height: 16),
                _row(
                    Icons.event,
                    DateFormat('EEE, MMM d • h:mm a')
                        .format(e.eventDate.toLocal())),
                const SizedBox(height: 8),
                if (e.isOnline)
                  InkWell(
                    onTap: () => _open(e.meetingLink),
                    child: _row(Icons.link, e.meetingLink ?? '', link: true),
                  )
                else ...[
                  _row(Icons.place_outlined, e.address ?? ''),
                  if (e.latitude != null && e.longitude != null) ...[
                    const SizedBox(height: 12),
                    StaticMapView(
                      lat: e.latitude!,
                      lng: e.longitude!,
                      height: 170,
                      label: 'Tap for directions',
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Text('About', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(e.description,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Avatar(
                        url: e.creatorPhotoUrl,
                        name: e.creatorName,
                        radius: 18),
                    const SizedBox(width: 10),
                    Text('Hosted by ${e.creatorName ?? 'a member'}'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    '${e.participantCount}${e.maxParticipants != null ? ' / ${e.maxParticipants}' : ''} joined',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                HlopplButton(
                  label: e.isFull ? 'Event Full' : 'Join Event',
                  onPressed: e.isFull
                      ? null
                      : () async {
                          final ok = await runWithFeedback(
                            context,
                            () => ref
                                .read(eventsProvider.notifier)
                                .toggleJoin(e, join: true),
                            successMessage: 'Joined event',
                          );
                          if (ok != null) {
                            ref.invalidate(eventDetailProvider(eventId));
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, {bool link = false}) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: link ? AppColors.primary : AppColors.onSurface,
                    decoration: link ? TextDecoration.underline : null)),
          ),
        ],
      );

  Future<void> _open(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
