# Verificacion en dispositivo real.
#
# Instala la app en el telefono conectado, la arranca y toma las capturas que
# pide la Definition of Done: las paletas, el arabe en RTL y el panel de
# donacion. Tambien comprueba que en el binario no haya ninguna biblioteca de
# facturacion.
#
#   powershell -ExecutionPolicy Bypass -File .\scripts\verify-on-device.ps1
#
# Requisitos: Flutter, JDK 17, Android SDK y un telefono con depuracion USB
# activada y autorizada.

param(
    [string]$DeviceId = '',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$capturas = Join-Path $repo 'docs\store\capturas'
New-Item -ItemType Directory -Force $capturas | Out-Null

function Buscar($nombre, $rutas) {
    $cmd = Get-Command $nombre -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($r in $rutas) { if ($r -and (Test-Path $r)) { return $r } }
    return $null
}

$adb = Buscar 'adb' @("$env:ANDROID_HOME\platform-tools\adb.exe", "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe")
$flutter = Buscar 'flutter' @()

if (-not $adb) { Write-Error 'No encuentro adb. Instala platform-tools o define ANDROID_HOME.' }
if (-not $flutter) { Write-Error 'No encuentro flutter en el PATH.' }

# --- 1. Dispositivo ----------------------------------------------------------
Write-Host '==> Dispositivos conectados'
$salida = & $adb devices
$salida | Write-Host

$dispositivos = $salida |
    Select-Object -Skip 1 |
    Where-Object { $_ -match '\S' } |
    ForEach-Object { ($_ -split '\s+')[0..1] } |
    Where-Object { $_ }

if ($salida.Count -le 1 -or -not ($salida -match "`tdevice$")) {
    Write-Host ''
    Write-Host 'No hay ningun dispositivo autorizado. Comprueba, por este orden:' -ForegroundColor Yellow
    Write-Host '  1. Que el cable transmita datos, no solo carga.'
    Write-Host '  2. Que el telefono este en modo "Transferencia de archivos" y no en "Solo carga".'
    Write-Host '  3. Que "Depuracion por USB" este activada en Opciones de desarrollador.'
    Write-Host '  4. Que hayas aceptado el aviso de "Permitir depuracion USB" en la pantalla del telefono.'
    Write-Host '     Si aparece "unauthorized", ejecuta: adb kill-server; adb start-server'
    exit 1
}

if (-not $DeviceId) {
    $DeviceId = (($salida | Where-Object { $_ -match "`tdevice$" }) -split "`t")[0]
}
Write-Host "==> Usando el dispositivo $DeviceId"

$modelo = (& $adb -s $DeviceId shell getprop ro.product.model).Trim()
$version = (& $adb -s $DeviceId shell getprop ro.build.version.release).Trim()
$api = (& $adb -s $DeviceId shell getprop ro.build.version.sdk).Trim()
Write-Host "    $modelo · Android $version · API $api"

if ([int]$api -lt 26) {
    Write-Warning "El minSdk del proyecto es 26 y este dispositivo es API $api: la app no se instalara."
}

# --- 2. Compilar e instalar --------------------------------------------------
if (-not $SkipBuild) {
    Write-Host '==> Compilando el APK de depuracion'
    Push-Location $repo
    & $flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error 'La compilacion fallo.' }
    Pop-Location
}

$apk = Join-Path $repo 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path $apk)) { Write-Error "No encuentro el APK en $apk" }

Write-Host '==> Instalando'
& $adb -s $DeviceId install -r $apk

# --- 3. Comprobacion de facturacion -----------------------------------------
Write-Host '==> Comprobando que no hay bibliotecas de facturacion en el arbol de dependencias'
Push-Location (Join-Path $repo 'android')
$deps = & .\gradlew.bat ':app:dependencies' '--configuration' 'releaseRuntimeClasspath' '-q' 2>&1
Pop-Location
$billing = $deps | Select-String -Pattern 'billingclient|com\.android\.billing'
if ($billing) {
    Write-Host 'FALLO: se ha colado una biblioteca de facturacion.' -ForegroundColor Red
    $billing | Write-Host
    exit 1
}
Write-Host '    Sin bibliotecas de facturacion.' -ForegroundColor Green

# --- 4. Capturas -------------------------------------------------------------
function Captura($nombre) {
    $destino = Join-Path $capturas "$nombre.png"
    & $adb -s $DeviceId exec-out screencap -p > $destino
    Write-Host "    $destino"
}

Write-Host '==> Arrancando la app'
& $adb -s $DeviceId shell monkey -p com.ghatostudio.shardpay -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 6
Captura '01-arranque'

Write-Host ''
Write-Host 'Capturas automaticas hechas. Las siguientes son manuales, porque hay' -ForegroundColor Cyan
Write-Host 'que navegar por la app:' -ForegroundColor Cyan
Write-Host '  - Ajustes con las paletas'
Write-Host '  - Una paleta clara y una oscura aplicadas'
Write-Host '  - El selector de idioma'
Write-Host '  - La app en arabe, comprobando que la interfaz esta reflejada'
Write-Host '  - El panel de "invitame a un cafe", claro y oscuro'
Write-Host '  - La pantalla de captura de tickets, con el marco'
Write-Host '  - El dialogo de revision de un ticket leido'
Write-Host ''
Write-Host 'Para cada una, cuando la tengas en pantalla:'
Write-Host "  adb -s $DeviceId exec-out screencap -p > docs\store\capturas\NOMBRE.png"
Write-Host ''
Write-Host 'Para probar el arabe sin cambiarlo a mano:'
Write-Host "  adb -s $DeviceId shell am start -n com.ghatostudio.shardpay/.MainActivity"
Write-Host '  (y cambiar el idioma desde Ajustes > Idioma > العربية)'
