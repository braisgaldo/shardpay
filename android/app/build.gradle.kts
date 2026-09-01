import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// El plugin de Google Services aborta la compilacion si no encuentra
// google-services.json, y ese fichero lleva credenciales, asi que no se
// versiona. El resultado era que el proyecto recien clonado NO COMPILABA, aunque
// el codigo Dart si contempla la ausencia de credenciales y arranca en modo de
// demostracion local.
//
// Aplicandolo solo cuando el fichero existe, `flutter build apk` funciona sobre
// un clon limpio y sigue funcionando igual cuando hay credenciales.
val googleServicesFile = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("ShardPay: sin android/app/google-services.json. Se compila sin Firebase y la app arrancara en modo de demostracion local.")
}

// Credenciales de firma. Viven FUERA del repositorio, en android/key.properties,
// que esta en .gitignore. Sin ese fichero el proyecto sigue compilando: la
// version de publicacion cae a la firma de depuracion y avisa por consola.
// El procedimiento para generarlas esta en docs/INSTALL.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.ghatostudio.shardpay"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ghatostudio.shardpay"
        // Android 8.0. Lo exige el proyecto y ademas es el minimo comodo para
        // ML Kit, Firebase y el idioma por app.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // versionCode y versionName los inyecta el flujo de publicacion con
        // --build-number y --build-name. La formula del versionCode esta
        // documentada en docs/INSTALL.md.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Idiomas que se empaquetan. Sin esto, el recortador de recursos deja
        // fuera las traducciones de Material de los idiomas menos comunes.
        resourceConfigurations += setOf(
            "en", "es", "gl", "ca", "eu", "fr", "it", "pt",
            "de", "el", "ru", "ar", "zh", "ja"
        )
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // La ruta se resuelve desde `android/`, que es donde vive
                // key.properties. Por defecto Gradle la resolveria desde
                // `android/app/`, y entonces `storeFile=shardpay-upload.jks`
                // apunta a un sitio donde nadie pone la clave: el error que sale
                // es «Keystore file not found», sin decir contra que directorio
                // ha buscado. Una ruta absoluta sigue funcionando igual.
                storeFile = keystoreProperties["storeFile"]?.let {
                    // Ojo: hay que preguntarle a la CADENA si es absoluta. Con
                    // `file(texto).isAbsolute` la respuesta es siempre si,
                    // porque `file()` ya ha resuelto la ruta contra el modulo.
                    val texto = it as String
                    val esAbsoluta = texto.startsWith("/") || Regex("^[A-Za-z]:[\\/].*").matches(texto)
                    if (esAbsoluta) file(texto) else rootProject.file(texto)
                }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("ShardPay: sin android/key.properties, la version de publicacion se firma con la clave de depuracion y NO se puede subir a Play.")
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
