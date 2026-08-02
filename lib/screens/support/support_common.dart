import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/support_ticket_model.dart';

/// A colored pill showing a ticket's status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final SupportStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      SupportStatus.open => (const Color(0xFFDDEEFF), const Color(0xFF2A6FB0)),
      SupportStatus.inProgress =>
        (const Color(0xFFFDEFD6), const Color(0xFFB08A2A)),
      SupportStatus.resolved =>
        (const Color(0xFFE0F5E4), const Color(0xFF2A8B45)),
      SupportStatus.closed => (const Color(0xFFEDE7EF), AppColors.mutedText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppShapes.pill)),
      child: Text(status.label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

/// Compact relative time, e.g. "just now", "5m", "3h", "2d", or a date.
String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
