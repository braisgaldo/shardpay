# ADR-0003 — Mantener `com.ghatostudio.shardpay` como identificador

- **Fecha:** 2026-08-31
- **Estado:** aceptado
- **Decide:** Brais Castiñeiras Galdo

## Contexto

La plantilla fija `APP_ID` en `es.ghatostudio.shardpay`. El proyecto usa
`com.ghatostudio.shardpay` desde el principio: está en
`android/app/build.gradle.kts`, en el `namespace` de Kotlin, en el valor por
defecto de `FIREBASE_IOS_BUNDLE_ID` y en el registro de la aplicación Android
dentro del proyecto de Firebase.

## Decisión

**Se mantiene `com.ghatostudio.shardpay`.** No se renombra.

## Motivos

Cambiar el identificador antes de publicar es técnicamente posible, pero arrastra
una cadena de trabajo que no compra nada:

1. Hay que **registrar una aplicación nueva** en el proyecto de Firebase: el
   registro va atado al nombre de paquete y no se puede renombrar.
2. Hay que volver a subir las **huellas SHA-1 y SHA-256** de la clave de
   depuración y de la de publicación, o el inicio de sesión con Google deja de
   funcionar.
3. Hay que regenerar el **cliente OAuth** y el `google-services.json`.
4. Hay que rehacer el `applicationId`, el `namespace`, la ruta del paquete Kotlin
   y el `bundleId` de iOS.
5. El enlace profundo `shardpay://join` y el enlace de aplicación
   `https://shardpay.app/join` hay que volver a verificarlos.

A cambio de eso, el beneficio es cero: `com.` es la convención mayoritaria y
ningún usuario ve nunca el identificador.

## Cuándo sí habría que hacerlo

Si Brais quiere unificar el identificador con el resto de apps de Ghato Studio
bajo `es.ghatostudio.*`, es una decisión razonable **y hay que tomarla antes de
la primera publicación**, porque después Google Play no permite cambiar el
`applicationId` de una app publicada: sería una app distinta, sin sus usuarios ni
sus valoraciones.

El procedimiento completo, si se decide, está en
[`docs/INSTALL.md`](../INSTALL.md#renombrar-el-identificador-de-aplicacion).

## Consecuencias

- La plantilla y el código discrepan en este punto. Queda anotado aquí para que
  la discrepancia sea deliberada y no un descuido.
- El identificador se muestra en **Ajustes → Acerca de**, copiable, para que
  quede claro cuál es el bueno cuando haya que reportar algo.
