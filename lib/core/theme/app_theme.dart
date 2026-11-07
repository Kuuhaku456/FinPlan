import 'package:flutter/material.dart';

import 'app_colors.dart';

// ============================================
// FINPLAN - APP THEME
// ============================================

abstract final class AppTheme {
  // Theme dibuat sekali dan digunakan kembali.
  static final ThemeData light = _build(
    Brightness.light,
  );

  static final ThemeData dark = _build(
    Brightness.dark,
  );

  // ==========================================
  // SELECT THEME
  // ==========================================

  static ThemeData forBrightness(
    Brightness brightness,
  ) {
    return brightness == Brightness.dark
        ? dark
        : light;
  }

  // ==========================================
  // BUILD THEME
  // ==========================================

  static ThemeData _build(
    Brightness brightness,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,

      colorScheme: scheme,

      // ======================================
      // BACKGROUND
      // ======================================

      scaffoldBackgroundColor: isDark
          ? scheme.surface
          : AppColors.lightBackground,

      // ======================================
      // APP BAR
      // ======================================

      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? scheme.surface
            : AppColors.lightBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      // ======================================
      // INPUT DECORATION
      // ======================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: isDark
            ? scheme.surfaceContainerHigh
            : Colors.white,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),

      // ======================================
      // CARD THEME
      // ======================================

      cardTheme: CardThemeData(
        elevation: 0,

        color: isDark
            ? scheme.surfaceContainerLow
            : Colors.white,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),

      // ======================================
      // FILLED BUTTON
      // ======================================

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}