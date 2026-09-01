---
title: "ShardPay — Guía de publicación"
subtitle: "Google Play y App Store · versión 1.0.0"
lang: es
---

# Guía de publicación

Todo lo necesario para publicar ShardPay, con las decisiones ya tomadas y las
políticas citadas para poder defenderlas si una revisión las cuestiona.

**Las políticas de las tiendas cambian.** Todo lo que se cita aquí se consultó el
**2026-08-31**. Antes de cada envío hay que volver a leerlas y guardar captura
con fecha en `docs/store/politicas/`.

---

## 1. Antes de nada: la declaración de compras integradas

**Compras integradas: NO.** Tanto en la ficha de Google Play como en App Store
Connect.

Esto es coherente con que en el binario no exista ninguna biblioteca de
facturación, y hay que poder demostrarlo:

```bash
cd android && ./gradlew :app:dependencies > /tmp/deps.txt
grep -i "billingclient\|billing" /tmp/deps.txt   # tiene que salir vacío
```

El flujo de integración continua lo comprueba en cada envío y falla si aparece.

### Por qué la donación no es una compra integrada

**Google Play — Política de pagos**
(<https://support.google.com/googleplay/android-developer/answer/9858738>,
consultada el 2026-08-31; la página no muestra fecha de última actualización).

La política obliga a usar el sistema de facturación de Google Play para las
compras integradas de bienes y servicios digitales dentro de la app. Su apartado
de excepciones enumera transacciones que no lo requieren, e incluye expresamente
los donativos exentos de impuestos.

**El argumento que sostiene el caso de ShardPay no es esa excepción** —que apunta
a entidades sin ánimo de lucro registradas, y aquí el receptor es un
particular— **sino el hecho anterior: no hay ninguna compra.** No se adquiere
ningún bien digital ni ninguna funcionalidad. La app es gratuita y completa para
todo el mundo, done o no done. Es una propina por algo que ya se tiene entero.

Eso solo se sostiene mientras la donación **no desbloquee absolutamente nada**.
Véase [ADR-0008](adr/0008-donacion-y-politicas-de-tienda.md).

**App Store — Directrices de revisión**
(<https://developer.apple.com/app-store/review/guidelines/>, consultada el
2026-08-31; la página no muestra fecha de última actualización).

Aquí la lectura es la contraria, y hay que decirlo:

- **3.1.1** — «Apps may use in-app purchase currencies to enable customers to
  "tip" the developer or digital content providers in the app.» La vía prevista
  por Apple para dar propina al desarrollador dentro de la app es la compra
  integrada.
- **3.2.1(vii)** — «Apps may enable individual users to give a monetary gift to
  another individual without using in-app purchase, provided that (a) the gift is
  a completely optional choice by the giver, and (b) 100% of the funds go to the
  receiver of the gift.» La exención es para regalos **entre usuarios finales**,
  no del usuario al desarrollador.
- **3.2.1(vi)** — La recaudación dentro de la app está reservada a entidades sin
  ánimo de lucro aprobadas, y con Apple Pay.

**Conclusión:** en iOS, un enlace externo para dar propina al desarrollador es un
riesgo real de rechazo. Por eso la donación va detrás de
`DonationConfig.isEnabled`, **apagada por defecto en iOS**, y cuando se active
apuntará a la página del proyecto y no a la pasarela.

### Vías sin tienda

El APK se publica también en las **GitHub Releases** y el proyecto es candidato a
**F-Droid**. En ninguno de los dos aplica política de facturación alguna.

---

## 2. Google Play

### 2.1 Requisitos de la cuenta

| Concepto | Coste | Notas |
| --- | --- | --- |
| Cuenta de desarrollador de Google Play | 25 USD, pago único | |
| **Pruebas cerradas con 12 testers durante 14 días seguidos** | — | **Aplica** si la cuenta es personal y se creó después de noviembre de 2023 |

**Esto hay que planificarlo desde el principio.** Si la cuenta es personal y
reciente, Google exige 12 testers que hayan aceptado la invitación y tengan la
app instalada, durante 14 días consecutivos, antes de poder solicitar acceso a
producción. Son dos semanas de calendario que no se pueden comprimir.

Plan sugerido:

1. Semana 0: subir el primer AAB a una **pista cerrada**.
2. Invitar a 12 personas por correo o por grupo de Google. Confirmar una por una
   que han aceptado **y** instalado.
3. Semanas 1 y 2: mantener el número. Si alguien desinstala, el contador se
   resiente.
4. Semana 3: solicitar acceso a producción.

### 2.2 Ficha de la tienda

El texto en los trece idiomas está en [`store/ficha-play.md`](store/ficha-play.md).

