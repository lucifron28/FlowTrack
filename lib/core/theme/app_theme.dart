import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const _accent = Color(0xFF6D28D9);
  static const _accentTint = Color(0xFFDDD6FE);
  static const _success = Color(0xFF10B981);
  static const _lightCanvas = Color(0xFFF8FAFC);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightText = Color(0xFF0F172A);
  static const _lightMuted = Color(0xFF64748B);
  static const _darkCanvas = Color(0xFF0B0F19);
  static const _darkSurface = Color(0xFF161B26);
  static const _darkText = Color(0xFFF1F5F9);
  static const _darkMuted = Color(0xFF94A3B8);

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: _accent,
      onPrimary: Colors.white,
      primaryContainer: _accentTint,
      onPrimaryContainer: _lightText,
      secondary: _success,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD1FAE5),
      onSecondaryContainer: Color(0xFF064E3B),
      tertiary: _lightMuted,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE2E8F0),
      onTertiaryContainer: _lightText,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: _lightSurface,
      onSurface: _lightText,
      surfaceContainerLowest: _lightSurface,
      surfaceContainerLow: _lightSurface,
      surfaceContainer: Color(0xFFF1F5F9),
      surfaceContainerHigh: Color(0xFFE2E8F0),
      surfaceContainerHighest: Color(0xFFCBD5E1),
      onSurfaceVariant: _lightMuted,
      outline: _lightMuted,
      outlineVariant: Color(0xFFCBD5E1),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: _darkSurface,
      onInverseSurface: _darkText,
      inversePrimary: _accentTint,
    );
    return _theme(scheme);
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _accentTint,
      onPrimary: Color(0xFF2E1065),
      primaryContainer: _accent,
      onPrimaryContainer: Colors.white,
      secondary: _success,
      onSecondary: Color(0xFF022C22),
      secondaryContainer: Color(0xFF065F46),
      onSecondaryContainer: Color(0xFFD1FAE5),
      tertiary: _darkMuted,
      onTertiary: _darkCanvas,
      tertiaryContainer: Color(0xFF334155),
      onTertiaryContainer: _darkText,
      error: Color(0xFFFCA5A5),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: _darkSurface,
      onSurface: _darkText,
      surfaceContainerLowest: _darkCanvas,
      surfaceContainerLow: _darkSurface,
      surfaceContainer: Color(0xFF1E293B),
      surfaceContainerHigh: Color(0xFF334155),
      surfaceContainerHighest: Color(0xFF475569),
      onSurfaceVariant: _darkMuted,
      outline: _darkMuted,
      outlineVariant: Color(0xFF334155),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: _darkText,
      onInverseSurface: _darkCanvas,
      inversePrimary: _accent,
    );
    return _theme(scheme);
  }

  static ThemeData _theme(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: scheme.brightness == Brightness.light
          ? _lightCanvas
          : _darkCanvas,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
    );
  }
}
