/// Geometría del OCR: convierte los fragmentos sueltos que devuelve el motor
/// de reconocimiento de texto en filas ordenadas y medidas agregadas.
///
/// Todo este fichero es Dart puro a propósito: no importa ML Kit, ni Flutter,
/// ni `dart:ui`. Gracias a eso el parser de tickets se puede probar en
/// `flutter test` con datos sintéticos, sin cámara y sin dispositivo.
library;

import 'dart:math' as math;

/// Caja delimitadora de un fragmento de texto, en píxeles de la imagen.
class TextBox {
  const TextBox({required this.left, required this.top, required this.right, required this.bottom});

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  /// Fracción de solape vertical con [other], entre 0 y 1.
  ///
  /// Se usa en lugar de la distancia entre centros porque tolera los tickets
  /// fotografiados con perspectiva: dos fragmentos del mismo renglón siguen
  /// solapándose aunque sus centros estén desplazados por la inclinación.
  double verticalOverlapWith(TextBox other) {
    final overlap = math.min(bottom, other.bottom) - math.max(top, other.top);
    if (overlap <= 0) {
      return 0;
    }
    final smallestHeight = math.min(height, other.height);
    if (smallestHeight <= 0) {
      return 0;
    }
    return overlap / smallestHeight;
  }

  TextBox mergedWith(TextBox other) {
    return TextBox(
      left: math.min(left, other.left),
      top: math.min(top, other.top),
      right: math.max(right, other.right),
      bottom: math.max(bottom, other.bottom),
    );
  }

  @override
  String toString() => 'TextBox(${left.round()}, ${top.round()}, ${right.round()}, ${bottom.round()})';
}

/// Un trozo de texto reconocido junto con su posición en la imagen.
class OcrFragment {
  const OcrFragment({required this.text, required this.box, this.confidence});

  final String text;
  final TextBox box;

  /// Confianza del motor OCR entre 0 y 1, cuando la expone. ML Kit solo la
  /// publica en algunos idiomas, así que el parser nunca depende de ella.
  final double? confidence;

  @override
  String toString() => '"$text" @ $box';
}

/// Una fila del ticket: los fragmentos que comparten renglón, ya ordenados de
/// izquierda a derecha.
class OcrRow {
  OcrRow(List<OcrFragment> fragments)
    : assert(fragments.isNotEmpty, 'Una fila necesita al menos un fragmento'),
      fragments = List<OcrFragment>.unmodifiable(fragments),
      box = fragments.map((fragment) => fragment.box).reduce((a, b) => a.mergedWith(b)),
      text = fragments.map((fragment) => fragment.text).join(' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  final List<OcrFragment> fragments;
  final TextBox box;
  final String text;

  double get top => box.top;
  double get bottom => box.bottom;
  double get centerY => box.centerY;
  double get height => box.height;

  bool get isEmpty => text.isEmpty;

  @override
  String toString() => text;
}

/// Documento OCR completo: filas ordenadas de arriba abajo más la geometría
/// agregada que el parser necesita para decidir qué número es un precio.
class OcrDocument {
  OcrDocument._({required this.rows, required this.medianLineHeight, required this.contentLeft, required this.contentRight});

  final List<OcrRow> rows;

  /// Altura mediana de línea. Es la unidad de medida de todas las tolerancias:
  /// así un ticket fotografiado de cerca y otro de lejos se parsean igual,
  /// porque las distancias se expresan en múltiplos de esta altura y no en
  /// píxeles absolutos.
  final double medianLineHeight;

  final double contentLeft;
  final double contentRight;

  double get contentWidth => math.max(1, contentRight - contentLeft);

  bool get isEmpty => rows.isEmpty;

  /// Posición horizontal relativa: 0 es el margen izquierdo del contenido y 1
  /// el derecho.
  double relativeX(double x) {
    final relative = (x - contentLeft) / contentWidth;
    if (relative < 0) {
      return 0;
    }
    if (relative > 1) {
      return 1;
    }
    return relative;
  }

