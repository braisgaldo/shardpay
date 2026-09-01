/// Grupo de ejemplo que comparten el tour guiado, la pantalla de ayuda y el
/// manual de usuario.
///
/// Dart puro, a propósito. Que el ejemplo sea **código** y no una tabla escrita
/// a mano en el manual tiene una consecuencia muy concreta: hay una prueba que
/// pasa estos gastos por el motor de cálculo de verdad y comprueba que los
/// saldos y las liquidaciones que se enseñan al usuario son exactamente los que
/// la app calcularía. Un ejemplo con las cuentas mal explicadas es peor que no
/// poner ejemplo.
///
/// Los importes están elegidos para que el reparto entre cuatro caiga en euros
/// redondos y las cuentas se puedan seguir de cabeza. Los repartos entre tres
/// dan porcentajes de 33,33 y arrastran céntimos que distraen de lo que se está
/// explicando.
library;

import '../models/app_models.dart';

/// Identificadores de las personas del ejemplo.
class SampleMembers {
  const SampleMembers._();

  static const String brais = 'ejemplo-brais';
  static const String noa = 'ejemplo-noa';
  static const String leo = 'ejemplo-leo';
  static const String marta = 'ejemplo-marta';
}

/// Nombres visibles, en el orden en que aparecen en el grupo.
const List<String> sampleMemberNames = <String>['Brais', 'Noa', 'Leo', 'Marta'];

/// Construye el grupo de ejemplo: «Roadtrip Costa», cuatro personas y cuatro
/// gastos pagados por tres de ellas.
ExpenseGroup buildSampleGroup() {
  final creado = DateTime(2026, 7, 17, 10);

  const miembros = <GroupMember>[
    GroupMember(userId: SampleMembers.brais, name: 'Brais', email: 'brais@ejemplo.com'),
    GroupMember(userId: SampleMembers.noa, name: 'Noa', email: 'noa@ejemplo.com'),
    GroupMember(userId: SampleMembers.leo, name: 'Leo', email: 'leo@ejemplo.com'),
    GroupMember(userId: SampleMembers.marta, name: 'Marta', email: 'marta@ejemplo.com'),
  ];

  // Reparto a partes iguales entre los cuatro: 25 % cada uno.
  const entreTodos = <SplitAllocation>[
    SplitAllocation(userId: SampleMembers.brais, percentage: 25),
    SplitAllocation(userId: SampleMembers.noa, percentage: 25),
    SplitAllocation(userId: SampleMembers.leo, percentage: 25),
    SplitAllocation(userId: SampleMembers.marta, percentage: 25),
  ];

  // Reparto solo entre dos, para enseñar que se ajusta línea a línea.
  const entreNoaYMarta = <SplitAllocation>[
    SplitAllocation(userId: SampleMembers.noa, percentage: 50),
    SplitAllocation(userId: SampleMembers.marta, percentage: 50),
  ];

  final gastos = <ExpenseRecord>[
    ExpenseRecord(
      id: 'ejemplo-cena',
      title: 'Cena del viernes',
      payerId: SampleMembers.brais,
      createdAt: creado.add(const Duration(days: 1)),
      items: const <ExpenseItem>[
        ExpenseItem(id: 'ejemplo-cena-1', name: 'Cena del viernes', amount: 84, categoryId: 'food', allocations: entreTodos),
      ],
    ),
    ExpenseRecord(
      id: 'ejemplo-gasolina',
      title: 'Gasolina',
      payerId: SampleMembers.leo,
      createdAt: creado.add(const Duration(days: 1, hours: 6)),
      items: const <ExpenseItem>[
        ExpenseItem(id: 'ejemplo-gasolina-1', name: 'Gasolina', amount: 60, categoryId: 'transport', allocations: entreTodos),
      ],
    ),
    ExpenseRecord(
      id: 'ejemplo-museo',
      title: 'Entradas al museo',
      payerId: SampleMembers.noa,
      createdAt: creado.add(const Duration(days: 2)),
      items: const <ExpenseItem>[
        ExpenseItem(id: 'ejemplo-museo-1', name: 'Entradas al museo', amount: 24, categoryId: 'fun', allocations: entreNoaYMarta),
      ],
    ),
    ExpenseRecord(
      id: 'ejemplo-super',
      title: 'Supermercado',
      payerId: SampleMembers.marta,
      createdAt: creado.add(const Duration(days: 2, hours: 4)),
      items: const <ExpenseItem>[
        ExpenseItem(id: 'ejemplo-super-1', name: 'Supermercado', amount: 48, categoryId: 'groceries', allocations: entreTodos),
      ],
    ),
  ];

  return ExpenseGroup(
    id: 'ejemplo-roadtrip',
    name: 'Roadtrip Costa',
    description: 'Gastos del viaje, comida y coche',
    iconKey: 'plane',
    currency: 'EUR',
    ownerId: SampleMembers.brais,
    adminIds: const <String>[],
    inviteCode: 'COSTA26',
    joinPin: '4821',
    memberIds: const <String>[SampleMembers.brais, SampleMembers.noa, SampleMembers.leo, SampleMembers.marta],
    members: miembros,
    pendingMembers: const <PendingGroupMember>[],
    allowAnonymousJoin: false,
    customCategories: const <ExpenseCategory>[],
    expenses: gastos,
    createdAt: creado,
    updatedAt: creado.add(const Duration(days: 2, hours: 4)),
    isClosed: false,
  );
}

