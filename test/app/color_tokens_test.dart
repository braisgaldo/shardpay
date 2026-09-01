import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Trinquete de colores a fuego en la interfaz.
///
/// El proyecto exige que todos los colores salgan de los tokens de
/// `AppThemeOption`, y que no haya colores sueltos por las pantallas. Hoy no se
/// cumple: quedan 142 literales repartidos por la interfaz, casi todos colores
/// semánticos (verde de saldo a favor, rojo de deuda, ámbar de aviso) y paletas
/// de gráficas, que **todavía no existen como token**.
///
/// Barrer los 142 de golpe significaría reescribir cinco pantallas grandes sin
/// poder revisarlas una a una, así que en lugar de eso esta prueba **congela la
/// deuda**: fija el número actual por fichero y falla si alguien lo sube. El
/// código nuevo tiene que usar tokens.
///
/// Para bajarlo hay que añadir los tokens semánticos que faltan a
/// `AppThemeOption` (`positive`, `negative`, `warning`, `info` y una paleta de
/// gráficas) y migrar fichero a fichero, bajando el número de esta tabla en el
/// mismo commit.
///
/// **Por qué existe esta prueba.** Al probar en un dispositivo real con el tema
/// del sistema en oscuro, la pantalla de acceso salía con la tarjeta blanca fija
/// y el texto claro del tema encima: ilegible. Ese `Colors.white` llevaba ahí
/// desde el principio y solo se vio cuando el modo oscuro dejó de ser
/// inalcanzable.
void main() {
  /// Literales permitidos hoy, por fichero.
  ///
  /// Un cero significa «este fichero ya está limpio y tiene que seguir así».
  const permitidos = <String, int>{
    // --- Ficheros limpios: no pueden volver atrás ----------------------------
    'lib/screens/receipts/receipt_scan_summary.dart': 0,
    'lib/screens/settings/about_screen.dart': 0,
    'lib/screens/settings/help_screen.dart': 0,
    'lib/widgets/brand_mark.dart': 0,
    'lib/screens/groups/add_expense_screen.dart': 0,
    'lib/screens/settings/settings_sections.dart': 0,
    'lib/widgets/tour/shardpay_tour.dart': 0,

    // --- Justificados -------------------------------------------------------
    // El identificador de marca y una sombra suave; son la identidad visual,
    // no el tema.
    'lib/screens/auth/auth_screen.dart': 2,
    // Los colores de las banderas son los de las banderas: no pueden depender
    // del tema.
    'lib/widgets/language_flag.dart': 8,
    // La pantalla de captura se dibuja sobre una vista de cámara en vivo, no
    // sobre una superficie del tema: los controles tienen que leerse sobre
    // cualquier imagen.
    'lib/screens/receipts/receipt_scanner_screen.dart': 15,
    // Las líneas de la rejilla de recorte van sobre la foto.
    'lib/screens/receipts/receipt_image_editor_screen.dart': 2,
    // El QR necesita blanco puro para poder escanearse en los temas oscuros.
    'lib/widgets/donation/donation_sheet.dart': 1,
    // El velo del tour va sobre la pantalla real: tiene que oscurecerla de
    // verdad. Un velo tomado del tema seria claro sobre un tema claro, y no
    // taparia nada.
    'lib/widgets/tour/guided_tour.dart': 1,

    // --- Deuda congelada, pendiente de tokens semánticos ---------------------
    'lib/screens/groups/group_detail_screen.dart': 78,
    'lib/screens/balances/global_balances_screen.dart': 12,
    'lib/screens/stats/stats_screen.dart': 11,
    'lib/screens/home/home_shell.dart': 6,
    'lib/screens/notifications/notifications_screen.dart': 4,
    'lib/screens/settings/settings_screen.dart': 3,
  };

  /// `Colors.transparent` no es un color: es la ausencia de uno.
  final patron = RegExp(r'Colors\.[a-zA-Z]+|Color\(0x[0-9A-Fa-f]{8}\)');

  int contar(File fichero) {
    final contenido = fichero.readAsStringSync();
    return patron.allMatches(contenido).map((m) => m.group(0)!).where((valor) => valor != 'Colors.transparent').length;
  }

  List<File> ficherosDeInterfaz() {
    return <File>[
      for (final directorio in <String>['lib/screens', 'lib/widgets'])
        ...Directory(directorio).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
    ];
  }

  String clave(File fichero) => fichero.path.replaceAll(r'\', '/');

  test('ningun fichero de interfaz sube su cuenta de colores a fuego', () {
    final excesos = <String>[];

    for (final fichero in ficherosDeInterfaz()) {
      final ruta = clave(fichero);
      final actual = contar(fichero);
      final tope = permitidos[ruta] ?? 0;

      if (actual > tope) {
        excesos.add('$ruta: $actual (el tope es $tope)');
      }
    }

    expect(
      excesos,
      isEmpty,
      reason:
          'Hay colores a fuego nuevos en la interfaz. Usa los tokens de AppThemeOption '
          '(Theme.of(context).colorScheme) en lugar de literales.\n${excesos.join('\n')}',
    );
  });

  test('la tabla de permitidos no se queda desfasada por lo alto', () {
    // Si un fichero baja de literales, el tope tiene que bajar con el. Si no,
    // el trinquete deja de apretar y la deuda puede volver a crecer sin que
    // nadie se entere.
    final holgados = <String>[];

    for (final entrada in permitidos.entries) {
      final fichero = File(entrada.key);
      if (!fichero.existsSync()) {
        holgados.add('${entrada.key}: el fichero ya no existe, quita la entrada');
        continue;
      }
      final actual = contar(fichero);
      if (actual < entrada.value) {
        holgados.add('${entrada.key}: quedan $actual pero el tope sigue en ${entrada.value}');
      }
    }

    expect(holgados, isEmpty, reason: 'Baja el tope en la tabla:\n${holgados.join('\n')}');
  });

  test('la pantalla de acceso no vuelve a fijar el fondo de la tarjeta', () {
    // Regresion concreta: `color: Colors.white` en la tarjeta de acceso hacia
    // que en tema oscuro saliera texto claro sobre fondo blanco.
    final contenido = File('lib/screens/auth/auth_screen.dart').readAsStringSync();
    expect(contenido, isNot(contains('color: Colors.white')));
    expect(contenido, contains('color: colorScheme.surface'));
    expect(contenido, contains('color: colorScheme.onPrimary'));
  });
}
