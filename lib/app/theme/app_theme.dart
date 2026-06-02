import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand colors (from CG6 logo) ────────────────────────────────

  static const _brandBlue = Color(0xFF0E5DCB);
  static const _brandBlueDeep = Color(0xFF0846B4);
  static const _accentCyan = Color(0xFF22B8E6);
  static const _accentGold = Color(0xFFD9A441);
  static const _errorRed = Color(0xFFDC3545);

  // ── Light palette ───────────────────────────────────────────────

  static const _lightBg = Color(0xFFF5F8FC);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceMuted = Color(0xFFEEF3F8);
  static const _lightBorder = Color(0xFFC9D6E5);
  static const _lightText = Color(0xFF101820);
  static const _lightTextSecondary = Color(0xFF4E6082);

  // ── Dark palette ────────────────────────────────────────────────

  static const _darkBg = Color(0xFF070B10);
  static const _darkSurface = Color(0xFF0F1720);
  static const _darkSurfaceElevated = Color(0xFF152232);
  static const _darkSurfaceMuted = Color(0xFF1B2A3D);
  static const _darkBorder = Color(0xFF2A3B50);
  static const _darkText = Color(0xFFF4F8FF);
  static const _darkTextSecondary = Color(0xFFA9B8CB);

  // ── Light theme ─────────────────────────────────────────────────

  static ThemeData get light {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: _brandBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDCEAFF),
      onPrimaryContainer: _brandBlueDeep,
      secondary: _accentGold,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFDF3DC),
      onSecondaryContainer: const Color(0xFF6B4C15),
      tertiary: _accentCyan,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFDCF5FC),
      onTertiaryContainer: const Color(0xFF0D5B73),
      error: _errorRed,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF93000A),
      surface: _lightSurface,
      onSurface: _lightText,
      surfaceContainerHighest: _lightSurfaceMuted,
      onSurfaceVariant: _lightTextSecondary,
      outline: _lightBorder,
      outlineVariant: _lightBorder,
      shadow: Colors.black26,
    );

    return _base(scheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: _lightBg,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _lightSurfaceMuted,
        selectedIconTheme: IconThemeData(color: _brandBlue),
        selectedLabelTextStyle: TextStyle(color: _brandBlue),
        unselectedIconTheme:
            IconThemeData(color: _lightTextSecondary.withValues(alpha: 0.6)),
      ),
    );
  }

  // ── Dark theme ──────────────────────────────────────────────────

  static ThemeData get dark {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF4D8DFF),
      onPrimary: const Color(0xFF003573),
      primaryContainer: const Color(0xFF0E2A55),
      onPrimaryContainer: const Color(0xFFDCEAFF),
      secondary: const Color(0xFFE2B354),
      onSecondary: const Color(0xFF3D2A04),
      secondaryContainer: const Color(0xFF57400C),
      onSecondaryContainer: const Color(0xFFFDF3DC),
      tertiary: const Color(0xFF27C7F2),
      onTertiary: const Color(0xFF003544),
      tertiaryContainer: const Color(0xFF004D62),
      onTertiaryContainer: const Color(0xFFDCF5FC),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: _darkSurface,
      onSurface: _darkText,
      surfaceContainerHighest: _darkSurfaceElevated,
      onSurfaceVariant: _darkTextSecondary,
      outline: _darkBorder,
      outlineVariant: _darkBorder,
      shadow: Colors.black,
    );

    return _base(scheme, Brightness.dark).copyWith(
      scaffoldBackgroundColor: _darkBg,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _darkSurfaceMuted,
        selectedIconTheme:
            IconThemeData(color: const Color(0xFF4D8DFF)),
        selectedLabelTextStyle:
            TextStyle(color: const Color(0xFF4D8DFF)),
        unselectedIconTheme:
            IconThemeData(color: _darkTextSecondary.withValues(alpha: 0.5)),
      ),
    );
  }

  // ── Base theme (shared) ─────────────────────────────────────────

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,

      // ── Typography ────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: const TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineLarge:
            const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        headlineMedium:
            const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        headlineSmall:
            const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        titleSmall:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        labelMedium: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.25),
        labelSmall: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),

      // ── Cards ──────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        color: scheme.surface,
      ),

      // ── Inputs ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),

      // ── Buttons ────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(48, 44),
          visualDensity: VisualDensity.compact,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(48, 44),
          visualDensity: VisualDensity.compact,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      ),

      // ── AppBar ─────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 1,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleSpacing: 16,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Dialogs ────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        backgroundColor: scheme.surfaceContainerHighest,
      ),

      // ── DataTable ──────────────────────────────────────────────
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
        dataTextStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
        headingRowHeight: 38,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 46,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
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
