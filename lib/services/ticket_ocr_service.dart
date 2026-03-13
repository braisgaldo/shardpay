import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';

class ParsedReceipt {
  ParsedReceipt({
    required this.items,
    this.note,
  });

  final String? note;
  final List<ExpenseItem> items;
}

class TicketOcrService {
  TicketOcrService() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  final _uuid = const Uuid();
  static final RegExp _moneyAtEndRegExp = RegExp(r'([0-9]{1,3}(?:[\.,\s][0-9]{3})*[\.,][0-9]{2})\s*(?:€|eur|euros?)?$', caseSensitive: false);
  static final RegExp _amountAnywhereRegExp = RegExp(r'([0-9]{1,3}(?:[\.,\s][0-9]{3})*[\.,][0-9]{2})');
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
  ];

  Future<ParsedReceipt> parseReceipt({
    required String imagePath,
    required List<SplitAllocation> defaultAllocations,
    required String defaultCategoryId,
  }) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final result = await _recognizer.processImage(inputImage);
    final lines = result.blocks.expand((block) => block.lines).map((line) => _normalizeLine(line.text)).where((line) => line.isNotEmpty).toList();
    final items = <ExpenseItem>[];
    final seenItems = <String>{};

    for (final line in lines) {
      final parsedItem = _parseItemLine(line);
      if (parsedItem == null) {
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
    }

    final fallbackTitle = lines.isNotEmpty ? lines.first : 'Ticket importado';

    if (items.isEmpty) {
      final fallbackTotal = lines
          .map(_extractLastAmount)
          .whereType<double>()
          .fold<double>(0, (currentMax, amount) => amount > currentMax ? amount : currentMax);

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
      note: 'Añadido con OCR',
      items: items,
    );
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

String _normalizeLine(String value) {
  return value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('€', ' €')
      .trim();
}

_ParsedReceiptItem? _parseItemLine(String rawLine) {
  final amountMatch = TicketOcrService._moneyAtEndRegExp.firstMatch(rawLine);
  if (amountMatch == null) {
    return null;
  }

  final amount = _parseMoney(amountMatch.group(1)!);
  if (amount == null || amount <= 0) {
    return null;
  }

  final rawName = rawLine.substring(0, amountMatch.start).trim();
  final normalizedName = rawName
      .replaceAll(RegExp(r'[\.·:_-]{2,}$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  if (normalizedName.isEmpty) {
    return null;
  }

  final lowered = normalizedName.toLowerCase();
  if (TicketOcrService._ignoredLineTokens.any(lowered.contains)) {
    return null;
  }

  if (RegExp(r'^[0-9\s\.,xX]+$').hasMatch(normalizedName)) {
    return null;
  }

  return _ParsedReceiptItem(name: normalizedName, amount: amount);
}

double? _extractLastAmount(String line) {
  final match = TicketOcrService._amountAnywhereRegExp.allMatches(line).lastOrNull;
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