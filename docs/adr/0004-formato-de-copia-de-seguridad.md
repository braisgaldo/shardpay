# ADR-0004 — `.shardpay.bak` es JSON comprimido con gzip

- **Fecha:** 2026-08-31
- **Estado:** aceptado
- **Decide:** Brais Castiñeiras Galdo

## Contexto

La plantilla pide una exportación a fichero con extensión propia y deja libre el
formato interno, siempre que se documente: SQLite, JSON o ZIP con manifiesto.

## Decisión

`.shardpay.bak` es **JSON en UTF-8 comprimido con gzip**, con una cabecera que
lleva identificador de formato, versión de esquema, versión de la app, fecha y
suma de verificación.

```jsonc
{
  "format": "es.ghatostudio.shardpay.backup",
  "schemaVersion": 1,
  "appVersion": "1.0.0",
  "createdAt": "2026-08-31T10:30:00.000Z",
  "deviceLabel": "Pixel 8",
  "checksum": "3f7a1c...",     // FNV-1a de 64 bits del JSON del contenido
  "payload": {
    "preferences": { "app.theme": "aurora", "app.language": "gl", ... },
    "groups": [ /* ExpenseGroup.toMap() */ ]
  }
}
```

## Motivos

**JSON y no SQLite.** El modelo de dominio ya sabe convertirse a mapas
(`toMap`/`fromMap`), que es lo mismo que usa Firestore. Con SQLite habría que
mantener un esquema relacional en paralelo, con sus migraciones, para un fichero
que solo se escribe y se lee entero. Y un JSON se puede abrir con un editor de
texto para ver qué pasó cuando algo falla.

**gzip y no ZIP.** Un ZIP con manifiesto tiene sentido cuando hay varios ficheros
—por ejemplo, si se adjuntaran las fotos de los tickets—. Aquí hay uno solo.
`dart:io` trae gzip de serie, así que no añade ninguna dependencia. Un grupo de
mil gastos ronda los 400 kB en claro y unos 30 kB comprimido.

**FNV-1a y no SHA-256.** La suma de verificación existe para detectar un fichero
truncado o corrupto al pasarlo de un móvil a otro, que es el fallo real. No
protege contra nadie: quien pueda editar el fichero puede recalcular la suma.
Un SHA-256 obligaría a arrastrar `package:crypto` para el mismo resultado
práctico, y además invitaría a confundirlo con una garantía de integridad
criptográfica que no es.

**Sin cifrar, y dicho en voz alta.** El fichero es del usuario, en su
dispositivo. Cifrarlo obligaría a gestionar una clave —que el usuario perdería—
y a una promesa de confidencialidad que la app no puede sostener. Está
documentado en `SECURITY.md` y en el manual de usuario.

## Alcance de la restauración

La importación **no reemplaza los grupos que ya existen**. Un grupo de ShardPay
es compartido: sus gastos vivos pueden incluir cosas que otras personas han
añadido después de hacerse la copia, y machacarlos borraría trabajo ajeno.

Se ofrecen dos modos, y la app explica cuál hace qué antes de tocar nada:

- **Solo ajustes** — tema, idioma, notificaciones y estado del aviso de donación.
- **Ajustes y grupos** — lo anterior, más volver a crear los grupos de la copia
  que ya no existen para este usuario. El grupo restaurado es un grupo nuevo, del
  que pasa a ser propietario quien importa, con código de invitación nuevo. Los
  demás miembros vuelven a entrar con la invitación.

Antes de aplicar nada se guarda una **copia automática del estado actual**.

## Migraciones

`migratePayload()` es una cadena de pasos, uno por salto de versión de esquema.
Hoy está vacía porque solo existe la versión 1, pero el andamio y su prueba están
escritos ya: el momento de montarlo es antes de que haya copias reales de gente
en juego.

Una copia de una versión de esquema **más nueva** se rechaza siempre: no se puede
adivinar qué significan campos que aún no existen.

## Consecuencias

- El formato es inspeccionable y reparable a mano.
- No añade ninguna dependencia.
- El fichero no está cifrado, y eso está declarado en la política de privacidad
  y en `SECURITY.md`.
- La restauración de grupos crea grupos nuevos, no restaura los originales. Es
  la única opción segura en un modelo compartido, y la app lo dice con esas
  palabras.
