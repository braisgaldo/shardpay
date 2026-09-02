# La firma de ShardPay

Todo lo que hay que saber sobre cómo está firmada la app y qué pasa si se pierde
la clave. **Este fichero no contiene la contraseña**: está en
`android/key.properties`, que no va en git.

## Lo que hay ahora mismo

| | |
| --- | --- |
| **Almacén** | `android/shardpay-upload.jks` |
| **Formato** | PKCS12 |
| **Alias** | `shardpay` |
| **Algoritmo** | RSA 2048, SHA256withRSA |
| **Validez** | 10 000 días (hasta 2053) |
| **Titular** | `CN=Ghato Studio, OU=ShardPay, O=Ghato Studio, L=A Coruna, C=ES` |
| **Contraseña** | 28 caracteres aleatorios, en `android/key.properties` |
| **Creada** | 1 de septiembre de 2026 |

Huellas:

```
SHA-1    3D:E5:D5:5C:26:77:F8:95:DD:D4:55:08:FA:EE:A6:DA:0C:A2:1A:04
SHA-256  76:F1:86:FC:5B:AC:65:19:AC:9F:0E:15:DB:63:76:E7:EA:78:67:58:BE:69:A1:2C:35:D7:37:80:81:6E:0B:78
```

Las dos están **registradas en Firebase** para el app id
`1:626260906991:android:8749331d8c852a841f5c1a`. Sin eso, el acceso con Google
falla con `DEVELOPER_ERROR`.

## Lo primero: haz una copia

Los dos ficheros están fuera de git a propósito, así que **no hay copia en
ninguna parte** salvo la que hagas tú:

```
android/shardpay-upload.jks
android/key.properties
```

Guárdalos juntos, cifrados, fuera de este ordenador. Un gestor de contraseñas con
adjuntos vale; un correo a ti mismo, no.

**Qué pasa si los pierdes.** Con Play App Signing activado —lo normal— la clave
que firma lo que instala la gente la custodia Google, y esta de aquí es solo la
llave de subida: se puede reemplazar abriendo una incidencia con Google y
esperando unos días. **Sin** Play App Signing, perderla significa que nadie puede
volver a publicar una actualización de la app. Nunca. Se acabó.

## Cómo se usa al compilar

Gradle lee `android/key.properties` solo. No hay que pasar nada por línea de
comandos:

```bash
flutter build appbundle --release --dart-define-from-file=config/firebase.local.json
flutter build apk        --release --dart-define-from-file=config/firebase.local.json
```

Comprueba **siempre** con qué se ha firmado antes de subir:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep -i propietario
```

- `CN=Ghato Studio` → correcto.
- `CN=Android Debug` → Gradle no encontró `key.properties` y ha caído a la clave
  de depuración. Play lo rechaza.

### Una trampa que costó tres compilaciones

`storeFile` en `key.properties` va **relativo a `android/`**, que es donde está
el propio `key.properties`. Gradle, por defecto, lo resolvería contra
`android/app/`, y el error que sale es:

```
Keystore file '...\android\app\shardpay-upload.jks' not found for signing config 'release'
```

...sin decir contra qué directorio ha buscado ni por qué. `build.gradle.kts` lo
resuelve ya contra `android/`, y acepta rutas absolutas tal cual. Si mueves el
`.jks` a otro sitio, pon la ruta absoluta y te ahorras el problema.

## El paso que falta, y que no se ve fallar

Play App Signing hace que Google firme la app con **una clave suya**, distinta de
esta. La app que instala la gente lleva **otro certificado, con otro SHA-1**.

Después del primer envío:

1. Play Console → **Configuración de la aplicación** → **Integridad de la
   aplicación** → certificado de firma de apps.
2. Copia su SHA-1 y regístralo también:

**Ya está hecho** para esta app: el SHA-1 de Play App Signing es
`A1:75:DF:D5:7A:78:95:03:02:3D:B9:13:07:56:B9:FD:9C:28:9A:83` y está registrado.
Lo que queda es comprobarlo instalando **desde Play**, porque por USB se instala
el paquete firmado con la clave de subida y el fallo no se ve.

```bash
npx firebase apps:android:sha:create \
  1:626260906991:android:8749331d8c852a841f5c1a <SHA-1-de-Play> --project shardpay
```

Si te lo saltas, el acceso con Google **funciona en tu móvil** —tu clave de
subida está registrada— y **falla en el de todos los demás**. Es el peor tipo de
fallo que hay: el que tú no ves.

## Rehacerla desde cero

Solo si no existe. Si ya hay una publicada, esto no la sustituye.

```powershell
pwsh scripts/crear-clave-subida.ps1
```

## Para la CI

`.github/workflows/release.yml` ya trae el paso que reconstruye el almacén desde
un secreto; lo que falta es **crear los secretos**. En GitHub → Settings →
Secrets and variables → Actions, con estos nombres exactos:

| Secreto | Valor |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 android/shardpay-upload.jks` |
| `ANDROID_STORE_PASSWORD` | la contraseña de `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | la misma |
| `ANDROID_KEY_ALIAS` | `shardpay` |

Y los de Firebase, o la CI publicará una app en modo de demostración:
`FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
`FIREBASE_STORAGE_BUCKET`, `FIREBASE_ANDROID_APP_ID` y
`GOOGLE_SERVER_CLIENT_ID`, todos en `config/firebase.local.json`.

Mientras eso no exista, **el paquete que se sube a Play se compila a mano**, no
lo produce la CI. El workflow **falla a propósito** si el secreto no está: antes
avisaba y seguía, y el resultado era una Release con un AAB firmado en
depuración —un fichero que parece la app, pesa como la app y Play rechaza—.
Publicar eso es peor que no publicar nada.

Hay además una comprobación después de compilar que mira el certificado del
artefacto de verdad, porque que exista `key.properties` no garantiza que Gradle
lo haya usado: una ruta mal resuelta en `storeFile` deja el paquete firmado en
depuración sin que nada falle.
