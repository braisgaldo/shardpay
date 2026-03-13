$ErrorActionPreference = 'Stop'

$firebase = 'npx firebase'
$flutterfire = Join-Path $env:LOCALAPPDATA 'Pub\Cache\bin\flutterfire.bat'

Write-Host '1. Inicia sesión si todavía no lo has hecho:'
Write-Host '   npx firebase login'
Write-Host ''
Write-Host '2. Asocia el proyecto:'
Write-Host '   npx firebase use --add'
Write-Host ''

if (Test-Path $flutterfire) {
  Write-Host '3. FlutterFire CLI detectada. Puedes ejecutar:'
  Write-Host "   $flutterfire configure"
} else {
  Write-Host '3. FlutterFire CLI no está en PATH, pero quedó instalada en Pub Cache.'
}

Write-Host ''
Write-Host '4. Rellena config/firebase.local.json y ejecuta scripts/run-android.ps1'