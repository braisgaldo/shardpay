import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/app/preferences.dart';
import 'package:shardpay/app/theme.dart';
import 'package:shardpay/widgets/tour/guided_tour.dart';
import 'package:shardpay/widgets/tour/tour_ledger_example.dart';

/// El tour se dibuja encima de todo y con la tarjeta anclada a un elemento
/// concreto. Si el texto de un paso crece —y crece cada vez que se traduce a un
/// idioma mas largo— la tarjeta puede desbordar la pantalla y dejar «Siguiente»
/// fuera. Entonces el tour no se puede ni terminar ni saltar.
///
/// Estas pruebas lo montan en la pantalla mas pequena que la app soporta.
final TextTheme _tipografia = Typography.material2021().black;

const String _textoLargo =
    'Cuatro amigos se van de viaje y cada uno paga lo que le toca sobre la marcha. '
    'Al final del fin de semana hay cinco deudas cruzadas por 54 euros, y ShardPay '
    'las cruza y propone dos pagos por 48 euros sin que nadie gane ni pierda un '
    'centimo, porque lo unico que cambia es a quien se le transfiere el dinero.';

Future<void> _montarTour(
  WidgetTester tester, {
  required List<TourStep> pasos,
  required GlobalKey ancla,
  Locale locale = const Locale('es'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildShardPayTheme(appThemeOptions.first, baseTextTheme: _tipografia),
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedAppLocales,
      home: Scaffold(
        body: Center(child: SizedBox(key: ancla, width: 120, height: 48)),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(onPressed: () => showGuidedTour(context, pasos), child: const Icon(Icons.play_arrow)),
        ),
      ),
    ),
  );

  await tester.tap(find.byType(FloatingActionButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tour guiado', () {
    // Un movil pequeno de gama baja, que es donde esto se rompe.
    setUp(() {
      // ignore: deprecated_member_use
      final vista = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      vista.physicalSize = const Size(360 * 3, 640 * 3);
      vista.devicePixelRatio = 3;
    });

    tearDown(() {
      // ignore: deprecated_member_use
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize();
    });

    testWidgets('la tarjeta con ilustración cabe en una pantalla de 360x640', (tester) async {
      final ancla = GlobalKey();

      await _montarTour(
        tester,
        ancla: ancla,
        pasos: [
          TourStep(
            title: 'Con dos pagos queda saldado',
            body: _textoLargo,
            icon: Icons.account_tree_rounded,
            targetKey: ancla,
            illustration: const TourSettlementExample(),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('los botones siguen siendo alcanzables con el paso más alto', (tester) async {
      final ancla = GlobalKey();

      await _montarTour(
        tester,
        ancla: ancla,
        pasos: [
          TourStep(
            title: 'Los gastos del viaje',
            body: '$_textoLargo $_textoLargo',
            icon: Icons.receipt_long_rounded,
            targetKey: ancla,
            illustration: const TourExpensesExample(),
          ),
          const TourStep(title: 'Segundo paso', body: 'Corto.', icon: Icons.check_rounded),
        ],
      );

      // Si la tarjeta desbordara, «Siguiente» quedaria fuera de la pantalla y
      // este toque no llegaria al boton.
      expect(find.text('Siguiente'), findsOneWidget);
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      expect(find.text('Segundo paso'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
    });

    testWidgets('se puede saltar el tour desde el primer paso', (tester) async {
      final ancla = GlobalKey();

      await _montarTour(
        tester,
        ancla: ancla,
        pasos: [
          TourStep(
            title: 'Primero',
            body: _textoLargo,
            icon: Icons.info_rounded,
            targetKey: ancla,
            illustration: const TourBalancesExample(),
          ),
          const TourStep(title: 'Segundo', body: 'Corto.', icon: Icons.check_rounded),
        ],
      );

      await tester.tap(find.text('Saltar el tour'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      expect(find.text('Primero'), findsNothing);
    });
  });
}
