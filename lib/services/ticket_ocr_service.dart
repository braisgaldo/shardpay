import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';

class ParsedReceipt {
  ParsedReceipt({
    required this.items,
    this.title,
    this.note,
  });

  final String? title;
  final String? note;
  final List<ExpenseItem> items;
}

class TicketOcrService {
  TicketOcrService() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  final _uuid = const Uuid();
  static final RegExp _moneyAtEndRegExp = RegExp(r'([0-9]{1,3}(?:[\.,\s][0-9]{3})*[\.,][0-9]{2})\s*(?:€|eur|euros?)?$', caseSensitive: false);
  static final RegExp _amountAnywhereRegExp = RegExp(r'([0-9]{1,3}(?:[\.,\s][0-9]{3})*[\.,][0-9]{2})');
  static final RegExp _amountWithoutDecimalsRegExp = RegExp(r'([0-9]{1,3}(?:[\.,\s][0-9]{3})*)(?:\s*(?:€|eur|euros?))$', caseSensitive: false);
  static final RegExp _quantityPrefixRegExp = RegExp(r'^(?:\d+[xX]\s+|\d+\s*[xX]\s+|\d+\s+)');
  static final RegExp _danglingAmountRegExp = RegExp(r'\b\d+(?:[\.,]\d{2,3})?\b');
  static final List<String> _ignoredLineTokens = [
    'total',
    'subtotal',
    'importe',
    'cambio',
    'visa',
    'mastercard',
    'tarjeta',
    'efectivo',
    'fecha',
    'hora',
    'ticket',
    'factura',
    'nif',
    'cif',
    'iva',
    'mesa',
    'uds',
    'ud',
    'unid',
    'cant',
    'cantidad',
    'pago',
    'cash',
    'datafono',
    'comercio',
    'saldo',
    'entregado',
    'recibido',
    'vuelto',
  ];

  Future<ParsedReceipt> parseReceipt({
    required String imagePath,
    required List<SplitAllocation> defaultAllocations,
    required String defaultCategoryId,
  }) async {
    final preparedImagePath = await _prepareImageForOcr(imagePath);
    final inputImage = InputImage.fromFile(File(preparedImagePath));
    final result = await _recognizer.processImage(inputImage);
    final fragments = _extractFragments(result);
    final rows = _buildRows(fragments);
    final lines = rows.map((row) => row.fullText).where((line) => line.isNotEmpty).toList();
    final trimmedLines = _trimTrailingSummaryLines(lines);
    final items = <ExpenseItem>[];
    final seenItems = <String>{};
    final detectedNames = <String>[];

    _logOcrLines(trimmedLines);

    final trimmedRows = rows.where((row) => trimmedLines.contains(row.fullText)).toList();

    for (final row in trimmedRows) {
      final parsedItem = _parseRow(row, trimmedRows);
      if (parsedItem == null) {
        final candidateName = _extractNameCandidate(row.fullText);
        if (candidateName != null) {
          detectedNames.add(candidateName);
        }
        continue;
      }

      final seenKey = '${parsedItem.name}|${parsedItem.amount.toStringAsFixed(2)}';
      if (!seenItems.add(seenKey)) {
        continue;
      }

      items.add(
        ExpenseItem(
          id: _uuid.v4(),
          name: parsedItem.name,
          amount: parsedItem.amount,
          categoryId: defaultCategoryId,
          allocations: defaultAllocations,
        ),
      );

      _logAcceptedItem(parsedItem);
    }

    final fallbackTitle = _detectReceiptTitle(lines);
    final fallbackTotal = lines
        .map(_extractLastAmount)
        .whereType<double>()
        .fold<double>(0, (currentMax, amount) => amount > currentMax ? amount : currentMax);

    if (items.isEmpty && detectedNames.length >= 2 && fallbackTotal > 0) {
      final estimatedAmount = double.parse((fallbackTotal / detectedNames.length).toStringAsFixed(2));
      for (final name in detectedNames.take(24)) {
        items.add(
          ExpenseItem(
            id: _uuid.v4(),
            name: name,
            amount: estimatedAmount,
            categoryId: defaultCategoryId,
            allocations: defaultAllocations,
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        ExpenseItem(
          id: _uuid.v4(),
          name: fallbackTitle,
          amount: fallbackTotal > 0 ? fallbackTotal : 0,
          categoryId: defaultCategoryId,
          allocations: defaultAllocations,
        ),
      );
    }

    return ParsedReceipt(
      title: fallbackTitle,
      note: items.length >= 2 && detectedNames.isNotEmpty && items.every((item) => item.amount == items.first.amount)
          ? 'Añadido con OCR · revisa importes estimados'
          : 'Añadido con OCR',
      items: items,
    );
  }

  void _logOcrLines(List<String> lines) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[OCR] Lines: ${lines.length}');
    for (final line in lines.take(80)) {
      debugPrint('[OCR] > $line');
    }
  }

  void _logAcceptedItem(_ParsedReceiptItem item) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[OCR] Item accepted: ${item.name} | ${item.amount.toStringAsFixed(2)}');
  }

