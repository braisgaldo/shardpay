/// Lectura de importes dentro de una línea de ticket.
///
/// Dart puro y sin dependencias: es la parte del OCR que más se equivoca y la
/// que más falta hace poder probar con cientos de casos en `flutter test`.
library;

import 'ocr_document.dart';

/// Separador decimal deducido para el documento completo.
enum DecimalSeparator { comma, dot }

/// Un número con pinta de dinero encontrado dentro de una línea.
class MoneyToken {
  const MoneyToken({
    required this.value,
    required this.raw,
    required this.start,
    required this.end,
    required this.hasExplicitDecimals,
    required this.hasCurrencyMark,
    required this.isNegative,
    this.box,
  });

  /// Valor absoluto en unidades de la divisa (ya con el signo aplicado).
  final double value;

  /// Texto tal cual aparecía.
  final String raw;

  /// Posición dentro de la línea normalizada.
  final int start;
  final int end;

  /// `true` si traía parte decimal explícita (`12,40`) y no solo `12`.
  final bool hasExplicitDecimals;

  /// `true` si venía pegado a un símbolo o código de divisa.
  final bool hasCurrencyMark;

  final bool isNegative;

  /// Caja del fragmento que contiene este número, si se conoce.
  final TextBox? box;

  MoneyToken copyWith({TextBox? box}) {
    return MoneyToken(
      value: value,
      raw: raw,
      start: start,
      end: end,
      hasExplicitDecimals: hasExplicitDecimals,
      hasCurrencyMark: hasCurrencyMark,
      isNegative: isNegative,
      box: box ?? this.box,
    );
  }

  @override
  String toString() => 'MoneyToken($raw -> $value)';
}

/// Símbolos y códigos de divisa que el escáner reconoce.
const Map<String, String> currencySymbols = <String, String>{
  '€': 'EUR',
  '\$': 'USD',
  '£': 'GBP',
  '¥': 'JPY',
  '₽': 'RUB',
  '₩': 'KRW',
  '₹': 'INR',
  'CHF': 'CHF',
  'EUR': 'EUR',
  'USD': 'USD',
  'GBP': 'GBP',
  'MXN': 'MXN',
  'ARS': 'ARS',
  'COP': 'COP',
  'BRL': 'BRL',
};

/// Números candidatos a importe.
///
/// Deliberadamente permisiva: el filtrado por contexto (fechas, horas,
/// porcentajes, códigos) se hace después, donde se puede razonar con los
/// caracteres de alrededor.
final RegExp _numberPattern = RegExp(r'\d+(?:[.,  ]\d{3})*(?:[.,]\d{1,2})?');

final RegExp _currencyCodePattern = RegExp(r'\b(EUR|USD|GBP|CHF|MXN|ARS|COP|BRL|JPY|RUB)\b', caseSensitive: false);

/// Deduce el separador decimal del documento entero.
///
/// Mirar cada número por separado es un error clásico: en «1.234,56» el punto
/// es de millar y en «1,234.56» lo es la coma, y con un solo número no siempre
/// se puede saber. Con todas las líneas delante sí: gana el separador que
/// aparece más veces seguido de exactamente dos dígitos al final del número.
DecimalSeparator inferDecimalSeparator(Iterable<String> lines) {
  var commaScore = 0;
  var dotScore = 0;

  final decimalLike = RegExp('\\d[.,]\\d{2}(?![\\d])');
  final thousandLike = RegExp('\\d[.,]\\d{3}(?![\\d])');

  for (final line in lines) {
    for (final match in decimalLike.allMatches(line)) {
      if (match.group(0)![1] == ',') {
        commaScore += 2;
      } else {
        dotScore += 2;
      }
    }
    for (final match in thousandLike.allMatches(line)) {
      // Un grupo de tres dígitos apunta a millar, así que refuerza al *otro*
      // separador como decimal.
      if (match.group(0)![1] == ',') {
        dotScore += 1;
      } else {
        commaScore += 1;
      }
    }
  }

  if (dotScore > commaScore) {
    return DecimalSeparator.dot;
  }
  return DecimalSeparator.comma;
}

