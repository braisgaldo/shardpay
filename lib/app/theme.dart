import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'preferences.dart';

/// Luminancia relativa segun WCAG 2.1.
double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// Relacion de contraste entre dos colores, de 1:1 a 21:1.
double contrastRatio(Color foreground, Color background) {
  final first = _relativeLuminance(foreground);
  final second = _relativeLuminance(background);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Contraste minimo exigido para texto normal por WCAG AA.
const double minimumTextContrast = 4.5;

/// Elige el color de texto que mejor se lee sobre [background].
///
/// La version anterior usaba `ThemeData.estimateBrightnessForColor`, que decide
/// por un umbral de luminancia de 0,15 y no por contraste real. El resultado era
/// que **las trece paletas** ponian texto blanco sobre acentos claros: el naranja
/// del tema por defecto daba 3,68:1 cuando AA exige 4,5:1. Aqui se calcula la
/// relacion de contraste de verdad y, si ninguno de los dos candidatos del tema
/// llega al minimo, se recurre al blanco o al negro puros.
Color colorOn(Color background, {Color light = Colors.white, Color dark = const Color(0xFF101522)}) {
  final withLight = contrastRatio(light, background);
  final withDark = contrastRatio(dark, background);

  if (withLight >= minimumTextContrast || withDark >= minimumTextContrast) {
    return withLight >= withDark ? light : dark;
  }

  // Ningun color del tema se lee sobre este fondo: se usa el extremo que mas
  // contraste da. Es preferible un negro puro que un texto ilegible.
  return contrastRatio(Colors.white, background) >= contrastRatio(Colors.black, background) ? Colors.white : Colors.black;
}

/// Construye el tema completo a partir de una paleta.
///
/// [baseTextTheme] existe para las pruebas: por defecto se usa Space Grotesk de
/// Google Fonts, que se descarga en tiempo de ejecucion y por tanto no esta
/// disponible en un entorno de prueba sin red. Inyectando una tipografia vacia
/// se puede comprobar la parte que importa —los colores y sus contrastes— sin
/// depender de una descarga.
ThemeData buildShardPayTheme(AppThemeOption option, {TextTheme? baseTextTheme}) {
  final textTheme = (baseTextTheme ?? GoogleFonts.spaceGroteskTextTheme()).apply(bodyColor: option.ink, displayColor: option.ink);
  final onAccent = colorOn(option.accent, dark: option.ink);
  final onSecondary = colorOn(option.secondary, dark: option.ink);

  final scheme = ColorScheme.fromSeed(seedColor: option.accent, brightness: option.brightness, surface: option.card).copyWith(
    primary: option.accent,
    secondary: option.secondary,
    surface: option.card,
    onSurface: option.ink,
    onPrimary: onAccent,
    onSecondary: onSecondary,
    onPrimaryContainer: colorOn(Color.alphaBlend(option.accent.withValues(alpha: 0.18), option.card), dark: option.ink),
    onSecondaryContainer: colorOn(Color.alphaBlend(option.secondary.withValues(alpha: 0.18), option.card), dark: option.ink),
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
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
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
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary),
    cardTheme: CardThemeData(
      color: option.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // El relleno sale del token de la paleta, no de un blanco fijo.
      fillColor: option.isDark ? option.card.withValues(alpha: 0.9) : option.card,
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
      labelStyle: textTheme.labelMedium!.copyWith(
        color: colorOn(Color.alphaBlend(option.accent.withValues(alpha: 0.10), option.card), dark: option.ink),
      ),
      secondaryLabelStyle: textTheme.labelMedium!.copyWith(
        color: colorOn(Color.alphaBlend(option.accent.withValues(alpha: 0.18), option.card), dark: option.ink),
      ),
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
        fillColor: option.isDark ? option.card.withValues(alpha: 0.9) : option.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        ),
      ),
    ),
  );
}