| Campo | Límite | Estado |
| --- | --- | --- |
| Título | 30 caracteres | listo |
| Descripción corta | 80 caracteres | listo, en 13 idiomas |
| Descripción larga | 4000 caracteres | listo, en 13 idiomas |
| Icono | 512 × 512 PNG, 32 bits | **pendiente de exportar** |
| Gráfico destacado | 1024 × 500 PNG o JPEG | **pendiente** |
| Capturas de teléfono | 2 mínimo, 8 máximo, entre 320 y 3840 px | **pendiente** |
| Capturas de tablet 7" | opcional | pendiente |
| Capturas de tablet 10" | opcional | pendiente |

Las capturas se toman del dispositivo real y se guardan en
`docs/store/capturas/`.

### 2.3 Clasificación de contenido

Cuestionario IARC. Respuestas para ShardPay:

| Pregunta | Respuesta |
| --- | --- |
| Categoría de la app | Utilidades / Productividad |
| Violencia | No |
| Sexualidad | No |
| Lenguaje soez | No |
| Sustancias controladas | No |
| Juegos de azar (simulados o reales) | **No** |
| Contenido generado por usuarios | Sí — nombres de grupo, conceptos de gasto y notas, visibles solo dentro del grupo |
| Compartición de ubicación | No |
| Compras digitales | **No** |
| Publicidad | No |

Resultado esperado: **PEGI 3 / Todos**.

> Ojo con «juegos de azar»: ShardPay maneja dinero, pero no hay apuesta, ni
> premio, ni azar. La respuesta es No.

### 2.4 Seguridad de los datos

Formulario obligatorio. Respuestas decididas (véase
[ADR-0006](adr/0006-permisos-y-privacidad.md)):

| Tipo de dato | ¿Se recopila? | ¿Se comparte? | ¿Obligatorio? | Para qué |
| --- | --- | --- | --- | --- |
| Nombre | Sí | No | Sí | Identificar a la persona dentro del grupo |
| Dirección de correo | Sí | No | Sí | Autenticación |
| Foto de perfil | Sí, si se entra con Google | No | No | Mostrar el avatar |
| Fotos (tickets) | Solo si el usuario adjunta el ticket | No | No | Adjuntar el justificante al gasto |
| Información financiera del usuario | **No** | No | — | La app no maneja cuentas ni pagos: solo cantidades que las personas se apuntan entre sí |
| Ubicación | No | No | — | — |
| Contactos | No | No | — | — |
| Identificadores de dispositivo | Sí (token de notificaciones) | No | Sí | Entregar los avisos |
| Actividad en la app / analítica | **No** | No | — | No hay analítica |

Además:

- **¿Se cifran los datos en tránsito?** Sí (HTTPS, por Firebase).
- **¿Se pueden solicitar el borrado?** Sí, desde **Ajustes → Eliminar perfil**, y
  también por correo.
- **¿La app cumple la política de familias?** No aplica: no está dirigida a
  menores.

### 2.5 Público objetivo

- **Edad:** 18 y más. Justificación: gestión de dinero entre adultos.
- **¿Atrae a menores?** No. Ni gráficos infantiles, ni personajes, ni temática
  escolar.

### 2.6 Política de privacidad

**URL obligatoria y pública:**
<https://braisgaldo.github.io/shardpay/privacidad.html>

La fuente está en [`PRIVACIDAD.md`](PRIVACIDAD.md) y la publica el flujo
`.github/workflows/pages.yml` en GitHub Pages, que es gratis.

### 2.7 Subir la versión

```bash
flutter build appbundle --release \
  --dart-define=SHARDPAY_VERSION=1.0.0 \
  --dart-define=SHARDPAY_BUILD=26083101 \
  --dart-define=SHARDPAY_COMMIT=$(git rev-parse --short HEAD) \
  --dart-define=SHARDPAY_BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-name=1.0.0 --build-number=26083101
```

El AAB sale en `build/app/outputs/bundle/release/app-release.aab`.

---

## 3. App Store

### 3.1 Coste

**Apple Developer Program: 99 €/año, y es inevitable.** No hay forma de publicar
en la App Store sin ello, ni siquiera una app gratuita. Además hace falta un Mac
para compilar y firmar.

### 3.2 Trabajo pendiente

Véase [ADR-0007](adr/0007-escritorio-e-ios.md). En resumen:

| Pieza | Qué falta |
| --- | --- |
| `Info.plist` | `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription`, redactadas en los 13 idiomas |
| `Info.plist` | Declarar el tipo de documento `.shardpay.bak` (`CFBundleDocumentTypes` + `UTExportedTypeDeclarations`) |
| Firebase | `GoogleService-Info.plist` y cliente OAuth de iOS |
| Donación | Decidir si se envía activada; por defecto va apagada |
| Cuenta | Apple Developer Program |

