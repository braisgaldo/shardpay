/// Vocabulario multiidioma para clasificar las líneas de un ticket.
///
/// Dart puro: sin dependencias de Flutter ni de plugins, para que el parser sea
/// testeable sin dispositivo.
///
/// La versión anterior comparaba con `linea.contains('ud')`, y eso descartaba
/// productos legítimos: «Gouda», «Budín» o «Ciudad Real» contienen «ud» como
/// subcadena. Aquí todo se compara con límites de palabra sobre el texto ya
/// normalizado, así que solo cuenta la palabra completa.
library;

/// Quita acentos y signos diacríticos y pasa a minúsculas.
///
/// Sirve para dos cosas a la vez: comparar «Fecha» con «FECHA» y absorber los
/// fallos típicos del OCR con tildes en tickets impresos en térmica.
String normalizeForMatching(String value) {
  final lowered = value.toLowerCase();
  final buffer = StringBuffer();

  for (final rune in lowered.runes) {
    final replacement = _diacriticFolding[rune];
    if (replacement != null) {
      buffer.write(replacement);
    } else {
      buffer.writeCharCode(rune);
    }
  }

  return buffer.toString();
}

const Map<int, String> _diacriticFolding = <int, String>{
  0xE0: 'a',
  0xE1: 'a',
  0xE2: 'a',
  0xE3: 'a',
  0xE4: 'a',
  0xE5: 'a',
  0xE8: 'e',
  0xE9: 'e',
  0xEA: 'e',
  0xEB: 'e',
  0xEC: 'i',
  0xED: 'i',
  0xEE: 'i',
  0xEF: 'i',
  0xF2: 'o',
  0xF3: 'o',
  0xF4: 'o',
  0xF5: 'o',
  0xF6: 'o',
  0xF8: 'o',
  0xF9: 'u',
  0xFA: 'u',
  0xFB: 'u',
  0xFC: 'u',
  0xE7: 'c',
  0xF1: 'n',
  0xFD: 'y',
  0xFF: 'y',
  0xDF: 'ss',
  0xE6: 'ae',
  0x153: 'oe',
};

/// Construye una expresión regular que exige palabra completa.
RegExp _wordsRegExp(Iterable<String> words) {
  final escaped = words.map(RegExp.escape).join('|');
  return RegExp('(?<![a-z0-9])(?:$escaped)(?![a-z0-9])');
}

/// Etiquetas de total final. Ordenadas de más específica a más genérica: el
/// parser prefiere «total a pagar» sobre «total» cuando ambas aparecen.
const List<String> totalWords = <String>[
  'total a pagar',
  'total a abonar',
  'importe total',
  'total importe',
  'total factura',
  'total ticket',
  'total compra',
  'total venta',
  'a pagar',
  'total',
  'suma total',
  'gesamtbetrag',
  'gesamt',
  'summe',
  'totale',
  'totaal',
  'montant total',
  'net a payer',
  'net a paye',
  'grand total',
  'amount due',
  'balance due',
  'to pay',
  'total a pagamento',
  'total geral',
  'sumo total',
];

/// Etiquetas de subtotal o base imponible: son sumas parciales, no artículos.
const List<String> subtotalWords = <String>[
  'subtotal',
  'sub total',
  'base imponible',
  'imponible',
  'zwischensumme',
  'netto',
  'sous total',
  'sous-total',
  'imponibile',
  'suma',
  'subtotaal',
];

/// Impuestos.
const List<String> taxWords = <String>[
  'iva',
  'i v a',
  'igic',
  'ipsi',
  'vat',
  'tva',
  'mwst',
  'ust',
  'tax',
  'impuesto',
  'impuestos',
  'cuota iva',
  'tipo iva',
  'iva incluido',
  'iva no incluido',
  'imposta',
  'taxa',
];

/// Propinas y recargos voluntarios.
const List<String> tipWords = <String>[
  'propina',
  'propinas',
  'tip',
  'tips',
  'gratuity',
  'service charge',
  'trinkgeld',
  'pourboire',
  'mancia',
  'servizio',
  'servicio incluido',
];

/// Descuentos: la línea existe, pero su importe resta.
const List<String> discountWords = <String>[
  'descuento',
  'descuentos',
  'dto',
  'dcto',
  'promocion',
  'promo',
  'oferta',
  'rebaja',
  'discount',
  'rabatt',
  'remise',
  'sconto',
  'cupon',
  'vale descuento',
  'ahorro',
];

/// Medios de pago, cambio y demás pie del ticket.
const List<String> paymentWords = <String>[
  'efectivo',
  'metalico',
  'contado',
  'tarjeta',
  'visa',
  'mastercard',
  'maestro',
  'amex',
  'american express',
  'bizum',
  'paypal',
  'apple pay',
  'google pay',
  'contactless',
  'datafono',
  'tpv',
  'cash',
  'card',
  'credit card',
  'debit card',
  'barzahlung',
  'karte',
  'espece',
  'especes',
  'carte',
  'contante',
  'carta',
  'entregado',
  'recibido',
  'cambio',
  'vuelto',
  'devolucion',
  'change',
  'wechselgeld',
  'monnaie',
  'resto',
  'saldo',
  'importe entregado',
  'su pago',
  'pago',
];

