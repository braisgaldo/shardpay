import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Configuración común a todas las pruebas de `test/`.
///
/// `flutter test` reconoce este fichero por el nombre y lo ejecuta antes que
/// cualquier suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // El tema usa `GoogleFonts.spaceGroteskTextTheme()`, que intenta descargar la
  // fuente. En una prueba no hay red —y no debe haberla—, así que se desactiva
  // la descarga y se usa la fuente de respaldo. Sin esto, cualquier prueba que
  // construya el tema falla con un error de red que no tiene nada que ver con
  // lo que se está comprobando.
  GoogleFonts.config.allowRuntimeFetching = false;

  await testMain();
}
