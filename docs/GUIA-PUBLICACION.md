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

Los textos están en [`google_play/textos/`](google_play/textos/), **un fichero
por idioma**, catorce en total. Las longitudes ya están comprobadas contra los
límites.

| Campo | Límite | Estado |
| --- | --- | --- |
| Título | 30 caracteres | listo, 14 idiomas |
| Descripción corta | 80 caracteres | listo, 14 idiomas |
| Descripción larga | 4000 caracteres | listo, 14 idiomas |
| Icono | 512 × 512 PNG, 32 bits | listo — `google_play/graficos/icono-512.png` |
| Gráfico destacado | 1024 × 500 | listo — `google_play/graficos/destacado-1024x500.png` |
| Capturas de teléfono | 2 mínimo, 8 máximo | listo — ocho en `google_play/capturas/`, montadas a 9:16 |
| Capturas de tablet | opcional | no hay |

Las **notas de la versión** van aparte, en el paso de crear la versión, y en otro
formato: Play las pide todas juntas etiquetadas por idioma. Están listas para
pegar en [`google_play/textos/notas-de-version.md`](google_play/textos/notas-de-version.md).

#### Categoría y etiquetas

- **Tipo**: aplicación, no juego.
- **Categoría**: **Finanzas**.
- **Etiquetas**: solo las que sean ciertas. No hay que llegar a cinco.

Finanzas y no Productividad porque es donde busca la gente que necesita esto:
Splitwise, Tricount y Settle Up están ahí.

**No marcar** ninguna etiqueta de banca, préstamos, pagos, transferencias,
carteras, inversión, criptomonedas, impuestos, seguros ni puntuación crediticia.
Ninguna es cierta, y una sola puede meter la ficha en la revisión de servicios
financieros que se evita declarando que no hay funciones financieras (§2.8).

### 2.3 Clasificación de contenido

Cuestionario IARC. Las respuestas, con su razonamiento, están en
[`google_play/clasificacion-de-contenido.md`](google_play/clasificacion-de-contenido.md).
Resultado esperado: **PEGI 3 / Todos**.

Las tres que se responden mal con más facilidad:

- **¿Los usuarios intercambian contenido?** **Sí.** La tentación es decir que no
  porque no hay chat, pero las notas de un gasto son texto libre que leen los
  demás miembros del grupo. Declarar que no y que Google lo vea después es peor.
- **¿Se puede denunciar o bloquear?** **No**, ninguna de las dos. Lo que hay a
  cambio es que los grupos son cerrados —código **y** PIN, sin descubrimiento— y
  que **quien administra puede expulsar a cualquier miembro**.
- **¿Juegos de azar?** **No.** La app maneja dinero, pero no hay apuesta, ni
  premio, ni azar.

### 2.4 Seguridad de los datos

Formulario obligatorio, y lo que se declare **sale publicado en la ficha**. La
autoridad son las respuestas de
[`google_play/seguridad-de-datos.md`](google_play/seguridad-de-datos.md), que
llevan al lado dónde comprobar cada una en el código.

Siete tipos de datos, todos **recogidos**, **ninguno compartido**:

| Tipo | Recogido | Compartido | Obligatorio | Finalidad |
| --- | --- | --- | --- | --- |
| Nombre | Sí | No | Sí | Funcionalidad + Gestión de cuentas |
| Dirección de correo | Sí | No | Sí | Funcionalidad + Gestión de cuentas |
| IDs de usuario | Sí | No | Sí | Funcionalidad + Gestión de cuentas |
| Historial de compras | Sí | No | Sí | Funcionalidad |
| Otra información financiera | Sí | No | Sí | Funcionalidad |
| Otro contenido generado por el usuario | Sí | No | Sí | Funcionalidad |
| IDs de dispositivo | Sí | No | **No** | Funcionalidad |

Y las cinco trampas de este formulario:

- **Fotos: No.** Contraintuitivo. La foto de un ticket se lee en el propio móvil
  y se descarta; no hay ninguna pantalla para adjuntarla a un gasto, y los campos
  `receiptStoragePath` y `receiptDownloadUrl` del modelo están siempre en nulo
  porque nadie llama a `uploadReceipt`.
- **Información para pagos del usuario: No.** La app no procesa pagos. Marcarla
  publicaría que recoge datos de tarjeta, que es falso.
- **Historial de compras: Sí**, aunque no se venda nada. Google lo define como
  «transacciones que ha hecho el usuario» sin exigir que pasen por la app, y un
  gasto es exactamente eso.
- **«Se comparten»: en ninguno.** Firebase es un proveedor de servicios, no un
  tercero; y lo que ve el resto del grupo llega por una acción deliberada
  —teclear un código y un PIN— cuyo efecto el usuario espera. Las dos son
  exenciones que el propio formulario reconoce.
- **El token de notificaciones es el único opcional**, y solo desde la 1.2.1:
  antes se guardaba aunque se rechazara el permiso.

