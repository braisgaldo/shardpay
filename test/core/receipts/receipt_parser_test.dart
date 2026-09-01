import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/receipts/money_scanner.dart';
import 'package:shardpay/core/receipts/ocr_document.dart';
import 'package:shardpay/core/receipts/receipt_parser.dart';

const parser = ReceiptParser();

ReceiptScan parseLines(List<String> lines) => parser.parse(OcrDocument.fromLines(lines));

/// Construye un documento con geometría de ticket real: nombre a la izquierda,
/// importe alineado a la derecha en su propia columna.
OcrDocument twoColumnDocument(List<(String, String)> rows, {double rightEdge = 400}) {
  final fragments = <OcrFragment>[];
  for (var index = 0; index < rows.length; index++) {
    final (name, amount) = rows[index];
    final top = 100.0 + index * 34;
    if (name.isNotEmpty) {
      fragments.add(
        OcrFragment(
          text: name,
          box: TextBox(left: 40, top: top, right: 40 + name.length * 9.0, bottom: top + 22),
        ),
      );
    }
    if (amount.isNotEmpty) {
      fragments.add(
        OcrFragment(
          text: amount,
          box: TextBox(left: rightEdge - amount.length * 9.0, top: top, right: rightEdge, bottom: top + 22),
        ),
      );
    }
  }
  return OcrDocument.fromFragments(fragments);
}

List<String> namesOf(ReceiptScan scan) => scan.items.map((item) => item.name).toList();

