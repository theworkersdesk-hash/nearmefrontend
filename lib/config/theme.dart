import 'package:flutter/material.dart';

/// hloppl color system, derived from primary #B65FCB. Kept in one place so every
/// widget references named tokens rather than raw hex.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFFB65FCB);
  static const Color primaryLight = Color(0xFFD48BE3);
  static const Color primaryDark = Color(0xFF7B2D8E);
  static const Color secondary = Color(0xFFE8A0F6);
  static const Color tertiary = Color(0xFFF3D5FA);
  static const Color surface = Color(0xFFFAF5FC);
  static const Color background = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF9A825);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1A2E);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5D6EB);
  static const Color disabled = Color(0xFFC4B5CC);

  /// Signature purple→magenta gradient used on primary CTAs and accents
  /// (matches the design's gradient pill buttons).
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF9D4EDD), Color(0xFF7B2D8E)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Soft lavender page-background gradient for hero / auth screens.
  static const Gradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFF3E9FB), Color(0xFFFAF5FC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Shared shape tokens.
class AppShapes {
  const AppShapes._();
  static const double pill = 30; // fully-rounded button radius
  static const double card = 20;
  static const double field = 16;
}

/// Central [ThemeData]. Poppins for display/headings/buttons, Inter for body.
/// (Add the font files to assets/fonts + pubspec to use them; falls back to
/// platform defaults otherwise.)
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        surface: AppColors.background,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.disabled,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(), // fully-rounded pill (design)
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Soft lavender field fill, borderless — matches the design mockups.
        fillColor: const Color(0xFFEFE9F8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.4),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.4),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedText,
        ),
        hintStyle: const TextStyle(color: AppColors.mutedText),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.tertiary,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.onSurface),
        secondaryLabelStyle: const TextStyle(color: AppColors.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: 'Poppins', fontSize: 30, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14),
        bodySmall: TextStyle(
            fontFamily: 'Inter', fontSize: 12, color: AppColors.mutedText),
      ).apply(
          bodyColor: AppColors.onSurface, displayColor: AppColors.onSurface),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
