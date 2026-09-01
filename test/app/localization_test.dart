import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/app/app_text.dart';
import 'package:shardpay/app/preferences.dart';
import 'package:shardpay/widgets/language_flag.dart';

/// Los trece idiomas que el proyecto exige.
const _idiomasExigidos = <String>{'en', 'es', 'fr', 'de', 'zh', 'ja', 'ru', 'it', 'el', 'ar', 'gl', 'ca', 'eu'};

void main() {
  group('idiomas', () {
    test('estan los trece exigidos', () {
      final disponibles = appLanguageOptions.map((option) => option.code).toSet();
      final faltan = _idiomasExigidos.difference(disponibles);

      expect(faltan, isEmpty, reason: 'faltan idiomas obligatorios: $faltan');
      expect(appLanguageOptions.length, greaterThanOrEqualTo(13));
    });

    test('no hay codigos repetidos y cada uno tiene su nombre nativo', () {
      final codigos = appLanguageOptions.map((option) => option.code).toList();
      expect(codigos.toSet().length, codigos.length);

      for (final option in appLanguageOptions) {
        expect(option.label.trim(), isNotEmpty, reason: 'el idioma ${option.code} no tiene nombre');
        expect(option.locale.languageCode, option.code);
      }
    });

    test('el arabe es el unico de derecha a izquierda', () {
      final rtl = appLanguageOptions.where((option) => option.isRtl).map((option) => option.code).toList();
      expect(rtl, <String>['ar']);

      final arabe = appLanguageOptions.firstWhere((option) => option.code == 'ar');
      expect(arabe.textDirection, TextDirection.rtl);
    });

    test('el ingles y el arabe usan icono neutro en lugar de bandera nacional', () {
      // Ninguno de los dos pertenece a un pais concreto: elegirle uno a dedo es
      // una decision politica gratuita en una app de dividir cuentas.
      final neutros = appLanguageOptions.where((option) => option.usesNeutralIcon).map((option) => option.code).toSet();
      expect(neutros, <String>{'en', 'ar'});
      expect(neutros, LanguageFlag.neutralIconCodes);
    });

    test('supportedAppLocales coincide con la lista de idiomas', () {
      expect(supportedAppLocales.map((locale) => locale.languageCode).toList(), appLanguageOptions.map((option) => option.code).toList());
    });

    test('flutter_localizations sabe traducir todos los idiomas ofrecidos', () {
      // Si un idioma no esta soportado por las traducciones de Material, los
      // textos del sistema (botones de dialogo, selector de fecha) saldrian en
      // ingles dentro de una interfaz traducida.
      for (final option in appLanguageOptions) {
        expect(
          GlobalMaterialLocalizations.delegate.isSupported(option.locale),
          isTrue,
          reason: 'Material no tiene traducciones para ${option.code}',
        );
        expect(
          GlobalCupertinoLocalizations.delegate.isSupported(option.locale),
          isTrue,
          reason: 'Cupertino no tiene traducciones para ${option.code}',
        );
      }
    });

    test('locales_config.xml coincide con los idiomas de la app', () {
      // Es lo que hace que Android 13 ofrezca el idioma por app. Si las dos
      // listas se separan, el ajuste del sistema ensena idiomas que la app no
      // tiene, o se deja fuera alguno que si tiene.
      final fichero = File('android/app/src/main/res/xml/locales_config.xml');
      expect(fichero.existsSync(), isTrue, reason: 'falta locales_config.xml');

      final contenido = fichero.readAsStringSync();
      final declarados = RegExp('android:name="([a-zA-Z-]+)"').allMatches(contenido).map((match) => match.group(1)!).toSet();

      expect(
        declarados,
        appLanguageOptions.map((option) => option.code).toSet(),
        reason: 'locales_config.xml y appLanguageOptions no coinciden',
      );
    });

    test('el manifiesto declara soporte de derecha a izquierda', () {
      final manifiesto = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifiesto, contains('android:supportsRtl="true"'));
      expect(manifiesto, contains('android:localeConfig="@xml/locales_config"'));
    });
  });

  group('tr()', () {
    Future<String> traducir(WidgetTester tester, Locale locale, String Function(BuildContext) build) async {
      late String resultado;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedAppLocales,
          home: Builder(
            builder: (context) {
              resultado = build(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return resultado;
    }

    testWidgets('devuelve el castellano cuando el idioma es castellano', (tester) async {
      final texto = await traducir(tester, const Locale('es'), (context) => tr(context, es: 'Ajustes', en: 'Settings'));
      expect(texto, 'Ajustes');
    });

    testWidgets('devuelve el ingles cuando el idioma es ingles', (tester) async {
      final texto = await traducir(tester, const Locale('en'), (context) => tr(context, es: 'Ajustes', en: 'Settings'));
      expect(texto, 'Settings');
    });

    testWidgets('los idiomas romances caen al castellano y no al ingles', (tester) async {
      // Quien habla catalan o gallego entiende mejor el castellano que el
      // ingles: el respaldo tiene que ir en esa direccion.
      for (final codigo in <String>['gl', 'ca', 'fr', 'it', 'pt']) {
        final texto = await traducir(tester, Locale(codigo), (context) => tr(context, es: 'Sin traducir', en: 'Untranslated'));
        expect(texto, 'Sin traducir', reason: 'el idioma $codigo deberia caer al castellano');
      }
    });

    testWidgets('los demas idiomas se resuelven contra el catalogo', (tester) async {
      // «Settings» esta en el catalogo de los cuatro, asi que ninguno deberia
      // devolver el texto ingles tal cual.
      for (final codigo in <String>['de', 'ru', 'ar', 'el']) {
        final texto = await traducir(tester, Locale(codigo), (context) => tr(context, es: 'Ajustes', en: 'Settings'));
        expect(texto, isNot('Settings'), reason: 'el idioma $codigo no encontro la traduccion en su catalogo');
        expect(texto, isNot('Ajustes'));
      }
    });

    testWidgets('el arabe pone la interfaz de derecha a izquierda', (tester) async {
      late TextDirection direccion;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedAppLocales,
          home: Builder(
            builder: (context) {
              direccion = Directionality.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(direccion, TextDirection.rtl);
    });

    testWidgets('el castellano deja la interfaz de izquierda a derecha', (tester) async {
      late TextDirection direccion;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedAppLocales,
          home: Builder(
            builder: (context) {
              direccion = Directionality.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(direccion, TextDirection.ltr);
    });
  });

  group('plurales de recuento', () {
    // «1 grupos» y «1 miembros» salian en la pantalla de saldo global y en la
    // ficha de cada grupo. No rompe nada y se ve en la primera captura que
    // alguien mira.
    Future<String> etiqueta(WidgetTester tester, String idioma, String Function(BuildContext) construir) async {
      late String resultado;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(idioma),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedAppLocales,
          home: Builder(
            builder: (context) {
              resultado = construir(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return resultado;
    }

    testWidgets('un grupo va en singular en los idiomas que lo marcan', (tester) async {
      for (final idioma in <String>['es', 'en', 'gl', 'ca', 'fr', 'it', 'pt', 'de']) {
        final uno = await etiqueta(tester, idioma, (context) => groupCountLabel(context, 1));
        final varios = await etiqueta(tester, idioma, (context) => groupCountLabel(context, 3));

        expect(uno, isNot(contains('1 grupos')), reason: 'plural mal en $idioma');
        expect(uno, isNot(varios), reason: 'singular y plural iguales en $idioma');
        expect(varios, contains('3'), reason: 'falta el numero en $idioma');
      }
    });

    testWidgets('un miembro va en singular en los idiomas que lo marcan', (tester) async {
      for (final idioma in <String>['es', 'en', 'gl', 'ca', 'fr', 'it', 'pt', 'de']) {
        final uno = await etiqueta(tester, idioma, (context) => memberCountLabel(context, 1));
        final varios = await etiqueta(tester, idioma, (context) => memberCountLabel(context, 5));

        expect(uno, isNot(contains('1 miembros')), reason: 'plural mal en $idioma');
        expect(uno, isNot(varios), reason: 'singular y plural iguales en $idioma');
        expect(varios, contains('5'), reason: 'falta el numero en $idioma');
      }
    });

    testWidgets('los catorce idiomas devuelven algo con el numero dentro', (tester) async {
      for (final opcion in appLanguageOptions) {
        final texto = await etiqueta(tester, opcion.code, (context) => groupCountLabel(context, 7));
        expect(texto.trim(), isNotEmpty, reason: 'sin texto en ${opcion.code}');
        expect(texto, contains('7'), reason: 'falta el numero en ${opcion.code}');
      }
    });
  });
}
