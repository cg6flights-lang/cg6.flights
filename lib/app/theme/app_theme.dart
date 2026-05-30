import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Seed colors (evolved from original palette) ─────────────────

  static const _primarySeed = Color(0xFF008A9E);
  static const _secondarySeed = Color(0xFFC8963E);
  static const _tertiarySeed = Color(0xFF5B7A3A);
  static const _errorSeed = Color(0xFFDC3545);

  // ── Surface tones ───────────────────────────────────────────────

  static const _darkScaffold = Color(0xFF0D1114);
  static const _darkSurface = Color(0xFF151A1D);
  static const _lightScaffold = Color(0xFFF4F6F5);
  static const _lightSurface = Color(0xFFFBFCFB);

  // ── Light theme ─────────────────────────────────────────────────

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.light,
      primary: _primarySeed,
      secondary: _secondarySeed,
      tertiary: _tertiarySeed,
      surface: _lightSurface,
      error: _errorSeed,
    );

    return _base(scheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: _lightScaffold,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(color: scheme.primary),
        unselectedIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
      ),
    );
  }

  // ── Dark theme ──────────────────────────────────────────────────

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.dark,
      primary: _primarySeed,
      secondary: _secondarySeed,
      tertiary: _tertiarySeed,
      surface: _darkSurface,
      error: _errorSeed,
    );

    return _base(scheme, Brightness.dark).copyWith(
      scaffoldBackgroundColor: _darkScaffold,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(color: scheme.primary),
        unselectedIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
      ),
    );
  }

  // ── Base theme (shared) ─────────────────────────────────────────

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,

      // ── Typography ────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        headlineSmall: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        labelMedium: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.25),
        labelSmall: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),

      // ── Cards ──────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        color: scheme.surfaceContainerLow,
      ),

      // ── Inputs ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),

      // ── Buttons ────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(48, 44),
          visualDensity: VisualDensity.compact,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(48, 44),
          visualDensity: VisualDensity.compact,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),

      // ── AppBar ─────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: isDark ? 1 : 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleSpacing: 16,
        backgroundColor: isDark
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Dialogs ────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        backgroundColor: scheme.surfaceContainerHigh,
      ),

      // ── DataTable ──────────────────────────────────────────────
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
        dataTextStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        horizontalMargin: 16,
        columnSpacing: 20,
        dividerThickness: 1,
      ),

      // ── Chips ──────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        labelStyle: const TextStyle(fontSize: 12),
      ),

      // ── Dividers ───────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      ),

      // ── Misc ───────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: 3,
      ),
    );
  }
}
