# ADR-0002 — Firebase como backend, y por qué aquí sí hace falta

- **Fecha:** 2026-08-31
- **Estado:** aceptado, **revisado en parte por [ADR-0010](0010-plan-blaze-y-control-de-gasto.md)**
- **Decide:** Brais Castiñeiras Galdo

## Contexto

La plantilla pide decidir explícitamente si hace falta backend y gestión de
usuarios, y advierte de que en una v1 con datos locales lo más probable es que
**no** haga falta.

## Decisión

**Sí hace falta, y se mantiene Firebase** (Auth, Firestore, Storage y Cloud
Messaging).

> **Corrección posterior.** Este ADR decía «en su capa gratuita». No era cierto:
> `functions/index.js` usa Cloud Functions, que exige el plan **Blaze**. El
> proyecto está en Blaze con el gasto atado; el porqué y las cinco capas de
> control están en [ADR-0010](0010-plan-blaze-y-control-de-gasto.md). El
> presupuesto declarado sigue siendo el mismo: 5 €/mes.

## Motivos

El consejo de la plantilla es bueno para la mayoría de las apps, pero no aplica
a ésta. La naturaleza de ShardPay es **repartir gastos entre varias personas**:

- Un grupo tiene varios miembros, cada uno con su móvil.
- Cuando alguien añade un gasto, el resto tiene que verlo.
- Los saldos son una función de lo que han metido *todos*.
- Las invitaciones por enlace y por QR solo tienen sentido si hay un sitio común
  donde vive el grupo.

Sin servidor, ShardPay sería una calculadora de reparto para una sola persona,
que es otro producto. No hay «modo local» que salve esto: no es una app de notas
a la que se le pueda quitar la nube.

Lo que sí se mantiene es que **el reconocimiento de tickets es enteramente
local** (ML Kit en el dispositivo). Las fotos de los tickets no se envían a
ningún servicio de terceros para leerlas.

## Servicios y por qué cada uno

| Servicio | Para qué | Alternativa descartada |
| --- | --- | --- |
| **Auth** | Identificar a cada miembro del grupo | Sin identidad no hay «quién debe a quién» |
| **Firestore** | Documento por grupo, sincronizado en tiempo real | Un backend propio cuesta más de 5 €/mes solo en alojamiento |
| **Storage** | Guardar la foto del ticket si el usuario decide adjuntarla | Opcional: la app funciona sin ello |
| **Cloud Messaging** | Avisar de gastos y reembolsos nuevos | El sondeo periódico gasta batería y no llega con la app cerrada |

Para el uso previsto —grupos de amigos, decenas de usuarios— el consumo no se
acerca a los cupos gratuitos, que en Blaze se mantienen. Véase
[ADR-0010](0010-plan-blaze-y-control-de-gasto.md).

## Coste y control del gasto

Presupuesto máximo: **5 €/mes sumando todos los servicios**. La configuración de
la alerta y del límite, paso a paso, está en
[`docs/GUIA-PUBLICACION.md`](../GUIA-PUBLICACION.md#alertas-de-presupuesto).

Resumen: presupuesto de 5 € en Google Cloud Billing sobre el proyecto de
Firebase, con avisos por correo al 50 %, 90 % y 100 %.

En Blaze el presupuesto **avisa pero no corta**, así que no basta por sí solo.
Las otras cuatro capas de control —reglas que impiden barrer colecciones, tope
de instancias en las funciones, App Check y corte manual— están en
[ADR-0010](0010-plan-blaze-y-control-de-gasto.md).

## Consecuencias

### Buenas

- La app hace lo que promete: repartir gastos entre varias personas.
- Las notificaciones llegan con la app cerrada.
- No hay servidor propio que mantener.

### Malas

- Hay dependencia de un servicio de Google, con lo que eso implica de bloqueo de
  proveedor y de política de privacidad que declarar.
- Al estar en Blaze, **no hay tope automático de gasto**. Véase
  [ADR-0010](0010-plan-blaze-y-control-de-gasto.md).
- El modelo de datos actual guarda **todos los gastos de un grupo dentro del
  documento del grupo**. Es cómodo y rápido de leer, pero tiene techo: un
  documento de Firestore no puede pasar de 1 MiB. Véase ADR-0005.

### Mitigaciones

- Reglas de seguridad en `firestore.rules`, con acceso limitado a los miembros
  del grupo.
- Modo de demostración local (`MockAppRepository`) cuando no hay credenciales:
  la app sigue siendo navegable sin backend, lo cual permite desarrollar y hacer
  capturas sin tocar producción.
- La app es usable sin conexión gracias a la caché de Firestore; los cambios se
  sincronizan al recuperar la red.