Textos sugeridos para los permisos (castellano; el resto en
[`store/ficha-appstore.md`](store/ficha-appstore.md)):

- **Cámara:** «ShardPay usa la cámara para fotografiar tus tickets. El texto se
  reconoce en tu propio dispositivo y la foto no se envía a ningún servicio
  externo.»
- **Fotos:** «ShardPay accede a tus fotos solo para que puedas elegir la imagen
  de un ticket que ya tengas guardada.»

### 3.3 Equivalencias con Google Play

| Google Play | App Store Connect |
| --- | --- |
| Descripción corta | Subtítulo (30 caracteres) |
| Descripción larga | Descripción (4000) |
| Gráfico destacado | No existe |
| Clasificación IARC | Age Rating propio de Apple |
| Seguridad de los datos | App Privacy («Nutrition Label») |
| Pruebas cerradas | TestFlight |

En App Privacy, las respuestas son las mismas que en la tabla de la sección 2.4.

### 3.4 Verificación de portabilidad

Sin cuenta de pago se puede comprobar que el código Dart compila para iOS:

```bash
flutter build ios --no-codesign
```

Está en el flujo de integración continua, en un trabajo que corre en macOS y que
**no bloquea** la publicación de Android.

---

## 4. Alertas de presupuesto

Presupuesto máximo del proyecto: **5 €/mes sumando todos los servicios**.

### Pasar el proyecto a Blaze

ShardPay necesita **Blaze** porque usa Cloud Functions (la notificación push de
`functions/index.js`), y Spark no las permite. El porqué y las cinco capas de
control de gasto están en
[ADR-0010](adr/0010-plan-blaze-y-control-de-gasto.md).

Blaze **incluye el mismo cupo gratuito mensual que Spark**. Por debajo de él la
factura es de 0 €. Lo que desaparece es el tope automático, y de ahí todo lo que
viene a continuación.

1. Consola de Firebase → **⚙ Configuración del proyecto** → **Uso y facturación**
   → **Detalles y configuración** → **Modificar plan** → **Blaze**.
2. Asocia una cuenta de facturación de Google Cloud. Si no tienes ninguna, se
   crea en el mismo paso.
3. En el mismo diálogo, Firebase ofrece un **importe de alerta de presupuesto**.
   Pon **5 €**. No sustituye al presupuesto de Cloud Billing de abajo: es una
   alerta más, y cuantas más haya, mejor.
4. Comprueba después que **el cupo gratuito sigue aplicándose**: Uso y
   facturación → **Uso** debe seguir enseñando el consumo contra los límites sin
   coste.

### Google Cloud (proyecto de Firebase)

1. Entra en <https://console.cloud.google.com/billing> y selecciona la cuenta de
   facturación del proyecto de Firebase.
2. **Presupuestos y alertas** → **Crear presupuesto**.
3. **Alcance:** filtra por el proyecto de ShardPay. Sin filtro, la alerta
   vigilaría toda tu cuenta.
4. **Importe:** presupuesto fijo de **5 EUR**.
5. **Umbrales de alerta:** 50 %, 90 % y 100 % del gasto real. Añade uno al 100 %
   del gasto **previsto**, que avisa antes de que ocurra.
6. **Destinatarios:** tu correo. Marca «Enviar alertas por correo a los
   administradores de facturación».
7. Guarda.

> Un presupuesto **avisa, no corta**. Google no interrumpe el servicio al
> llegar al límite. Para cortar de verdad hay que atar una función de Cloud
> Functions al tema de Pub/Sub del presupuesto que deshabilite la facturación del
> proyecto. Está documentado en
> <https://cloud.google.com/billing/docs/how-to/notify>.

### Lo que sí limita el gasto de verdad

Un presupuesto es una alarma de incendios, no un extintor. Lo que de verdad acota
cuánto se puede consumir:

| Capa | Qué impide | Estado |
| --- | --- | --- |
| **Reglas de Firestore** | Que un desconocido barra la colección `groups` en bucle. Cada consulta sin filtro se cobra por documento leído; antes de [ADR-0009](adr/0009-lectura-de-invitaciones.md) cualquiera con una cuenta podía lanzarla | Hecho, con 37 pruebas contra el emulador |
| **`maxInstances: 10`** | Que una tormenta de escrituras levante instancias de función sin techo. Ya está fijado en `functions/index.js` | Hecho |
| **App Check** | Que se usen las credenciales de la app desde fuera de la app para consumir cuota | **Pendiente**, en la lista de abajo |
| **Corte manual** | Todo, en el peor caso: deshabilitar la facturación del proyecto desde Cloud Billing | Procedimiento, no automatismo |

### Repaso mensual

Cinco minutos, una vez al mes: Firebase → **Uso y facturación** → **Uso**.
Mirar lecturas de Firestore, invocaciones de funciones y almacenamiento. Lo que
se busca no es el número absoluto, es un **salto** que no cuadre con haber
ganado usuarios.

