import 'package:flutter/material.dart';

/// Palette. Kept as plain constants so widgets can reach for a specific hue
/// (mineral blue for water facts, apricot for health warnings) without
/// stretching the semantic ColorScheme slots out of shape.
abstract final class Botanic {
  static const Color ink = Color(0xFF12291E);
  static const Color inkSoft = Color(0xFF4C5F53);
  static const Color surface = Color(0xFFE6EBE1);
  static const Color card = Color(0xFFF2F5EE);
  static const Color chlorophyll = Color(0xFF2F7A52);
  static const Color chlorophyllDeep = Color(0xFF1F5638);
  static const Color mineral = Color(0xFF3E6E8C);
  static const Color apricot = Color(0xFFD98F45);
  static const Color rust = Color(0xFFA5462F);
  static const Color hairline = Color(0xFFCBD4C4);
}

ThemeData buildPlantScanTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Botanic.chlorophyll,
    onPrimary: Color(0xFFF6F8F3),
    primaryContainer: Botanic.chlorophyllDeep,
    onPrimaryContainer: Color(0xFFF6F8F3),
    secondary: Botanic.mineral,
    onSecondary: Color(0xFFF6F8F3),
    tertiary: Botanic.apricot,
    onTertiary: Botanic.ink,
    error: Botanic.rust,
    onError: Color(0xFFF6F8F3),
    surface: Botanic.surface,
    onSurface: Botanic.ink,
    surfaceContainerHighest: Botanic.card,
    onSurfaceVariant: Botanic.inkSoft,
    outline: Botanic.hairline,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: Botanic.surface,
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 34,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.9,
          ),
          headlineSmall: const TextStyle(
            fontSize: 23,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: const TextStyle(fontSize: 14.5, height: 1.45),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          labelSmall: const TextStyle(
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.35,
          ),
        )
        .apply(bodyColor: Botanic.ink, displayColor: Botanic.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Botanic.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Botanic.ink,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Botanic.ink,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: Botanic.ink,
        side: const BorderSide(color: Botanic.hairline, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Botanic.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Botanic.chlorophyll.withValues(alpha: 0.16),
      height: 66,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Botanic.ink,
      contentTextStyle: TextStyle(color: Color(0xFFF2F5EE), fontSize: 14.5),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
      color: Botanic.hairline,
      thickness: 1,
      space: 1,
    ),
  );
}
