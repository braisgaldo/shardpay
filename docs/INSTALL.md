# Instalación y despliegue

## Requisitos

| Herramienta | Versión | Para qué |
| --- | --- | --- |
| Flutter | 3.35 o superior (Dart 3.11+) | compilar la app |
| JDK | 17 | Gradle y Android |
| Android SDK | API 36, *build-tools* 36 | compilar y firmar |
| Node.js | 20 o superior | solo para `firebase-tools` |
| Pandoc | 3.x | solo para generar los documentos en PDF y DOCX |

Comprueba el estado con:

```bash
flutter doctor -v
```

## Poner en marcha el proyecto

```bash
git clone https://github.com/braisgaldo/shardpay.git
cd shardpay
flutter pub get
```

### Sin Firebase: modo de demostración

La app arranca sin ninguna credencial. En cuanto detecta que faltan, usa un
repositorio en memoria con datos de ejemplo y la app es completamente navegable.

```bash
flutter run
```

Es el modo recomendado para tocar la interfaz, hacer capturas y probar el lector
de tickets sin tocar producción.

> El plugin de Gradle de Google Services solo se aplica si existe
> `android/app/google-services.json`. Sin ese fichero el proyecto **compila
> igualmente** y Gradle lo avisa por consola. Antes no: la compilación abortaba
> en `processDebugGoogleServices` y un clon limpio no se podía compilar.

### Con Firebase real

La configuración sensible **no se versiona**. Parte de la plantilla:

```bash
cp config/firebase.template.json config/firebase.local.json
```

Rellena los valores desde la consola de Firebase y lanza la app pasándolos por
`--dart-define`:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=...
```

En Windows hay un ayudante que lo hace por ti:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\configure-firebase.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\run-android.ps1
```

Además necesitas `android/app/google-services.json`, que tampoco se versiona.

## Compilar

### Depuración

```bash
flutter run -d <dispositivo>
```

### Publicación

```bash
flutter build appbundle --release \
  --dart-define=SHARDPAY_VERSION=1.0.0 \
  --dart-define=SHARDPAY_BUILD=26083101 \
  --dart-define=SHARDPAY_COMMIT=$(git rev-parse --short HEAD) \
  --dart-define=SHARDPAY_BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-name=1.0.0 \
  --build-number=26083101
```

Esos `--dart-define` son los que hacen que **Ajustes → Acerca de** sepa decir de
qué commit salió el binario. Sin ellos, la pantalla avisa de que es una
compilación local.

### Fórmula del `versionCode`

```
versionCode = AAMMDDNN
```

- `AA` — dos últimas cifras del año, en UTC
- `MM` — mes
- `DD` — día
- `NN` — número de compilación de ese día, empezando en 01

Ejemplo: la primera compilación del 31 de agosto de 2026 es `26083101`.

Es creciente por construcción mientras no se hagan más de 99 compilaciones en un
día, y se lee de un vistazo. Google Play exige que sea estrictamente creciente y
menor que 2 100 000 000; esta fórmula lo cumple hasta el año 2100.

## Firma de publicación

**El almacén de claves nunca entra en el repositorio.** Está en `.gitignore`
junto con `android/key.properties`.

### Generar el almacén

```bash
keytool -genkey -v \
  -keystore ~/claves/shardpay-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias shardpay
```

Guarda el `.jks` y la contraseña **fuera del proyecto** y haz una copia en un
sitio seguro: si se pierde, no se puede volver a publicar una actualización de la
app con esa firma. (Si tienes activada la Firma de aplicaciones de Play, Google
guarda la clave de firma y tú solo pierdes la de carga, que sí es recuperable.)

### Declararlo

Crea `android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=shardpay
storeFile=/ruta/absoluta/a/shardpay-release.jks
```

Si el fichero no existe, el proyecto **sigue compilando**: la versión de
publicación cae a la firma de depuración y Gradle avisa por consola de que ese
binario no se puede subir a Play.

### Huellas para Firebase

El inicio de sesión con Google necesita las huellas de la clave registradas en
Firebase:

```bash
keytool -list -v -keystore ~/claves/shardpay-release.jks -alias shardpay
```

Copia SHA-1 y SHA-256 a **Consola de Firebase → Configuración del proyecto →
Tus apps → Android → Añadir huella digital**. Haz lo mismo con la clave de
depuración (`~/.android/debug.keystore`, contraseña `android`) o el inicio de
sesión no funcionará en desarrollo.

## Regenerar credenciales

Si sospechas que una credencial se ha filtrado, en este orden:

1. **Clave de API de Firebase.** Consola de Google Cloud → APIs y servicios →
   Credenciales → regenerar. Actualiza los `--dart-define` y los *secrets* de
   GitHub.
2. **Cliente OAuth.** Consola de Google Cloud → Credenciales → borrar el cliente
   y crear uno nuevo. Vuelve a añadir las huellas SHA.
3. **Almacén de claves de firma.** No se puede rotar sin perder la continuidad de
   la app en Play, salvo que uses la Firma de aplicaciones de Play, en cuyo caso
   sí se puede sustituir la clave de carga desde la consola de Play.
4. **Secrets de GitHub Actions.** Repositorio → Settings → Secrets and variables
   → Actions.

## Renombrar el identificador de aplicación

Solo tiene sentido **antes de la primera publicación**. Después, Google Play no
lo permite. Véase [ADR-0003](adr/0003-identificador-de-aplicacion.md).

1. `android/app/build.gradle.kts`: `applicationId` y `namespace`.
2. Mover `android/app/src/main/kotlin/com/ghatostudio/shardpay/` a la ruta nueva
   y actualizar el `package` de `MainActivity.kt`.
