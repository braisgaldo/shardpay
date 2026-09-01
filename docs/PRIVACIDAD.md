---
title: "ShardPay — Política de privacidad"
lang: es
---

# Política de privacidad de ShardPay

**Última actualización: 31 de agosto de 2026**

Responsable: Brais Castiñeiras Galdo (Ghato Studio).
Contacto: [ghatostudioofficial@gmail.com](mailto:ghatostudioofficial@gmail.com)

---

## En corto

- Las fotos de tus tickets **se leen en tu propio móvil**. No se envían a ningún
  servicio de terceros para reconocer el texto.
- Los datos de un grupo los ven **los miembros de ese grupo**, nadie más.
- **No hay analítica, ni telemetría, ni publicidad, ni venta de datos.**
- Puedes exportar todo lo tuyo y borrar tu cuenta desde la propia app.

---

## Qué datos se tratan

### Los que das al registrarte

| Dato | Para qué | Base legal |
| --- | --- | --- |
| Nombre visible | Que el resto del grupo sepa quién eres | Ejecución del servicio |
| Correo electrónico | Autenticación y recuperación de cuenta | Ejecución del servicio |
| Foto de perfil | Mostrar tu avatar. Solo si entras con Google | Ejecución del servicio |

### Los que generas usando la app

| Dato | Para qué |
| --- | --- |
| Grupos: nombre, descripción, moneda, miembros | Organizar los gastos |
| Gastos: concepto, importe, fecha, categoría, notas | Calcular quién debe qué |
| Repartos por persona | Calcular los saldos |
| Fotos de tickets | **Solo si decides adjuntarlas** a un gasto |

### Los técnicos

| Dato | Para qué |
| --- | --- |
| Token de notificaciones (Firebase Cloud Messaging) | Entregarte los avisos. Es un identificador de instalación, no de persona |

### Los que se quedan en tu móvil

Tema, idioma, preferencias de notificación y el estado del aviso de donación
viven en el almacenamiento local del dispositivo y **no se envían a ningún sitio**.

---

## Lo que NO se hace

- **No hay analítica ni telemetría.** Ni Firebase Analytics, ni Crashlytics, ni
  ninguna otra herramienta de medición.
- **No hay publicidad.** Ni propia, ni de terceros, ni redes de anuncios.
- **No se venden ni se ceden datos** a nadie.
- **No se crean perfiles** ni se toman decisiones automatizadas sobre ti.
- **No se accede a tu ubicación, ni a tus contactos, ni a tu agenda.**
- **No se envían las fotos de tus tickets a ningún servicio de reconocimiento
  externo.** El reconocimiento lo hace ML Kit dentro de tu dispositivo.

---

## Quién ve tus datos

### Los miembros de tus grupos

Cuando entras en un grupo, el resto de miembros ven tu nombre visible, tu foto de
perfil si la tienes, y los gastos que apuntas ahí. Es lo que hace la app.

**No ven** tu correo electrónico ni tus otros grupos.

### Google, como proveedor de infraestructura

ShardPay funciona sobre **Firebase**, de Google Ireland Limited:

| Servicio | Qué guarda |
| --- | --- |
| Firebase Authentication | Correo e identificador de usuario |
| Cloud Firestore | Grupos, gastos y repartos |
| Firebase Storage | Fotos de tickets, solo las que adjuntes |
| Firebase Cloud Messaging | Token de notificaciones |

Google actúa como **encargado del tratamiento**: procesa los datos por cuenta de
ShardPay y según sus instrucciones. Los datos se alojan en la Unión Europea.

Documentación de Google:
<https://firebase.google.com/support/privacy>

### Nadie más

No hay más terceros. Ni redes publicitarias, ni analítica, ni servicios de
atención al cliente con acceso a los datos.

---

## Permisos que pide la app

| Permiso | Para qué | ¿Obligatorio? |
| --- | --- | --- |
| **Cámara** | Fotografiar tickets desde la pantalla de captura | No. Puedes apuntar los gastos a mano o usar la galería |
| **Notificaciones** | Avisarte de gastos y reembolsos | No. Se puede denegar y la app sigue funcionando |

**No se pide** almacenamiento: exportar e importar usan el selector de ficheros
del sistema, que da acceso únicamente al fichero que elijas.

---

## Cuánto tiempo se conservan

- **Mientras uses la app**, tus datos siguen ahí.
- **Si borras tu cuenta** desde Ajustes → Eliminar perfil, se elimina tu perfil.
  Tu participación en los grupos queda archivada bajo un identificador anónimo,
  porque borrarla sin más rompería el histórico de saldos del resto del grupo. Tu
  nombre y tu correo desaparecen.
- **Si borras un grupo del que eres propietario**, se borra para todos.

---

## Tus derechos

Bajo el Reglamento General de Protección de Datos (UE 2016/679) tienes derecho a:

| Derecho | Cómo ejercerlo |
| --- | --- |
| **Acceso y portabilidad** | Ajustes → Exportar mis datos. Sale un fichero legible con todo lo tuyo |
| **Rectificación** | Editar tu nombre y tus gastos desde la app |
| **Supresión** | Ajustes → Eliminar perfil |
| **Oposición y limitación** | Escribe al correo de contacto |
| **Reclamación** | Agencia Española de Protección de Datos, <https://www.aepd.es> |

Respondo a las solicitudes por correo en un plazo máximo de 30 días.

---

## Copias de seguridad

El fichero `.shardpay.bak` que genera la app **no va cifrado**. Es un fichero
tuyo, en tu dispositivo, y lo compartes tú con quien quieras.

Lleva una suma de verificación, pero eso sirve para detectar que el fichero se ha
corrompido al copiarlo, **no** para protegerlo de nadie.

Si contiene información que no quieres que vea otra persona, guárdalo en un sitio
protegido.

---

## Menores

ShardPay está dirigida a **mayores de 18 años**. No se recopilan datos de menores
a sabiendas. Si crees que un menor ha creado una cuenta, avísame y la elimino.

---

## Seguridad

- Todo el tráfico va cifrado con HTTPS.
- El acceso a los datos de un grupo está limitado a sus miembros por las reglas
  de seguridad de Firestore, que son públicas y auditables en
  [`firestore.rules`](https://github.com/braisgaldo/shardpay/blob/main/firestore.rules).
- No hay credenciales en el código fuente.
- El código es abierto: cualquiera puede comprobar lo que dice esta política en
  <https://github.com/braisgaldo/shardpay>.

Si encuentras un fallo de seguridad, sigue el procedimiento de
[`SECURITY.md`](https://github.com/braisgaldo/shardpay/blob/main/SECURITY.md).

---

## Cambios en esta política

Si cambia algo sustancial, se anuncia en las notas de la versión y se actualiza
la fecha de arriba. El historial completo está en el repositorio: cada cambio de
esta política es un commit.
