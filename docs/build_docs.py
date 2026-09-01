# -*- coding: utf-8 -*-
"""Genera los documentos de ShardPay en HTML y PDF.

La fuente unica son los Markdown de `docs/`, que si van en commits. Los binarios
salen en `docs/out/`, que esta en .gitignore, y se publican como assets de la
GitHub Release.

Por que este script y no Pandoc: Pandoc necesita ademas un motor LaTeX para el
PDF, y su salida por defecto no se parece en nada a la app. Aqui el HTML se
genera con la paleta de ShardPay, portada propia y estilos pensados tambien para
papel, y el PDF se imprime con Microsoft Edge en modo sin ventana, que ya esta en
cualquier Windows.

    python docs/build_docs.py
    python docs/build_docs.py --no-pdf     solo HTML

Requisitos: Python 3.9+, `pip install markdown pygments`. Para el PDF, Edge o
Chrome instalados.
"""
from __future__ import annotations

import argparse
import base64
import datetime as _dt
import functools
import html
import io
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

try:
    import markdown
except ImportError:  # pragma: no cover
    sys.exit('Falta el modulo markdown. Instalalo con: pip install markdown pygments')

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DOCS = RAIZ / 'docs'
SALIDA = DOCS / 'out'

VERSION = os.environ.get('SHARDPAY_VERSION', '1.0.0')
FECHA = _dt.datetime.now(_dt.timezone.utc).strftime('%d/%m/%Y')

# (fichero, nombre de salida, titulo, subtitulo, emoji de portada)
DOCUMENTOS = [
    ('MANUAL-USUARIO.md', 'shardpay-manual-usuario', 'Manual de usuario',
     'Todo lo que necesitas para repartir gastos sin discutir', '🧾'),
    ('MANUAL-TECNICO.md', 'shardpay-manual-tecnico', 'Manual técnico',
     'Arquitectura, decisiones de diseño, despliegue y pruebas', '⚙️'),
    ('GUIA-PUBLICACION.md', 'shardpay-guia-publicacion', 'Guía de publicación',
     'Google Play y App Store, paso a paso', '🚀'),
    ('PRIVACIDAD.md', 'shardpay-privacidad', 'Política de privacidad',
     'Qué datos se tratan, quién los ve y qué no se hace', '🔒'),
]

