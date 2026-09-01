# ADR-0007 — Escritorio e iOS: qué funciona hoy y qué falta

- **Fecha:** 2026-08-31
- **Estado:** aceptado
- **Decide:** Brais Castiñeiras Galdo

## Contexto

La plantilla marca Android como obligatorio, iOS como obligatorio por
portabilidad y escritorio como deseable, con distribución por GitHub Releases sin
pasar por ninguna tienda.

## Estado real

El repositorio tiene carpeta `android/` e `ios/`. **No tiene** `windows/`,
`macos/` ni `linux/`.

### iOS

El código Dart es el mismo. Lo que hace falta antes de poder publicar:

| Pieza | Estado | Qué falta |
| --- | --- | --- |
| Código de la app | listo | nada |
| Firebase | registrado | `GoogleService-Info.plist` y el cliente OAuth de iOS |
| Cámara | soportada por el plugin | añadir `NSCameraUsageDescription` al `Info.plist` |
| Galería | soportada | `NSPhotoLibraryUsageDescription` |
| Importar copias | soportada | declarar el tipo de documento `.shardpay.bak` en `Info.plist` |
| Donación | **desactivada por defecto** | véase abajo |
| Cuenta de desarrollador | no | Apple Developer Program, 99 €/año, inevitable |

El detalle está en
[`docs/GUIA-PUBLICACION.md`](../GUIA-PUBLICACION.md#app-store).

**La donación va detrás de un interruptor por plataforma.** `DonationConfig` la
deja activa en Android y apagada en iOS, salvo que se compile con
`--dart-define=SHARDPAY_DONATIONS_IOS=true`. El motivo está en el ADR-0008.

### Escritorio

Los objetivos de escritorio se pueden generar con `flutter create --platforms`.
Lo que **no** funcionaría tal cual:

- **Firebase.** Los plugins de FlutterFire tienen soporte de escritorio parcial y
  desigual. Auth y Firestore van por la vía web en Windows; Messaging no va.
- **ML Kit.** `google_mlkit_text_recognition` es solo Android e iOS. En
  escritorio no hay lector de tickets, o hay que buscar otro motor.
- **Cámara.** El plugin `camera` no soporta escritorio.

O sea: en escritorio quedaría una app de consulta y de introducción manual, sin
lo que la distingue.

## Decisión

- **Android:** objetivo principal de la 1.0.0.
- **iOS:** se mantiene la portabilidad del código y se documenta el trabajo que
  falta. No entra en la 1.0.0 porque depende de una cuenta de pago.
- **Escritorio:** no se generan los objetivos todavía. Añadir tres carpetas que
  compilan una versión mutilada de la app es peor que no tenerlas: da la falsa
  impresión de que está soportado.

## Cuándo se revisa

- **iOS:** en cuanto haya cuenta de Apple Developer.
- **Escritorio:** cuando exista una razón de uso real —por ejemplo, gestionar un
  grupo grande desde el ordenador— y no antes. Si llega ese momento, el camino
  es una versión de consulta que use el SDK web de Firebase y renuncie
  explícitamente al lector de tickets, no fingir que la app entera funciona.

## Verificación de portabilidad

`flutter build ios --no-codesign` comprueba que el código Dart compila para iOS
sin necesidad de cuenta de pago. Está en el flujo de integración continua, en un
trabajo que corre en macOS y que **no bloquea** la publicación de Android.