/// Identificadores fiscales y metadatos administrativos.
const List<String> administrativeWords = <String>[
  'nif',
  'cif',
  'nie',
  'dni',
  'vat id',
  'ust id',
  'siret',
  'siren',
  'partita iva',
  'p iva',
  'tel',
  'telf',
  'telefono',
  'phone',
  'fax',
  'email',
  'web',
  'www',
  'factura',
  'facturas',
  'ticket',
  'tiquet',
  'recibo',
  'receipt',
  'rechnung',
  'quittung',
  'facture',
  'scontrino',
  'documento',
  'simplificada',
  'simplificado',
  'copia',
  'original',
  'caja',
  'cajero',
  'cajera',
  'camarero',
  'camarera',
  'operador',
  'atendido por',
  'le atendio',
  'mesa',
  'comensales',
  'pax',
  'turno',
  'fecha',
  'hora',
  'date',
  'time',
  'datum',
  'uhrzeit',
  'heure',
  'data',
  'ora',
  'num',
  'numero',
  'ref',
  'referencia',
  'autorizacion',
  'aut',
  'terminal',
  'comercio',
  'establecimiento',
  'sucursal',
  'tienda',
  'store',
  'cp',
  'codigo postal',
];

/// Cortesías del pie: nunca son artículos.
const List<String> farewellWords = <String>[
  'gracias por su visita',
  'gracias por su compra',
  'gracias',
  'vuelva pronto',
  'hasta pronto',
  'buen provecho',
  'que aproveche',
  'thank you',
  'thanks',
  'goodbye',
  'see you',
  'danke',
  'vielen dank',
  'merci',
  'au revoir',
  'grazie',
  'arrivederci',
  'obrigado',
  'obrigada',
  'conserve este ticket',
  'guarde este ticket',
  'iva incluido',
  'no se admiten devoluciones',
  'plazo de devolucion',
];

/// Cabeceras de columna en tickets con rejilla.
const List<String> columnHeaderWords = <String>[
  'descripcion',
  'description',
  'concepto',
  'articulo',
  'articulos',
  'producto',
  'productos',
  'cantidad',
  'cant',
  'uds',
  'unidades',
  'precio',
  'p unit',
  'precio unidad',
  'importe',
  'qty',
  'quantity',
  'price',
  'unit price',
  'amount',
  'menge',
  'preis',
  'betrag',
  'quantite',
  'prix',
  'montant',
  'quantita',
  'prezzo',
  'importo',
];

/// Unidades de medida que acompañan a un artículo sin ser su nombre.
const List<String> unitWords = <String>[
  'kg',
  'gr',
  'grs',
  'g',
  'ml',
  'cl',
  'lt',
  'l',
  'ud',
  'uds',
  'un',
  'unid',
  'pack',
  'bot',
  'pza',
  'pzas',
  'x',
];

/// Clasificación de una línea del ticket.
enum ReceiptLineKind {
  /// Aún sin clasificar.
  unknown,

  /// Candidata a artículo comprado.
  item,

  /// Suma parcial (subtotal, base imponible).
  subtotal,

  /// Total final.
  total,

  /// Impuesto.
  tax,

  /// Propina o recargo por servicio.
  tip,

  /// Descuento (resta).
  discount,

  /// Medio de pago, cambio o entregado.
  payment,

  /// Metadato administrativo (NIF, fecha, mesa, cabecera de columna…).
  administrative,

  /// Cortesía del pie.
  farewell,
}

/// Diccionario compilado una sola vez.
///
/// Las expresiones regulares son estáticas y se reutilizan en cada ticket:
/// compilarlas por línea era una de las fuentes de lentitud del parser
/// anterior.
class ReceiptLexicon {
  ReceiptLexicon._();

  static final RegExp total = _wordsRegExp(totalWords);
  static final RegExp subtotal = _wordsRegExp(subtotalWords);
  static final RegExp tax = _wordsRegExp(taxWords);
  static final RegExp tip = _wordsRegExp(tipWords);
  static final RegExp discount = _wordsRegExp(discountWords);
  static final RegExp payment = _wordsRegExp(paymentWords);
  static final RegExp administrative = _wordsRegExp(administrativeWords);
  static final RegExp farewell = _wordsRegExp(farewellWords);
  static final RegExp columnHeader = _wordsRegExp(columnHeaderWords);
  static final RegExp unit = _wordsRegExp(unitWords);

  /// Clasifica una línea ya normalizada.
  ///
  /// El orden importa. «TOTAL TARJETA» es un medio de pago y no el total del
  /// ticket, así que descuento y pago se comprueban antes que total; y
  /// «SUBTOTAL» se mira antes que «TOTAL» porque lo contiene como subcadena.
  static ReceiptLineKind classify(String normalizedLine) {
    if (normalizedLine.isEmpty) {
      return ReceiptLineKind.unknown;
    }
    if (discount.hasMatch(normalizedLine)) {
      return ReceiptLineKind.discount;
    }
    if (tip.hasMatch(normalizedLine)) {
      return ReceiptLineKind.tip;
    }
    if (subtotal.hasMatch(normalizedLine)) {
      return ReceiptLineKind.subtotal;
    }
    if (payment.hasMatch(normalizedLine)) {
      return ReceiptLineKind.payment;
    }
    if (total.hasMatch(normalizedLine)) {
      return ReceiptLineKind.total;
    }
    if (tax.hasMatch(normalizedLine)) {
      return ReceiptLineKind.tax;
    }
    if (farewell.hasMatch(normalizedLine)) {
      return ReceiptLineKind.farewell;
    }
    if (columnHeader.hasMatch(normalizedLine) && !_looksLikeItemWithColumnWord(normalizedLine)) {
      return ReceiptLineKind.administrative;
    }
    if (administrative.hasMatch(normalizedLine)) {
      return ReceiptLineKind.administrative;
    }
    return ReceiptLineKind.unknown;
  }

  /// Una cabecera de columna es una línea corta y casi sin números.
  ///
  /// «IMPORTE 12,40» dentro del cuerpo del ticket es un artículo mal impreso,
  /// no la cabecera de una tabla.
  static bool _looksLikeItemWithColumnWord(String normalizedLine) {
    final digits = RegExp(r'\d').allMatches(normalizedLine).length;
    return digits >= 3;
  }
}