3. `lib/core/app_config.dart`: valor por defecto de `FIREBASE_IOS_BUNDLE_ID`.
4. `lib/core/app_info.dart`: `applicationId`.
5. Registrar una **aplicación nueva** en Firebase con el nombre de paquete nuevo,
   añadirle las huellas SHA y descargar el `google-services.json` nuevo.
6. `ios/Runner.xcodeproj`: `PRODUCT_BUNDLE_IDENTIFIER`.
7. Volver a verificar el enlace de aplicación `https://shardpay.app/join`.

## Activar el acceso real

Sin credenciales, la app arranca en **modo de demostración local**: datos en
memoria, sin cuenta y sin nube. Es lo que permite desarrollar y hacer capturas
sin tocar producción, pero no es la app.

Para que el acceso sea real hacen falta **tres cosas**, y las tres se olvidan por
separado:

### 1. Credenciales en el binario

Los valores viven en `config/firebase.local.json`, que **no** va en commits.
Hay una plantilla vacía al lado, `config/firebase.template.json`.

```bash
flutter run  --dart-define-from-file=config/firebase.local.json
flutter build apk --release --dart-define-from-file=config/firebase.local.json
```

Si faltan, `AppConfig.hasFirebaseConfiguration` da falso y `AppBootstrap` cae al
repositorio de demostración **sin avisar en una compilación de publicación**: la
app funciona, parece normal y no guarda nada en la nube. Es el fallo más fácil de
no ver, así que compruébalo en el log:

```bash
adb logcat | grep FirebaseApp     # tiene que decir "initialization successful"
```

Para Android hace falta además `android/app/google-services.json`, que tampoco va
en commits. Sin él, Gradle avisa por consola y compila igual, pero el acceso con
Google y las notificaciones no funcionan.

### 2. Proveedores habilitados en el proyecto

**Esto es configuración del proyecto, no del código, y es lo que más despista:**
la app compila bien, se conecta bien, y el alta falla con
`OPERATION_NOT_ALLOWED`. ShardPay traduce ese error a «El alta por email todavía
no está habilitada en Firebase Auth para este proyecto», que es exactamente lo
que pasa.

Consola de Firebase → **Authentication** → **Sign-in method**, y habilita
**Email/Password** y **Google**.

Para comprobarlo sin abrir la consola:

```bash
curl -s -X POST \
  "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=TU_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"email":"sonda@ejemplo.com","password":"Sonda123456","returnSecureToken":true}'
```

Si responde `OPERATION_NOT_ALLOWED`, el proveedor está apagado. Si crea la cuenta,
bórrala: no dejes cuentas sonda en el proyecto.

### 3. Reglas desplegadas

Las reglas del repositorio **no son las que aplican** hasta que se despliegan:

```bash
npx firebase deploy --only firestore:rules,storage:rules
```

Con reglas antiguas, la app nueva parece funcionar hasta que alguien intenta
unirse por invitación o borrar su cuenta, y entonces recibe un «permiso
denegado» sin explicación. Antes de desplegar, pasa la suite:

```bash
cd firestore-tests && npm test
```

### Comprobación de que está de verdad activado

Cuatro flujos, en este orden, con un correo desechable:

1. **Crear cuenta.** La cabecera debe saludarte con tu nombre.
2. **Cerrar sesión.** Vuelve a la pantalla de acceso.
3. **Volver a entrar** con el mismo correo.
4. **Eliminar el perfil.** Debe echarte a la pantalla de acceso.

Y después, que el proyecto haya quedado limpio:

```bash
npx firebase auth:export /tmp/usuarios.json --project TU_PROYECTO --format=json
```

## Reglas de Firestore y Storage

```bash
npx firebase deploy --only firestore:rules,firestore:indexes,storage
```

Los ficheros son `firestore.rules` y `storage.rules`. Léelos antes de tocarlos:
son la única barrera entre los datos de un grupo y quien no es miembro.

> Para Storage el objetivo es `storage`, **no** `storage:rules`: lo que va
> detrás de los dos puntos se interpreta como el nombre de un *target* de
> bucket, y el despliegue aborta con `Could not find rules for the following
> storage targets: rules`. Firestore sí acepta `firestore:rules` y
> `firestore:indexes`.

Antes de desplegar, pasa las pruebas de las reglas contra el emulador; están en
`firestore-tests/` y no necesitan credenciales ni proyecto real:

```bash
cd firestore-tests && npm install && npm test
```

## Documentación en HTML y PDF

El manual de usuario, el manual técnico, la guía de publicación y la política de
privacidad se publican también en HTML y PDF, con portada, índice y estilo
propio. Los binarios **no se versionan**: la fuente es el Markdown de `docs/`, y
los generados se adjuntan a la Release.

```bash
bash docs/build-docs.sh          # Linux y macOS
pwsh docs/build-docs.ps1         # Windows

bash docs/build-docs.sh --no-pdf # solo HTML, sin necesitar navegador
```

Hace falta **Python 3.9 o superior**; los scripts instalan `markdown`,
`pygments` y `pillow` si no están. El PDF lo imprime **Edge o Chrome sin
ventana**, que ya están en cualquier equipo de desarrollo y en los ejecutores de
GitHub: no hace falta Pandoc ni una distribución de TeX.

`pillow` está para las **capturas del manual de usuario**: se recortan las barras
del sistema, se reescalan y se incrustan en el HTML como `data:` URI, de forma
que el documento generado es **un solo fichero** que se puede mandar por correo o
subir a la web sin arrastrar una carpeta de imágenes detrás. Las capturas de la
ficha de la tienda se quedan intactas en `docs/store/capturas/`.

Salen en `docs/out/`, que está en `.gitignore`.
