"""Quita el marco verde de grabación de pantalla de las capturas.

Cuando Android está grabando la pantalla o proyectándola, algunos móviles pintan
un marco verde de tres a cinco píxeles alrededor de todo. En una captura para la
ficha de la tienda eso es un defecto: no forma parte de la app y se ve.

Pasó de verdad: once de las capturas de ShardPay lo tenían y no se detectó hasta
maquetarlas en el manual, donde el marco quedaba como una raya de color al lado
del texto.

    python scripts/limpiar_capturas.py                 # revisa y avisa
    python scripts/limpiar_capturas.py --arreglar      # recorta el marco

El recorte es de unos pocos píxeles sobre 1080, así que no cambia el encuadre.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

CAPTURAS = pathlib.Path(__file__).resolve().parent.parent / 'docs' / 'store' / 'capturas'

GROSOR_MAXIMO = 24
"""Más que esto ya no es un marco: es contenido, y no se toca."""


def _es_verde_de_grabacion(color: tuple[int, int, int]) -> bool:
    """Verde saturado y oscuro, que no aparece en ninguna paleta de ShardPay."""
    rojo, verde, azul = color
    return verde > 90 and verde > rojo * 1.15 and azul < 60


def _grosor_del_marco(imagen) -> int:
    """Píxeles de marco verde, medidos en el centro de cada lado."""
    pixeles = imagen.load()
    medio_y = imagen.height // 2
    medio_x = imagen.width // 2

    def contar(muestras) -> int:
        total = 0
        for color in muestras:
            if not _es_verde_de_grabacion(color):
                break
            total += 1
        return total

    return max(
        contar(pixeles[x, medio_y] for x in range(GROSOR_MAXIMO)),
        contar(pixeles[imagen.width - 1 - x, medio_y] for x in range(GROSOR_MAXIMO)),
        contar(pixeles[medio_x, y] for y in range(GROSOR_MAXIMO)),
        contar(pixeles[medio_x, imagen.height - 1 - y] for y in range(GROSOR_MAXIMO)),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--arreglar', action='store_true', help='recorta el marco en vez de solo avisar')
    args = parser.parse_args()

    try:
        from PIL import Image
    except ImportError:
        print('Falta Pillow:  pip install pillow', file=sys.stderr)
        return 1

    afectadas = []
    for ruta in sorted(CAPTURAS.glob('*.png')):
        with Image.open(ruta) as imagen:
            imagen = imagen.convert('RGB')
            grosor = _grosor_del_marco(imagen)
            if grosor == 0:
                continue

            afectadas.append((ruta.name, grosor))
            if args.arreglar:
                recortada = imagen.crop((grosor, grosor, imagen.width - grosor, imagen.height - grosor))
                recortada.save(ruta, format='PNG', optimize=True)

    if not afectadas:
        print('Ninguna captura tiene marco de grabación.')
        return 0

    verbo = 'Recortado' if args.arreglar else 'Marco de grabación en'
    for nombre, grosor in afectadas:
        print(f'  {verbo:<24} {nombre}  ({grosor} px)')

    if not args.arreglar:
        print(f'\n{len(afectadas)} capturas con marco. Ejecuta con --arreglar para recortarlo.')
        return 1

    print(f'\n{len(afectadas)} capturas limpias.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
