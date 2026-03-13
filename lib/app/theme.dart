import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'preferences.dart';

ThemeData buildShardPayTheme(AppThemeOption option) {
  final textTheme = GoogleFonts.spaceGroteskTextTheme().apply(
    bodyColor: option.ink,
    displayColor: option.ink,
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: option.accent,
    brightness: option.brightness,
    surface: option.card,
  ).copyWith(
    primary: option.accent,
    secondary: option.secondary,
    surface: option.card,
    onSurface: option.ink,
    onPrimary: option.brightness == Brightness.dark ? option.canvas : Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: option.brightness,
    scaffoldBackgroundColor: option.canvas,
    colorScheme: scheme,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: option.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: option.card,
      indicatorColor: option.accent.withValues(alpha: 0.14),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: option.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: option.brightness == Brightness.dark ? option.card.withValues(alpha: 0.9) : Colors.white,
      labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: textTheme.labelLarge?.copyWith(color: option.accent, fontWeight: FontWeight.w700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: option.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD00036), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD00036), width: 1.6),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: option.accent.withValues(alpha: 0.10),
      selectedColor: option.accent.withValues(alpha: 0.18),
      labelStyle: textTheme.labelMedium!,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: option.brightness == Brightness.dark ? option.card.withValues(alpha: 0.9) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        ),
      ),
    ),
  );
}