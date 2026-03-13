$ErrorActionPreference = 'Stop'

$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$emulator = Join-Path $sdkRoot 'emulator\emulator.exe'
$adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
$avdName = 'ShardPay_Pixel_9'

if (-not (Test-Path $emulator)) {
  throw 'No se encontró emulator.exe. Revisa la instalación del Android SDK.'
}

$running = & $adb devices | Select-String 'emulator-' -Quiet
if (-not $running) {
  Start-Process -FilePath $emulator -ArgumentList '-avd', $avdName, '-no-snapshot-save'
}

Write-Host "Esperando a que el emulador $avdName esté listo..."
& $adb wait-for-device | Out-Null
Write-Host 'Emulador listo.'