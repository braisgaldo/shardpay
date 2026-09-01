import 'package:flutter/foundation.dart';

/// Configuración de la invitación a un café.
///
/// **Regla dura del proyecto: la donación no desbloquea nada.** Ni funciones,
/// ni temas, ni contenido. Eso es exactamente lo que la mantiene fuera del
/// ámbito de la facturación obligatoria de las tiendas: no se compra un bien
/// digital, se agradece algo que ya es gratis y completo. Si alguna vez alguien
/// ata una función a esto, el argumento se cae entero.
///
/// Por el mismo motivo el proyecto **no** incluye ninguna biblioteca de
/// facturación: ni `com.android.billingclient:billing` ni StoreKit. Se verifica
/// en el flujo de integración continua.
class DonationConfig {
  const DonationConfig._();

  /// Destino del pago. Revolut permite fijar el importe y pagar con tarjeta o
  /// con la propia app, y evita publicar un IBAN personal dentro de una app
  /// distribuida.
  static const String url = 'https://revolut.me/brais2oz6';

  /// Página del proyecto, alternativa para iOS.
  static const String projectPageUrl = 'https://braisgaldo.github.io/shardpay/';

  /// Importe sugerido.
  static const double suggestedAmount = 1;

  /// Divisa del importe sugerido.
  static const String currencyCode = 'EUR';

  /// ¿Se ofrece la donación en esta plataforma?
  ///
  /// Activa en Android y **desactivada por defecto en iOS**. La directriz 3.1.1
  /// de App Store Review dice que para dar propina al desarrollador dentro de
  /// la app hay que usar compras integradas, y la 3.2.1(vii) solo exime los
  /// regalos entre usuarios finales, no al desarrollador. Un enlace de pago
  /// externo en iOS es, por tanto, un riesgo real de rechazo.
  ///
  /// En iOS, cuando se active, el enlace apuntará a la página del proyecto en
  /// GitHub Pages y no directamente a la pasarela. Consultado el 2026-08-31;
  /// las políticas cambian, así que se vuelve a verificar antes de cada envío.
  static bool get isEnabled {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return true;
      case TargetPlatform.iOS:
        return _enabledOnIos;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        // Fuera de las tiendas no aplica ninguna política de facturación.
        return true;
    }
  }

  /// Interruptor de iOS. Se pondrá a `true` solo si App Review lo acepta.
  static const bool _enabledOnIos = bool.fromEnvironment('SHARDPAY_DONATIONS_IOS');

  /// Enlace efectivo para la plataforma actual.
  static String get effectiveUrl {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return projectPageUrl;
    }
    return url;
  }
}