Además: **cifrado en tránsito**, sí, lo impone Firebase. **Ninguno se trata de
forma temporal**: todo se guarda en Firestore.

### 2.5 Eliminación de datos

Dos URL, en campos distintos:

| Campo | URL |
| --- | --- |
| Eliminación de cuentas | <https://braisgaldo.github.io/shardpay/eliminar-cuenta.html> |
| Solicitud de eliminación de datos | la misma, con `#borrar-datos-concretos-sin-eliminar-la-cuenta` |

La segunda existe porque a la pregunta «¿pueden los usuarios borrar algunos datos
sin eliminar la cuenta?» la respuesta es **sí**: se puede borrar un gasto, un
grupo o la propia participación desde la app. La fuente de la página es
[`ELIMINAR-CUENTA.md`](ELIMINAR-CUENTA.md) y la publica el mismo flujo de Pages.

### 2.6 Datos de inicio de sesión

Antes «Acceso a la app». **Sí, hay partes restringidas, y hay que dar
credenciales.** Es fácil responderlo mal: la tentación es decir que no hacen
falta porque cualquiera se crea una cuenta desde la app, pero el propio
formulario avisa de que **Google no crea cuentas para revisar**. Sin
credenciales, el revisor se queda en la pantalla de acceso y rechaza la versión.

Hay una cuenta de revisión creada para esto. La contraseña va en el gestor de
contraseñas, junto a la clave de firma.

Conviene decirle al revisor que al entrar sale un tour guiado y que el lector de
tickets está dentro de un grupo, en «Ticket con cámara» o «Subir ticket».

### 2.7 Público objetivo y privacidad

- **Edad**: 18 y más. Gestión de dinero entre adultos.
- **¿Atrae a menores?** No. Ni gráficos infantiles, ni personajes, ni temática
  escolar.
- **Política de privacidad**:
  <https://braisgaldo.github.io/shardpay/privacidad.html>. La fuente está en
  [`PRIVACIDAD.md`](PRIVACIDAD.md) y la publica `.github/workflows/pages.yml`.

### 2.8 Los tres formularios que se responden en un minuto

| Formulario | Respuesta |
| --- | --- |
| **ID de publicidad** | **No usa ninguno.** Comprobado en el manifiesto fusionado del paquete: `aapt2 dump permissions` no saca `com.google.android.gms.permission.AD_ID`. No hay que marcar «desactivar errores de la versión»: esa casilla es para quien declara que sí |
| **Funciones financieras** | **«Mi aplicación no proporciona funciones financieras».** Ninguna de las otras. La app no mueve dinero, no procesa pagos y no se conecta a ningún banco: calcula quién debe qué. Marcar cualquiera abre una verificación regulatoria que no corresponde |
| **Aplicaciones de salud** | **«Mi aplicación no tiene ninguna función de salud»** |

### 2.9 Subir la versión

El `versionCode` sigue la fórmula `AAMMDDNN` de [`INSTALL.md`](INSTALL.md) y
**tiene que subir en cada envío**: Play rechaza uno repetido.

```bash
VERSION=1.2.1
BUILD=26090202

flutter build appbundle --release \
  --dart-define-from-file=config/firebase.local.json \
  --dart-define=SHARDPAY_VERSION=$VERSION \
  --dart-define=SHARDPAY_BUILD=$BUILD \
  --dart-define=SHARDPAY_COMMIT=$(git rev-parse --short HEAD) \
  --dart-define=SHARDPAY_BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-name=$VERSION --build-number=$BUILD
```

El AAB sale en `build/app/outputs/bundle/release/app-release.aab`. **Comprueba
las dos cosas que Play rechaza**, antes de subirlo:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep -i propietario
# CN=Ghato Studio  -> correcto
# CN=Android Debug -> Gradle no encontro android/key.properties. Play lo rechaza

aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | head -1
# versionCode nuevo y mayor que el anterior
```

Si compilas **sin** `--dart-define-from-file`, la app se publica en modo de
demostración local: funciona, parece normal y no guarda nada en la nube. No
avisa. Compruébalo con `adb logcat | grep FirebaseApp`, que debe decir
«initialization successful».

Todo el detalle de la firma, y el paso de Play App Signing que no se ve fallar,
está en [`google_play/FIRMA.md`](google_play/FIRMA.md).

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

- [x] `flutter analyze` sin avisos — *verificado el 2026-09-02 con Flutter 3.47.2*
- [x] `flutter test` en verde — *231 pruebas*
- [x] Reglas de Firestore probadas contra el emulador — *44 comprobaciones,
      `cd firestore-tests && npm test`* — [ADR-0009](adr/0009-lectura-de-invitaciones.md)
- [x] **Reglas desplegadas** en el proyecto (`firebase deploy --only firestore:rules`)
      — *2026-09-02*
- [x] **Proveedores de acceso habilitados** en Firebase Auth: email/contraseña y
      Google — *verificado contra el proyecto*
- [x] **Alta, acceso, cierre de sesión y borrado de cuenta probados en un
      dispositivo físico** contra Firebase real, comprobando en cada paso que la
      cuenta aparece y desaparece del proyecto
- [x] **Entrada por invitación probada en un dispositivo físico** con una segunda
      cuenta, reclamando un hueco reservado. No es opcional: esto estuvo roto en
      producción en la 1.1.0 y la suite no lo cogía
- [x] **Expulsar a un miembro probado en un dispositivo físico**, comprobando que
      la participación queda como «histórico» y los saldos no cambian
- [x] Proyecto en **Blaze** con presupuesto de 5 € y alertas al 50/90/100 % —
      [ADR-0010](adr/0010-plan-blaze-y-control-de-gasto.md)
- [ ] `./gradlew :app:dependencies` sin `billingclient`
- [ ] **Abrir la cámara del lector de tickets** en un dispositivo, después de
      quitar `RECORD_AUDIO` del manifiesto en la 1.2.1
- [ ] Las 13 paletas revisadas
- [ ] Los 14 idiomas revisados
- [ ] Árabe en RTL revisado, con captura
- [ ] Panel de donación revisado en las 6 paletas y en RTL, con capturas
- [ ] Exportar → borrar datos → importar devuelve el estado anterior
- [ ] TalkBack probado en las pantallas principales

### Firma y compilación

- [x] `android/key.properties` y el `.jks` fuera del repositorio, con copia
      guardada en otro sitio
- [x] Huellas SHA-1 y SHA-256 de la clave de subida registradas en Firebase
- [x] SHA-1 de **Play App Signing** registrado en Firebase
- [x] `versionCode` mayor que el de la versión anterior — *fórmula `AAMMDDNN`*
- [x] AAB generado con los `--dart-define` de versión, compilación y commit
- [x] Certificado del artefacto comprobado con `keytool` antes de subirlo
      (`CN=Ghato Studio`, no `CN=Android Debug`)
- [ ] Secretos de firma configurados en GitHub para que el flujo `Release`
      compile él los paquetes — hasta entonces **falla a propósito** y el
      paquete se compila a mano ([`google_play/FIRMA.md`](google_play/FIRMA.md))

### Ficha de Play

- [x] Título, descripción corta y larga en los **14** idiomas —
      [`google_play/textos/`](google_play/textos/)
- [x] Icono 512 × 512 y gráfico destacado 1024 × 500 —
      [`google_play/graficos/`](google_play/graficos/)
- [x] Ocho capturas de teléfono montadas a 9:16 —
      [`google_play/capturas/`](google_play/capturas/)
- [x] Notas de la versión en los 14 idiomas, dentro del límite de 500 caracteres
- [ ] **Categoría Finanzas**, tipo aplicación, y ninguna etiqueta de banca,
      préstamos, pagos, transferencias, inversión ni criptomonedas (§2.2)
- [ ] Clasificación de contenido completada (§2.3)
- [ ] Seguridad de los datos completada (§2.4)
- [ ] **Las dos URL de eliminación de datos** (§2.5)
- [ ] Credenciales de la cuenta de revisión dadas en «Datos de inicio de sesión»
      (§2.6). Sin ellas, el revisor se queda en la pantalla de acceso
- [ ] Público objetivo declarado: 18 y más
- [ ] **Compras integradas: No**
- [ ] **ID de publicidad: No** — y sin marcar «desactivar errores de la versión»
- [ ] **Funciones financieras: ninguna**
- [ ] **Funciones de salud: ninguna**
- [ ] URL de política de privacidad accesible y pública
- [ ] Capturas de las políticas guardadas con fecha en `store/politicas/`

### Pruebas cerradas

- [ ] 12 testers invitados
- [ ] 12 testers con la invitación aceptada **y** la app instalada
- [ ] 14 días consecutivos cumplidos
- [ ] Acceso a producción solicitado

> **Instala desde Play, no por USB.** Es la única forma de comprobar que Play App
> Signing no ha roto el acceso con Google: por USB se instala el paquete firmado
> con la clave de subida, que sí está registrada, y el fallo no se ve.

### Repositorio

- [x] `CHANGELOG.md` cerrado con la versión y la fecha
- [x] Etiqueta `v1.2.0` creada y GitHub Release publicada con el AAB, el APK y
      los documentos
- [x] GitHub Pages publicado con la política de privacidad y la página de
      eliminación de cuenta
- [x] Sin secretos en la historia de git
- [ ] Etiqueta `v1.2.1`, pendiente de comprobar la cámara

### Después

- [ ] Presupuesto de 5 € configurado y probado
- [ ] Correo de contacto operativo: `ghatostudioofficial@gmail.com`

> El correo de contacto de la ficha de Play y de la política de privacidad es
> **ghatostudioofficial@gmail.com**. Es el mismo que aparece en **Ajustes → Acerca de**,
> en `SECURITY.md` y en la página del proyecto: si cambia, hay que cambiarlo en
> los cinco sitios.
