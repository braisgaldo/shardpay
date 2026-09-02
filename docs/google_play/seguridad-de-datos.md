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

| Dato | ¿Se recoge? | ¿Se comparte? | Para qué |
| --- | --- | --- | --- |
| **Historial de compras** | Sí | No | El concepto, el importe y la fecha de cada gasto que apunta el usuario |
| **Otra información financiera** | Sí | No | Los saldos y las deudas entre miembros del grupo |

**Historial de compras se marca aunque la app no venda nada.** Google lo define
como «información sobre compras o transacciones que ha hecho el usuario», sin
exigir que pasen por la app, y un gasto de ShardPay —«Cena, 84 €, 15 de marzo»—
es exactamente eso. La tentación es no marcarlo porque no hay pasarela de pago,
pero eso es la casilla de al lado.

**Información para pagos del usuario: NO.** La app **no procesa pagos**. No hay
pasarela, no hay tarjetas y no hay compras dentro de la aplicación. La donación
es un enlace externo a Revolut y ocurre **fuera** de la app
([ADR-0008](../adr/0008-donacion-y-politicas-de-tienda.md)). Marcar esta casilla
publicaría en la ficha que ShardPay recoge datos de pago, que es falso.

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


---

## «Se recogen» frente a «Se comparten»

Después de elegir los tipos, Play pregunta por cada uno si se **recoge**, se
**comparte**, o las dos cosas. Son cosas distintas y la segunda casi nunca
aplica aquí:

- **Se recoge** = el dato sale del dispositivo, aunque sea hacia tu propio
  servidor. Todo lo que declara ShardPay sale del móvil: vive en Firestore.
- **Se comparte** = el dato llega a un **tercero**.

**Los siete tipos van marcados solo como «se recogen».** Ninguno como «se
comparte», por dos exenciones que el propio formulario reconoce:

1. **Un proveedor de servicios no es un tercero.** Firebase procesa los datos
   por cuenta de ShardPay y según sus instrucciones. Mandar un gasto a Firestore
   no es compartirlo con Google en el sentido del formulario.
2. **Lo que ve el resto del grupo llega por una acción deliberada del usuario.**
   El formulario exime «los datos que se transfieren a un tercero por una acción
   concreta iniciada por el usuario, cuando este espera razonablemente que se
   compartan». A un grupo se entra tecleando un código y un PIN, y los gastos se
   apuntan uno a uno. Que los otros miembros vean tu nombre y lo que apuntaste es
   justo lo que esperas al hacerlo.

Y no hay ningún tercero más: no hay analítica, ni publicidad, ni SDK de terceros
que reciba nada. Comprobado en el `pubspec.yaml` y en el manifiesto, donde los
únicos permisos son `CAMERA` y `POST_NOTIFICATIONS`.