### Firebase

Mientras el proyecto siga en el **plan Spark (gratuito)** no puede haber gasto: al
llegar a las cuotas, el servicio se limita en lugar de facturar. El presupuesto
de arriba es la red de seguridad para el día en que alguien pase el proyecto a
Blaze sin darse cuenta.

Comprueba el plan en **Consola de Firebase → Uso y facturación**.

### Cuotas del plan Spark, para tenerlas a mano

| Servicio | Cuota diaria gratuita |
| --- | --- |
| Firestore — lecturas | 50 000 |
| Firestore — escrituras | 20 000 |
| Firestore — almacenamiento | 1 GiB total |
| Storage | 5 GB almacenados, 1 GB/día de descarga |
| Cloud Messaging | ilimitado |
| Authentication | ilimitado (salvo SMS, que no se usa) |

Para grupos de amigos, no se acerca.

---

## 5. Lista final de publicación

### Bloqueante

- [ ] **Activar App Check** antes de abrir el registro al público. Es la única
      capa de control de gasto que falta desde que el proyecto está en Blaze
      ([ADR-0010](adr/0010-plan-blaze-y-control-de-gasto.md)). Sin ella, las
      credenciales de la app sirven para consumir cuota desde fuera de la app.

### Código

- [x] `flutter analyze` sin avisos — *verificado el 2026-08-31 con Flutter 3.47.2*
- [x] `flutter test` en verde — *220 pruebas*
- [x] **Proveedores de acceso habilitados** en Firebase Auth: email/contraseña y
      Google — *verificado el 2026-08-31 contra el proyecto*
- [x] **Reglas desplegadas** en el proyecto (`firebase deploy --only firestore:rules`)
      — *2026-08-31*
- [x] **Alta, acceso, cierre de sesión y borrado de cuenta probados en un
      dispositivo físico** contra Firebase real, comprobando en cada paso que la
      cuenta aparece y desaparece del proyecto
- [x] Reglas de Firestore probadas contra el emulador — *38 comprobaciones,
      `cd firestore-tests && npm test`* — [ADR-0009](adr/0009-lectura-de-invitaciones.md)
- [x] Proyecto en **Blaze** con presupuesto de 5 € y alertas al 50/90/100 % —
      [ADR-0010](adr/0010-plan-blaze-y-control-de-gasto.md)
- [ ] `./gradlew :app:dependencies` sin `billingclient`
- [x] Probado en dispositivo físico — *acceso completo; falta el lector con un ticket de papel*
- [ ] Las 13 paletas revisadas
- [ ] Los 14 idiomas revisados
- [ ] Árabe en RTL revisado, con captura
- [ ] Panel de donación revisado en las 6 paletas y en RTL, con capturas
- [ ] Exportar → borrar datos → importar devuelve el estado anterior
- [ ] TalkBack probado en las pantallas principales

### Firma y compilación

- [ ] `android/key.properties` fuera del repositorio
- [ ] Huellas SHA-1 y SHA-256 registradas en Firebase
- [ ] `versionCode` mayor que el de la versión anterior
- [ ] AAB generado con los `--dart-define` de versión, compilación y commit

### Ficha de Play

- [ ] Título, descripción corta y larga en los 13 idiomas
- [ ] Icono 512 × 512
- [ ] Gráfico destacado 1024 × 500
- [ ] Al menos 2 capturas de teléfono
- [ ] Clasificación de contenido completada
- [ ] Seguridad de los datos completada
- [ ] URL de política de privacidad accesible y pública
- [ ] Público objetivo declarado
- [ ] **Compras integradas: No**
- [ ] Capturas de ambas políticas guardadas con fecha en `docs/store/politicas/`

### Pruebas cerradas

- [ ] 12 testers invitados
- [ ] 12 testers con la invitación aceptada **y** la app instalada
- [ ] 14 días consecutivos cumplidos
- [ ] Acceso a producción solicitado

### Repositorio

- [ ] `CHANGELOG.md` cerrado con la versión y la fecha
- [ ] Etiqueta `v1.0.0` creada
- [ ] GitHub Release con el AAB, el APK y los documentos adjuntos
- [ ] GitHub Pages publicado con la política de privacidad
- [ ] Sin secretos en la historia de git

### Después

- [ ] Presupuesto de 5 € configurado y probado
- [ ] Correo de contacto operativo: `ghatostudioofficial@gmail.com`

> El correo de contacto de la ficha de Play y de la política de privacidad es
> **ghatostudioofficial@gmail.com**. Es el mismo que aparece en **Ajustes → Acerca de**,
> en `SECURITY.md` y en la página del proyecto: si cambia, hay que cambiarlo en
> los cinco sitios.