void main() {
  group('interpretNumber', () {
    test('lee coma decimal', () {
      expect(interpretNumber('12,40', decimalSeparator: DecimalSeparator.comma), 12.40);
    });

    test('lee punto decimal', () {
      expect(interpretNumber('12.40', decimalSeparator: DecimalSeparator.dot), 12.40);
    });

    test('con los dos separadores manda el de la derecha', () {
      expect(interpretNumber('1.234,56', decimalSeparator: DecimalSeparator.comma), 1234.56);
      expect(interpretNumber('1,234.56', decimalSeparator: DecimalSeparator.dot), 1234.56);
    });

    test('tres digitos detras del separador ajeno son millares', () {
      expect(interpretNumber('1.234', decimalSeparator: DecimalSeparator.comma), 1234);
      expect(interpretNumber('1,234', decimalSeparator: DecimalSeparator.dot), 1234);
    });

    test('entero sin separador', () {
      expect(interpretNumber('45', decimalSeparator: DecimalSeparator.comma), 45);
    });
  });

  group('inferDecimalSeparator', () {
    test('deduce coma en un ticket espanol', () {
      expect(inferDecimalSeparator(<String>['CERVEZA 2,50', 'TOTAL 1.234,56']), DecimalSeparator.comma);
    });

    test('deduce punto en un ticket ingles', () {
      expect(inferDecimalSeparator(<String>['BEER 2.50', 'TOTAL 1,234.56']), DecimalSeparator.dot);
    });
  });

  group('scanMoney', () {
    test('ignora fechas, horas y porcentajes', () {
      final tokens = scanMoney('FECHA 31/08/2026 12:45 IVA 21% 4,20', decimalSeparator: DecimalSeparator.comma);
      expect(tokens.map((token) => token.value).toList(), <double>[4.20]);
    });

    test('detecta el signo negativo pospuesto de las impresoras termicas', () {
      final tokens = scanMoney('DESCUENTO 3,00-', decimalSeparator: DecimalSeparator.comma);
      expect(tokens.single.value, -3.00);
    });

    test('detecta la marca de divisa', () {
      final tokens = scanMoney('CAFE 1,60 €', decimalSeparator: DecimalSeparator.comma);
      expect(tokens.single.hasCurrencyMark, isTrue);
    });
  });

  group('ReceiptParser', () {
    test('lee un ticket de bar y cuadra con el total', () {
      final scan = parseLines(<String>[
        'BAR LA PLAZA',
        'CIF B12345678',
        'FECHA 31/08/2026 21:14',
        'CERVEZA 2,50',
        'VINO TINTO 3,20',
        'TORTILLA 6,80',
        'TOTAL 12,50',
        'EFECTIVO 20,00',
        'CAMBIO 7,50',
      ]);

      expect(scan.total, 12.50);
      expect(scan.itemsTotal, 12.50);
      expect(scan.reconciled, isTrue);
      expect(namesOf(scan), <String>['Cerveza', 'Vino Tinto', 'Tortilla']);
      expect(scan.warnings, isEmpty);
      expect(scan.confidence, greaterThan(0.6));
    });

    test('no se corta cuando la cabecera contiene la palabra total', () {
      // Regresion: el parser anterior cortaba en la PRIMERA aparicion de
      // «total» y se comia el ticket entero.
      final scan = parseLines(<String>[
        'SUPERMERCADO EJEMPLO',
        'TOTAL COMPRA ONLINE',
        'LECHE 1,10',
        'PAN 0,95',
        'HUEVOS 2,45',
        'TOTAL 4,50',
      ]);

      expect(namesOf(scan), containsAll(<String>['Leche', 'Pan', 'Huevos']));
      expect(scan.total, 4.50);
    });

    test('no descarta productos que contienen palabras clave como subcadena', () {
      // Regresion: «Gouda» contiene «ud», «Antipasto» contiene «tip» y
      // «Privado» contiene «iva». El parser anterior los tiraba.
      final scan = parseLines(<String>['QUESERIA', 'GOUDA CURADO 4,90', 'ANTIPASTO 7,50', 'SALON PRIVADO 10,00', 'TOTAL 22,40']);

      expect(namesOf(scan), <String>['Gouda Curado', 'Antipasto', 'Salon Privado']);
      expect(scan.reconciled, isTrue);
    });

    test('interpreta cantidad, precio unitario e importe de linea', () {
      final scan = parseLines(<String>['CAFETERIA', '2 x CERVEZA 2,50 5,00', '3 x CAFE 1,20 3,60', 'TOTAL 8,60']);

      expect(scan.items.length, 2);
      expect(scan.items.first.quantity, 2);
      expect(scan.items.first.unitPrice, 2.50);
      expect(scan.items.first.amount, 5.00);
      expect(scan.items.first.name, 'Cerveza');
      expect(scan.items[1].quantity, 3);
      expect(scan.items[1].amount, 3.60);
      expect(scan.reconciled, isTrue);
    });

    test('deduce la cantidad cuando el ticket no la imprime', () {
      final scan = parseLines(<String>['PANADERIA', 'BARRA PAN 1,20 3,60', 'TOTAL 3,60']);

      expect(scan.items.single.quantity, 3);
      expect(scan.items.single.unitPrice, 1.20);
      expect(scan.items.single.amount, 3.60);
    });

    test('anade un ajuste cuando faltan articulos para llegar al total', () {
      final scan = parseLines(<String>['RESTAURANTE', 'ENSALADA 8,00', 'PASTA 10,00', 'TOTAL 25,00']);

      expect(scan.items.length, 3);
      expect(scan.items.last.kind, ReceiptItemKind.adjustment);
      expect(scan.items.last.amount, 7.00);
      expect(scan.itemsTotal, 25.00);
      expect(scan.warnings, contains(ReceiptWarning.adjustmentAdded));
    });

    test('descarta la linea duplicada cuando los articulos pasan del total', () {
      final scan = parseLines(<String>['TIENDA', 'ARROZ 3,00', 'ACEITE 5,00', 'SUMA ARTICULOS 8,00', 'TOTAL 8,00']);

      expect(scan.itemsTotal, 8.00);
      expect(scan.items.length, 2);
    });

    test('trata el descuento como importe negativo', () {
      final scan = parseLines(<String>['TIENDA', 'CAMISETA 20,00', 'DESCUENTO PROMO 5,00-', 'TOTAL 15,00']);

      expect(scan.itemsTotal, 15.00);
      expect(scan.reconciled, isTrue);
    });

    test('sin articulos legibles deja una sola linea con el total', () {
      final scan = parseLines(<String>['PARKING CENTRO', 'NIF A11111111', 'TOTAL 4,30']);

      expect(scan.items.single.kind, ReceiptItemKind.adjustment);
      expect(scan.items.single.amount, 4.30);
      expect(scan.warnings, contains(ReceiptWarning.noItemsDetected));
    });

    test('detecta comercio, fecha y divisa', () {
      final scan = parseLines(<String>['CAFE CENTRAL', 'CALLE MAYOR 3', 'FECHA 05/03/2026', 'CAFE 1,60 €', 'TOTAL 1,60 €']);

      expect(scan.merchant, 'Cafe Central');
      expect(scan.date, DateTime(2026, 3, 5));
      expect(scan.currencyCode, 'EUR');
    });

    test('lee un ticket en formato ingles con punto decimal', () {
      final scan = parseLines(<String>['THE CORNER PUB', 'FISH AND CHIPS 12.50', 'LEMONADE 3.25', 'TOTAL 15.75']);

      expect(scan.itemsTotal, 15.75);
      expect(scan.reconciled, isTrue);
    });

    test('documento vacio devuelve un resultado vacio y avisado', () {
      final scan = parser.parse(OcrDocument.fromLines(const <String>[]));
      expect(scan.isEmpty, isTrue);
      expect(scan.confidence, 0);
      expect(scan.warnings, contains(ReceiptWarning.noItemsDetected));
    });
  });

  group('ReceiptParser con geometria', () {
    test('usa la columna de importes de un ticket a dos columnas', () {
      final scan = parser.parse(
        twoColumnDocument(const <(String, String)>[
          ('SUPERMERCADO SOL', ''),
          ('LECHE ENTERA 1L', '1,10'),
          ('PAN DE MOLDE', '2,35'),
          ('MANZANAS', '3,05'),
          ('TOTAL', '6,50'),
        ]),
      );

      expect(namesOf(scan), <String>['Leche Entera 1L', 'Pan De Molde', 'Manzanas']);
      expect(scan.total, 6.50);
      expect(scan.reconciled, isTrue);
    });

    test('empareja un nombre sin precio con el importe de la fila contigua', () {
      final fragments = <OcrFragment>[
        const OcrFragment(text: 'MENU DEL DIA', box: TextBox(left: 40, top: 100, right: 180, bottom: 122)),
        const OcrFragment(text: '13,90', box: TextBox(left: 340, top: 128, right: 400, bottom: 150)),
        const OcrFragment(text: 'AGUA', box: TextBox(left: 40, top: 168, right: 100, bottom: 190)),
        const OcrFragment(text: '1,50', box: TextBox(left: 350, top: 168, right: 400, bottom: 190)),
        const OcrFragment(text: 'TOTAL', box: TextBox(left: 40, top: 210, right: 110, bottom: 232)),
        const OcrFragment(text: '15,40', box: TextBox(left: 340, top: 210, right: 400, bottom: 232)),
      ];

      final scan = parser.parse(OcrDocument.fromFragments(fragments));

      expect(namesOf(scan), containsAll(<String>['Menu Del Dia', 'Agua']));
      expect(scan.itemsTotal, 15.40);
    });

    test('agrupa en la misma fila fragmentos de un ticket torcido', () {
      // El importe cae 6 px mas abajo que el nombre por la perspectiva de la
      // foto; con un umbral por distancia entre centros se separarian.
      final fragments = <OcrFragment>[
        const OcrFragment(text: 'CROQUETAS', box: TextBox(left: 40, top: 100, right: 170, bottom: 122)),
        const OcrFragment(text: '7,20', box: TextBox(left: 340, top: 106, right: 400, bottom: 128)),
        const OcrFragment(text: 'TOTAL', box: TextBox(left: 40, top: 150, right: 110, bottom: 172)),
        const OcrFragment(text: '7,20', box: TextBox(left: 340, top: 156, right: 400, bottom: 178)),
      ];

      final scan = parser.parse(OcrDocument.fromFragments(fragments));

      expect(scan.items.single.name, 'Croquetas');
      expect(scan.items.single.amount, 7.20);
    });
  });

  group('roundMoney', () {
    test('redondea a dos decimales sin pasar por cadenas', () {
      expect(roundMoney(1.006), 1.01);
      expect(roundMoney(1.004), 1.00);
      expect(roundMoney(2.674999), 2.67);
      expect(roundMoney(-3.456), -3.46);
      expect(roundMoney(0.1 + 0.2), 0.30);
    });

    test('reparte un importe entre tres sin perder ni ganar centimos', () {
      // El caso que de verdad importa en una app de dividir gastos: 10 euros
      // entre tres personas no puede sumar 9,99 ni 10,01.
      const total = 10.0;
      final tercio = roundMoney(total / 3);
      final resto = roundMoney(total - tercio * 2);
      expect(tercio, 3.33);
      expect(resto, 3.34);
      expect(roundMoney(tercio * 2 + resto), total);
    });
  });

  group('cruce aritmetico del bloque de totales', () {
    // El caso real que lo motivo: un ticket de prueba de `BAR LA PLAZA` con
    // `TOTAL 52,36`, que el reconocimiento de texto del movil leyo como
    // `52,00`. Las lineas sumaban 47,60 y el subtotal impreso decia 47,60: dos
    // lecturas independientes de acuerdo. 47,60 + 4,76 = 52,36, asi que el
    // unico numero fuera de sitio era el total.
    List<(String, String)> barLaPlaza({required String total}) => [
      ('BAR LA PLAZA', ''),
      ('CROQUETAS', '8,50'),
      ('PULPO A FEIRA', '16,00'),
      ('ENSALADA MIXTA', '7,20'),
      ('AGUA 1L', '2,30'),
      ('VINO RIBEIRO', '12,00'),
      ('CAFE SOLO', '1,60'),
      ('SUBTOTAL', '47,60'),
      ('IVA 10%', '4,76'),
      ('TOTAL', total),
    ];

    test('corrige el total cuando las lineas y el subtotal se dan la razon', () {
      final scan = parser.parse(twoColumnDocument(barLaPlaza(total: '52,00')));

      expect(scan.total, 52.36, reason: 'el total no se corrigio con subtotal + IVA');
      expect(scan.warnings, contains(ReceiptWarning.totalCorrectedByArithmetic));

      // Sigue habiendo linea de ajuste, y debe haberla: las lineas del ticket
      // son sin IVA y el total lo lleva. Lo que cambia es cuanto vale. Con el
      // total mal leido salia 52,00 - 47,60 = 4,40, un numero que no significa
      // nada. Con el total corregido sale 4,76, que es exactamente el IVA
      // impreso: el ajuste deja de ser un parche y pasa a ser el impuesto.
      final ajuste = scan.items.firstWhere((item) => item.kind == ReceiptItemKind.adjustment);
      expect(ajuste.amount, closeTo(4.76, 0.001));
    });

    test('no toca nada cuando el total leido ya cuadra', () {
      final scan = parser.parse(twoColumnDocument(barLaPlaza(total: '52,36')));

      expect(scan.total, 52.36);
      expect(scan.warnings, isNot(contains(ReceiptWarning.totalCorrectedByArithmetic)));
    });

    test('no corrige si el subtotal no cuadra con las lineas', () {
      // Aqui el subtotal impreso no coincide con la suma de articulos, asi que
      // no hay dos testigos de acuerdo y no hay base para corregir el total.
      final filas = barLaPlaza(total: '52,00');
      filas[7] = ('SUBTOTAL', '41,10');
      final scan = parser.parse(twoColumnDocument(filas));

      expect(scan.total, 52.00, reason: 'ha corregido el total sin base para hacerlo');
      expect(scan.warnings, isNot(contains(ReceiptWarning.totalCorrectedByArithmetic)));
    });

    test('no corrige una desviacion grande: eso no es un digito mal leido', () {
      // 20 € de diferencia no es un fallo de reconocimiento, es que se ha
      // identificado mal alguna linea. Corregir aqui seria inventarse el total.
      final scan = parser.parse(twoColumnDocument(barLaPlaza(total: '72,36')));

      expect(scan.total, 72.36);
      expect(scan.warnings, isNot(contains(ReceiptWarning.totalCorrectedByArithmetic)));
    });

    test('sin subtotal impreso no hay nada que cruzar', () {
      final filas = barLaPlaza(total: '52,00')..removeAt(7);
      final scan = parser.parse(twoColumnDocument(filas));

      expect(scan.total, 52.00);
      expect(scan.warnings, isNot(contains(ReceiptWarning.totalCorrectedByArithmetic)));
    });

    test('tiene en cuenta el descuento y la propina', () {
      final scan = parser.parse(
        twoColumnDocument([
          ('CAFETERIA O ANDEN', ''),
          ('TARTA DE QUEIXO', '5,50'),
          ('ZUMO NARANJA', '3,20'),
          ('SUBTOTAL', '8,70'),
          ('DESCUENTO CLIENTE', '-1,50'),
          ('IVA 10%', '0,72'),
          ('TOTAL', '7,00'), // lo correcto es 8,70 + 0,72 - 1,50 = 7,92
        ]),
      );

      expect(scan.total, 7.92);
      expect(scan.warnings, contains(ReceiptWarning.totalCorrectedByArithmetic));
    });
  });
}
