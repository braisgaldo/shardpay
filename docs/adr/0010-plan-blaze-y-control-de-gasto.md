# ADR-0010 — El proyecto pasa al plan Blaze, con el gasto atado

- **Fecha:** 2026-08-31
- **Estado:** aceptado
- **Decide:** Brais Castiñeiras Galdo
- **Revisa parcialmente:** [ADR-0002](0002-backend-y-usuarios.md)

## Contexto

[ADR-0002](0002-backend-y-usuarios.md) decía que ShardPay vivía en la **capa
gratuita (Spark)** y que «no se usa ningún servicio de pago de Google».

Eso **ya no era cierto** cuando se escribió. `functions/index.js` contiene
`pushUserNotification`, un disparador de Cloud Functions que envía la
notificación push cuando alguien apunta un gasto o registra un reembolso. **Cloud
Functions exige el plan Blaze**, en cualquiera de sus versiones. O sea que el
proyecto tenía dos afirmaciones incompatibles conviviendo:

- ADR-0002: todo cabe en Spark, no se paga nada.
- `functions/index.js`: hay una función desplegada, que Spark no permite.

La contradicción salió a la luz al cerrar [ADR-0009](0009-lectura-de-invitaciones.md),
cuyo plan original proponía **otra** Cloud Function para sincronizar la ficha
pública de las invitaciones. Se descartó precisamente por esto, y el espejo lo
mantiene el cliente.

## Decisión

**El proyecto pasa a Blaze**, con el gasto atado por varios lados a la vez.

Se descarta la alternativa —quitar `pushUserNotification` y quedarse en Spark—
porque las notificaciones son el motivo por el que la gente se entera de que le
han apuntado un gasto. Sin ellas hay que abrir la app para descubrirlo, que es
justo lo que la app existe para evitar.

Blaze **no** significa que se vaya a gastar dinero: los cupos gratuitos se
mantienen —en Firestore son diarios (lecturas, escrituras y borrados por día), en
Cloud Functions mensuales— y por debajo de ellos la factura es de 0 €. Lo que
cambia es que **deja de haber un tope automático**: en Spark, pasarse del cupo
significa que la operación falla; en Blaze, significa que se cobra. Por eso este
ADR trata sobre todo del control de gasto.

## Cómo se ata el gasto

Cinco capas, de la más barata a la más drástica:

### 1. Las reglas de seguridad, que ahora también son control de coste

Este es el cambio más importante y es reciente. Antes de
[ADR-0009](0009-lectura-de-invitaciones.md), **cualquier usuario autenticado
podía barrer la colección `groups` entera**. En Spark eso era una fuga de datos;
en Blaze sería además una factura: una consulta sin filtro sobre una colección
grande se cobra por documento leído, y cualquiera con una cuenta podía lanzarla
en bucle.

Ahora `groups` sólo lo leen sus miembros y `invites` no se puede enumerar. La
superficie de lectura que un desconocido puede provocar es **un documento por
código de invitación que ya conozca**.

### 2. Presupuesto y avisos en Cloud Billing

Presupuesto de **5 €/mes** sobre el proyecto, con avisos por correo al 50 %,
90 % y 100 %. El procedimiento paso a paso está en
[`GUIA-PUBLICACION.md`](../GUIA-PUBLICACION.md#alertas-de-presupuesto).

Ojo con lo que un presupuesto **no** hace: avisa, no corta. Es una alarma de
incendios, no un extintor.

### 3. Tope de instancias en las funciones

`functions/index.js` ya fija `maxInstances: 10` globalmente. Es el extintor real
para el único componente que puede escalar solo: una tormenta de escrituras no
puede levantar mil instancias facturables, se encola.

### 4. App Check

Pendiente. Es lo que impide que alguien use las credenciales de la app desde
fuera de la app —un script, un cliente reescrito— para consumir cuota. Está en
la lista de publicación como tarea previa a abrir el registro al público.

### 5. Corte manual

Si un aviso del 100 % llega y no se explica por uso legítimo, se deshabilita la
facturación del proyecto desde Cloud Billing. La app cae a modo degradado —los
datos siguen ahí, las funciones dejan de responder— y se investiga sin reloj.

## Consecuencias

### Buenas

- Las notificaciones push dejan de estar en un limbo: se usan y están pagadas
  por el plan que corresponde.
- La documentación deja de decir algo que no era verdad. Esto importa más de lo
  que parece: un ADR que miente sobre el plan hace que el siguiente lector tome
  decisiones sobre una base falsa, que es exactamente lo que pasó en ADR-0009.
- Queda abierta la puerta a mover el espejo de invitaciones a una función si
  alguna vez compensa (véase ADR-0009), aunque hoy no compensa.

### Malas

- **Desaparece el tope automático de Spark.** Un fallo en bucle, un ataque o un
  éxito repentino pueden generar factura. Las cinco capas de arriba existen por
  esto, y ninguna es infalible por sí sola.
- Hay que vigilar el consumo, aunque sea una vez al mes. Antes no hacía falta.
- Hace falta una tarjeta asociada al proyecto.

### Qué se mantiene de ADR-0002

Todo lo demás: Auth, Firestore, Storage y Cloud Messaging siguen siendo los
servicios, el reconocimiento de tickets sigue siendo **enteramente local**, y el
presupuesto máximo declarado sigue siendo **5 €/mes**. Lo único que cambia es el
plan sobre el que corren y la vigilancia que eso obliga a tener.
