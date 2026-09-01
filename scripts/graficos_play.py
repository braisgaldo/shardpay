"""Genera los gráficos que Google Play exige y que no salen de ninguna captura.

Play pide dos piezas que no existen en el proyecto y sin las cuales no se puede
publicar:

- **Icono de 512x512** PNG de 32 bits. Sale del icono de la app de 1024.
- **Gráfico destacado de 1024x500**, la banda que encabeza la ficha. Este hay que
  componerlo: no es un recorte de nada.

Ambos se pintan con la paleta Claro Arena de la app, para que la ficha y la app
no parezcan dos productos distintos.

    python scripts/graficos_play.py
"""
from __future__ import annotations

import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
# El icono de la marca. NO se usa el de iOS: ese sigue siendo el de Flutter por
# defecto, un fallo aparte que hay que arreglar antes de tocar la App Store.
ICONO_ORIGEN = RAIZ / 'android' / 'app' / 'src' / 'main' / 'res' / 'mipmap-xxxhdpi' / 'shardpay_launcher.png'
SALIDA = RAIZ / 'docs' / 'google_play' / 'graficos'

# Paleta Claro Arena, la misma de lib/app/preferences.dart.
ACENTO = (228, 87, 46)
TINTA = (31, 26, 23)
ARENA = (253, 248, 244)
CREMA = (243, 198, 119)


def _fuente(tamano: int):
    """Una tipografía de palo seco con peso, buscada entre las del sistema."""
    from PIL import ImageFont

    for nombre in ('seguisb.ttf', 'segoeuib.ttf', 'arialbd.ttf', 'DejaVuSans-Bold.ttf'):
        for base in (pathlib.Path('C:/Windows/Fonts'), pathlib.Path('/usr/share/fonts/truetype/dejavu')):
            ruta = base / nombre
            if ruta.exists():
                return ImageFont.truetype(str(ruta), tamano)
    return ImageFont.load_default()


def icono() -> pathlib.Path:
    from PIL import Image

    destino = SALIDA / 'icono-512.png'
    with Image.open(ICONO_ORIGEN) as imagen:
        # Play exige 32 bits: RGBA aunque el icono sea opaco.
        imagen.convert('RGBA').resize((512, 512), Image.LANCZOS).save(destino, format='PNG')
    return destino


def destacado() -> pathlib.Path:
    from PIL import Image, ImageDraw

    destino = SALIDA / 'destacado-1024x500.png'
    ancho, alto = 1024, 500
    lienzo = Image.new('RGB', (ancho, alto), ARENA)
    pincel = ImageDraw.Draw(lienzo)

    # Banda diagonal de acento en el tercio derecho. Play recorta los bordes en
    # algunas pantallas, asi que el texto se queda en el lado izquierdo y la
    # banda solo aporta color: si se pierde un trozo, no se pierde informacion.
    pincel.polygon([(ancho * 0.70, 0), (ancho, 0), (ancho, alto), (ancho * 0.54, alto)], fill=ACENTO)
    pincel.polygon([(ancho * 0.92, 0), (ancho, 0), (ancho, alto), (ancho * 0.80, alto)], fill=CREMA)

    with Image.open(ICONO_ORIGEN) as marca:
        lado = 150
        marca = marca.convert('RGBA').resize((lado, lado), Image.LANCZOS)
        redondeado = Image.new('L', (lado, lado), 0)
        ImageDraw.Draw(redondeado).rounded_rectangle([0, 0, lado - 1, lado - 1], radius=38, fill=255)
        lienzo.paste(marca, (72, 96), redondeado)

    pincel.text((248, 128), 'ShardPay', font=_fuente(76), fill=TINTA)
    pincel.text((252, 216), 'Reparte gastos en grupo', font=_fuente(30), fill=(110, 98, 90))
    pincel.text((72, 316), 'Apunta a mano o hazle una foto al ticket:', font=_fuente(27), fill=(110, 98, 90))
    pincel.text((72, 356), 'la app lee las líneas y calcula quién debe qué.', font=_fuente(27), fill=(110, 98, 90))
    # La última línea se queda corta a propósito: la banda empieza en 0,54 del
    # ancho por abajo, y un texto más largo se metería debajo del naranja.
    pincel.text((72, 414), 'Gratis  ·  sin anuncios  ·  sin rastreo', font=_fuente(24), fill=ACENTO)

    lienzo.save(destino, format='PNG')
    return destino



# Capturas de la ficha ---------------------------------------------------------
#
# Play exige una relacion de aspecto entre 16:9 y 9:16. Las capturas del S22
# Ultra son 1080x2316, o sea 1:2,14: **mas altas que el maximo**, y se rechazan.
#
# En vez de recortar contenido, se montan centradas sobre un lienzo 9:16 con el
# fondo de la marca. De paso se les quitan las barras del sistema, que en una
# ficha de tienda no aportan nada.

LIENZO_CAPTURA = (1242, 2208)
"""9:16 exacto. Dentro del rango de Play y suficientemente grande."""

RECORTE_SUPERIOR_TIENDA = 0.040
RECORTE_INFERIOR_TIENDA = 0.050


def capturas() -> list[pathlib.Path]:
    from PIL import Image, ImageDraw

    origen = RAIZ / 'docs' / 'google_play' / 'capturas'
    hechas = []

    for ruta in sorted(origen.glob('*.png')):
        with Image.open(ruta) as captura:
            captura = captura.convert('RGB')
            arriba = round(captura.height * RECORTE_SUPERIOR_TIENDA)
            abajo = captura.height - round(captura.height * RECORTE_INFERIOR_TIENDA)
            captura = captura.crop((0, arriba, captura.width, abajo))

            ancho, alto = LIENZO_CAPTURA
            margen = 64
            escala = min((ancho - margen * 2) / captura.width, (alto - margen * 2) / captura.height)
            nuevo = (round(captura.width * escala), round(captura.height * escala))
            captura = captura.resize(nuevo, Image.LANCZOS)

            # Esquinas redondeadas: el movil las tiene y la captura plana no.
            mascara = Image.new('L', nuevo, 0)
            ImageDraw.Draw(mascara).rounded_rectangle([0, 0, nuevo[0] - 1, nuevo[1] - 1], radius=36, fill=255)

            lienzo = Image.new('RGB', LIENZO_CAPTURA, ARENA)
            lienzo.paste(captura, ((ancho - nuevo[0]) // 2, (alto - nuevo[1]) // 2), mascara)
            lienzo.save(ruta, format='PNG')

        hechas.append(ruta)

    return hechas

def main() -> int:
    try:
        import PIL  # noqa: F401
    except ImportError:
        print('Falta Pillow:  pip install pillow', file=sys.stderr)
        return 1

    if not ICONO_ORIGEN.exists():
        print(f'No encuentro el icono de origen: {ICONO_ORIGEN}', file=sys.stderr)
        return 1

    SALIDA.mkdir(parents=True, exist_ok=True)
    for hecho in (icono(), destacado()):
        print(f'  {hecho.relative_to(RAIZ)}  ({hecho.stat().st_size // 1024} kB)')

    for hecho in capturas():
        print(f'  {hecho.relative_to(RAIZ)}  (montada en lienzo 9:16)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
