import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/defaults.dart';
import 'package:shardpay/models/app_models.dart';

/// El identificador de una categoria es un dato interno. Antes, cuando no se
/// encontraba la categoria, la interfaz enseñaba el identificador crudo: en una
/// pantalla en español aparecian etiquetas como «coffee» entre «Comida» y
/// «Transporte». Se vio en una captura de la ficha de la tienda.
void main() {
  group('nombre visible de una categoria', () {
    test('usa el nombre cuando la categoria existe', () {
      const categoria = ExpenseCategory(id: 'food', name: 'Comida', iconKey: 'utensils', colorHex: '0xFFE4572E');
      expect(categoryDisplayName(categoria, 'Otros'), 'Comida');
    });

    test('nunca enseña el identificador cuando la categoria no existe', () {
      expect(categoryDisplayName(null, 'Otros'), 'Otros');
    });

    test('tampoco cuando la categoria existe pero no tiene nombre', () {
      const sinNombre = ExpenseCategory(id: 'x', name: '   ', iconKey: 'utensils', colorHex: '0xFFE4572E');
      expect(categoryDisplayName(sinNombre, 'Otros'), 'Otros');
    });

    test('todas las categorias por defecto tienen nombre', () {
      for (final categoria in buildDefaultCategories()) {
        expect(categoria.name.trim(), isNotEmpty, reason: 'la categoria ${categoria.id} no tiene nombre');
        expect(categoryDisplayName(categoria, 'Otros'), isNot('Otros'));
      }
    });
  });
}