  /// Agrupa fragmentos en filas.
  ///
  /// El agrupado va por solape vertical y no por distancia entre centros
  /// porque los tickets se fotografían torcidos: con cinco grados de
  /// inclinación el extremo derecho de un renglón queda más bajo que el centro
  /// del renglón siguiente, y cualquier umbral por distancia los mezcla.
  factory OcrDocument.fromFragments(Iterable<OcrFragment> input) {
    final fragments = input.where((fragment) => fragment.text.trim().isNotEmpty).toList(growable: false);
    if (fragments.isEmpty) {
      return OcrDocument._(rows: const [], medianLineHeight: 1, contentLeft: 0, contentRight: 1);
    }

    final medianHeight = _median(fragments.map((fragment) => fragment.box.height).toList());
    final rowGap = medianHeight <= 0 ? 20.0 : medianHeight * 2;
    final sorted = [...fragments]
      ..sort((a, b) {
        final byTop = a.box.top.compareTo(b.box.top);
        return byTop != 0 ? byTop : a.box.left.compareTo(b.box.left);
      });

    final buckets = <List<OcrFragment>>[];
    final bucketBoxes = <TextBox>[];

    for (final fragment in sorted) {
      var matchedIndex = -1;
      var bestOverlap = 0.0;

      // Los fragmentos llegan ordenados por altura, así que basta con mirar
      // hacia atrás hasta salir del alcance vertical. Sin ese corte esto sería
      // cuadrático en tickets largos.
      for (var index = bucketBoxes.length - 1; index >= 0; index--) {
        final box = bucketBoxes[index];
        if (fragment.box.top - box.bottom > rowGap) {
          break;
        }
        final overlap = box.verticalOverlapWith(fragment.box);
        if (overlap > bestOverlap) {
          bestOverlap = overlap;
          matchedIndex = index;
        }
      }

      if (matchedIndex >= 0 && bestOverlap >= 0.4) {
        buckets[matchedIndex].add(fragment);
        bucketBoxes[matchedIndex] = bucketBoxes[matchedIndex].mergedWith(fragment.box);
      } else {
        buckets.add(<OcrFragment>[fragment]);
        bucketBoxes.add(fragment.box);
      }
    }

    final rows =
        buckets
            .map((bucket) => OcrRow([...bucket]..sort((a, b) => a.box.left.compareTo(b.box.left))))
            .where((row) => row.text.isNotEmpty)
            .toList()
          ..sort((a, b) => a.centerY.compareTo(b.centerY));

    var contentLeft = double.infinity;
    var contentRight = double.negativeInfinity;
    for (final row in rows) {
      contentLeft = math.min(contentLeft, row.box.left);
      contentRight = math.max(contentRight, row.box.right);
    }

    return OcrDocument._(
      rows: rows,
      medianLineHeight: medianHeight <= 0 ? 1 : medianHeight,
      contentLeft: contentLeft.isFinite ? contentLeft : 0,
      contentRight: contentRight.isFinite ? contentRight : 1,
    );
  }

  /// Construye un documento a partir de líneas de texto sin geometría.
  ///
  /// Es el camino degradado: lo usan las pruebas y el caso en que el motor OCR
  /// solo devuelve texto plano. Se sintetizan cajas con altura constante para
  /// que el resto del parser funcione sin ramas especiales.
  factory OcrDocument.fromLines(Iterable<String> lines) {
    const lineHeight = 20.0;
    const charWidth = 10.0;
    final fragments = <OcrFragment>[];
    var index = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isNotEmpty) {
        fragments.add(
          OcrFragment(
            text: line,
            box: TextBox(
              left: 0,
              top: index * lineHeight * 1.5,
              right: line.length * charWidth,
              bottom: index * lineHeight * 1.5 + lineHeight,
            ),
          ),
        );
      }
      index++;
    }

    return OcrDocument.fromFragments(fragments);
  }
}

double _median(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}