  Future<String> _prepareImageForOcr(String imagePath) async {
    try {
      final originalBytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) {
        return imagePath;
      }

      final targetWidth = decoded.width < 1800 ? 1800 : decoded.width;
      var processed = decoded.width == targetWidth ? img.Image.from(decoded) : img.copyResize(decoded, width: targetWidth);
      processed = img.grayscale(processed);
      processed = img.adjustColor(processed, contrast: 1.9, brightness: 0.08, gamma: 0.92);
      processed = img.gaussianBlur(processed, radius: 1);
      processed = img.adjustColor(processed, contrast: 2.4, brightness: 0.03);
      for (final pixel in processed) {
        final luminance = img.getLuminance(pixel);
        final binary = luminance >= 165 ? 255 : 0;
        pixel
          ..r = binary
          ..g = binary
          ..b = binary;
      }

      final preparedFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}shardpay_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await preparedFile.writeAsBytes(img.encodeJpg(processed, quality: 96), flush: true);
      if (kDebugMode) {
        debugPrint('[OCR] Prepared image saved at ${preparedFile.path}');
      }
      return preparedFile.path;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[OCR] Image preprocessing failed: $error');
      }
      return imagePath;
    }
  }

  void dispose() {
    _recognizer.close();
  }
}

class _ParsedReceiptItem {
  const _ParsedReceiptItem({required this.name, required this.amount});

  final String name;
  final double amount;
}

class _OcrFragment {
  const _OcrFragment({required this.text, required this.left, required this.top, required this.right, required this.bottom});

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

class _OcrRow {
  const _OcrRow({required this.fragments, required this.fullText});

  final List<_OcrFragment> fragments;
  final String fullText;

