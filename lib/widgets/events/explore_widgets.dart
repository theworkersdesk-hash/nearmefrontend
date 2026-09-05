import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/event_model.dart';

/// Visual identity (icon + gradient) for an event category. Keeps the Explore
/// screen colourful and consistent — every card/tile of the same category looks
/// the same. Falls back to a neutral celebration look for unknown categories.
({IconData icon, List<Color> gradient}) categoryVisual(String category) {
  const palettes = <List<Color>>[
    [Color(0xFFF8A488), Color(0xFFF06E6E)], // warm coral
    [Color(0xFF9D4EDD), Color(0xFF7B2D8E)], // brand purple
    [Color(0xFFF6B24B), Color(0xFFF08E2E)], // amber
    [Color(0xFFF17A9E), Color(0xFFE0518A)], // pink
    [Color(0xFF6FB1F0), Color(0xFF4E7FDD)], // blue
    [Color(0xFF63C88B), Color(0xFF2FA36A)], // green
  ];

  final icon = switch (category) {
    'marathon' => Icons.directions_run,
    'yoga' => Icons.self_improvement,
    'kirtan' => Icons.music_note,
    'meetup' => Icons.groups,
    'workshop' => Icons.handyman,
    'sports' => Icons.sports_basketball,
    'hiking' => Icons.terrain,
    'volunteering' => Icons.volunteer_activism,
    'food_fest' => Icons.restaurant,
    'art' => Icons.palette,
    'gaming' => Icons.sports_esports,
    'music_jam' => Icons.music_note,
    'movie_watch' => Icons.movie,
    'quiz' => Icons.quiz,
    'book_club' => Icons.menu_book,
    'coding' => Icons.code,
    'meditation' => Icons.spa,
    'language_exchange' => Icons.translate,
    'debate' => Icons.forum,
    'webinar' => Icons.cast_for_education,
    _ => Icons.celebration,
  };
  // Stable per-category colour so the same category always renders identically.
  final gradient = palettes[category.hashCode.abs() % palettes.length];
  return (icon: icon, gradient: gradient);
}

/// Prettifies a snake_case category into a Title Case label.
String prettyCategory(String category) => category
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// A section header row: bold title, optional muted suffix, and a "See all"
/// action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.suffix,
    this.onSeeAll,
    this.trailing,
  });

  final String title;
  final String? suffix;
  final VoidCallback? onSeeAll;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (suffix != null) ...[
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(suffix!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.mutedText)),
          ),
        ],
        const Spacer(),
        if (trailing != null) trailing!,
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Text('See all',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Tall image card for "Offline Experiences": cover photo (or category
/// gradient), a location/label pill, an icon chip, title and subtitle.
class ExperienceCard extends StatelessWidget {
  const ExperienceCard({
    super.key,
    required this.event,
    required this.onTap,
    this.badgeLabel,
  });

  final EventModel event;
  final VoidCallback onTap;

  /// Top-left pill text — a distance ("450 m") when known, otherwise a label.
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final visual = categoryVisual(event.category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppShapes.card),
          gradient: LinearGradient(
            colors: visual.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: visual.gradient.last.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (event.coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: event.coverImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            // Dark scrim so the text stays readable over any image.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                  stops: [0.35, 0.7, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badgeLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppShapes.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(badgeLabel!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(visual.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square game tile for "Play Arena": a gradient icon square with the title
/// and a live participant count below.
class GameTile extends StatelessWidget {
  const GameTile({super.key, required this.event, required this.onTap});

  final EventModel event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = categoryVisual(event.category);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: visual.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: visual.gradient.last.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(visual.icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${event.participantCount} playing',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static "Groups Near You" card (feature not yet backed by the API — shown so
/// the Explore layout matches the design; Join is a coming-soon stub).
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.title,
    required this.description,
    required this.members,
    required this.icon,
    required this.tint,
    required this.onJoin,
  });

  final String title;
  final String description;
  final int members;
  final IconData icon;
  final Color tint;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppShapes.card),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 15, color: AppColors.mutedText),
                    const SizedBox(width: 4),
                    Text('$members Members',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    GestureDetector(
                      onTap: onJoin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(AppShapes.pill),
                        ),
                        child: const Text('Join Group',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
