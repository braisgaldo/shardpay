# ShardPay

ShardPay es una app móvil en Flutter para repartir gastos en grupo con Firebase, invitaciones por enlace o QR, OCR local de tickets, reparto avanzado por persona e insights visuales.

## Funcionalidad actual

- Autenticación con Google y email/password.
- Grupos con administración, invitaciones y miembros pendientes de vincular.
- Creación de grupos con divisa configurable.
- Gastos manuales y gastos a partir de ticket usando cámara o galería.
- Reparto por porcentajes con suma obligatoria del 100%.
- Categorías por defecto y categorías personalizadas por grupo.
- Gráficos e insights calculados en cliente.
- Cambio de idioma y tema desde la app.
- Fallback a modo demo local si Firebase no está configurado.

## Stack técnico

- Flutter con Riverpod para estado y composición de pantallas.
- Firebase Auth, Firestore y Storage.
- ML Kit OCR en dispositivo para evitar coste de APIs externas.
- `fl_chart` para visualizaciones.
- `image_picker`, `mobile_scanner`, `qr_flutter` y `share_plus` para captura, QR y compartición.

## Requisitos

- Windows con PowerShell.
- JDK 17.
- Android SDK y `adb` disponibles.
- Node.js si vas a usar Firebase CLI mediante `npx firebase`.
- Una cuenta de Firebase si quieres backend real.

## Estructura relevante

- [lib](lib): código principal de la app.
- [lib/app](lib/app): bootstrap, tema, preferencias e infraestructura base.
- [lib/models](lib/models): modelos de dominio.
- [lib/repositories](lib/repositories): acceso a datos, con implementación Firebase y mock.
- [lib/screens](lib/screens): pantallas y flujos UI.
- [config](config): configuración local y plantillas Firebase.
- [scripts](scripts): utilidades para emulador, Firebase y ejecución Android.
- [test](test): pruebas automatizadas.
- [tools/flutter](tools/flutter): SDK local de Flutter usado por este repo en este entorno.

## Instalación

### 1. Preparar Flutter

Este proyecto usa Flutter local en [tools/flutter](tools/flutter). Si ya existe, no necesitas instalar otro SDK global para trabajar en este repo.

```powershell
.\tools\flutter\bin\flutter --version
.\tools\flutter\bin\flutter pub get
```

### 2. Preparar Android

Si no tienes emulador abierto, puedes arrancarlo con:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-emulator.ps1
```

Para lanzar la app en Android con el helper del repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android.ps1
```

También puedes ejecutar Flutter directamente:

```powershell
.\tools\flutter\bin\flutter run -d emulator-5554
```

## Configuración de Firebase real

### 1. Crear tu fichero local

La configuración sensible no se versiona. Parte de la plantilla incluida en [config/firebase.template.json](config/firebase.template.json):

```powershell
Copy-Item .\config\firebase.template.json .\config\firebase.local.json
```

Rellena después `config/firebase.local.json` con tus valores reales.

### 2. Variables esperadas

El fichero local debe contener estos campos:

- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_IOS_BUNDLE_ID`
- `GOOGLE_SERVER_CLIENT_ID`
- `GOOGLE_IOS_CLIENT_ID`

### 3. Enlazar el proyecto Firebase

```powershell
npx firebase login
npx firebase use --add
```

Si necesitas reconfigurar artefactos Firebase del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\configure-firebase.ps1
```

### 4. Ejecutar con Firebase activo

```powershell
.\tools\flutter\bin\flutter run -d emulator-5554 --dart-define-from-file=.\config\firebase.local.json
```

Si `firebase.local.json` no existe, la app entra en modo demo local automáticamente.

## Comandos útiles

Instalar dependencias:

```powershell
.\tools\flutter\bin\flutter pub get
```

Analizar el proyecto:

```powershell
.\tools\flutter\bin\flutter analyze lib test
```

Ejecutar tests:

```powershell
.\tools\flutter\bin\flutter test
```

Generar APK release:

```powershell
.\tools\flutter\bin\flutter build apk --dart-define-from-file=config/firebase.local.json
```

Instalar APK en un dispositivo conectado:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <DEVICE_ID> install -r "build\app\outputs\flutter-apk\app-release.apk"
```

## Cómo ampliar el desarrollo

### Añadir una nueva funcionalidad de producto

1. Define o extiende el modelo en [lib/models/app_models.dart](lib/models/app_models.dart).
2. Añade la firma necesaria en [lib/repositories/app_repository.dart](lib/repositories/app_repository.dart).
3. Implementa el cambio en Firebase y mock para no romper el modo demo:
	[lib/repositories/firebase/firebase_app_repository.dart](lib/repositories/firebase/firebase_app_repository.dart)
	[lib/repositories/mock/mock_app_repository.dart](lib/repositories/mock/mock_app_repository.dart)
4. Expón el estado desde providers si hace falta en [lib/app/providers.dart](lib/app/providers.dart).
5. Conecta la UI en la pantalla correspondiente dentro de [lib/screens](lib/screens).

### Añadir una nueva pantalla

1. Crea la pantalla en `lib/screens/...`.
2. Mantén la lógica de acceso a datos en repositorio, no en widgets.
3. Reutiliza `tr(...)` desde [lib/app/app_text.dart](lib/app/app_text.dart) para no dejar textos sin traducir.
4. Usa `sortedMembersByName(...)` y `group.visibleMembers` cuando el flujo deba incluir miembros pendientes.

### Añadir nuevas categorías o divisas

- Categorías por defecto: [lib/core/defaults.dart](lib/core/defaults.dart).
- Divisas disponibles: [lib/core/defaults.dart](lib/core/defaults.dart).

### Mejorar i18n

La base actual usa `tr(...)` y `localeTag(...)` en [lib/app/app_text.dart](lib/app/app_text.dart). Si el proyecto crece, el siguiente paso razonable es migrar a un sistema basado en ARB y generación de localizaciones para evitar textos embebidos en widgets.

### Escalar persistencia

Ahora mismo los gastos viven embebidos en cada grupo. Para grupos con mucho histórico, conviene mover `expenses` a subcolecciones Firestore y calcular agregados ligeros para listados.

## Convenciones de este repo

- Mantén la paridad entre repositorio Firebase y mock.
- No subas secretos: `config/firebase.local.json`, `google-services.json` y credenciales nativas están ignorados.
- Usa el Flutter local del repo para evitar diferencias de versión.
- Valida siempre con análisis y tests antes de generar APK.

## Riesgos y próximos pasos recomendados

- Migrar textos restantes a un sistema de localización más estructurado.
- Separar gastos en subcolecciones si el volumen real crece.
- Añadir persistencia de preferencias locales de tema e idioma.
- Añadir más tests de repositorio y flujos de grupo.
