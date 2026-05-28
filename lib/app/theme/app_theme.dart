import 'package:flutter/material.dart';

class AppTheme {
  static const _olive = Color(0xFF556B2F);
  static const _teal = Color(0xFF007C89);
  static const _amber = Color(0xFFD7A84B);
  static const _ink = Color(0xFF101312);
  static const _surface = Color(0xFF181D1B);
  static const _lightSurface = Color(0xFFF5F7F5);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: Brightness.dark,
      primary: _teal,
      secondary: _amber,
      tertiary: _olive,
      surface: _surface,
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: _ink,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _surface,
        selectedIconTheme: IconThemeData(color: scheme.secondary),
        selectedLabelTextStyle: TextStyle(color: scheme.secondary),
      ),
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: Brightness.light,
      primary: _teal,
      secondary: _amber,
      tertiary: _olive,
      surface: _lightSurface,
    );

    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(48, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(48, 44),
        ),
      ),
    );
  }
}
