import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/expense_math.dart';
import 'package:shardpay/models/app_models.dart';

void main() {
  group('expense math', () {
    test('equalAllocations always sums 100%', () {
      final allocations = equalAllocations(const [
        GroupMember(userId: 'a', name: 'A', email: 'a@example.com'),
        GroupMember(userId: 'b', name: 'B', email: 'b@example.com'),
        GroupMember(userId: 'c', name: 'C', email: 'c@example.com'),
      ]);

      final total = allocations.fold<double>(0, (sum, item) => sum + item.percentage);
      expect((total - 100).abs(), lessThan(0.01));
    });

    test('directBalancesForMember keeps multi-person expenses split correctly', () {
      final group = _group(
        id: 'g1',
        members: const [
          GroupMember(userId: 'a', name: 'A', email: 'a@example.com'),
          GroupMember(userId: 'b', name: 'B', email: 'b@example.com'),
          GroupMember(userId: 'c', name: 'C', email: 'c@example.com'),
        ],
        expenses: [
          _expense(
            id: 'e1',
            payerId: 'a',
            items: [
              _item(
                amount: 90,
                allocations: const [
                  SplitAllocation(userId: 'b', percentage: 50),
                  SplitAllocation(userId: 'c', percentage: 50),
                ],
              ),
            ],
          ),
        ],
      );

      final balances = directBalancesForMember(group, 'a');
      expect(balances['b'], 45);
      expect(balances['c'], 45);
    });

    test('globalCounterpartyBalances aggregates authenticated counterparties across groups', () {
      final groups = [
        _group(
          id: 'g1',
          members: const [
            GroupMember(userId: 'a', name: 'A', email: 'a@example.com'),
            GroupMember(userId: 'b', name: 'B', email: 'b@example.com'),
          ],
          expenses: [
            _expense(
              id: 'e1',
              payerId: 'a',
              items: [
                _item(amount: 10, allocations: const [SplitAllocation(userId: 'b', percentage: 100)]),
              ],
            ),
          ],
        ),
        _group(
          id: 'g2',
          members: const [
            GroupMember(userId: 'a', name: 'A', email: 'a@example.com'),
            GroupMember(userId: 'b', name: 'B', email: 'b@example.com'),
          ],
          expenses: [
            _expense(
              id: 'e2',
              payerId: 'a',
              items: [
                _item(amount: 20, allocations: const [SplitAllocation(userId: 'b', percentage: 100)]),
              ],
            ),
          ],
        ),
      ];

      final entries = globalCounterpartyBalances(groups, 'a', includePendingUsers: false);

      expect(entries, hasLength(1));
      expect(entries.single.counterpartyId, 'b');
      expect(entries.single.groupBreakdown, hasLength(2));
      expect(entries.single.netAmount, 30);
    });

    test('globalCounterpartyBalances keeps pending users scoped to their group', () {
      final groups = [
        _group(
          id: 'g1',
          members: const [GroupMember(userId: 'a', name: 'A', email: 'a@example.com')],
          pendingMembers: const [PendingGroupMember(id: 'p1', name: 'Pending One')],
          expenses: [
            _expense(
              id: 'e1',
              payerId: 'a',
              items: [
                _item(amount: 12, allocations: const [SplitAllocation(userId: 'pending:p1', percentage: 100)]),
              ],
            ),
          ],
        ),
        _group(
          id: 'g2',
          members: const [GroupMember(userId: 'a', name: 'A', email: 'a@example.com')],
          pendingMembers: const [PendingGroupMember(id: 'p2', name: 'Pending Two')],
          expenses: [
            _expense(
              id: 'e2',
              payerId: 'a',
              items: [
                _item(amount: 8, allocations: const [SplitAllocation(userId: 'pending:p2', percentage: 100)]),
              ],
            ),
          ],
        ),
      ];

      final entries = globalCounterpartyBalances(groups, 'a', includePendingUsers: true);

      expect(entries, hasLength(2));
      expect(entries.every((entry) => entry.isScopedToGroup), isTrue);
      expect(entries.every((entry) => entry.groupBreakdown.length == 1), isTrue);
    });

    test('group and global summaries expose incoming and outgoing amounts per person', () {
      final firstGroup = _group(
        id: 'g1',
        members: const [
          GroupMember(userId: 'a', name: 'A', email: 'a@example.com'),
          GroupMember(userId: 'b', name: 'B', email: 'b@example.com'),
          GroupMember(userId: 'c', name: 'C', email: 'c@example.com'),
        ],
        expenses: [
          _expense(
            id: 'e1',
            payerId: 'a',
            items: [
              _item(amount: 30, allocations: const [SplitAllocation(userId: 'c', percentage: 100)]),
            ],
          ),
          _expense(
            id: 'e2',
            payerId: 'b',
            items: [
              _item(amount: 20, allocations: const [SplitAllocation(userId: 'a', percentage: 100)]),
            ],
          ),
        ],
      );
      final secondGroup = _group(
        id: 'g2',
        members: const [
          GroupMember(userId: 'a', name: 'A', email: 'a@example.com'),
          GroupMember(userId: 'b', name: 'B', email: 'b@example.com'),
        ],
        expenses: [
          _expense(
            id: 'e3',
            payerId: 'a',
            items: [
              _item(amount: 15, allocations: const [SplitAllocation(userId: 'b', percentage: 100)]),
            ],
          ),
        ],
      );

      final groupSummaryA = groupBalanceSummaries(firstGroup).firstWhere((entry) => entry.memberId == 'a');
      expect(groupSummaryA.incomingAmount, 30);
      expect(groupSummaryA.outgoingAmount, 20);
      expect(groupSummaryA.netAmount, 10);

      final globalSummaryB = globalBalanceSummaries(
        [firstGroup, secondGroup],
        'a',
        includePendingUsers: false,
      ).firstWhere((entry) => entry.memberId == 'b');
      expect(globalSummaryB.incomingAmount, 15);
      expect(globalSummaryB.outgoingAmount, 20);
      expect(globalSummaryB.netAmount, -5);
    });

    test('recorded settlements reduce the minimum settlement plan for the group', () {
      final baseGroup = _group(
        id: 'g3',
        members: const [
          GroupMember(userId: 'a', name: 'A', email: 'a@example.com'),
          GroupMember(userId: 'b', name: 'B', email: 'b@example.com'),
          GroupMember(userId: 'c', name: 'C', email: 'c@example.com'),
        ],
        expenses: [
          _expense(
            id: 'e1',
            payerId: 'b',
            items: [
              _item(amount: 30, allocations: const [SplitAllocation(userId: 'a', percentage: 100)]),
            ],
          ),
          _expense(
            id: 'e2',
            payerId: 'c',
            items: [
              _item(amount: 20, allocations: const [SplitAllocation(userId: 'a', percentage: 100)]),
            ],
          ),
        ],
      );

      final initialEdges = settlementEdges(baseGroup, activeAccountsOnly: false);
      expect(initialEdges, hasLength(2));
      expect(initialEdges.first.fromUserId, 'a');
      expect(initialEdges.first.toUserId, 'b');
      expect(initialEdges.first.amount, 30);

      final settledGroup = baseGroup.copyWith(
        expenses: [
          ...baseGroup.expenses,
          ExpenseRecord(
            id: 's1',
            title: 'Settlement',
            payerId: 'a',
            createdAt: DateTime(2026, 3, 14, 13),
            kind: ExpenseRecordKind.settlement,
            items: const [
              ExpenseItem(
                id: 's1-item',
                name: 'Recorded payment',
                amount: 30,
                categoryId: 'work',
                allocations: [
                  SplitAllocation(userId: 'b', percentage: 100),
                  SplitAllocation(userId: 'a', percentage: 0),
                ],
              ),
            ],
          ),
        ],
      );

      final remainingEdges = settlementEdges(settledGroup, activeAccountsOnly: false);
      expect(remainingEdges, hasLength(1));
      expect(remainingEdges.single.fromUserId, 'a');
      expect(remainingEdges.single.toUserId, 'c');
      expect(remainingEdges.single.amount, 20);

      final summaryA = groupBalanceSummaries(settledGroup).firstWhere((entry) => entry.memberId == 'a');
      expect(summaryA.outgoingAmount, 20);
      expect(summaryA.netAmount, -20);
    });
  });

  group('indice del grupo', () {
    // El indice es la pieza que hizo que calcular saldos dejara de recorrer los
    // gastos una vez por miembro. Estas pruebas fijan su semantica para que una
    // optimizacion futura no se lleve por delante el resultado.

    ExpenseGroup buildGroup() {
      return _group(
        id: 'ledger',
        members: const [
          GroupMember(userId: 'a', name: 'A', email: 'a@example.com'),
          GroupMember(userId: 'b', name: 'B', email: 'b@example.com'),
          GroupMember(userId: 'c', name: 'C', email: 'c@example.com'),
        ],
        pendingMembers: const [PendingGroupMember(id: 'p1', name: 'Invitada')],
        expenses: [
          _expense(
            id: 'e1',
            payerId: 'a',
            items: [
              _item(
                amount: 60,
                allocations: const [
                  SplitAllocation(userId: 'a', percentage: 25),
                  SplitAllocation(userId: 'b', percentage: 25),
                  SplitAllocation(userId: 'c', percentage: 25),
                  SplitAllocation(userId: 'pending:p1', percentage: 25),
                ],
              ),
            ],
          ),
          _expense(
            id: 'e2',
            payerId: 'b',
            items: [
              _item(
                amount: 30,
                allocations: const [
                  SplitAllocation(userId: 'a', percentage: 50),
                  SplitAllocation(userId: 'c', percentage: 50),
                ],
              ),
            ],
          ),
        ],
      );
    }

    test('los saldos de un grupo cerrado suman cero', () {
      final balances = memberBalances(buildGroup());
      final total = balances.values.fold<double>(0, (sum, value) => sum + value);
      expect(total.abs(), lessThan(0.011));
    });

    test('la matriz de deudas es antisimetrica', () {
      final group = buildGroup();
      final ledger = ledgerOf(group);

      for (final row in ledger.pairwiseBalances.entries) {
        for (final cell in row.value.entries) {
          final mirrored = ledger.pairwiseBalances[cell.key]?[row.key] ?? 0;
          expect((cell.value + mirrored).abs(), lessThan(0.011));
        }
      }
    });

    test('el indice se reutiliza para la misma instancia de grupo', () {
      final group = buildGroup();
      expect(identical(ledgerOf(group), ledgerOf(group)), isTrue);
      expect(identical(ledgerOf(group), ledgerOf(buildGroup())), isFalse);
    });

    test('normaliza el identificador de los invitados pendientes', () {
      final group = buildGroup();
      expect(canonicalGroupUserId(group, 'p1'), 'pending:p1');
      expect(canonicalGroupUserId(group, 'pending:p1'), 'pending:p1');
      expect(canonicalGroupUserId(group, '  a  '), 'a');
      expect(canonicalGroupUserId(group, ''), '');
      expect(resolveGroupMember(group, 'p1')?.name, 'Invitada');
    });

    test('las liquidaciones propuestas dejan a todo el mundo a cero', () {
      final group = buildGroup();
      final balances = Map<String, double>.from(memberBalances(group));

      for (final edge in settlementEdges(group, activeAccountsOnly: false)) {
        balances[edge.fromUserId] = (balances[edge.fromUserId] ?? 0) + edge.amount;
        balances[edge.toUserId] = (balances[edge.toUserId] ?? 0) - edge.amount;
      }

      for (final entry in balances.entries) {
        expect(entry.value.abs(), lessThan(0.011), reason: 'queda saldo en ${entry.key}');
      }
    });

    test('las listas de miembros derivadas se calculan una sola vez', () {
      final group = buildGroup();
      expect(identical(group.visibleMembers, group.visibleMembers), isTrue);
      expect(identical(group.activeMembers, group.activeMembers), isTrue);
      expect(identical(group.selectableMembers, group.selectableMembers), isTrue);
      expect(group.visibleMembers.length, 4);
      expect(group.selectableMembers.length, 4);
    });
  });

  group('huecos reservados reclamados', () {
    // Antes, cuando alguien entraba diciendo «soy Marta», el movil reescribia
    // todos los gastos del grupo cambiando `pending:marta` por su uid. Eso
    // exigia leer el grupo entero sin ser miembro, que es el agujero de
    // ADR-0009. Ahora la equivalencia se anota en `claimedSlots` y se resuelve
    // aqui, al calcular. El resultado tiene que ser identico.
    ExpenseGroup grupoConHueco({
      Map<String, String> claimedSlots = const <String, String>{},
      List<GroupMember> extra = const <GroupMember>[],
    }) {
      return ExpenseGroup(
        id: 'g1',
        name: 'Piso',
        iconKey: 'home',
        currency: 'EUR',
        ownerId: 'ana',
        adminIds: const <String>[],
        inviteCode: 'PISO01',
        joinPin: '1234',
        memberIds: <String>['ana', ...extra.map((m) => m.userId)],
        members: <GroupMember>[
          const GroupMember(userId: 'ana', name: 'Ana', email: 'ana@ejemplo.com'),
          ...extra,
        ],
        pendingMembers: const <PendingGroupMember>[PendingGroupMember(id: 'slot-marta', name: 'Marta')],
        allowAnonymousJoin: false,
        customCategories: const <ExpenseCategory>[],
        expenses: <ExpenseRecord>[
          ExpenseRecord(
            id: 'e1',
            title: 'Compra',
            payerId: 'ana',
            createdAt: DateTime(2026, 7, 18),
            items: const <ExpenseItem>[
              ExpenseItem(
                id: 'l1',
                name: 'Compra',
                amount: 60,
                categoryId: 'groceries',
                allocations: <SplitAllocation>[
                  SplitAllocation(userId: 'ana', percentage: 50),
                  SplitAllocation(userId: 'pending:slot-marta', percentage: 50),
                ],
              ),
            ],
          ),
        ],
        createdAt: DateTime(2026, 7, 17),
        updatedAt: DateTime(2026, 7, 18),
        isClosed: false,
        claimedSlots: claimedSlots,
      );
    }

    test('sin reclamar, la deuda queda a nombre del hueco', () {
      final saldos = memberBalances(grupoConHueco());

      expect(saldos['ana'], 30);
      expect(saldos['pending:slot-marta'], -30);
    });

    test('al reclamarlo, la deuda pasa a la persona sin tocar los gastos', () {
      const marta = GroupMember(userId: 'uid-marta', name: 'Marta', email: 'marta@ejemplo.com');
      final grupo = grupoConHueco(claimedSlots: const <String, String>{'slot-marta': 'uid-marta'}, extra: <GroupMember>[marta]);
      final saldos = memberBalances(grupo);

      expect(saldos['ana'], 30);
      expect(saldos['uid-marta'], -30, reason: 'la deuda del hueco no ha pasado a quien lo reclamo');
      expect(saldos.containsKey('pending:slot-marta'), isFalse, reason: 'el hueco sigue apareciendo como si nadie lo hubiera cogido');

      // Y los gastos siguen exactamente como estaban: ese era el objetivo.
      expect(grupo.expenses.single.items.single.allocations.map((a) => a.userId), contains('pending:slot-marta'));
    });

    test('un hueco reclamado deja de ofrecerse y de contar como miembro pendiente', () {
      const marta = GroupMember(userId: 'uid-marta', name: 'Marta', email: 'marta@ejemplo.com');
      final grupo = grupoConHueco(claimedSlots: const <String, String>{'slot-marta': 'uid-marta'}, extra: <GroupMember>[marta]);

      expect(grupo.openSlots, isEmpty);
      expect(grupo.visibleMembers.map((m) => m.userId), <String>['ana', 'uid-marta']);
      expect(grupo.totalDisplayedMembers, 2);
    });

    test('un reclamo que apunta a alguien que no esta en el grupo se ignora', () {
      // Defensa contra datos incoherentes: si el uid reclamado no es miembro, se
      // sigue tratando como hueco en vez de perder la deuda por el camino.
      final grupo = grupoConHueco(claimedSlots: const <String, String>{'slot-marta': 'uid-fantasma'});
      final saldos = memberBalances(grupo);

      expect(saldos['pending:slot-marta'], -30);
      expect(saldos.values.fold<double>(0, (suma, v) => suma + v).abs(), lessThan(0.011));
    });
  });
}

