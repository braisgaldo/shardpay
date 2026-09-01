/// Parser de tickets de compra.
///
/// Dart puro: entra un [OcrDocument] y sale un [ReceiptScan]. No conoce ML Kit,
/// ni Flutter, ni el modelo de dominio de ShardPay. Esa frontera es
/// deliberada — es lo que permite cubrir con pruebas la parte que de verdad
/// falla (interpretar el papel) sin cámara, sin emulador y en milisegundos.
library;

import 'dart:math' as math;

import 'money_scanner.dart';
import 'ocr_document.dart';
import 'receipt_lexicon.dart';

/// Avisos que el parser devuelve para que la interfaz los traduzca.
///
/// Son un enum y no cadenas porque la app se distribuye en trece idiomas: un
/// texto fijo aquí sería una cadena escrita a fuego imposible de localizar.
enum ReceiptWarning {
  /// No se reconoció ninguna línea de artículo.
  noItemsDetected,

  /// No se encontró una línea de total.
  totalNotFound,

  /// La suma de artículos no cuadra con el total impreso.
  itemsDoNotMatchTotal,

  /// Se añadió una línea de ajuste para que la suma cuadre con el total.
  adjustmentAdded,

  /// Se descartó una línea porque duplicaba el total.
  duplicatedTotalDropped,

  /// La imagen dio muy poco texto; probablemente esté movida o mal iluminada.
  lowTextQuality,

  /// El total impreso no cuadraba con `subtotal + impuestos` y se corrigió con
  /// la aritmética del propio ticket.
  totalCorrectedByArithmetic,
}

/// Naturaleza de una línea del resultado.
enum ReceiptItemKind {
  /// Un producto o servicio del ticket.
  product,

  /// Propina o recargo por servicio.
  tip,

  /// Ajuste sintético para cuadrar con el total impreso.
  adjustment,
}

/// Una línea del ticket ya interpretada.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    required this.amount,
    this.quantity = 1,
    this.unitPrice,
    this.confidence = 0.5,
    this.kind = ReceiptItemKind.product,
  });

  /// Nombre legible. Vacío en los ajustes: los nombra la interfaz, traducidos.
  final String name;

  /// Importe total de la línea, con la cantidad ya aplicada.
  final double amount;

  final int quantity;

  /// Precio unitario cuando el ticket lo imprimía aparte.
  final double? unitPrice;

  /// Confianza de esta línea concreta, de 0 a 1.
  final double confidence;

  final ReceiptItemKind kind;

  ReceiptLineItem copyWith({String? name, double? amount, int? quantity, double? unitPrice, double? confidence, ReceiptItemKind? kind}) {
    return ReceiptLineItem(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      confidence: confidence ?? this.confidence,
      kind: kind ?? this.kind,
    );
  }

  @override
  String toString() => '$quantity x $name = $amount';
}

/// Resultado de leer un ticket.
class ReceiptScan {
  const ReceiptScan({
    required this.items,
    required this.warnings,
    required this.confidence,
    this.merchant,
    this.date,
    this.currencyCode,
    this.subtotal,
    this.taxAmount,
    this.tipAmount,
    this.discountAmount,
    this.total,
    this.rawLines = const <String>[],
  });

  const ReceiptScan.empty()
    : items = const <ReceiptLineItem>[],
      warnings = const <ReceiptWarning>[ReceiptWarning.noItemsDetected, ReceiptWarning.lowTextQuality],
      confidence = 0,
      merchant = null,
      date = null,
      currencyCode = null,
      subtotal = null,
      taxAmount = null,
      tipAmount = null,
      discountAmount = null,
      total = null,
      rawLines = const <String>[];

  final List<ReceiptLineItem> items;
  final List<ReceiptWarning> warnings;

  /// Confianza global de 0 a 1. La interfaz la usa para decidir si presenta el
  /// resultado como listo o como borrador que hay que revisar.
  final double confidence;

  final String? merchant;
  final DateTime? date;
  final String? currencyCode;
  final double? subtotal;
  final double? taxAmount;
  final double? tipAmount;
  final double? discountAmount;
  final double? total;

  /// Texto crudo por líneas. Solo para depuración y para el informe de errores.
  final List<String> rawLines;

  bool get isEmpty => items.isEmpty;

