import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Circular avatar with a graceful initial-letter fallback.
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, this.name, this.radius = 24});

  final String? url;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.tertiary,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    final initial =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.tertiary,
      child: Text(initial,
          style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.8)),
    );
  }
}