# --- Estilo -------------------------------------------------------------------
# Los colores son los de la paleta «Claro Arena» de la app, para que el documento
# y el producto se reconozcan como lo mismo.
CSS = r"""
@page {
  size: A4;
  margin: 18mm 16mm 20mm 16mm;
}

:root {
  --lienzo: #f6efe8;
  --papel: #fffbf8;
  --tinta: #101522;
  --suave: #6b6558;
  --acento: #c9431f;
  --acento-claro: #ffe9e1;
  --secundario: #f3c677;
  --linea: #e8ded3;
  --verde: #1e7a4f;
  --verde-claro: #e4f4ec;
  --ambar: #a86a00;
  --ambar-claro: #fdf1dc;
}

* { box-sizing: border-box; }

html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }

body {
  margin: 0;
  background: var(--papel);
  color: var(--tinta);
  font-family: "Segoe UI", -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
  font-size: 10.8pt;
  line-height: 1.62;
  hyphens: auto;
}

.pagina { max-width: 190mm; margin: 0 auto; padding: 0 4mm; }

/* --- Portada -------------------------------------------------------------- */
.portada {
  min-height: 247mm;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 0 14mm;
  background:
    radial-gradient(circle at 88% 8%, rgba(243, 198, 119, .40), transparent 46%),
    radial-gradient(circle at 6% 92%, rgba(201, 67, 31, .16), transparent 44%),
    var(--lienzo);
  break-after: page;
  page-break-after: always;
}

.portada .emoji { font-size: 58pt; line-height: 1; margin-bottom: 10mm; }

.portada .marca {
  display: inline-block;
  font-size: 12pt;
  font-weight: 800;
  letter-spacing: .22em;
  text-transform: uppercase;
  color: var(--acento);
  margin-bottom: 5mm;
}

.portada h1 {
  font-size: 34pt;
  line-height: 1.06;
  font-weight: 800;
  margin: 0 0 5mm;
  letter-spacing: -.02em;
  border: 0;
  padding: 0;
}

.portada .lema {
  font-size: 14pt;
  color: var(--suave);
  margin: 0 0 14mm;
  max-width: 130mm;
  line-height: 1.45;
}

.portada .meta {
  display: flex;
  gap: 8mm;
  flex-wrap: wrap;
  font-size: 9.5pt;
  color: var(--suave);
  border-top: 2px solid var(--acento);
  padding-top: 5mm;
  max-width: 130mm;
}

.portada .meta b { color: var(--tinta); display: block; font-size: 10.5pt; }

/* --- Indice --------------------------------------------------------------- */
.toc {
  background: var(--lienzo);
  border: 1px solid var(--linea);
  border-radius: 6mm;
  padding: 7mm 9mm;
  margin: 0 0 12mm;
  break-inside: avoid;
}

.toc > .toc-titulo {
  font-size: 9pt;
  font-weight: 800;
  letter-spacing: .16em;
  text-transform: uppercase;
  color: var(--acento);
  margin-bottom: 4mm;
}

.toc ul { list-style: none; padding-left: 0; margin: 0; }
.toc ul ul { padding-left: 6mm; margin-top: 1mm; }
.toc li { margin: 1.6mm 0; }
.toc a { color: var(--tinta); text-decoration: none; border-bottom: 0; font-size: 10pt; }
.toc > ul > li > a { font-weight: 700; }
.toc ul ul a { color: var(--suave); font-size: 9.4pt; }

/* --- Tipografia ----------------------------------------------------------- */
h1, h2, h3, h4 { line-height: 1.22; font-weight: 800; break-after: avoid; page-break-after: avoid; }

h1 {
  font-size: 21pt;
  margin: 12mm 0 5mm;
  padding-bottom: 3mm;
  border-bottom: 3px solid var(--acento);
  break-before: page;
  page-break-before: always;
}

.pagina > h1:first-of-type { break-before: auto; page-break-before: auto; margin-top: 0; }

h2 {
  font-size: 15pt;
  margin: 9mm 0 3.5mm;
  padding-left: 4mm;
  border-left: 4px solid var(--secundario);
}

h3 { font-size: 12pt; margin: 7mm 0 2.5mm; color: var(--acento); }
h4 { font-size: 10.8pt; margin: 5mm 0 2mm; color: var(--suave); text-transform: uppercase; letter-spacing: .05em; }

p { margin: 0 0 3.5mm; }
strong { font-weight: 700; }
a { color: var(--acento); text-decoration: none; border-bottom: 1px solid rgba(201, 67, 31, .3); }

ul, ol { margin: 0 0 4mm; padding-left: 6mm; }
li { margin: 1.4mm 0; }
li::marker { color: var(--acento); }

hr { border: 0; border-top: 1px solid var(--linea); margin: 9mm 0; }

/* --- Codigo --------------------------------------------------------------- */
code {
  font-family: "Cascadia Mono", Consolas, "SFMono-Regular", monospace;
  font-size: .86em;
  background: var(--lienzo);
  padding: .12em .38em;
  border-radius: 3px;
  color: #8a3517;
}

pre {
  background: #1b2130;
  color: #eef1f6;
  padding: 4.5mm 5.5mm;
  border-radius: 4mm;
  overflow-x: auto;
  font-size: 8.8pt;
  line-height: 1.5;
  break-inside: avoid;
  page-break-inside: avoid;
  margin: 0 0 4mm;
}

pre code { background: none; padding: 0; color: inherit; font-size: 1em; }

/* --- Tablas --------------------------------------------------------------- */
table {
  width: 100%;
  border-collapse: collapse;
  margin: 0 0 5mm;
  font-size: 9.4pt;
  break-inside: avoid;
  page-break-inside: avoid;
}

thead th {
  background: var(--acento);
  color: #fff;
  text-align: left;
  font-weight: 700;
  padding: 2.4mm 3mm;
}

thead th:first-child { border-top-left-radius: 2.5mm; }
thead th:last-child { border-top-right-radius: 2.5mm; }

tbody td { padding: 2.2mm 3mm; border-bottom: 1px solid var(--linea); vertical-align: top; }

/* Una tabla sin cabecera real no debe dejar una barra de color suelta. */
thead:has(th:empty:only-child) { display: none; }
tbody tr:nth-child(even) { background: rgba(246, 239, 232, .55); }

/* --- Capturas de pantalla ------------------------------------------------- */
/*
   Rejilla que se adapta sola: dos capturas de movil caben una al lado de otra
   en pantalla y en A4, y una sola se queda centrada sin estirarse. El movil es
   estrecho y alto, asi que dejarlo ocupar el ancho de la columna lo convierte en
   una torre que se come la pagina.
*/
.capturas {
  display: flex;
  flex-wrap: wrap;
  gap: 7mm;
  justify-content: center;
  align-items: flex-start;
  margin: 7mm 0;
}

figure.captura {
  margin: 0;
  flex: 0 1 62mm;
  max-width: 62mm;
  text-align: center;
  break-inside: avoid;
  page-break-inside: avoid;
}

figure.captura img {
  width: 100%;
  height: auto;
  display: block;
  border-radius: 5mm;
  border: 1px solid var(--linea);
  box-shadow: 0 2mm 6mm rgba(31, 26, 23, .13);
  background: #fff;
}

figure.captura figcaption {
  margin-top: 2.5mm;
  font-size: 8.2pt;
  line-height: 1.35;
  color: var(--tenue);
  text-align: center;
}

/* Una sola captura en su bloque se queda algo mas grande: suele ser la que
   ilustra una pantalla entera y no una comparacion. */
.capturas:has(figure.captura:only-child) figure.captura {
  flex: 0 1 74mm;
  max-width: 74mm;
}

@media print {
  figure.captura img { box-shadow: none; }
}

/* --- Citas y avisos ------------------------------------------------------- */
blockquote {
  margin: 0 0 5mm;
  padding: 4mm 5mm 4mm 6mm;
  background: var(--ambar-claro);
  border-left: 4px solid var(--ambar);
  border-radius: 0 3mm 3mm 0;
  color: #5a4114;
  break-inside: avoid;
}

blockquote p:last-child { margin-bottom: 0; }

/* Listas de comprobacion */
li input[type="checkbox"] { margin-right: 2mm; }

/* --- Pie ------------------------------------------------------------------ */
.pie {
  margin-top: 14mm;
  padding-top: 5mm;
  border-top: 1px solid var(--linea);
  font-size: 8.6pt;
  color: var(--suave);
  text-align: center;
}

@media screen {
  body { background: #ece4dc; padding: 0 0 40px; }
  .pagina {
    background: var(--papel);
    max-width: 210mm;
    margin: 0 auto;
    padding: 16mm 18mm;
    box-shadow: 0 10px 40px rgba(16, 21, 34, .12);
  }
  .portada {
    max-width: 210mm;
    margin: 0 auto;
    min-height: auto;
    padding: 28mm 18mm;
    box-shadow: 0 10px 40px rgba(16, 21, 34, .12);
  }
  h1 { break-before: auto; page-break-before: auto; }
}
"""

