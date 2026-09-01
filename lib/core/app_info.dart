/// Identidad de esta compilación concreta.
///
/// Los valores llegan por `--dart-define` desde el flujo de publicación, así
/// que un binario firmado siempre sabe decir de qué commit salió. En una
/// compilación local quedan los valores por defecto, que dejan claro que no es
/// una compilación de publicación.
///
/// Se usan constantes de compilación y no `package_info_plus` porque el hash
/// del commit y la fecha de compilación no están en ningún sitio del que un
/// plugin pueda leerlos: los pone la máquina que compila.
library;

class AppInfo {
  const AppInfo._();

  /// Versión semántica. Coincide con `version` en `pubspec.yaml`.
  static const String version = String.fromEnvironment('SHARDPAY_VERSION', defaultValue: '1.0.0');

  /// Número de compilación monótono (`versionCode` en Android).
  ///
  /// Fórmula documentada en `docs/INSTALL.md`: se genera desde la fecha en UTC
  /// como `AAMMDDNN`, donde `NN` es el número de compilación de ese día. Es
  /// creciente por construcción y legible de un vistazo.
  static const String buildNumber = String.fromEnvironment('SHARDPAY_BUILD', defaultValue: '1');

  /// Hash corto del commit.
  static const String commit = String.fromEnvironment('SHARDPAY_COMMIT', defaultValue: 'local');

  /// Fecha de compilación en ISO 8601.
  static const String buildDate = String.fromEnvironment('SHARDPAY_BUILD_DATE', defaultValue: '');

  /// `true` cuando el binario viene del flujo de publicación.
  static bool get isReleaseBuild => commit != 'local';

  static const String license = 'Apache-2.0';
  static const String repositoryUrl = 'https://github.com/braisgaldo/shardpay';
  static const String projectPageUrl = 'https://braisgaldo.github.io/shardpay/';
  static const String privacyPolicyUrl = 'https://braisgaldo.github.io/shardpay/privacidad.html';
  static const String issuesUrl = 'https://github.com/braisgaldo/shardpay/issues';
  static const String contactEmail = 'ghatostudioofficial@gmail.com';
  static const String applicationId = 'com.ghatostudio.shardpay';

  /// Ficha en Google Play. Vale también para el botón de compartir.
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$applicationId';

  /// Ficha en la App Store. Vacía hasta que exista.
  static const String appStoreUrl = String.fromEnvironment('SHARDPAY_APP_STORE_URL');

  /// Enlace que se comparte: la ficha de Play cuando existe, y si no la página
  /// del proyecto.
  static String get shareUrl => playStoreUrl;
}