  double get centerY => fragments.fold<double>(0, (total, item) => total + item.centerY) / fragments.length;
  String? get rightMostAmount => fragments.map((fragment) => fragment.text).where((text) => _extractLastAmount(text) != null).lastOrNull;
  bool get isAmountOnly => fragments.isNotEmpty && fragments.every((fragment) => _extractNameCandidate(fragment.text) == null) && rightMostAmount != null;
}

String _normalizeLine(String value) {
  return value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('€', ' €')
      .replaceAll('|', '1')
      .replaceAllMapped(RegExp(r'(?<=\D)(\d{1,2})[Oo](?=\d{2}\b)'), (match) => '${match.group(1)}0')
      .trim();
}

List<String> _trimTrailingSummaryLines(List<String> lines) {
  final totalIndex = lines.indexWhere((line) => RegExp(r'\b(total|importe total|subtotal|base imponible)\b', caseSensitive: false).hasMatch(line));
  if (totalIndex <= 0) {
    return lines;
  }
  return lines.take(totalIndex).toList(growable: false);
}

String _detectReceiptTitle(List<String> lines) {
  for (final line in lines) {
    final lowered = line.toLowerCase();
    final hasAmount = TicketOcrService._amountAnywhereRegExp.hasMatch(line) || TicketOcrService._amountWithoutDecimalsRegExp.hasMatch(line);
    if (TicketOcrService._ignoredLineTokens.any(lowered.contains) || hasAmount) {
      continue;
    }
    return line;
  }
  return lines.isNotEmpty ? lines.first : 'Ticket importado';
}

List<_OcrFragment> _extractFragments(RecognizedText result) {
  final fragments = <_OcrFragment>[];

  for (final block in result.blocks) {
    for (final line in block.lines) {
      if (line.elements.isEmpty) {
        final text = _normalizeLine(line.text);
        final box = line.boundingBox;
        if (text.isNotEmpty) {
          fragments.add(_OcrFragment(text: text, left: box.left.toDouble(), top: box.top.toDouble(), right: box.right.toDouble(), bottom: box.bottom.toDouble()));
        }
        continue;
      }

      for (final element in line.elements) {
        final text = _normalizeLine(element.text);
        final box = element.boundingBox;
        if (text.isEmpty) {
          continue;
        }
        fragments.add(_OcrFragment(text: text, left: box.left.toDouble(), top: box.top.toDouble(), right: box.right.toDouble(), bottom: box.bottom.toDouble()));
      }
    }
  }

  fragments.sort((a, b) => a.top.compareTo(b.top));
  return fragments;
}

List<_OcrRow> _buildRows(List<_OcrFragment> fragments) {
  if (fragments.isEmpty) {
    return const [];
  }

  final averageHeight = fragments.fold<double>(0, (total, fragment) => total + fragment.height) / fragments.length;
  final threshold = averageHeight.clamp(10, 22).toDouble();
  final rows = <List<_OcrFragment>>[];

  for (final fragment in fragments) {
    final row = rows.isEmpty ? null : rows.last;
    if (row == null) {
      rows.add([fragment]);
      continue;
    }

    final rowCenterY = row.fold<double>(0, (total, item) => total + item.centerY) / row.length;
    if ((fragment.centerY - rowCenterY).abs() <= threshold) {
      row.add(fragment);
    } else {
      rows.add([fragment]);
    }
  }

  return rows
      .map((row) {
        final sortedRow = [...row]..sort((a, b) => a.left.compareTo(b.left));
        return sortedRow;
      })
      .map((row) => _OcrRow(fragments: row, fullText: _normalizeLine(row.map((fragment) => fragment.text).join(' '))))
      .where((row) => row.fullText.isNotEmpty)
      .toList();
}

_ParsedReceiptItem? _parseRow(_OcrRow row, List<_OcrRow> allRows) {
  final direct = _parseItemLine(row.fullText);
  if (direct != null) {
    return direct;
  }

  final candidateName = _extractNameCandidate(row.fullText);
  if (candidateName == null) {
    return null;
  }

  _OcrRow? nextRow;
  for (final candidate in allRows) {
    if (candidate.centerY > row.centerY && (candidate.centerY - row.centerY) < 30 && candidate.isAmountOnly) {
      nextRow = candidate;
      break;
    }
  }
  final nextAmount = nextRow?.rightMostAmount;
  if (nextAmount == null) {
    return null;
  }

  final amount = _parseMoney(nextAmount);
  if (amount == null || amount <= 0) {
    return null;
  }

  return _ParsedReceiptItem(name: candidateName, amount: amount);
}

String? _extractNameCandidate(String rawLine) {
  final loweredLine = rawLine.toLowerCase();
  if (TicketOcrService._ignoredLineTokens.any(loweredLine.contains)) {
    return null;
  }

  final withoutAmounts = rawLine
      .replaceAll(TicketOcrService._amountAnywhereRegExp, ' ')
      .replaceAll(TicketOcrService._amountWithoutDecimalsRegExp, ' ')
      .replaceFirst(TicketOcrService._quantityPrefixRegExp, '')
      .replaceAll(TicketOcrService._danglingAmountRegExp, ' ')
      .replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  if (withoutAmounts.length < 3 || RegExp(r'^[0-9\s]+$').hasMatch(withoutAmounts)) {
    return null;
  }

  return withoutAmounts;
}

_ParsedReceiptItem? _parseItemLine(String rawLine) {
  final loweredLine = rawLine.toLowerCase();
  if (TicketOcrService._ignoredLineTokens.any(loweredLine.contains)) {
    return null;
  }

  final amountMatch = TicketOcrService._moneyAtEndRegExp.firstMatch(rawLine) ?? TicketOcrService._amountAnywhereRegExp.allMatches(rawLine).lastOrNull ?? TicketOcrService._amountWithoutDecimalsRegExp.firstMatch(rawLine);
  if (amountMatch == null) {
    return null;
  }

  final amount = _parseMoney(amountMatch.group(1)!);
  if (amount == null || amount <= 0) {
    return null;
  }

  final rawName = '${rawLine.substring(0, amountMatch.start)} ${rawLine.substring(amountMatch.end)}'.trim();
  final normalizedName = _extractNameCandidate(rawName);

  if (normalizedName == null || normalizedName.isEmpty) {
    return null;
  }

  final lowered = normalizedName.toLowerCase();
  if (TicketOcrService._ignoredLineTokens.any(lowered.contains) || lowered.length < 2) {
    return null;
  }

  if (RegExp(r'^[0-9\s\.,xX]+$').hasMatch(normalizedName)) {
    return null;
  }

  return _ParsedReceiptItem(name: normalizedName, amount: amount);
}

double? _extractLastAmount(String line) {
  final match = TicketOcrService._amountAnywhereRegExp.allMatches(line).lastOrNull ?? TicketOcrService._amountWithoutDecimalsRegExp.firstMatch(line);
  if (match == null) {
    return null;
  }
  return _parseMoney(match.group(1)!);
}

double? _parseMoney(String rawValue) {
  var value = rawValue.replaceAll(' ', '').replaceAll(RegExp(r'[^0-9,\.]'), '');
  if (value.isEmpty) {
    return null;
  }

  final lastComma = value.lastIndexOf(',');
  final lastDot = value.lastIndexOf('.');
  final decimalSeparatorIndex = lastComma > lastDot ? lastComma : lastDot;

  if (decimalSeparatorIndex >= 0) {
    final integerPart = value.substring(0, decimalSeparatorIndex).replaceAll(RegExp(r'[^0-9]'), '');
    final decimalPart = value.substring(decimalSeparatorIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');
    value = '$integerPart.$decimalPart';
  } else {
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  return double.tryParse(value);
}