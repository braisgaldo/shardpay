# Genera el manual de usuario, el manual tecnico, la guia de publicacion y la
# politica de privacidad en HTML y PDF.
#
# La fuente unica es el Markdown de docs/, y eso SI va en commits. Los binarios
# NO: se generan aqui y se adjuntan como assets de la GitHub Release.
#
#   pwsh docs/build-docs.ps1              HTML y PDF
#   pwsh docs/build-docs.ps1 -NoPdf       solo HTML
#
# Requisitos: Python 3.9+ con `markdown` y `pygments`. Para el PDF, Edge o
# Chrome instalados; el PDF se imprime en modo sin ventana.
param([switch]$NoPdf)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$python = (Get-Command python -ErrorAction SilentlyContinue) ?? (Get-Command python3 -ErrorAction SilentlyContinue)
if (-not $python) { Write-Error 'Hace falta Python 3.9 o superior.' }

& $python.Source -c "import markdown, PIL" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host '==> Instalando las dependencias de documentacion'
    & $python.Source -m pip install --quiet --disable-pip-version-check markdown pygments pillow
}

$argumentos = @((Join-Path $root 'docs\build_docs.py'))
if ($NoPdf) { $argumentos += '--no-pdf' }

& $python.Source @argumentos