PLANTILLA = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ShardPay · {titulo}</title>
<style>{css}</style>
</head>
<body>

<section class="portada">
  <div class="emoji">{emoji}</div>
  <span class="marca">ShardPay</span>
  <h1>{titulo}</h1>
  <p class="lema">{subtitulo}</p>
  <div class="meta">
    <div><b>Versión</b>{version}</div>
    <div><b>Fecha</b>{fecha}</div>
    <div><b>Autor</b>Brais Castiñeiras Galdo · Ghato Studio</div>
    <div><b>Licencia</b>Apache-2.0</div>
  </div>
</section>

<main class="pagina">
{indice}
{contenido}
<div class="pie">
  ShardPay {version} · Divide tickets, no amistades · github.com/braisgaldo/shardpay
</div>
</main>

</body>
</html>
"""



# --- Capturas de pantalla -----------------------------------------------------
#
# Un manual de una app sin capturas es una lista de instrucciones a ciegas. Las
# imagenes se **incrustan** en el HTML como data URI en vez de enlazarse: asi el
# fichero generado es uno solo, se puede mandar por correo o subir a la web sin
# arrastrar una carpeta detras, y el navegador que imprime el PDF no tiene que ir
# a buscar nada.
#
# El precio es el tamaño, y por eso se reescalan antes: 1080 px de ancho en un
# documento que se lee a 640 px de columna no aporta nada y multiplica por seis
# el peso del fichero.

ANCHO_CAPTURA = 460
"""Ancho en pixeles al que se reescalan las capturas antes de incrustarlas."""

RECORTE_SUPERIOR = 0.040
RECORTE_INFERIOR = 0.050
"""Proporcion de la captura que ocupan la barra de estado y la de navegacion.

Se recortan. En la ficha de la tienda tienen sentido —enseñan que es una app de
movil de verdad—, pero en un manual son ruido: la hora, la bateria y los tres
botones de Android no explican nada de ShardPay y le roban sitio a lo que si.

