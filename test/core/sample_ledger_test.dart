import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/expense_math.dart';
import 'package:shardpay/core/sample_ledger.dart';
import 'package:shardpay/models/app_models.dart';

/// El ejemplo que sale en el tour, en la ayuda y en el manual tiene que dar
/// exactamente lo que la app calcularía con esos mismos gastos.
///
/// Sin esta prueba, la documentación se convierte en una tabla escrita a mano
/// que se desincroniza del código a la primera. Enseñarle a alguien unas cuentas
/// que la app no hace es peor que no enseñarle nada.
void main() {
  final grupo = buildSampleGroup();

  Map<String, double> saldosPorNombre() {
    final porId = memberBalances(grupo);
    return <String, double>{for (final miembro in grupo.members) miembro.name: porId[miembro.userId] ?? 0};
  }

  group('grupo de ejemplo', () {
    test('tiene cuatro personas y cuatro gastos', () {
      expect(grupo.members.map((miembro) => miembro.name), sampleMemberNames);
      expect(grupo.expenses.length, sampleExpenseRows.length);
    });

    test('las filas que se enseñan coinciden con los gastos reales', () {
      for (var i = 0; i < sampleExpenseRows.length; i++) {
        final fila = sampleExpenseRows[i];
        final gasto = grupo.expenses[i];
        final pagador = grupo.members.firstWhere((miembro) => miembro.userId == gasto.payerId);

        expect(gasto.title, fila.concept);
        expect(pagador.name, fila.payer, reason: 'el pagador de "${fila.concept}" no coincide');
        expect(totalExpense(gasto), fila.amount, reason: 'el importe de "${fila.concept}" no coincide');
        expect(
          gasto.items.single.allocations.where((reparto) => reparto.percentage > 0).length,
          fila.sharedBy,
          reason: 'el número de participantes de "${fila.concept}" no coincide',
        );
      }
    });

    test('el gasto total es el que dice la documentación', () {
      expect(totalGroupSpend(grupo), sampleTotalSpend);
    });

    test('los saldos son los que dice la documentación', () {
      final calculados = saldosPorNombre();

      for (final entrada in sampleNetBalances.entries) {
        expect(calculados[entrada.key], entrada.value, reason: 'el saldo de ${entrada.key} que se enseña no es el que calcula la app');
      }
    });

    test('los saldos suman cero', () {
      final total = saldosPorNombre().values.fold<double>(0, (suma, valor) => suma + valor);
      expect(total.abs(), lessThan(0.011));
    });

    test('las liquidaciones son las dos que dice la documentación', () {
      final nombrePorId = <String, String>{for (final miembro in grupo.members) miembro.userId: miembro.name};

      final calculadas = settlementEdges(
        grupo,
      ).map((edge) => (from: nombrePorId[edge.fromUserId]!, to: nombrePorId[edge.toUserId]!, amount: edge.amount)).toList();

      expect(calculadas.length, sampleSettlements.length, reason: 'el número de pagos propuestos no coincide');
      for (final esperado in sampleSettlements) {
        expect(calculadas, contains(esperado), reason: 'falta el pago de ${esperado.from} a ${esperado.to}');
      }
    });

    test('las liquidaciones dejan a todo el mundo a cero', () {
      final saldos = Map<String, double>.from(memberBalances(grupo));

      for (final edge in settlementEdges(grupo)) {
        saldos[edge.fromUserId] = (saldos[edge.fromUserId] ?? 0) + edge.amount;
        saldos[edge.toUserId] = (saldos[edge.toUserId] ?? 0) - edge.amount;
      }

      for (final entrada in saldos.entries) {
        expect(entrada.value.abs(), lessThan(0.011), reason: 'queda saldo en ${entrada.key}');
      }
    });

    test('las deudas directas son las cinco que dice la documentación', () {
      final idPorNombre = <String, String>{for (final miembro in grupo.members) miembro.name: miembro.userId};
      final nombrePorId = <String, String>{for (final miembro in grupo.members) miembro.userId: miembro.name};

      // La matriz completa, en la misma forma que la tabla del manual: quien
      // debe, a quien, cuanto. Solo el lado deudor de cada par, para no contar
      // la misma deuda dos veces.
      final calculadas = <({String from, String to, double amount})>[];
      for (final miembro in grupo.members) {
        final fila = directBalancesForMember(grupo, miembro.userId);
        for (final entrada in fila.entries) {
          if (entrada.value > 0) {
            calculadas.add((from: nombrePorId[entrada.key]!, to: miembro.name, amount: entrada.value));
          }
        }
      }

      expect(calculadas.length, sampleDirectDebts.length, reason: 'el número de deudas directas no coincide');
      for (final esperada in sampleDirectDebts) {
        expect(calculadas, contains(esperada), reason: 'falta la deuda de ${esperada.from} a ${esperada.to}');
      }

      // Noa y Marta se cruzan 12 € en los dos sentidos: entre ellas, cero.
      expect(directBalancesForMember(grupo, idPorNombre['Noa']!)[idPorNombre['Marta']!], isNull);
    });

    test('simplificar reduce cinco pagos a dos por el mismo dinero', () {
      // Lo que justifica el botón de liquidar: menos transferencias, y ninguna
      // deuda perdida por el camino.
      expect(sampleSettlements.length, lessThan(sampleDirectDebts.length));

      final directo = sampleDirectDebts.fold<double>(0, (suma, deuda) => suma + deuda.amount);
      final simplificado = sampleSettlements.fold<double>(0, (suma, pago) => suma + pago.amount);
      expect(directo, 54);
      expect(simplificado, 48);
    });

    test('lo que puso cada persona es lo que dice la documentación', () {
      final porNombre = <String, double>{};
      for (final gasto in grupo.expenses) {
        final pagador = grupo.members.firstWhere((miembro) => miembro.userId == gasto.payerId);
        porNombre[pagador.name] = (porNombre[pagador.name] ?? 0) + totalExpense(gasto);
      }

      expect(porNombre, samplePaidByPerson);
      expect(porNombre.values.fold<double>(0, (suma, valor) => suma + valor), sampleTotalSpend);
    });

    test('el reparto por categorías cubre todo el gasto', () {
      final porCategoria = categoryTotals(<ExpenseGroup>[grupo]);

      expect(porCategoria['food'], 84);
      expect(porCategoria['transport'], 60);
      expect(porCategoria['fun'], 24);
      expect(porCategoria['groceries'], 48);
      expect(porCategoria, sampleCategoryTotals);
      expect(porCategoria.values.fold<double>(0, (suma, valor) => suma + valor), sampleTotalSpend);
    });

    test('quien no participa en una línea no paga nada de ella', () {
      // Las entradas al museo las comparten solo Noa y Marta: ni Brais ni Leo
      // deben un céntimo de esa línea.
      final museo = grupo.expenses.firstWhere((gasto) => gasto.title == 'Entradas al museo');

      expect(memberOwedInExpense(museo, SampleMembers.brais, group: grupo), 0);
      expect(memberOwedInExpense(museo, SampleMembers.leo, group: grupo), 0);
      expect(memberOwedInExpense(museo, SampleMembers.noa, group: grupo), 12);
      expect(memberOwedInExpense(museo, SampleMembers.marta, group: grupo), 12);
    });
  });
}
