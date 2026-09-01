import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/app/preferences.dart';
import 'package:shardpay/app/theme.dart';
import 'package:shardpay/core/donation_policy.dart';

/// Luminancia relativa según WCAG 2.1.
double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// Relación de contraste entre dos colores, de 1:1 a 21:1.
double contrastRatio(Color foreground, Color background) {
  final a = _relativeLuminance(foreground);
  final b = _relativeLuminance(background);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Tipografia completa para inyectar en las pruebas: el tema exige que los
/// estilos existan, y un `TextTheme()` vacio los deja todos a null.
final TextTheme _tipografiaDePrueba = Typography.material2021().black;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('paletas', () {
    test('hay al menos tres claras y tres oscuras', () {
      final claras = appThemeOptions.where((option) => !option.isDark).length;
      final oscuras = appThemeOptions.where((option) => option.isDark).length;

      expect(claras, greaterThanOrEqualTo(3), reason: 'el proyecto exige al menos tres temas claros');
      expect(oscuras, greaterThanOrEqualTo(3), reason: 'el proyecto exige al menos tres temas oscuros');
      expect(appThemeOptions.length, greaterThanOrEqualTo(6));
    });

    test('los identificadores no se repiten', () {
      final ids = appThemeOptions.map((option) => option.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('cada paleta tiene una hermana del brillo contrario', () {
      // Es lo que hace posible «Seguir el sistema» sin cambiar de estética.
      for (final option in appThemeOptions) {
        final counterpart = appThemeOptions.where((entry) => entry.id == option.counterpartId).toList();
        expect(counterpart, hasLength(1), reason: 'la hermana de ${option.id} no existe: ${option.counterpartId}');
        expect(counterpart.single.isDark, isNot(option.isDark), reason: '${option.id} y ${option.counterpartId} tienen el mismo brillo');
      }
    });

    test('resolvedTheme respeta el modo elegido y el del sistema', () {
      for (final option in appThemeOptions) {
        final preferences = AppPreferences(
          themeId: option.id,
          themeMode: AppThemeMode.system,
          languageCode: 'es',
          hasSeenManual: false,
          expenseNotificationsEnabled: true,
          refundNotificationsEnabled: true,
          refundRequestNotificationsEnabled: true,
          donation: const DonationState(),
        );

        expect(preferences.lightTheme.isDark, isFalse);
        expect(preferences.darkTheme.isDark, isTrue);
        expect(preferences.resolvedTheme(Brightness.light).isDark, isFalse);
        expect(preferences.resolvedTheme(Brightness.dark).isDark, isTrue);

        expect(preferences.copyWith(themeMode: AppThemeMode.light).resolvedTheme(Brightness.dark).isDark, isFalse);
        expect(preferences.copyWith(themeMode: AppThemeMode.dark).resolvedTheme(Brightness.light).isDark, isTrue);
      }
    });
  });

  group('contraste', () {
    // El proyecto exige contraste AA: 4,5:1 en texto normal y 3:1 en texto
    // grande y en elementos de interfaz. Se comprueba, no se supone.
    const minimoTextoNormal = 4.5;
    const minimoTextoGrande = 3.0;

    for (final option in appThemeOptions) {
      test('${option.id}: el texto se lee sobre el lienzo y sobre las tarjetas', () {
        expect(
          contrastRatio(option.ink, option.canvas),
          greaterThanOrEqualTo(minimoTextoNormal),
          reason: 'tinta sobre lienzo en ${option.label}',
        );
        expect(
          contrastRatio(option.ink, option.card),
          greaterThanOrEqualTo(minimoTextoNormal),
          reason: 'tinta sobre tarjeta en ${option.label}',
        );
      });

      test('${option.id}: el texto de los botones se lee sobre el acento', () {
        final scheme = buildShardPayTheme(option, baseTextTheme: _tipografiaDePrueba).colorScheme;

        expect(
          contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(minimoTextoNormal),
          reason: 'onPrimary sobre primary en ${option.label}',
        );
        expect(
          contrastRatio(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(minimoTextoNormal),
          reason: 'onSecondary sobre secondary en ${option.label}',
        );
      });

      test('${option.id}: el acento se distingue del fondo', () {
        // El acento se usa en iconos, bordes y estados seleccionados, que son
        // elementos de interfaz: el umbral aplicable es 3:1.
        expect(
          contrastRatio(option.accent, option.canvas),
          greaterThanOrEqualTo(minimoTextoGrande),
          reason: 'acento sobre lienzo en ${option.label}',
        );
      });
    }
  });

  group('buildShardPayTheme', () {
    test('usa Material 3 y el brillo de la paleta', () {
      for (final option in appThemeOptions) {
        final theme = buildShardPayTheme(option, baseTextTheme: _tipografiaDePrueba);
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, option.brightness);
        expect(theme.scaffoldBackgroundColor, option.canvas);
        expect(theme.colorScheme.primary, option.accent);
      }
    });
  });

  group('texto sobre superficie', () {
    // Aprendido a base de medirlo: el color de acento NO sirve como color de
    // texto sobre la superficie. En la paleta clara, `primary` sobre `surface`
    // da 3,58:1, por debajo del 4,5:1 que exige AA para texto de 16sp. El botón
    // de compartir de Ajustes se hizo primero así y estaba mal.
    //
    // Lo que sí se puede exigir, y estas dos pruebas lo fijan: que el texto
    // normal pase AA, y que el acento valga al menos como borde de un control.
    test('el texto normal pasa AA en las trece paletas', () {
      for (final tema in appThemeOptions) {
        final esquema = buildShardPayTheme(tema, baseTextTheme: _tipografiaDePrueba).colorScheme;
        expect(
          contrastRatio(esquema.onSurface, esquema.surface),
          greaterThanOrEqualTo(minimumTextContrast),
          reason: 'texto sobre superficie en la paleta ${tema.id}',
        );
      }
    });

    test('el acento vale como borde de control en las trece paletas', () {
      // 3:1 es el mínimo de WCAG 1.4.11 para elementos no textuales.
      for (final tema in appThemeOptions) {
        final esquema = buildShardPayTheme(tema, baseTextTheme: _tipografiaDePrueba).colorScheme;
        expect(
          contrastRatio(esquema.primary, esquema.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'borde de acento sobre superficie en la paleta ${tema.id}',
        );
      }
    });
  });
}
