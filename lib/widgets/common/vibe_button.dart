import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Primary CTA — a fully-rounded gradient pill with a loading spinner and an
/// optional trailing icon (e.g. the "Get Started →" arrow). Matches the design's
/// purple→magenta gradient buttons. The [outline] variant is a bordered pill.
class VibeButton extends StatelessWidget {
  const VibeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon,
    this.leadingIcon,
    this.variant = VibeButtonVariant.primary,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? trailingIcon;
  final Widget? leadingIcon;
  final VibeButtonVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isOutline = variant == VibeButtonVariant.outline;
    final fg = isOutline ? AppColors.onSurface : AppColors.onPrimary;

    final content = isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                leadingIcon!,
                const SizedBox(width: 8)
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 20, color: fg),
              ],
            ],
          );

    final enabled = !isLoading && onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppShapes.pill),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient:
                isOutline ? null : (enabled ? AppColors.primaryGradient : null),
            color: isOutline
                ? Colors.transparent
                : (enabled ? null : AppColors.disabled),
            borderRadius: BorderRadius.circular(AppShapes.pill),
            border: isOutline
                ? Border.all(color: AppColors.border, width: 1.4)
                : null,
            boxShadow: isOutline || !enabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

enum VibeButtonVariant { primary, outline }
