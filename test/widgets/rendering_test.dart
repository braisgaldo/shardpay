import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/app/preferences.dart';
import 'package:shardpay/app/theme.dart';
import 'package:shardpay/core/receipts/receipt_parser.dart';
import 'package:shardpay/core/sample_ledger.dart';
import 'package:shardpay/screens/receipts/receipt_scan_summary.dart';
import 'package:shardpay/widgets/donation/coffee_cup_illustration.dart';
import 'package:shardpay/widgets/language_flag.dart';
import 'package:shardpay/widgets/tour/tour_ledger_example.dart';

/// Tipografia completa: el tema espera que los estilos existan y Space Grotesk
/// no se puede descargar en una prueba.
final TextTheme _tipografia = Typography.material2021().black;

/// Monta un widget con el tema y el idioma indicados.
Future<void> montar(
  WidgetTester tester,
  Widget child, {
  required AppThemeOption tema,
  Locale locale = const Locale('es'),
  bool reducirAnimaciones = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildShardPayTheme(tema, baseTextTheme: _tipografia),
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedAppLocales,
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reducirAnimaciones),
            child: Scaffold(body: Center(child: child)),
          );
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

ReceiptScan _escaneo({
  required List<ReceiptLineItem> items,
  double? total,
  List<ReceiptWarning> warnings = const <ReceiptWarning>[],
  double confidence = 0.9,
}) {
  return ReceiptScan(items: items, warnings: warnings, confidence: confidence, total: total, merchant: 'Bar La Plaza');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tablas del grupo de ejemplo', () {
    // Estas tres tablas salen en el tour, en la ayuda y en catorce idiomas, y
    // van dentro de tarjetas estrechas. Son justo el tipo de widget que se
    // desborda en silencio con una traduccion larga o en arabe.
    const ejemplos = <String, Widget>{
      'gastos': TourExpensesExample(),
      'saldos': TourBalancesExample(),
      'deudas directas': TourDirectDebtsExample(),
      'liquidacion': TourSettlementExample(),
    };

    for (final entrada in ejemplos.entries) {
      testWidgets('${entrada.key}: se dibuja en las trece paletas', (tester) async {
        for (final tema in appThemeOptions) {
          await montar(tester, SizedBox(width: 320, child: entrada.value), tema: tema);
          expect(tester.takeException(), isNull, reason: 'la tabla de ${entrada.key} falla con la paleta ${tema.id}');
        }
      });

      testWidgets('${entrada.key}: se dibuja en arabe, de derecha a izquierda', (tester) async {
        await montar(
          tester,
          SizedBox(width: 320, child: entrada.value),
          tema: appThemeOptions.first,
          locale: const Locale('ar'),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('las cifras que se dibujan son las del ejemplo comprobado', (tester) async {
      await montar(tester, const SizedBox(width: 320, child: TourSettlementExample()), tema: appThemeOptions.first);

      // Si alguien cambia sampleSettlements sin mirar, esto lo caza: la tarjeta
      // tiene que enseñar a las dos personas que pagan y a las dos que cobran.
      for (final pago in sampleSettlements) {
        expect(find.text(pago.from), findsOneWidget);
        expect(find.text(pago.to), findsOneWidget);
      }
    });
  });

  group('ilustracion de la taza', () {
    // Se dibuja con los tokens del tema activo, asi que tiene que sobrevivir a
    // las trece paletas sin excepciones ni colores nulos.
    for (final tema in appThemeOptions) {
      testWidgets('se dibuja en la paleta ${tema.id}', (tester) async {
        await montar(tester, const CoffeeCupIllustration(semanticsLabel: 'Taza de cafe'), tema: tema);

        expect(find.byType(CoffeeCupIllustration), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('se dibuja en arabe, con la interfaz de derecha a izquierda', (tester) async {
      await montar(
        tester,
        const CoffeeCupIllustration(semanticsLabel: 'كوب قهوة'),
        tema: appThemeOptions.first,
        locale: const Locale('ar'),
      );

      expect(find.byType(CoffeeCupIllustration), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lleva descripcion para lectores de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester, const CoffeeCupIllustration(semanticsLabel: 'Taza de cafe con vapor'), tema: appThemeOptions.first);

      expect(find.bySemanticsLabel('Taza de cafe con vapor'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('respeta la preferencia de reducir animaciones', (tester) async {
      await montar(
        tester,
        const CoffeeCupIllustration(semanticsLabel: 'Taza de cafe'),
        tema: appThemeOptions.first,
        reducirAnimaciones: true,
      );

      // Con las animaciones reducidas no queda ningun temporizador pendiente:
      // si el vapor siguiera animandose, `pumpAndSettle` se colgaria.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('resumen de la lectura del ticket', () {
    final lecturaBuena = _escaneo(
      items: const [
        ReceiptLineItem(name: 'Cerveza', amount: 2.50),
        ReceiptLineItem(name: 'Tortilla', amount: 6.80),
      ],
      total: 9.30,
    );

    final lecturaParcial = _escaneo(
      items: const [
        ReceiptLineItem(name: 'Cerveza', amount: 2.50),
        ReceiptLineItem(name: '', amount: 6.80, kind: ReceiptItemKind.adjustment),
      ],
      total: 9.30,
      warnings: const [ReceiptWarning.adjustmentAdded],
      confidence: 0.5,
    );

    final lecturaMala = _escaneo(
      items: const [],
      warnings: const [ReceiptWarning.noItemsDetected, ReceiptWarning.lowTextQuality],
      confidence: 0,
    );

    for (final tema in appThemeOptions) {
      testWidgets('se dibuja en la paleta ${tema.id}', (tester) async {
        await montar(
          tester,
          ReceiptScanSummary(scan: lecturaBuena, currency: 'EUR'),
          tema: tema,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('avisa cuando la lectura cuadra con el total', (tester) async {
      await montar(
        tester,
        ReceiptScanSummary(scan: lecturaBuena, currency: 'EUR'),
        tema: appThemeOptions.first,
      );

      expect(find.textContaining('cuadrado'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('avisa cuando se anadio una linea de ajuste', (tester) async {
      await montar(
        tester,
        ReceiptScanSummary(scan: lecturaParcial, currency: 'EUR'),
        tema: appThemeOptions.first,
      );

      expect(find.textContaining('línea de ajuste'), findsOneWidget);
    });

    testWidgets('avisa cuando no se pudo leer casi nada', (tester) async {
      await montar(
        tester,
        ReceiptScanSummary(scan: lecturaMala, currency: 'EUR'),
        tema: appThemeOptions.first,
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      // El titular y el aviso de calidad hablan los dos de la luz: basta con
      // que el consejo aparezca.
      expect(find.textContaining('más luz'), findsAtLeastNWidgets(1));
    });

    testWidgets('se dibuja en arabe sin desbordarse', (tester) async {
      await montar(
        tester,
        ReceiptScanSummary(scan: lecturaParcial, currency: 'EUR'),
        tema: appThemeOptions.first,
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('bandera de idioma', () {
    for (final option in appLanguageOptions) {
      testWidgets('se dibuja la del idioma ${option.code}', (tester) async {
        await montar(tester, LanguageFlag(code: option.code), tema: appThemeOptions.first);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('el ingles y el arabe usan icono neutro', (tester) async {
      for (final codigo in LanguageFlag.neutralIconCodes) {
        await montar(tester, LanguageFlag(code: codigo), tema: appThemeOptions.first);
        expect(find.byIcon(Icons.translate_rounded), findsOneWidget, reason: 'el idioma $codigo deberia usar icono neutro');
      }
    });
  });
}
