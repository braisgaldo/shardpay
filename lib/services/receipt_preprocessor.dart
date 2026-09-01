import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Realce de la foto del ticket antes de pasarla por el OCR.
///
/// Dos cambios de fondo respecto a la versión anterior:
///
/// 1. **Se ejecuta en otra isla.** Antes el procesado de una foto de 12 MP
///    corría en el hilo de interfaz y congelaba la app varios segundos; el
///    diálogo de «analizando» ni siquiera llegaba a animarse.
/// 2. **Umbral adaptativo en vez de fijo.** El código anterior binarizaba con
///    un corte global (`luminancia >= 165`). En una foto con sombra —lo normal
///    al fotografiar un ticket sobre una mesa— eso deja media imagen en negro
///    y el OCR no lee nada. Aquí el umbral se calcula por vecindario con la
///    técnica de Sauvola sobre imágenes integrales, que es justo el caso para
///    el que se inventó: texto oscuro sobre papel claro con iluminación
///    desigual.
class ReceiptPreprocessor {
  const ReceiptPreprocessor();

  /// Lado máximo de la imagen entregada al OCR.
  ///
  /// Por encima de esto ML Kit no reconoce mejor y sí tarda bastante más: el
  /// texto de un ticket ocupa unos 20 px de alto ya a 2000 px de lado.
  static const int maxDimension = 2000;

  /// Devuelve la ruta de una copia realzada del ticket.
  ///
  /// Si algo falla devuelve `null` y el llamante sigue con la imagen original:
  /// el realce es una ayuda, nunca un requisito.
  Future<String?> enhance(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final processed = await compute(_enhanceBytes, bytes);
      if (processed == null) {
        return null;
      }

      final target = File(
        '${_workingDirectory(imagePath)}${Platform.pathSeparator}shardpay_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await target.writeAsBytes(processed, flush: true);
      return target.path;
    } catch (error, stackTrace) {
      debugPrint('[OCR] El realce de la imagen falló: $error');
      assert(() {
        debugPrintStack(stackTrace: stackTrace, label: 'ReceiptPreprocessor');
        return true;
      }());
      return null;
    }
  }

  String _workingDirectory(String imagePath) {
    final separatorIndex = imagePath.lastIndexOf(Platform.pathSeparator);
    if (separatorIndex <= 0) {
      return Directory.systemTemp.path;
    }
    return imagePath.substring(0, separatorIndex);
  }
}

/// Punto de entrada de la isla. Tiene que ser una función de nivel superior.
Uint8List? _enhanceBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }

  // Respeta la orientación EXIF: una foto tomada en vertical con la cámara
  // girada llega con los píxeles en horizontal y una etiqueta que nadie mira.
  var image = img.bakeOrientation(decoded);

  final longestSide = image.width > image.height ? image.width : image.height;
  if (longestSide > ReceiptPreprocessor.maxDimension) {
    final scale = ReceiptPreprocessor.maxDimension / longestSide;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  final width = image.width;
  final height = image.height;
  if (width < 8 || height < 8) {
    return null;
  }

  // 1. Luminancia en un buffer plano: recorrer píxeles del paquete `image` es
  //    caro, así que se hace una sola vez.
  final luminance = Uint8List(width * height);
  var index = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      luminance[index++] = img.getLuminance(image.getPixel(x, y)).round().clamp(0, 255);
    }
  }

  final binary = _sauvolaThreshold(luminance, width, height);

  // 2. Vuelca el resultado. Se escribe en los tres canales para que el JPEG
  //    resultante siga siendo válido en escala de grises.
  index = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final value = binary[index++];
      image.setPixelRgb(x, y, value, value, value);
    }
  }

  return img.encodeJpg(image, quality: 92);
}

/// Binarización de Sauvola con imágenes integrales.
///
/// `t(x,y) = m(x,y) · (1 + k · (s(x,y)/R − 1))`, donde `m` y `s` son la media y
/// la desviación típica de la ventana. Las imágenes integrales dejan el coste
/// en O(n) independientemente del tamaño de ventana; calcular la media pixel a
/// pixel sería O(n · w²) y tardaría minutos.
Uint8List _sauvolaThreshold(Uint8List luminance, int width, int height) {
  final windowSize = _windowSizeFor(width, height);
  final radius = windowSize ~/ 2;
  const k = 0.18;
  const dynamicRange = 128.0;

  final stride = width + 1;
  final sum = Uint32List(stride * (height + 1));
  final squaredSum = Float64List(stride * (height + 1));

  for (var y = 0; y < height; y++) {
    var rowSum = 0;
    var rowSquaredSum = 0.0;
    for (var x = 0; x < width; x++) {
      final value = luminance[y * width + x];
      rowSum += value;
      rowSquaredSum += value * value;
      final position = (y + 1) * stride + (x + 1);
      sum[position] = sum[position - stride] + rowSum;
      squaredSum[position] = squaredSum[position - stride] + rowSquaredSum;
    }
  }

  final output = Uint8List(width * height);

  for (var y = 0; y < height; y++) {
    final top = y - radius < 0 ? 0 : y - radius;
    final bottom = y + radius >= height ? height - 1 : y + radius;

    for (var x = 0; x < width; x++) {
      final left = x - radius < 0 ? 0 : x - radius;
      final right = x + radius >= width ? width - 1 : x + radius;

      final area = (bottom - top + 1) * (right - left + 1);
      final topLeft = top * stride + left;
      final topRight = top * stride + right + 1;
      final bottomLeft = (bottom + 1) * stride + left;
      final bottomRight = (bottom + 1) * stride + right + 1;

      final windowSum = sum[bottomRight] - sum[bottomLeft] - sum[topRight] + sum[topLeft];
      final windowSquaredSum = squaredSum[bottomRight] - squaredSum[bottomLeft] - squaredSum[topRight] + squaredSum[topLeft];

      final mean = windowSum / area;
      final variance = (windowSquaredSum / area) - (mean * mean);
      final deviation = variance <= 0 ? 0.0 : math.sqrt(variance);

      final threshold = mean * (1 + k * ((deviation / dynamicRange) - 1));
      output[y * width + x] = luminance[y * width + x] > threshold ? 255 : 0;
    }
  }

  return output;
}

/// Ventana proporcional al tamaño de la imagen y siempre impar.
///
/// Debe abarcar algo más que la altura de una línea de texto: si es menor, el
/// interior de las letras gruesas se blanquea y el OCR ve las letras huecas.
int _windowSizeFor(int width, int height) {
  final shortestSide = width < height ? width : height;
  var size = (shortestSide / 24).round();
  if (size < 15) {
    size = 15;
  }
  if (size > 81) {
    size = 81;
  }
  if (size.isEven) {
    size += 1;
  }
  return size;
}