ExpenseGroup _group({
  required String id,
  required List<GroupMember> members,
  List<PendingGroupMember> pendingMembers = const [],
  List<ExpenseRecord> expenses = const [],
}) {
  final now = DateTime(2026, 3, 14, 12);
  return ExpenseGroup(
    id: id,
    name: 'Group $id',
    iconKey: 'groups',
    currency: 'EUR',
    ownerId: members.first.userId,
    adminIds: const [],
    inviteCode: 'INV$id',
    joinPin: '1234',
    memberIds: members.map((member) => member.userId).toList(growable: false),
    members: members,
    pendingMembers: pendingMembers,
    allowAnonymousJoin: false,
    customCategories: const [],
    expenses: expenses,
    createdAt: now,
    updatedAt: now,
    isClosed: false,
  );
}

ExpenseRecord _expense({required String id, required String payerId, required List<ExpenseItem> items}) {
  return ExpenseRecord(id: id, title: 'Expense $id', payerId: payerId, createdAt: DateTime(2026, 3, 14, 12), items: items);
}

ExpenseItem _item({required double amount, required List<SplitAllocation> allocations}) {
  return ExpenseItem(id: 'item-$amount-${allocations.length}', name: 'Item', amount: amount, categoryId: 'food', allocations: allocations);
}
