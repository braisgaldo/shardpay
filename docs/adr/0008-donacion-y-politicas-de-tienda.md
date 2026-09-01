# ADR-0008 — La donación no desbloquea nada, y por eso no es una compra

- **Fecha:** 2026-08-31
- **Estado:** aceptado
- **Fuentes consultadas el 2026-08-31**
- **Decide:** Brais Castiñeiras Galdo

## Contexto

ShardPay ofrece invitar a un café al desarrollador, con un importe sugerido de
1 € a través de un enlace de Revolut. Hay que sostener que eso **no** es una
compra integrada, porque si lo fuera habría que pasar por el sistema de
facturación de cada tienda.

## Decisión

### La regla dura

**La donación no desbloquea absolutamente nada.** Ni funciones, ni temas, ni
quitar anuncios —no hay anuncios—, ni contenido, ni un tema «de agradecimiento».
La app es gratuita y **completa** para todo el mundo.

Esto es lo único que sostiene el argumento entero. Si alguien ata alguna vez una
función a haber donado, el resto de este documento deja de valer.

### Nada de bibliotecas de facturación

- `com.android.billingclient:billing` **no puede aparecer** en el proyecto, ni
  directa ni transitivamente.
- Lo mismo con StoreKit en el objetivo de iOS.
- Se comprueba en integración continua sobre el árbol de dependencias real
  (`./gradlew :app:dependencies`), no de memoria.

### Cómo se abre el enlace

Con `LaunchMode.inAppBrowserView`, que son las **Custom Tabs** en Android y el
**SFSafariViewController** en iOS: el navegador del sistema, con su barra de
direcciones a la vista. **Nunca un WebView incrustado**, porque eso sí parecería
una pasarela de pago dentro de la app.

### Vocabulario

Prohibidas, en la app y en la ficha de tienda: *comprar*, *pagar*, *desbloquear*,
*pro*, *premium*, *suscripción*, *precio*. Y nunca se dice que exista una
«versión completa», porque la que hay ya lo es.

Se usa: «invítame a un café», «apoyar el desarrollo», «gracias».

### Al volver del navegador

El mensaje es «Gracias por pasarte por ahí». **No se afirma que el pago se haya
hecho**: la app no tiene forma de comprobarlo y decirlo sería mentir.

## Las políticas, citadas

### Google Play — Política de pagos

Fuente: <https://support.google.com/googleplay/android-developer/answer/9858738>
(consultada el 2026-08-31; la página no muestra fecha de última actualización).

La política obliga a usar el sistema de facturación de Google Play para las
compras integradas de bienes y servicios digitales dentro de la app. En su
apartado de excepciones enumera transacciones que **no** requieren ese sistema, e
incluye expresamente los **donativos exentos de impuestos** («tax exempt
donations»).

**Matiz honesto que hay que tener presente.** Esa excepción, tal como está
redactada, apunta a donativos a entidades sin ánimo de lucro registradas, y aquí
el receptor es un particular. El argumento que sostiene el caso de ShardPay no es
esa excepción, sino el anterior: **no hay ninguna compra**, porque no se adquiere
ningún bien digital ni ninguna funcionalidad. Es una propina por algo que ya es
gratis y completo.

El riesgo residual existe y es bajo. La mitigación está más abajo.

### App Store — Directrices de revisión

Fuente: <https://developer.apple.com/app-store/review/guidelines/> (consultada el
2026-08-31; la página no muestra fecha de última actualización).

Dos apartados son relevantes, y **los dos van en contra**:

- **3.1.1 (In-App Purchase).** «Apps may use in-app purchase currencies to enable
  customers to "tip" the developer or digital content providers in the app.» Es
  decir: la vía prevista por Apple para dar propina al desarrollador *dentro de
  la app* es la compra integrada.
- **3.2.1(vii).** «Apps may enable individual users to give a monetary gift to
  another individual without using in-app purchase, provided that (a) the gift is
  a completely optional choice by the giver, and (b) 100% of the funds go to the
  receiver of the gift.» La exención es para regalos **entre usuarios finales**,
  no del usuario al desarrollador de la app.
- **3.2.1(vi).** La recaudación dentro de la app está reservada a entidades sin
  ánimo de lucro aprobadas, y con Apple Pay.

**Conclusión:** en iOS, un enlace de pago externo para dar propina al
desarrollador es un riesgo real de rechazo.

## Consecuencia práctica: interruptor por plataforma

`DonationConfig.isEnabled`:

- **Android:** activa.
- **iOS:** desactivada por defecto. Se activa solo compilando con
  `--dart-define=SHARDPAY_DONATIONS_IOS=true`, y solo si App Review lo acepta.
- **Escritorio:** activa. Fuera de las tiendas no aplica ninguna política de
  facturación.

Además, en iOS el enlace apunta a la **página del proyecto en GitHub Pages** y no
directamente a la pasarela (`DonationConfig.effectiveUrl`).

## Otras vías sin tiendas

El APK se publica también en las **GitHub Releases**, y el proyecto es candidato
a **F-Droid**. En ninguno de los dos sitios aplica política de facturación
alguna. Está mencionado en el README.

## Antes de cada envío

1. Volver a leer las dos políticas. Cambian.
2. Guardar captura con fecha en `docs/store/politicas/`.
3. Comprobar que `./gradlew :app:dependencies` sigue sin `billingclient`.
4. Comprobar que en la ficha, la declaración de compras integradas sigue en
   **«No»**.

## Consecuencias

- La app puede estar en Google Play sin sistema de facturación y sin mentir en la
  ficha.
- En iOS la donación no se ofrece hasta que Apple lo acepte, y mientras tanto la
  app es exactamente igual de completa.
- Cualquier tentación futura de «dar algo a quien done» rompe todo esto. Está
  escrito aquí para que quien lo intente se encuentre con este párrafo.
