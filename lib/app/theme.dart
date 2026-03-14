import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'preferences.dart';

Color colorOn(Color background, {Color light = Colors.white, Color dark = const Color(0xFF101522)}) {
  final lightContrast = ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
  return lightContrast ? light : dark;
}

ThemeData buildShardPayTheme(AppThemeOption option) {
  final textTheme = GoogleFonts.spaceGroteskTextTheme().apply(
    bodyColor: option.ink,
    displayColor: option.ink,
  );
  final onAccent = colorOn(option.accent, dark: option.ink);
  final onSecondary = colorOn(option.secondary, dark: option.ink);

  final scheme = ColorScheme.fromSeed(
    seedColor: option.accent,
    brightness: option.brightness,
    surface: option.card,
  ).copyWith(
    primary: option.accent,
    secondary: option.secondary,
    surface: option.card,
    onSurface: option.ink,
    onPrimary: onAccent,
    onSecondary: onSecondary,
    onPrimaryContainer: colorOn(option.accent.withValues(alpha: 0.18), dark: option.ink),
    onSecondaryContainer: colorOn(option.secondary.withValues(alpha: 0.18), dark: option.ink),
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
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.onPrimaryContainer);
        }
        return IconThemeData(color: scheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
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
      isDense: false,
      labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.2),
      floatingLabelStyle: textTheme.labelLarge?.copyWith(color: option.accent, fontWeight: FontWeight.w700, height: 1.1),
      alignLabelWithHint: true,
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
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      contentPadding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: option.accent.withValues(alpha: 0.10),
      selectedColor: option.accent.withValues(alpha: 0.18),
      labelStyle: textTheme.labelMedium!.copyWith(color: scheme.onPrimaryContainer),
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