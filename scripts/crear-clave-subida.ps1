# Crea la clave de subida para Google Play.
#
# Sin esto, `flutter build appbundle --release` firma con la clave de
# DEPURACION y Play rechaza el paquete: «You uploaded a debug-signed APK or
# Android App Bundle». No es un aviso, es un rechazo.
#
#   pwsh scripts/crear-clave-subida.ps1
#
# Genera dos ficheros en formato PKCS12, los DOS fuera de git:
#
#   android/shardpay-upload.jks   la clave
#   android/key.properties        las contrasenas, que Gradle lee al compilar
#
# GUARDA UNA COPIA DEL .jks FUERA DE ESTE ORDENADOR.
#
# Con Play App Signing —que es lo normal desde 2021— la clave de firma final la
# custodia Google y esta se puede reemplazar si se pierde, pero hay que abrir una
# incidencia y esperar. Sin Play App Signing, perder este fichero significa que
# NADIE puede volver a publicar una actualizacion de la app. Nunca.

$ErrorActionPreference = 'Stop'

$raiz = Split-Path -Parent $PSScriptRoot
$almacen = Join-Path $raiz 'android\shardpay-upload.jks'
$propiedades = Join-Path $raiz 'android\key.properties'

if (Test-Path $almacen) {
    Write-Host "Ya existe $almacen. No lo toco." -ForegroundColor Yellow
    Write-Host 'Si de verdad quieres una clave nueva, mueve la vieja a otro sitio primero.'
    exit 1
}

# keytool viene con cualquier JDK 17.
$keytool = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\keytool.exe' } else { 'keytool' }
if ($env:JAVA_HOME -and -not (Test-Path $keytool)) {
    Write-Error "No encuentro keytool en JAVA_HOME ($env:JAVA_HOME)."
}

Write-Host 'Clave de subida de ShardPay para Google Play' -ForegroundColor Cyan
Write-Host ''
$clave = Read-Host -AsSecureString 'Contrasena para la clave (minimo 6 caracteres)'
$confirmacion = Read-Host -AsSecureString 'Reptela'

$texto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clave))
$textoConfirmacion = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmacion))

if ($texto -ne $textoConfirmacion) { Write-Error 'Las contrasenas no coinciden.' }
if ($texto.Length -lt 6) { Write-Error 'Minimo 6 caracteres.' }

# 10000 dias: Play exige que la clave siga siendo valida despues de 2033.
& $keytool -genkeypair `
    -alias shardpay `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -keystore $almacen `
    -storetype PKCS12 `
    -storepass $texto -keypass $texto `
    -dname 'CN=Ghato Studio, OU=ShardPay, O=Ghato Studio, L=A Coruna, C=ES'

if ($LASTEXITCODE -ne 0) { Write-Error 'keytool fallo.' }

# `storeFile` va relativo a android/, que es donde esta este key.properties. Lo
# resuelve asi build.gradle.kts; por defecto Gradle buscaria en android/app/ y el
# error que sale es «Keystore file not found» sin decir contra que ha buscado.
@"
storePassword=$texto
keyPassword=$texto
keyAlias=shardpay
storeFile=shardpay-upload.jks
"@ | Set-Content -Path $propiedades -Encoding UTF8 -NoNewline

Write-Host ''
Write-Host 'Hecho:' -ForegroundColor Green
Write-Host "  $almacen"
Write-Host "  $propiedades"
Write-Host ''
Write-Host 'Huella SHA-1 (registrala en Firebase para que funcione el acceso con Google):' -ForegroundColor Cyan
& $keytool -list -v -keystore $almacen -alias shardpay -storepass $texto |
    Select-String -Pattern 'SHA1:|SHA256:'

Write-Host ''
Write-Host 'GUARDA UNA COPIA DEL .jks FUERA DE ESTE ORDENADOR.' -ForegroundColor Yellow
Write-Host 'Ahora vuelve a compilar:  flutter build appbundle --release --dart-define-from-file=config/firebase.local.json'