Van en proporcion y no en pixeles para que sigan valiendo si algun dia las
capturas se hacen en otro movil.
"""


@functools.lru_cache(maxsize=None)
def _captura_incrustada(ruta: pathlib.Path) -> str:
    """Devuelve la captura sin barras del sistema, reescalada, como data URI."""
    try:
        from PIL import Image
    except ImportError:  # pragma: no cover - depende del entorno
        raise SystemExit(
            'Falta Pillow, que hace falta para incrustar las capturas del manual.\n'
            '    pip install pillow'
        ) from None

    with Image.open(ruta) as imagen:
        imagen = imagen.convert('RGB')
        arriba = round(imagen.height * RECORTE_SUPERIOR)
        abajo = imagen.height - round(imagen.height * RECORTE_INFERIOR)
        imagen = imagen.crop((0, arriba, imagen.width, abajo))

        alto = round(imagen.height * ANCHO_CAPTURA / imagen.width)
        imagen = imagen.resize((ANCHO_CAPTURA, alto), Image.LANCZOS)
        buffer = io.BytesIO()
        imagen.save(buffer, format='JPEG', quality=82, optimize=True, progressive=True)

    return 'data:image/jpeg;base64,' + base64.b64encode(buffer.getvalue()).decode('ascii')


def incrustar_capturas(cuerpo: str, base: pathlib.Path) -> str:
    """Sustituye las etiquetas <img> por figuras con la imagen dentro.

    El Markdown escribe `![Pie de foto](capturas/04-grupos.png)`. Aqui eso se
    convierte en una figura con su pie, y varias figuras seguidas se colocan en
    rejilla: dos capturas de movil una al lado de otra se leen mucho mejor que
    una debajo de otra ocupando dos pantallas.
    """

    def sustituir(coincidencia: re.Match[str]) -> str:
        origen = html.unescape(coincidencia.group('src'))
        pie = html.unescape(coincidencia.group('alt')).strip()
        ruta = (base / origen).resolve()

        if not ruta.exists():
            print(f'    AVISO: falta la captura {origen}')
            return ''

        figura = f'<figure class="captura"><img src="{_captura_incrustada(ruta)}" alt="{html.escape(pie)}">'
        if pie:
            figura += f'<figcaption>{html.escape(pie)}</figcaption>'
        return figura + '</figure>'

    cuerpo = re.sub(
        r'<img alt="(?P<alt>[^"]*)" src="(?P<src>[^"]+)"\s*/?>',
        sustituir,
        cuerpo,
    )

    # Markdown envuelve una imagen suelta en un parrafo. Un <figure> dentro de un
    # <p> es HTML invalido y el navegador lo cierra por su cuenta, rompiendo la
    # rejilla; hay que sacarlo.
    cuerpo = re.sub(r'<p>((?:\s*<figure class="captura">.*?</figure>\s*)+)</p>', r'<div class="capturas">\1</div>', cuerpo, flags=re.S)

    return cuerpo

def convertir(origen: pathlib.Path) -> tuple[str, str]:
    """Devuelve (html del cuerpo, html del indice)."""
    texto = origen.read_text(encoding='utf-8')

    # Quita el bloque YAML inicial: aqui el titulo lo pone la portada.
    texto = re.sub(r'\A---\n.*?\n---\n', '', texto, flags=re.S)

    # Quita el primer encabezado de nivel 1, que duplica la portada.
    texto = re.sub(r'\A\s*#\s+[^\n]*\n', '', texto)

    convertidor = markdown.Markdown(
        extensions=['extra', 'toc', 'sane_lists', 'admonition', 'codehilite'],
        extension_configs={
            'toc': {'toc_depth': '2-3', 'permalink': False},
            'codehilite': {'noclasses': True, 'pygments_style': 'friendly'},
        },
    )

    cuerpo = convertidor.convert(texto)
    cuerpo = incrustar_capturas(cuerpo, origen.parent)
    indice = getattr(convertidor, 'toc', '')

    if indice and '<li>' in indice:
        # `markdown` devuelve `<div class="toc"> ... </div>`. Hay que quitar esa
        # envoltura entera antes de poner la propia: sustituir el primer
        # `</div>` cerraria el titulo que se acaba de anadir, no el contenedor.
        interior = indice.replace('<div class="toc">', '', 1).strip()
        if interior.endswith('</div>'):
            interior = interior[: -len('</div>')].strip()
        indice = (
            '<nav class="toc"><div class="toc-titulo">Contenido</div>'
            + interior
            + '</nav>'
        )
    else:
        indice = ''

    # Casillas de verificacion reales en las listas de comprobacion.
    cuerpo = cuerpo.replace('<li>[ ] ', '<li><input type="checkbox" disabled> ')
    cuerpo = cuerpo.replace('<li>[x] ', '<li><input type="checkbox" checked disabled> ')

    return cuerpo, indice


def buscar_navegador() -> str | None:
    candidatos = [
        os.environ.get('SHARDPAY_BROWSER'),
        shutil.which('msedge'),
        shutil.which('chrome'),
        shutil.which('google-chrome'),
        shutil.which('chromium'),
        shutil.which('chromium-browser'),
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        '/usr/bin/microsoft-edge',
        '/usr/bin/google-chrome',
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    ]
    for ruta in candidatos:
        if ruta and pathlib.Path(ruta).exists():
            return ruta
    return None


def imprimir_pdf(navegador: str, fuente: pathlib.Path, destino: pathlib.Path) -> bool:
    """Imprime el HTML a PDF con el navegador sin ventana.

    Devuelve False y explica el motivo en lugar de propagar la excepcion: que un
    navegador se quede colgado en el ultimo documento no puede tirar abajo la
    generacion entera ni dejar la CI con un traceback en vez de un aviso.
    """
    orden = [
        navegador,
        '--headless=new',
        '--disable-gpu',
        '--no-sandbox',
        '--no-first-run',
        '--no-pdf-header-footer',
        f'--print-to-pdf={destino}',
        fuente.as_uri(),
    ]

    # Dos intentos: el primer arranque del navegador a veces se queda colgado
    # creando el perfil, y reintentar sale mas barato que perder el documento.
    destino.unlink(missing_ok=True)

    for intento in (1, 2):
        with tempfile.TemporaryDirectory() as perfil:
            try:
                resultado = subprocess.run(
                    orden[:-1] + [f'--user-data-dir={perfil}', orden[-1]],
                    capture_output=True,
                    text=True,
                    timeout=180,
                )
            except subprocess.TimeoutExpired:
                print(f'    el navegador no respondio en 180 s (intento {intento})')
                continue
            except OSError as error:
                print(f'    no se pudo lanzar el navegador: {error}')
                return False

        if destino.exists() and destino.stat().st_size > 0:
            return True

        print('    error al imprimir el PDF:', (resultado.stderr or resultado.stdout or '').strip()[:400])

    return False



def main() -> int:
    parser = argparse.ArgumentParser(description='Genera los documentos de ShardPay en HTML y PDF.')
    parser.add_argument('--no-pdf', action='store_true', help='genera solo el HTML')
    args = parser.parse_args()

    SALIDA.mkdir(parents=True, exist_ok=True)
    navegador = None if args.no_pdf else buscar_navegador()

    if not args.no_pdf and navegador is None:
        print('AVISO: no encuentro Edge ni Chrome; se genera solo el HTML.')

    generados = 0
    fallidos: list[str] = []
    for fichero, nombre, titulo, subtitulo, emoji in DOCUMENTOS:
        origen = DOCS / fichero
        if not origen.exists():
            print(f'AVISO: no existe {origen}, se omite')
            continue

        print(f'==> {titulo}')
        cuerpo, indice = convertir(origen)

        pagina = PLANTILLA.format(
            css=CSS,
            titulo=html.escape(titulo),
            subtitulo=html.escape(subtitulo),
            emoji=emoji,
            version=html.escape(VERSION),
            fecha=FECHA,
            indice=indice,
            contenido=cuerpo,
        )

        destino_html = SALIDA / f'{nombre}.html'
        destino_html.write_text(pagina, encoding='utf-8')
        print(f'    HTML  {destino_html.relative_to(RAIZ)}  ({destino_html.stat().st_size // 1024} kB)')
        generados += 1

        if navegador:
            destino_pdf = SALIDA / f'{nombre}.pdf'
            if imprimir_pdf(navegador, destino_html, destino_pdf):
                print(f'    PDF   {destino_pdf.relative_to(RAIZ)}  ({destino_pdf.stat().st_size // 1024} kB)')
            else:
                fallidos.append(nombre)

    print()
    print(f'{generados} documentos en {SALIDA.relative_to(RAIZ)} (que está en .gitignore).')

    if fallidos:
        print(f'ERROR: no se pudo generar el PDF de: {", ".join(fallidos)}')
        return 1

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
