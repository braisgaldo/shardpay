#!/usr/bin/env bash
#
# Genera el manual de usuario, el manual tecnico, la guia de publicacion y la
# politica de privacidad en HTML y PDF.
#
# La fuente unica es el Markdown de docs/, y eso SI va en commits. Los binarios
# NO: se generan aqui y se adjuntan como assets de la GitHub Release, para que
# el repositorio siga siendo ligero de clonar y cada documento corresponda a una
# version concreta.
#
#   bash docs/build-docs.sh              HTML y PDF
#   bash docs/build-docs.sh --no-pdf     solo HTML
#
# Requisitos: Python 3.9+ con `markdown` y `pygments`. Para el PDF, Edge o
# Chrome instalados; el PDF se imprime en modo sin ventana.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  echo "ERROR: hace falta Python 3.9 o superior." >&2
  exit 1
fi

PY="$(command -v python3 || command -v python)"

if ! "$PY" -c "import markdown, PIL" >/dev/null 2>&1; then
  echo "==> Instalando las dependencias de documentacion"
  "$PY" -m pip install --quiet --disable-pip-version-check markdown pygments pillow
fi

exec "$PY" "$ROOT/docs/build_docs.py" "$@"
