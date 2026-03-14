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
              _item(amount: 90, allocations: const [
                SplitAllocation(userId: 'b', percentage: 50),
                SplitAllocation(userId: 'c', percentage: 50),
              ]),
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
              items: [_item(amount: 10, allocations: const [SplitAllocation(userId: 'b', percentage: 100)])],
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
              items: [_item(amount: 20, allocations: const [SplitAllocation(userId: 'b', percentage: 100)])],
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
              items: [_item(amount: 12, allocations: const [SplitAllocation(userId: 'pending:p1', percentage: 100)])],
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
              items: [_item(amount: 8, allocations: const [SplitAllocation(userId: 'pending:p2', percentage: 100)])],
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
            items: [_item(amount: 30, allocations: const [SplitAllocation(userId: 'c', percentage: 100)])],
          ),
          _expense(
            id: 'e2',
            payerId: 'b',
            items: [_item(amount: 20, allocations: const [SplitAllocation(userId: 'a', percentage: 100)])],
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
            items: [_item(amount: 15, allocations: const [SplitAllocation(userId: 'b', percentage: 100)])],
          ),
        ],
      );

      final groupSummaryA = groupBalanceSummaries(firstGroup).firstWhere((entry) => entry.memberId == 'a');
      expect(groupSummaryA.incomingAmount, 30);
      expect(groupSummaryA.outgoingAmount, 20);
      expect(groupSummaryA.netAmount, 10);

      final globalSummaryB = globalBalanceSummaries([firstGroup, secondGroup], 'a', includePendingUsers: false)
          .firstWhere((entry) => entry.memberId == 'b');
      expect(globalSummaryB.incomingAmount, 15);
      expect(globalSummaryB.outgoingAmount, 20);
      expect(globalSummaryB.netAmount, -5);
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

ExpenseRecord _expense({
  required String id,
  required String payerId,
  required List<ExpenseItem> items,
}) {
  return ExpenseRecord(
    id: id,
    title: 'Expense $id',
    payerId: payerId,
    createdAt: DateTime(2026, 3, 14, 12),
    items: items,
  );
}

ExpenseItem _item({required double amount, required List<SplitAllocation> allocations}) {
  return ExpenseItem(
    id: 'item-$amount-${allocations.length}',
    name: 'Item',
    amount: amount,
    categoryId: 'food',
    allocations: allocations,
  );
}