/// Una fila del ejemplo, tal y como se enseña en el tour y en la ayuda.
class SampleExpenseRow {
  const SampleExpenseRow({required this.concept, required this.payer, required this.amount, required this.sharedBy});

  final String concept;
  final String payer;
  final double amount;

  /// Entre cuántas personas se reparte esa línea.
  final int sharedBy;

  /// Lo que le toca a cada participante de esa línea.
  double get perPerson => amount / sharedBy;
}

/// Las cuatro filas del ejemplo, en el orden en que se apuntaron.
const List<SampleExpenseRow> sampleExpenseRows = <SampleExpenseRow>[
  SampleExpenseRow(concept: 'Cena del viernes', payer: 'Brais', amount: 84, sharedBy: 4),
  SampleExpenseRow(concept: 'Gasolina', payer: 'Leo', amount: 60, sharedBy: 4),
  SampleExpenseRow(concept: 'Entradas al museo', payer: 'Noa', amount: 24, sharedBy: 2),
  SampleExpenseRow(concept: 'Supermercado', payer: 'Marta', amount: 48, sharedBy: 4),
];

/// Saldo neto de cada persona en el ejemplo, en euros.
///
/// Positivo: le deben dinero. Negativo: debe dinero.
/// Comprobado contra el motor de cálculo en `test/core/sample_ledger_test.dart`.
const Map<String, double> sampleNetBalances = <String, double>{'Brais': 36, 'Noa': -36, 'Leo': 12, 'Marta': -12};

/// Pagos mínimos que dejan el grupo a cero.
///
/// Son dos, y no cuatro: el algoritmo cruza las deudas antes de proponer nada.
/// También comprobado contra el motor.
const List<({String from, String to, double amount})> sampleSettlements = <({String from, String to, double amount})>[
  (from: 'Noa', to: 'Brais', amount: 36),
  (from: 'Marta', to: 'Leo', amount: 12),
];

/// Deudas directas, persona a persona, **antes** de simplificar.
///
/// Salen de mirar gasto a gasto quién le debe qué a quién: son cinco pagos. La
/// app no propone estos cinco, propone los dos de [sampleSettlements], porque
/// cruza las deudas antes de sugerir nada. Enseñar las dos listas juntas es la
/// forma más rápida de que se entienda qué hace exactamente el botón de
/// liquidar.
///
/// Noa y Marta no aparecen: se deben 12 € la una a la otra en los dos sentidos
/// (el museo y su parte del supermercado) y quedan a cero entre ellas.
///
/// Comprobado contra el motor en `test/core/sample_ledger_test.dart`.
const List<({String from, String to, double amount})> sampleDirectDebts = <({String from, String to, double amount})>[
  (from: 'Noa', to: 'Brais', amount: 21),
  (from: 'Marta', to: 'Brais', amount: 9),
  (from: 'Leo', to: 'Brais', amount: 6),
  (from: 'Noa', to: 'Leo', amount: 15),
  (from: 'Marta', to: 'Leo', amount: 3),
];

/// Gasto total del grupo de ejemplo.
const double sampleTotalSpend = 216;

/// Lo que puso cada persona, para la vista de estadísticas.
///
/// Suma [sampleTotalSpend]. Ojo: pagar mucho no es lo mismo que tener saldo a
/// favor; Marta puso 48 € y aun así debe dinero, porque participa en casi todo.
const Map<String, double> samplePaidByPerson = <String, double>{'Brais': 84, 'Leo': 60, 'Marta': 48, 'Noa': 24};

/// Gasto por categoría, para la vista de estadísticas.
const Map<String, double> sampleCategoryTotals = <String, double>{'food': 84, 'transport': 60, 'groceries': 48, 'fun': 24};
