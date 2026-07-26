import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/discover_user_model.dart';

/// Large image card for the discovery feed: full-bleed photo with a dark
/// gradient scrim, a distance badge, the person's name + bio, and a gradient
/// "Say Hii" CTA — matches the "People Nearby" cards in the design.
class UserCard extends StatelessWidget {
  const UserCard(
      {super.key,
      required this.user,
      required this.onConnect,
      required this.onTap});

  final DiscoverUser user;
  final VoidCallback onConnect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.card),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppShapes.card),
          color: AppColors.onSurface,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo (or gradient fallback).
            if (user.profilePhotoUrl != null)
              CachedNetworkImage(
                imageUrl: user.profilePhotoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.tertiary),
                errorWidget: (_, __, ___) => const _PhotoFallback(),
              )
            else
              const _PhotoFallback(),
            // Bottom scrim for legible text.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xE6000000)
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Distance badge (top-left).
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place,
                        size: 12, color: AppColors.secondary),
                    const SizedBox(width: 3),
                    Text('${user.distanceKm} km',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            // Text + CTA (bottom).
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${user.fullName ?? 'Someone'}${user.age != null ? ', ${user.age}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.25),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _cta(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cta() {
    switch (user.connectionStatus) {
      case ConnectionStatus.connected:
        return const _Pill(label: 'Connected', icon: Icons.check, solid: false);
      case ConnectionStatus.pendingSent:
        return const _Pill(
            label: 'Pending', icon: Icons.hourglass_top, solid: false);
      case ConnectionStatus.pendingReceived:
        return _Pill(label: 'Respond', icon: Icons.reply, onTap: onConnect);
      case ConnectionStatus.none:
        return _Pill(label: 'Say Hii', emoji: '👋', onTap: onConnect);
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label,
      this.icon,
      this.emoji,
      this.onTap,
      this.solid = true});
  final String label;
  final IconData? icon;
  final String? emoji;
  final VoidCallback? onTap;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppShapes.pill),
          child: Ink(
            height: 40,
            decoration: BoxDecoration(
              gradient: solid ? AppColors.primaryGradient : null,
              color: solid ? null : Colors.white24,
              borderRadius: BorderRadius.circular(AppShapes.pill),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (emoji != null)
                    Text(emoji!, style: const TextStyle(fontSize: 14)),
                  if (icon != null) Icon(icon, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        child:
            Center(child: Icon(Icons.person, size: 56, color: Colors.white70)),
      );
}
