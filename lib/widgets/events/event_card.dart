import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/event_model.dart';

/// Event list card: cover, title, mode badge, date, location/link, count.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onTap});

  final EventModel event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: event.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: event.coverImageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.tertiary,
                      child: const Icon(Icons.celebration,
                          size: 44, color: AppColors.primaryDark),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      _ModeBadge(isOnline: event.isOnline),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _iconRow(
                      Icons.event,
                      DateFormat('MMM d, h:mm a')
                          .format(event.eventDate.toLocal())),
                  const SizedBox(height: 4),
                  _iconRow(
                    event.isOnline ? Icons.link : Icons.place_outlined,
                    event.isOnline
                        ? 'Online event'
                        : (event.address ?? 'Offline'),
                  ),
                  const SizedBox(height: 4),
                  _iconRow(
                    Icons.group_outlined,
                    '${event.participantCount}${event.maxParticipants != null ? '/${event.maxParticipants}' : ''} joined',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 15, color: AppColors.mutedText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.mutedText, fontSize: 13)),
          ),
        ],
      );
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.isOnline});
  final bool isOnline;
  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.primaryDark : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(isOnline ? 'Online' : 'Offline',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
