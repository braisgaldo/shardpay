$ErrorActionPreference = 'Stop'

$flutter = Join-Path $PSScriptRoot '..\tools\flutter\bin\flutter.bat'
$configFile = Join-Path $PSScriptRoot '..\config\firebase.local.json'
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

if (-not (Test-Path $flutter)) {
  throw 'No se encontró Flutter local en tools/flutter.'
}

$args = @('run', '-d', 'emulator-5554')
if (Test-Path $configFile) {
  $args += "--dart-define-from-file=$configFile"
}

& $flutter @args