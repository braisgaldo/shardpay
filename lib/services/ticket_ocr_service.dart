import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/receipts/ocr_document.dart';
import '../core/receipts/receipt_parser.dart';
import 'receipt_preprocessor.dart';

/// Lectura de tickets: pone el reconocedor de texto de ML Kit al servicio del
/// parser puro de [ReceiptParser].
///
/// El reparto de responsabilidades es el que hace que esto se pueda mantener:
/// aquí solo vive lo que necesita el dispositivo (ML Kit, ficheros, islas), y
/// toda la lógica de interpretar el papel está en `lib/core/receipts`, cubierta
/// por pruebas.
class TicketOcrService {
  TicketOcrService({ReceiptParser parser = const ReceiptParser(), ReceiptPreprocessor preprocessor = const ReceiptPreprocessor()})
    : _parser = parser,
      _preprocessor = preprocessor;

  final ReceiptParser _parser;
  final ReceiptPreprocessor _preprocessor;

  TextRecognizer? _recognizer;
  bool _disposed = false;

  /// Confianza a partir de la cual no merece la pena realzar la imagen y
  /// volver a pasar el OCR.
  ///
  /// La versión anterior procesaba **siempre** las dos variantes, con lo que el
  /// caso bueno —una foto nítida, que es la mayoría— pagaba el doble de tiempo
  /// y de batería sin ganar nada.
  static const double _goodEnoughConfidence = 0.75;

  TextRecognizer get _textRecognizer {
    return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Lee un ticket a partir de una imagen.
  ///
  /// Primero prueba con la foto tal cual. Solo si el resultado no convence
  /// gasta tiempo en realzarla y repetir, y se queda con la mejor de las dos.
  Future<ReceiptScan> scanReceipt({required String imagePath}) async {
    final stopwatch = Stopwatch()..start();
    final direct = await _recognize(imagePath);

    if (direct.confidence >= _goodEnoughConfidence && direct.reconciled) {
      _log('lectura directa aceptada', direct, stopwatch);
      return direct;
    }

    String? enhancedPath;
    try {
      enhancedPath = await _preprocessor.enhance(imagePath);
      if (enhancedPath == null) {
        _log('sin realce disponible', direct, stopwatch);
        return direct;
      }

      final enhanced = await _recognize(enhancedPath);
      final best = _pickBest(direct, enhanced);
      _log(identical(best, enhanced) ? 'gana la imagen realzada' : 'gana la imagen original', best, stopwatch);
      return best;
    } finally {
      if (enhancedPath != null) {
        // El fichero intermedio se borra siempre. La versión anterior los
        // dejaba acumulándose en el directorio temporal, uno por cada ticket
        // leído en toda la vida de la instalación.
        unawaited(_deleteQuietly(enhancedPath));
      }
    }
  }

  Future<ReceiptScan> _recognize(String imagePath) async {
    if (_disposed) {
      return const ReceiptScan.empty();
    }

    try {
      final recognized = await _textRecognizer.processImage(InputImage.fromFile(File(imagePath)));
      final document = OcrDocument.fromFragments(_toFragments(recognized));
      return _parser.parse(document);
    } catch (error) {
      debugPrint('[OCR] El reconocimiento falló para $imagePath: $error');
      return const ReceiptScan.empty();
    }
  }

  /// Elige entre dos lecturas del mismo ticket.
  ///
  /// Manda la que cuadre con su propio total; entre dos que cuadren o dos que
  /// no, la de mayor confianza. Cuadrar con el total es una señal objetiva —el
  /// ticket confirma su propia aritmética—, mientras que la confianza es solo
  /// una heurística.
  ReceiptScan _pickBest(ReceiptScan first, ReceiptScan second) {
    if (first.reconciled != second.reconciled) {
      return first.reconciled ? first : second;
    }
    return second.confidence > first.confidence ? second : first;
  }

  /// Convierte el resultado de ML Kit en fragmentos con geometría.
  ///
  /// Se toman los elementos (palabras) y no las líneas completas: ML Kit une
  /// en una misma línea el nombre del artículo y su precio aunque estén en
  /// extremos opuestos del papel, y así se pierde la posición del importe, que
  /// es justo la señal que permite reconocer la columna de precios.
  Iterable<OcrFragment> _toFragments(RecognizedText recognized) sync* {
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        if (line.elements.isEmpty) {
          final text = line.text.trim();
          if (text.isNotEmpty) {
            yield OcrFragment(text: text, box: _toTextBox(line.boundingBox));
          }
          continue;
        }

        for (final element in line.elements) {
          final text = element.text.trim();
          if (text.isEmpty) {
            continue;
          }
          yield OcrFragment(text: text, box: _toTextBox(element.boundingBox));
        }
      }
    }
  }

  TextBox _toTextBox(Rect box) {
    return TextBox(left: box.left, top: box.top, right: box.right, bottom: box.bottom);
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Un temporal que no se puede borrar no es motivo para romper nada.
    }
  }

  void _log(String message, ReceiptScan scan, Stopwatch stopwatch) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[OCR] $message · ${scan.items.length} líneas · confianza '
      '${scan.confidence.toStringAsFixed(2)} · total ${scan.total} · '
      '${stopwatch.elapsedMilliseconds} ms',
    );
  }

  void dispose() {
    _disposed = true;
    _recognizer?.close();
    _recognizer = null;
  }
}