/// Detecta la divisa del ticket a partir de símbolos y códigos.
String? detectCurrencyCode(Iterable<String> lines) {
  final counts = <String, int>{};

  for (final line in lines) {
    for (final entry in currencySymbols.entries) {
      if (entry.key.length == 1 && line.contains(entry.key)) {
        counts.update(entry.value, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    for (final match in _currencyCodePattern.allMatches(line)) {
      final code = match.group(1)!.toUpperCase();
      counts.update(code, (value) => value + 2, ifAbsent: () => 2);
    }
  }

  if (counts.isEmpty) {
    return null;
  }

  var best = counts.entries.first;
  for (final entry in counts.entries) {
    if (entry.value > best.value) {
      best = entry;
    }
  }
  return best.key;
}

/// Extrae los importes de una línea.
///
/// [decimalSeparator] viene de [inferDecimalSeparator] sobre el documento
/// completo; sin él, «1.234» es ambiguo entre 1234 y 1,234.
List<MoneyToken> scanMoney(String line, {required DecimalSeparator decimalSeparator}) {
  final tokens = <MoneyToken>[];

  for (final match in _numberPattern.allMatches(line)) {
    final raw = match.group(0)!;
    final start = match.start;
    final end = match.end;

    final before = start > 0 ? line[start - 1] : '';
    final after = end < line.length ? line[end] : '';

    if (_isPartOfDateOrTime(line, start, end)) {
      continue;
    }
    if (after == '%' || (after == ' ' && _startsWith(line, end + 1, '%'))) {
      continue;
    }
    // Códigos de artículo y números de serie: pegados a letras por delante o
    // por detrás sin espacio de por medio.
    if (_isLetter(before) || _isLetter(after)) {
      continue;
    }

    final currencyBefore = _currencyMarkBefore(line, start);
    final currencyAfter = _currencyMarkAfter(line, end);
    final hasCurrencyMark = currencyBefore || currencyAfter;

    final negative = _isNegativeContext(line, start, end);
    final parsed = interpretNumber(raw, decimalSeparator: decimalSeparator);
    if (parsed == null) {
      continue;
    }

    final hasDecimals = RegExp('[.,]\\d{1,2}\$').hasMatch(raw);

    tokens.add(
      MoneyToken(
        value: negative ? -parsed : parsed,
        raw: raw,
        start: start,
        end: end,
        hasExplicitDecimals: hasDecimals,
        hasCurrencyMark: hasCurrencyMark,
        isNegative: negative,
      ),
    );
  }

  return tokens;
}

/// Convierte el texto de un número a `double` aplicando el separador decimal
/// deducido.
double? interpretNumber(String raw, {required DecimalSeparator decimalSeparator}) {
  final cleaned = raw.replaceAll(' ', '').replaceAll(' ', '').trim();
  if (cleaned.isEmpty) {
    return null;
  }

  final lastComma = cleaned.lastIndexOf(',');
  final lastDot = cleaned.lastIndexOf('.');

  int decimalIndex;
  if (lastComma >= 0 && lastDot >= 0) {
    // Con los dos presentes, el de más a la derecha es el decimal.
    decimalIndex = lastComma > lastDot ? lastComma : lastDot;
  } else if (lastComma >= 0 || lastDot >= 0) {
    final onlyIndex = lastComma >= 0 ? lastComma : lastDot;
    final separator = cleaned[onlyIndex];
    final decimalsCount = cleaned.length - onlyIndex - 1;
    final expected = decimalSeparator == DecimalSeparator.comma ? ',' : '.';

    if (decimalsCount == 3) {
      // Tres dígitos detrás: millar, salvo que el separador sea justo el
      // decimal del documento y no haya otro grupo (p. ej. «0,500 kg»).
      decimalIndex = separator == expected && cleaned.indexOf(separator) == onlyIndex && cleaned.length <= 5 ? onlyIndex : -1;
    } else if (decimalsCount == 1 || decimalsCount == 2) {
      decimalIndex = onlyIndex;
    } else {
      decimalIndex = -1;
    }
  } else {
    decimalIndex = -1;
  }

  final String integerPart;
  final String decimalPart;
  if (decimalIndex >= 0) {
    integerPart = cleaned.substring(0, decimalIndex).replaceAll(RegExp('[^0-9]'), '');
    decimalPart = cleaned.substring(decimalIndex + 1).replaceAll(RegExp('[^0-9]'), '');
  } else {
    integerPart = cleaned.replaceAll(RegExp('[^0-9]'), '');
    decimalPart = '';
  }

  if (integerPart.isEmpty && decimalPart.isEmpty) {
    return null;
  }

  final value = double.tryParse('${integerPart.isEmpty ? '0' : integerPart}.${decimalPart.isEmpty ? '0' : decimalPart}');
  return value;
}

bool _startsWith(String line, int index, String value) {
  return index >= 0 && index + value.length <= line.length && line.startsWith(value, index);
}

bool _isLetter(String character) {
  if (character.isEmpty) {
    return false;
  }
  final code = character.codeUnitAt(0);
  final isAscii = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  final isAccented = code >= 0xC0 && code <= 0x24F;
  return isAscii || isAccented;
}

bool _currencyMarkBefore(String line, int start) {
  var index = start - 1;
  while (index >= 0 && line[index] == ' ') {
    index--;
  }
  if (index < 0) {
    return false;
  }
  final character = line[index];
  if (currencySymbols.containsKey(character)) {
    return true;
  }
  final tail = line.substring(0, index + 1).toUpperCase();
  return tail.endsWith('EUR') || tail.endsWith('USD') || tail.endsWith('GBP');
}

bool _currencyMarkAfter(String line, int end) {
  var index = end;
  while (index < line.length && line[index] == ' ') {
    index++;
  }
  if (index >= line.length) {
    return false;
  }
  final character = line[index];
  if (currencySymbols.containsKey(character)) {
    return true;
  }
  final head = line.substring(index).toUpperCase();
  return head.startsWith('EUR') || head.startsWith('USD') || head.startsWith('GBP') || head == 'E';
}

/// Detecta el signo negativo por delante y también por detrás: muchas
/// impresoras térmicas imprimen los abonos como «3,00-».
bool _isNegativeContext(String line, int start, int end) {
  var index = start - 1;
  while (index >= 0 && line[index] == ' ') {
    index--;
  }
  if (index >= 0 && (line[index] == '-' || line[index] == '−')) {
    return true;
  }

  var tail = end;
  while (tail < line.length && line[tail] == ' ') {
    tail++;
  }
  if (tail < line.length && (line[tail] == '-' || line[tail] == '−')) {
    return true;
  }
  return false;
}

/// Un número pegado a barras, guiones de fecha o dos puntos no es dinero.
bool _isPartOfDateOrTime(String line, int start, int end) {
  final before = start > 0 ? line[start - 1] : '';
  final after = end < line.length ? line[end] : '';

  if (before == '/' || after == '/' || before == ':' || after == ':') {
    return true;
  }
  // «31-08-2026»: guion pegado por ambos lados o guion seguido de dos dígitos
  // más guion.
  if (before == '-' && after == '-') {
    return true;
  }
  if (after == '-' && RegExp(r'^-\d{2,4}[-/]').hasMatch(line.substring(end))) {
    return true;
  }
  if (before == '-' && start >= 3 && RegExp(r'\d{1,4}-$').hasMatch(line.substring(0, start))) {
    // Puede ser un abono «-12,50»; solo se descarta si por delante hay otro
    // grupo de fecha.
    final head = line.substring(0, start - 1);
    if (RegExp(r'\d{1,2}[-/]\d{1,2}$').hasMatch(head)) {
      return true;
    }
  }
  return false;
}
