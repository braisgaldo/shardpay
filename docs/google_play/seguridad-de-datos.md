# Seguridad de los datos — respuestas del formulario

Play Console → **Contenido de la aplicación** → **Seguridad de los datos**.

Esto no es papeleo: lo que se declare aquí sale publicado en la ficha, y si no
coincide con lo que la app hace de verdad, Google la retira. Cada respuesta de
abajo tiene al lado **dónde está en el código**, para que se pueda comprobar en
vez de creer.

> Si algún día se añade analítica, publicidad o un servicio de terceros, este
> fichero hay que rehacerlo **antes** de publicar la versión que lo lleve.

## Resumen

| Pregunta | Respuesta |
| --- | --- |
| ¿Recoge o comparte datos de usuario? | **Sí, recoge. No comparte.** |
| ¿Se cifran en tránsito? | **Sí** (HTTPS/TLS, lo impone Firebase) |
| ¿Se pueden borrar los datos? | **Sí**, desde Ajustes → Cuenta → Eliminar perfil |
| ¿Hay recogida obligatoria? | Sí, la cuenta y los datos de los grupos |
| ¿Datos de menores? | La app no va dirigida a menores de 13 años |

## Tipos de datos

### Información personal

| Dato | ¿Se recoge? | ¿Se comparte? | Obligatorio | Para qué | Dónde |
| --- | --- | --- | --- | --- | --- |
| **Nombre** | Sí | No | Sí | Que el resto del grupo sepa quién apuntó cada gasto | `GroupMember.name` |
| **Dirección de correo** | Sí | No | Sí | Identificar la cuenta y encontrar a la persona al invitarla | Firebase Auth |
| **Identificadores de usuario** | Sí | No | Sí | Vincular gastos y saldos a una persona | `memberIds` |

Ni teléfono, ni dirección postal, ni fecha de nacimiento, ni sexo, ni orientación,
ni ninguna otra categoría. La app no los pide.

### Información financiera

| Dato | ¿Se recoge? | Para qué |
| --- | --- | --- |
| **Otra información financiera** | Sí | Los importes de los gastos y los saldos entre miembros del grupo |

**No** se recoge información de pago: la app **no procesa pagos**. No hay
pasarela, no hay tarjetas y no hay compras dentro de la aplicación. La donación
es un enlace externo a Revolut y ocurre **fuera** de la app
([ADR-0008](../adr/0008-donacion-y-politicas-de-tienda.md)).

### Fotos y vídeos

| Dato | ¿Se recoge? | Para qué |
| --- | --- | --- |
| **Fotos** | **No** | — |

Contraintuitivo, pero es que **no**: ninguna foto sale nunca del dispositivo.

La foto de un ticket se usa para leerlo y ya está. El reconocimiento de texto
ocurre **entero en el móvil** con ML Kit, y el fichero temporal se borra al
terminar (`ticket_ocr_service.dart`, bloque `finally`).

Tampoco hay forma de adjuntar una foto a un gasto: no existe esa pantalla. El
proyecto tiene un `ReceiptStorageService` preparado para subirlas a Firebase
Storage y los campos `receiptStoragePath` y `receiptDownloadUrl` en el modelo,
pero **no los llama nadie** y esos campos están siempre en nulo. Comprobado con:

```bash
grep -rn "uploadReceipt" lib/          # solo la definición, ninguna llamada
grep -rn "receiptStoragePath:" lib/    # nada fuera del propio modelo
```

Si algún día se activa esa función, esta respuesta pasa a ser «Sí» y hay que
actualizar el formulario **antes** de publicar la versión que la traiga.

### Lo que NO se recoge

Responder «no» a todo esto es la mitad del valor de la ficha, así que conviene no
equivocarse:

- **Ubicación**, ni precisa ni aproximada. La app no pide el permiso.
- **Contactos.** No se lee la agenda; a la gente se la invita con un enlace.
- **Actividad en la app**, historial de navegación, búsquedas o interacciones.
- **Rendimiento**: sin registros de fallos ni diagnósticos. No hay Crashlytics
  ni Performance Monitoring. Verificable en `pubspec.yaml`.
- **Identificadores de publicidad.** No hay publicidad ni redes de anuncios.
- **Mensajes**, calendario, ficheros o música.

## Prácticas de seguridad

| Pregunta | Respuesta | Por qué |
| --- | --- | --- |
| ¿Se cifran en tránsito? | Sí | Firestore, Auth y Storage van por TLS y no admiten otra cosa |
| ¿Se puede pedir el borrado? | Sí | Ajustes → Cuenta → **Eliminar perfil**, dentro de la app, sin escribir a nadie |
| ¿Sigue la política de datos de la Familia? | No aplica | La app no va dirigida a menores |
| ¿Ha pasado una revisión de seguridad independiente? | No | Y no se declara que sí |

### URL de eliminación de la cuenta

Play exige una URL donde se explique cómo borrar la cuenta, aunque se pueda hacer
desde dentro de la app:

```
https://braisgaldo.github.io/shardpay/privacidad.html#eliminar-tus-datos
```

## Qué pasa con los datos al borrar la cuenta

Merece explicarse, porque **no** es un borrado total y hay que declararlo bien:

- La cuenta de Firebase Auth **se elimina**.
- El documento del usuario **se elimina**.
- Las participaciones en grupos **se archivan**, no se borran: el gasto que esa
  persona pagó sigue haciendo falta para que a los demás les cuadren las
  cuentas. Su nombre queda marcado como cuenta eliminada.
- Si era la única persona del grupo, **el grupo se borra entero**.

Esto es lo que dice el diálogo de confirmación dentro de la app, con estas mismas
palabras. Está implementado en `deleteUserProfile`
(`lib/repositories/firebase/firebase_app_repository.dart`).
