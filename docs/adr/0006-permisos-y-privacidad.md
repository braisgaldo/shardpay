# ADR-0006 — Permisos: solo dos, y los dos justificados

- **Fecha:** 2026-08-31
- **Estado:** aceptado
- **Decide:** Brais Castiñeiras Galdo

## Contexto

La plantilla exige mínimo privilegio: cada permiso declarado tiene que estar
justificado en un ADR y en la ficha de tienda, y ante la duda, no se pide.

## Decisión

ShardPay declara **dos** permisos en Android.

### `android.permission.CAMERA`

**Para qué.** Fotografiar el ticket desde la pantalla de captura propia.

**Por qué no se puede evitar.** La pantalla de captura muestra vista previa en
vivo con guía de encuadre, linterna y enfoque al tocar. Eso requiere acceso
directo a la cámara. La alternativa —lanzar la cámara del sistema con un
*intent*— no necesita permiso, pero es justamente lo que había antes y lo que se
ha cambiado: el usuario encuadraba a ciegas y no se enteraba de que la foto había
salido movida hasta que fallaba la lectura.

**Qué pasa con la foto.** El reconocimiento de texto ocurre **entero en el
dispositivo**, con ML Kit. La imagen no se envía a ningún servicio de terceros.
Solo sale del móvil si el usuario decide adjuntarla al gasto, y entonces va al
Storage del propio proyecto, visible únicamente para el grupo.

**Es opcional.** `<uses-feature android:required="false">`: la app se instala en
dispositivos sin cámara y se puede usar entera metiendo los gastos a mano o
leyendo tickets desde la galería.

### `android.permission.POST_NOTIFICATIONS`

**Para qué.** Avisar de gastos nuevos, reembolsos registrados y solicitudes de
reembolso en los grupos del usuario.

**Por qué.** Es el núcleo de una app compartida: si alguien añade un gasto de 80 €
al grupo, el resto tiene que enterarse sin abrir la app.

**Control.** Los tres tipos de aviso se pueden apagar por separado en
**Ajustes → Notificaciones**, y el permiso lo concede el usuario en tiempo de
ejecución desde Android 13.

## Permisos que NO se piden

| Permiso | Por qué no |
| --- | --- |
| Almacenamiento (`READ_MEDIA_*`, `READ_EXTERNAL_STORAGE`) | Exportar e importar usan el selector del sistema, que da acceso solo al fichero elegido. Leer de la galería lo hace `image_picker` con el selector del sistema. |
| Ubicación | La app no usa la ubicación para nada. |
| Contactos | Los miembros se invitan por enlace o QR. |
| Internet | Ya viene implícito en Android; no se declara aparte. |

## Analítica y telemetría

**No hay.** Ni Firebase Analytics, ni Crashlytics, ni ninguna otra. Si algún día
se añade, será con consentimiento explícito, apagada por defecto, y este ADR se
actualiza antes.

Firebase Cloud Messaging registra un token de dispositivo, que es
inevitable para que lleguen las notificaciones. Está declarado en la política de
privacidad.

## Formulario de Seguridad de los datos de Google Play

Lo que hay que declarar, con las respuestas ya decididas, está en
[`docs/GUIA-PUBLICACION.md`](../GUIA-PUBLICACION.md#seguridad-de-los-datos).
