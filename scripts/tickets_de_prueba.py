"""Genera tickets de prueba para el lector, como imágenes.

Probar el lector de tickets con un ticket de papel delante es lento y no se puede
repetir igual dos veces. Estos se generan siempre iguales, así que si una lectura
sale mal se puede repetir el caso exacto.

Cubren a propósito los casos que el parser tiene que resolver y que se explican
en `docs/MANUAL-TECNICO.md`:

- `1-simple`      líneas normales, total al final
- `2-cantidades`  líneas del tipo `2 x CERVEZA 2,50  5,00`
- `3-descuento`   un descuento en negativo, que no es una línea más
- `4-descuadre`   la suma de las líneas NO coincide con el total impreso

    python scripts/tickets_de_prueba.py

Salen en `docs/store/tickets-de-prueba/`. Para meterlos en el móvil:

    adb push docs/store/tickets-de-prueba/1-simple.png /sdcard/Pictures/
    adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \\
        -d file:///sdcard/Pictures/1-simple.png
"""
from __future__ import annotations

import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / 'docs' / 'store' / 'tickets-de-prueba'

ANCHO = 720
PAPEL = (250, 249, 246)
TINTA = (24, 24, 24)


def _fuente(tamano: int, negrita: bool = False):
    """Monoespaciada, que es como imprime cualquier caja registradora."""
    from PIL import ImageFont

    nombres = ('consolab.ttf', 'consola.ttf') if negrita else ('consola.ttf', 'cour.ttf')
    for nombre in nombres:
        for base in (pathlib.Path('C:/Windows/Fonts'), pathlib.Path('/usr/share/fonts/truetype/dejavu')):
            ruta = base / nombre
            if ruta.exists():
                return ImageFont.truetype(str(ruta), tamano)
    return ImageFont.load_default()


def _dibuja(nombre: str, comercio: str, cabecera: list[str], lineas: list[tuple[str, str]],
            pie: list[tuple[str, str]]) -> pathlib.Path:
    from PIL import Image, ImageDraw

    alto = 260 + len(cabecera) * 30 + len(lineas) * 34 + len(pie) * 40
    lienzo = Image.new('RGB', (ANCHO, alto), PAPEL)
    pincel = ImageDraw.Draw(lienzo)

    normal = _fuente(24)
    fuerte = _fuente(30, negrita=True)
    pequena = _fuente(20)

    y = 40
    pincel.text((ANCHO // 2, y), comercio, font=fuerte, fill=TINTA, anchor='ma')
    y += 48

    for texto in cabecera:
        pincel.text((ANCHO // 2, y), texto, font=pequena, fill=TINTA, anchor='ma')
        y += 28

    y += 14
    pincel.line([(40, y), (ANCHO - 40, y)], fill=TINTA, width=2)
    y += 22

    for concepto, importe in lineas:
        pincel.text((44, y), concepto, font=normal, fill=TINTA)
        pincel.text((ANCHO - 44, y), importe, font=normal, fill=TINTA, anchor='ra')
        y += 34

    y += 10
    pincel.line([(40, y), (ANCHO - 40, y)], fill=TINTA, width=2)
    y += 24

    for etiqueta, importe in pie:
        destacado = etiqueta.upper().startswith('TOTAL')
        f = fuerte if destacado else normal
        pincel.text((44, y), etiqueta, font=f, fill=TINTA)
        pincel.text((ANCHO - 44, y), importe, font=f, fill=TINTA, anchor='ra')
        y += 40 if destacado else 34

    destino = SALIDA / f'{nombre}.png'
    lienzo.save(destino, format='PNG')
    return destino


def main() -> int:
    try:
        import PIL  # noqa: F401
    except ImportError:
        print('Falta Pillow:  pip install pillow', file=sys.stderr)
        return 1

    SALIDA.mkdir(parents=True, exist_ok=True)

    hechos = [
        # 1. El caso facil: lineas y total, y la suma cuadra.
        _dibuja(
            '1-simple', 'BAR LA PLAZA',
            ['Rua Nova 14 - A Coruna', '31/08/2026  21:47', 'Mesa 7'],
            [('CROQUETAS', '8,50'), ('PULPO A FEIRA', '16,00'), ('ENSALADA MIXTA', '7,20'),
             ('AGUA 1L', '2,30'), ('VINO RIBEIRO', '12,00'), ('CAFE SOLO', '1,60')],
            [('SUBTOTAL', '47,60'), ('IVA 10%', '4,76'), ('TOTAL', '52,36')],
        ),
        # 2. Cantidades y precio unitario: `3 x CERVEZA 2,50  7,50`.
        _dibuja(
            '2-cantidades', 'SUPERMERCADO O CRUCE',
            ['Avda. Finisterre 200', '31/08/2026  12:05'],
            [('3 x CERVEZA ESTRELLA 1,20', '3,60'), ('2 x YOGUR NATURAL 0,85', '1,70'),
             ('PAN DE CENTENO', '2,40'), ('4 x MANZANA GOLDEN 0,55', '2,20'),
             ('QUESO GOUDA CUNA', '6,95'), ('ANTIPASTO VARIADO', '4,80')],
            [('TOTAL', '21,65'), ('TARJETA', '21,65')],
        ),
        # 3. Un descuento en negativo. No es una linea de gasto: resta.
        _dibuja(
            '3-descuento', 'CAFETERIA O ANDEN',
            ['Praza de Lugo 3', '31/08/2026  17:20'],
            [('TARTA DE QUEIXO', '5,50'), ('2 x CAFE CON LECHE 1,80', '3,60'),
             ('ZUMO NARANJA', '3,20'), ('DESCUENTO CLIENTE', '-1,50')],
            [('TOTAL', '10,80')],
        ),
        # 4. La suma de las lineas NO da el total impreso. El parser tiene que
        #    detectarlo, cuadrarlo con una linea de ajuste y avisar.
        _dibuja(
            '4-descuadre', 'RESTAURANTE O MUINO',
            ['Estrada de Santiago s/n', '31/08/2026  14:30', 'Menu del dia x2'],
            [('MENU DEL DIA', '14,50'), ('MENU DEL DIA', '14,50'),
             ('SUPLEMENTO MARISCO', '6,00'), ('CAFE', '1,40')],
            [('TOTAL', '41,90')],  # las lineas suman 36,40
        ),
    ]

    for hecho in hechos:
        print(f'  {hecho.relative_to(RAIZ)}')

    print()
    print('Las lineas de 4-descuadre suman 36,40 y el total impreso dice 41,90:')
    print('el lector tiene que darse cuenta y avisar.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