  double get itemsTotal => roundMoney(items.fold<double>(0, (sum, item) => sum + item.amount));

  /// `true` cuando la suma de las líneas coincide con el total impreso.
  bool get reconciled => total != null && (itemsTotal - total!).abs() <= 0.02;
}

/// Redondeo monetario a dos decimales.
///
/// Sustituye al `double.parse(x.toStringAsFixed(2))` que había repartido por
/// todo el proyecto: aquello construía y parseaba una cadena en cada operación,
/// dentro de bucles que se ejecutan miles de veces por pantalla.
double roundMoney(double value) => (value * 100).roundToDouble() / 100;

/// Parser de tickets.
class ReceiptParser {
  const ReceiptParser({this.maxItems = 150, this.reconciliationTolerance = 0.02});

  /// Tope de líneas devueltas. Un ticket de supermercado largo puede tener
  /// ochenta; por encima de esto casi siempre es ruido del OCR.
  final int maxItems;

  /// Margen en unidades de divisa dentro del cual se considera que la suma
  /// cuadra con el total.
  final double reconciliationTolerance;

  static final RegExp _quantityPrefix = RegExp(r'^\s*(\d{1,3})\s*(?:[xX×*]|uds?|unid(?:ades)?)?\s+');
  static final RegExp _quantityTimes = RegExp(r'^\s*(\d{1,3})\s*[xX×*]\s*');
  static final RegExp _quantitySuffix = RegExp(r'\s+[xX×*]\s*(\d{1,3})\s*$');
  static final RegExp _datePattern = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})');
  static final RegExp _isoDatePattern = RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})');
  static final RegExp _letters = RegExp('[A-Za-zÀ-ÿ]');
  static final RegExp _leftoverSymbols = RegExp(r'[^A-Za-zÀ-ÿ0-9%&/\+\-\.,\s]');
  static final RegExp _collapseSpaces = RegExp(r'\s{2,}');

  ReceiptScan parse(OcrDocument document) {
    if (document.isEmpty) {
      return const ReceiptScan.empty();
    }

    final rawLines = document.rows.map((row) => row.text).toList(growable: false);
    final decimalSeparator = inferDecimalSeparator(rawLines);
    final currencyCode = detectCurrencyCode(rawLines);

    final rows = <_ParsedRow>[];
    for (var index = 0; index < document.rows.length; index++) {
      rows.add(_ParsedRow.from(document.rows[index], index, decimalSeparator));
    }

    final amountColumn = _detectAmountColumn(rows, document);
    for (final row in rows) {
      row.markAmountColumn(amountColumn);
    }

    final summary = _readSummary(rows);
    final items = _readItems(rows, summary, document);
    final merchant = _detectMerchant(rows, document);
    final date = _detectDate(rawLines);

    final warnings = <ReceiptWarning>[];

    // Antes de cuadrar las lineas contra el total, comprobar que el total es
    // creible: el propio ticket trae la aritmetica para verificarlo.
    final verificado = _crossCheckSummary(summary, items, warnings);
    final reconciled = _reconcile(items, verificado, warnings);

    if (rows.length < 4) {
      warnings.add(ReceiptWarning.lowTextQuality);
    }
    if (verificado.total == null) {
      warnings.add(ReceiptWarning.totalNotFound);
    }
    if (reconciled.isEmpty) {
      warnings.add(ReceiptWarning.noItemsDetected);
    }

    final trimmed = reconciled.length > maxItems ? reconciled.sublist(0, maxItems) : reconciled;

    return ReceiptScan(
      items: List<ReceiptLineItem>.unmodifiable(trimmed),
      warnings: List<ReceiptWarning>.unmodifiable(warnings),
      confidence: _scoreConfidence(trimmed, verificado, amountColumn, warnings),
      merchant: merchant,
      date: date,
      currencyCode: currencyCode,
      subtotal: verificado.subtotal,
      taxAmount: verificado.tax,
      tipAmount: verificado.tip,
      discountAmount: verificado.discount,
      total: verificado.total,
      rawLines: rawLines,
    );
  }

  // ---------------------------------------------------------------------------
  // Cruce aritmetico del bloque de totales
  // ---------------------------------------------------------------------------

  /// Corrige el total leido usando la aritmetica que el propio ticket imprime.
  ///
  /// Un ticket trae la comprobacion dentro: `subtotal + impuestos + propina −
  /// descuento = total`. Son cuatro numeros que dicen lo mismo de dos maneras,
  /// y el reconocimiento de texto falla en **uno** cada vez, no en todos a la
  /// vez. Si tres cuadran entre si y el cuarto no, el raro es el cuarto.
  ///
  /// Encontrado probando con un ticket generado: `TOTAL 52,36` se leyo como
  /// `52,00`. Las lineas sumaban 47,60 y el subtotal impreso decia 47,60 —dos
  /// lecturas independientes de acuerdo—, y el IVA impreso decia 4,76. O sea que
  /// 47,60 + 4,76 = 52,36 y el unico numero fuera de sitio era el total. Sin
  /// esto, el cuadre posterior hacia su trabajo pero contra un total equivocado:
  /// añadia una linea de ajuste de 36 centimos que no existia.
  ///
  /// Es deliberadamente conservador. Solo corrige cuando **las lineas de
  /// articulos y el subtotal impreso coinciden entre si**, que es la señal de
  /// que esos dos se leyeron bien. Si no hay subtotal, o si no cuadra con las
  /// lineas, no se toca nada: mejor un total dudoso que un total inventado.
  ///
  /// Todo esto ocurre en el dispositivo. No hay ninguna llamada a ningun sitio.
  _Summary _crossCheckSummary(_Summary summary, List<ReceiptLineItem> items, List<ReceiptWarning> warnings) {
    final subtotal = summary.subtotal;
    final total = summary.total;
    if (subtotal == null || total == null || items.isEmpty) {
      return summary;
    }

    // Primer testigo: las lineas de articulos.
    final itemsTotal = roundMoney(items.fold<double>(0, (suma, item) => suma + item.amount));

    // Segundo testigo: el subtotal impreso. Si no coincide con las lineas, uno
    // de los dos esta mal y no hay base para corregir nada.
    if ((itemsTotal - subtotal).abs() > reconciliationTolerance) {
      return summary;
    }

    final esperado = roundMoney(subtotal + (summary.tax ?? 0) + (summary.tip ?? 0) - (summary.discount ?? 0));
    final desviacion = (esperado - total).abs();

    if (desviacion <= reconciliationTolerance) {
      return summary;
    }

    // Un salto grande no es un digito mal leido: es que se ha identificado mal
    // alguna linea del bloque. En ese caso no se corrige, se avisa y ya.
    if (desviacion > math.max(1.0, esperado * 0.10)) {
      return summary;
    }

    warnings.add(ReceiptWarning.totalCorrectedByArithmetic);
    return _Summary(
      startIndex: summary.startIndex,
      total: esperado,
      subtotal: summary.subtotal,
      tax: summary.tax,
      tip: summary.tip,
      discount: summary.discount,
    );
  }

  // ---------------------------------------------------------------------------
  // Columna de importes
  // ---------------------------------------------------------------------------

  /// Localiza la columna donde el ticket alinea los precios.
  ///
  /// Es la señal más fiable que existe en un ticket: los importes se imprimen
  /// alineados a la derecha en una columna, y cualquier número que caiga ahí es
  /// casi seguro un precio, mientras que los de en medio de la línea suelen ser
  /// gramajes, códigos o precios unitarios.
  _AmountColumn _detectAmountColumn(List<_ParsedRow> rows, OcrDocument document) {
    final rightEdges = <double>[];

    for (final row in rows) {
      if (row.tokens.isEmpty) {
        continue;
      }
      final last = row.tokens.last;
      final box = last.box;
      if (box == null) {
        continue;
      }
      // Solo cuentan los números que terminan la línea: son los candidatos a
      // estar en la columna de precios.
      if (last.end >= row.text.length - 3) {
        rightEdges.add(box.right);
      }
    }

    if (rightEdges.length < 3) {
      return const _AmountColumn.unknown();
    }

    rightEdges.sort();
    final median = rightEdges[rightEdges.length ~/ 2];
    final tolerance = math.max(document.contentWidth * 0.09, document.medianLineHeight * 2.5);

    var inside = 0;
    for (final edge in rightEdges) {
      if ((edge - median).abs() <= tolerance) {
        inside++;
      }
    }

    // Si los bordes están dispersos no hay columna: el ticket no está alineado
    // o la foto tiene demasiada perspectiva.
    if (inside < rightEdges.length * 0.6) {
      return const _AmountColumn.unknown();
    }

    return _AmountColumn(right: median, tolerance: tolerance);
  }

  // ---------------------------------------------------------------------------
  // Bloque de totales
  // ---------------------------------------------------------------------------

  /// Lee total, subtotal, impuestos, propina y descuentos.
  ///
  /// Recorre de abajo arriba porque el bloque de totales está siempre al final;
  /// la implementación anterior cortaba en la *primera* aparición de «total»,
  /// que en muchos tickets es la cabecera «TOTAL COMPRA» del encabezado, y se
  /// comía el ticket entero.
  _Summary _readSummary(List<_ParsedRow> rows) {
    double? total;
    double? subtotal;
    double? tax;
    double? tip;
    double? discount;
    var summaryStartIndex = rows.length;

    // El bloque de totales vive siempre en la parte baja del ticket. Limitar la
    // búsqueda evita la trampa clásica: una cabecera «TOTAL COMPRA» o un pie
    // «GRACIAS POR SU VISITA» que cortaban el ticket por donde no era.
    final earliestSummaryIndex = (rows.length * 0.4).floor();

    for (var index = rows.length - 1; index >= earliestSummaryIndex; index--) {
      final row = rows[index];
      final kind = row.kind;
      final amount = row.bestSummaryAmount();

      if (kind == ReceiptLineKind.total) {
        if (amount != null && total == null) {
          total = amount;
        }
        summaryStartIndex = math.min(summaryStartIndex, index);
      } else if (kind == ReceiptLineKind.subtotal) {
        if (amount != null && subtotal == null) {
          subtotal = amount;
        }
        summaryStartIndex = math.min(summaryStartIndex, index);
      } else if (kind == ReceiptLineKind.tax) {
        if (amount != null && tax == null) {
          tax = amount;
        }
        summaryStartIndex = math.min(summaryStartIndex, index);
      } else if (kind == ReceiptLineKind.tip) {
        if (amount != null && tip == null) {
          tip = amount;
        }
        summaryStartIndex = math.min(summaryStartIndex, index);
      } else if (kind == ReceiptLineKind.discount) {
        if (amount != null && discount == null) {
          discount = amount.abs();
        }
        // Un descuento no cierra el bloque de artículos: en muchos tickets
        // aparece intercalado justo debajo del producto al que se aplica.
      } else if (kind == ReceiptLineKind.payment || kind == ReceiptLineKind.farewell) {
        summaryStartIndex = math.min(summaryStartIndex, index);
      }
    }

    return _Summary(total: total, subtotal: subtotal, tax: tax, tip: tip, discount: discount, startIndex: summaryStartIndex);
  }

  // ---------------------------------------------------------------------------
  // Artículos
  // ---------------------------------------------------------------------------

  List<ReceiptLineItem> _readItems(List<_ParsedRow> rows, _Summary summary, OcrDocument document) {
    final items = <ReceiptLineItem>[];
    final consumed = <int>{};
    final limit = math.min(summary.startIndex, rows.length);

    for (var index = 0; index < limit; index++) {
      if (consumed.contains(index)) {
        continue;
      }
      final row = rows[index];
      if (!row.couldBeItem) {
        continue;
      }

      final priceTokens = row.priceTokens();

      if (priceTokens.isEmpty) {
        // Nombre sin precio: en tickets a dos columnas el importe cae en la
        // fila de al lado. Se busca solo entre vecinas inmediatas, no en todo
        // el documento como hacía la versión anterior (que era cuadrática).
        final partner = _findAmountOnlyNeighbour(rows, index, limit, consumed, document);
        if (partner == null) {
          continue;
        }
        final partnerPrices = partner.row.priceTokens();
        if (partnerPrices.isEmpty) {
          continue;
        }
        final amount = partnerPrices.last.value;
        final name = _cleanName(row.text, const <MoneyToken>[]);
        if (name == null || amount <= 0) {
          continue;
        }
        consumed.add(partner.index);
        items.add(ReceiptLineItem(name: name, amount: roundMoney(amount), confidence: 0.55));
        continue;
      }

      final parsed = _parseItemRow(row, priceTokens);
      if (parsed != null) {
        items.add(parsed);
      }
    }

    return items;
  }

  ReceiptLineItem? _parseItemRow(_ParsedRow row, List<MoneyToken> priceTokens) {
    var quantity = _extractQuantity(row.text);
    final lineTotalToken = row.amountColumnToken() ?? priceTokens.last;
    var amount = lineTotalToken.value;

    double? unitPrice;

    // Tickets con «cantidad · precio unidad · importe»: si el penúltimo número
    // multiplicado por la cantidad da el último, el ticket está confirmando su
    // propia aritmética y se puede confiar en la lectura.
    if (priceTokens.length >= 2) {
      final candidateUnit = priceTokens[priceTokens.length - 2];
      if (quantity > 1 && (candidateUnit.value * quantity - amount).abs() <= 0.02) {
        unitPrice = candidateUnit.value;
      } else if (quantity <= 1 && candidateUnit.value > 0) {
        final ratio = amount / candidateUnit.value;
        final rounded = ratio.round();
        if (rounded >= 2 && rounded <= 30 && (candidateUnit.value * rounded - amount).abs() <= 0.02) {
          quantity = rounded;
          unitPrice = candidateUnit.value;
        }
      }
    }

    // Solo precio unitario y cantidad, sin importe de línea impreso.
    if (unitPrice == null && quantity > 1 && priceTokens.length == 1 && row.amountColumnToken() == null) {
      unitPrice = amount;
      amount = roundMoney(amount * quantity);
    }

    // Los importes negativos solo valen en líneas de descuento o cuando el
    // ticket imprime explícitamente el signo: son abonos y tienen que restar
    // del reparto, no desaparecer.
    final allowsNegative = row.kind == ReceiptLineKind.discount || lineTotalToken.isNegative;
    if (amount == 0 || (amount < 0 && !allowsNegative)) {
      return null;
    }

    final name = _cleanName(row.text, priceTokens);
    if (name == null) {
      return null;
    }

    var confidence = 0.5;
    if (row.amountColumnToken() != null) {
      confidence += 0.25;
    }
    if (lineTotalToken.hasExplicitDecimals) {
      confidence += 0.15;
    }
    if (lineTotalToken.hasCurrencyMark) {
      confidence += 0.05;
    }
    if (unitPrice != null) {
      confidence += 0.05;
    }

    return ReceiptLineItem(
      name: name,
      amount: roundMoney(amount),
      quantity: quantity,
      unitPrice: unitPrice == null ? null : roundMoney(unitPrice),
      confidence: confidence > 1 ? 1 : confidence,
    );
  }

  /// Busca una fila contigua que sea solo un importe.
  _NeighbourRow? _findAmountOnlyNeighbour(List<_ParsedRow> rows, int index, int limit, Set<int> consumed, OcrDocument document) {
    final reach = document.medianLineHeight * 1.8;

    for (final candidateIndex in <int>[index + 1, index - 1]) {
      if (candidateIndex < 0 || candidateIndex >= limit || consumed.contains(candidateIndex)) {
        continue;
      }
      final candidate = rows[candidateIndex];
      if (!candidate.isAmountOnly) {
        continue;
      }
      if ((candidate.row.centerY - rows[index].row.centerY).abs() > reach) {
        continue;
      }
      return _NeighbourRow(candidate, candidateIndex);
    }
    return null;
  }

  int _extractQuantity(String text) {
    final times = _quantityTimes.firstMatch(text);
    if (times != null) {
      return int.tryParse(times.group(1)!) ?? 1;
    }
    final suffix = _quantitySuffix.firstMatch(text);
    if (suffix != null) {
      return int.tryParse(suffix.group(1)!) ?? 1;
    }
    final prefix = _quantityPrefix.firstMatch(text);
    if (prefix != null) {
      final value = int.tryParse(prefix.group(1)!) ?? 1;
      // Un «2» delante de un nombre es cantidad; un «2024» es un año.
      return value >= 1 && value <= 99 ? value : 1;
    }
    return 1;
  }

  /// Deja el nombre del artículo limpio de precios, cantidades y unidades.
  String? _cleanName(String text, List<MoneyToken> tokens) {
    final buffer = StringBuffer();
    var cursor = 0;
    final ordered = [...tokens]..sort((a, b) => a.start.compareTo(b.start));

    for (final token in ordered) {
      if (token.start < cursor) {
        continue;
      }
      buffer.write(text.substring(cursor, token.start));
      buffer.write(' ');
      cursor = token.end;
    }
    if (cursor < text.length) {
      buffer.write(text.substring(cursor));
    }

    var name = buffer.toString();
    name = name.replaceFirst(_quantityTimes, ' ');
    name = name.replaceFirst(_quantitySuffix, ' ');
    name = name.replaceFirst(_quantityPrefix, ' ');
    name = name.replaceAll(_leftoverSymbols, ' ');
    name = name.replaceAll(_collapseSpaces, ' ').trim();

    // Quita unidades sueltas que quedan al final tras retirar el número.
    final words = name.split(' ').where((word) => word.isNotEmpty).toList();
    while (words.isNotEmpty && ReceiptLexicon.unit.hasMatch(normalizeForMatching(words.last))) {
      words.removeLast();
    }
    while (words.isNotEmpty && ReceiptLexicon.unit.hasMatch(normalizeForMatching(words.first))) {
      words.removeAt(0);
    }

    name = words.join(' ').trim();
    if (name.length < 2) {
      return null;
    }
    if (_letters.allMatches(name).length < 2) {
      return null;
    }

    return _titleCase(name);
  }

  String _titleCase(String value) {
    // Los tickets se imprimen en mayúsculas y dentro de la app quedan a
    // gritos. Se pasa a capitalización de título con dos excepciones: las
    // palabras que llevan dígitos («1L», «500ML») se dejan como están, y en un
    // texto que ya mezcla mayúsculas y minúsculas una palabra corta en
    // mayúsculas suele ser una sigla o una marca.
    final isAllCaps = value == value.toUpperCase();

    return value
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }
          if (RegExp(r'\d').hasMatch(word)) {
            return word;
          }
          if (!isAllCaps && word.length <= 3 && word == word.toUpperCase() && _letters.hasMatch(word)) {
            return word;
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Cuadre
  // ---------------------------------------------------------------------------

  /// Cuadra las líneas leídas con el total impreso.
  ///
  /// Es la mejora que más se nota en una app de repartir gastos: da igual que
  /// el OCR se deje un producto si el reparto acaba sumando lo que de verdad se
  /// pagó. Sin esto, el grupo reparte una cifra que no es la del ticket.
  List<ReceiptLineItem> _reconcile(List<ReceiptLineItem> items, _Summary summary, List<ReceiptWarning> warnings) {
    final total = summary.total;
    var result = [...items];

    if (total == null || total <= 0) {
      return result;
    }

    if (result.isEmpty) {
      // No se reconoció ni un artículo, pero sí el total: mejor una línea única
      // por el importe pagado que un ticket vacío. El aviso deja claro que hay
      // que revisarlo.
      warnings.add(ReceiptWarning.noItemsDetected);
      return <ReceiptLineItem>[ReceiptLineItem(name: '', amount: roundMoney(total), confidence: 0.4, kind: ReceiptItemKind.adjustment)];
    }

    var sum = roundMoney(result.fold<double>(0, (value, item) => value + item.amount));
    var delta = roundMoney(total - sum);

    // Caso más común de sobrecuenta: una línea de subtotal o de total se coló
    // entre los artículos. Si al quitarla cuadra, era eso.
    if (delta < -reconciliationTolerance) {
      final culprit = result.indexWhere((item) => (item.amount + delta).abs() <= reconciliationTolerance);
      if (culprit >= 0) {
        result.removeAt(culprit);
        warnings.add(ReceiptWarning.duplicatedTotalDropped);
        sum = roundMoney(result.fold<double>(0, (value, item) => value + item.amount));
        delta = roundMoney(total - sum);
      }
    }

    if (delta.abs() <= reconciliationTolerance) {
      return result;
    }

    if (delta > 0) {
      final tip = summary.tip;
      if (tip != null && (delta - tip).abs() <= reconciliationTolerance) {
        result.add(ReceiptLineItem(name: '', amount: roundMoney(tip), confidence: 0.8, kind: ReceiptItemKind.tip));
        return result;
      }
      result.add(ReceiptLineItem(name: '', amount: delta, confidence: 0.3, kind: ReceiptItemKind.adjustment));
      warnings.add(ReceiptWarning.adjustmentAdded);
      return result;
    }

    warnings.add(ReceiptWarning.itemsDoNotMatchTotal);
    return result;
  }

  // ---------------------------------------------------------------------------
  // Metadatos
  // ---------------------------------------------------------------------------

  /// Busca el nombre del comercio.
  ///
  /// Aprovecha la geometría: en casi todos los tickets el rótulo es la línea
  /// con la letra más grande de la cabecera.
  String? _detectMerchant(List<_ParsedRow> rows, OcrDocument document) {
    if (rows.isEmpty) {
      return null;
    }

    final headerLimit = math.min(rows.length, math.max(3, (rows.length * 0.3).round()));
    _ParsedRow? best;
    var bestHeight = 0.0;

    for (var index = 0; index < headerLimit; index++) {
      final row = rows[index];
      if (row.tokens.isNotEmpty) {
        continue;
      }
      if (row.kind != ReceiptLineKind.unknown) {
        continue;
      }
      final text = row.text.trim();
      if (text.length < 3 || text.length > 42) {
        continue;
      }
      final letterCount = _letters.allMatches(text).length;
      if (letterCount < text.length * 0.6) {
        continue;
      }
      if (row.row.height > bestHeight) {
        bestHeight = row.row.height;
        best = row;
      }
    }

    if (best == null) {
      return null;
    }
    return _titleCase(best.text.replaceAll(_leftoverSymbols, ' ').replaceAll(_collapseSpaces, ' ').trim());
  }

  DateTime? _detectDate(List<String> lines) {
    for (final line in lines) {
      final iso = _isoDatePattern.firstMatch(line);
      if (iso != null) {
        final parsed = _buildDate(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
        if (parsed != null) {
          return parsed;
        }
      }

      final match = _datePattern.firstMatch(line);
      if (match != null) {
        var year = int.parse(match.group(3)!);
        if (year < 100) {
          year += 2000;
        }
        final parsed = _buildDate(year, int.parse(match.group(2)!), int.parse(match.group(1)!));
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  DateTime? _buildDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 2000 || year > 2100) {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  double _scoreConfidence(List<ReceiptLineItem> items, _Summary summary, _AmountColumn column, List<ReceiptWarning> warnings) {
    if (items.isEmpty) {
      return 0;
    }

    var score = 0.30;

    final sum = roundMoney(items.fold<double>(0, (value, item) => value + item.amount));
    if (summary.total != null && (sum - summary.total!).abs() <= reconciliationTolerance) {
      score += 0.35;
    }
    if (column.isKnown) {
      score += 0.15;
    }
    if (items.length >= 3) {
      score += 0.10;
    }

    final averageItemConfidence = items.fold<double>(0, (value, item) => value + item.confidence) / items.length;
    score += averageItemConfidence * 0.10;

    if (warnings.contains(ReceiptWarning.adjustmentAdded)) {
      score -= 0.15;
    }
    if (warnings.contains(ReceiptWarning.itemsDoNotMatchTotal)) {
      score -= 0.20;
    }
    if (warnings.contains(ReceiptWarning.lowTextQuality)) {
      score -= 0.10;
    }

    if (score < 0) {
      return 0;
    }
    if (score > 1) {
      return 1;
    }
    return score;
  }
}

// -----------------------------------------------------------------------------
// Tipos internos
// -----------------------------------------------------------------------------

class _AmountColumn {
  const _AmountColumn({required this.right, required this.tolerance});

  const _AmountColumn.unknown() : right = null, tolerance = 0;

  final double? right;
  final double tolerance;

  bool get isKnown => right != null;

  bool contains(TextBox? box) {
    if (box == null || right == null) {
      return false;
    }
    return (box.right - right!).abs() <= tolerance;
  }
}

class _Summary {
  const _Summary({required this.startIndex, this.total, this.subtotal, this.tax, this.tip, this.discount});

  final int startIndex;
  final double? total;
  final double? subtotal;
  final double? tax;
  final double? tip;
  final double? discount;
}

class _NeighbourRow {
  const _NeighbourRow(this.row, this.index);

  final _ParsedRow row;
  final int index;
}

/// Fila del ticket ya normalizada, clasificada y con sus importes localizados.
class _ParsedRow {
  _ParsedRow._({
    required this.row,
    required this.index,
    required this.text,
    required this.normalized,
    required this.kind,
    required this.tokens,
  });

  final OcrRow row;
  final int index;

  /// Texto de la fila con espaciado normalizado. Los desplazamientos de los
  /// tokens se refieren a esta cadena.
  final String text;

  final String normalized;
  final ReceiptLineKind kind;
  final List<MoneyToken> tokens;

  _AmountColumn _column = const _AmountColumn.unknown();

  /// Construye la fila resolviendo, de paso, a qué fragmento pertenece cada
  /// número. Esa correspondencia es lo que después permite saber si un importe
  /// cae o no en la columna de precios.
  factory _ParsedRow.from(OcrRow row, int index, DecimalSeparator decimalSeparator) {
    final buffer = StringBuffer();
    final spans = <_FragmentSpan>[];

    for (final fragment in row.fragments) {
      final piece = fragment.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (piece.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      final start = buffer.length;
      buffer.write(piece);
      spans.add(_FragmentSpan(start: start, end: buffer.length, box: fragment.box));
    }

    final text = buffer.toString();
    final tokens = scanMoney(
      text,
      decimalSeparator: decimalSeparator,
    ).map((token) => token.copyWith(box: _boxForRange(spans, token.start, token.end))).toList(growable: false);

    final normalized = normalizeForMatching(text);

    return _ParsedRow._(
      row: row,
      index: index,
      text: text,
      normalized: normalized,
      kind: ReceiptLexicon.classify(normalized),
      tokens: tokens,
    );
  }

  void markAmountColumn(_AmountColumn column) {
    _column = column;
  }

  /// `true` si la fila puede contener un artículo comprado.
  ///
  /// Los descuentos entran a propósito: llevan importe negativo, restan del
  /// reparto y el grupo tiene que verlos.
  bool get couldBeItem {
    return kind == ReceiptLineKind.unknown || kind == ReceiptLineKind.item || kind == ReceiptLineKind.discount;
  }

  /// La fila es solo un importe, sin nombre.
  bool get isAmountOnly {
    if (tokens.isEmpty) {
      return false;
    }
    final withoutNumbers = text.replaceAll(RegExp(r'[\d.,\s€\$£¥\-]'), '');
    return withoutNumbers.length <= 1;
  }

  /// Números de la fila que parecen precios de verdad.
  List<MoneyToken> priceTokens() {
    final candidates = tokens
        .where((token) {
          if (token.value == 0) {
            return false;
          }
          if (token.hasExplicitDecimals || token.hasCurrencyMark) {
            return true;
          }
          return _column.contains(token.box);
        })
        .toList(growable: false);

    return candidates;
  }

  /// El importe alineado en la columna de precios, si lo hay.
  MoneyToken? amountColumnToken() {
    if (!_column.isKnown) {
      return null;
    }
    for (var i = tokens.length - 1; i >= 0; i--) {
      if (_column.contains(tokens[i].box)) {
        return tokens[i];
      }
    }
    return null;
  }

  /// Importe representativo de una línea de totales.
  ///
  /// Se queda con el mayor: en «IVA 21% 4,20» el 21 es el tipo y 4,20 la cuota.
  double? bestSummaryAmount() {
    double? best;
    for (final token in tokens) {
      if (!token.hasExplicitDecimals && !token.hasCurrencyMark && !_column.contains(token.box)) {
        continue;
      }
      final value = token.value;
      if (best == null || value.abs() > best.abs()) {
        best = value;
      }
    }
    return best;
  }
}

class _FragmentSpan {
  const _FragmentSpan({required this.start, required this.end, required this.box});

  final int start;
  final int end;
  final TextBox box;
}

TextBox? _boxForRange(List<_FragmentSpan> spans, int start, int end) {
  TextBox? merged;
  for (final span in spans) {
    if (span.end <= start || span.start >= end) {
      continue;
    }
    merged = merged == null ? span.box : merged.mergedWith(span.box);
  }
  return merged;
}
