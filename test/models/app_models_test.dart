import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/expense_math.dart';
import 'package:shardpay/models/app_models.dart';

void main() {
  group('expense archiving', () {
    test('archiving a group zeroes every expense item and closes the group', () {
      final now = DateTime(2026, 3, 17, 12);
      final group = ExpenseGroup(
        id: 'g1',
        name: 'Grupo demo',
        iconKey: 'groups',
        currency: 'EUR',
        ownerId: 'owner',
        adminIds: const [],
        inviteCode: 'INVITE',
        joinPin: '1234',
        memberIds: const ['owner', 'friend'],
        members: const [
          GroupMember(userId: 'owner', name: 'Owner', email: 'owner@example.com'),
          GroupMember(userId: 'friend', name: 'Friend', email: 'friend@example.com'),
        ],
        pendingMembers: const [],
        allowAnonymousJoin: false,
        customCategories: const [],
        expenses: [
          ExpenseRecord(
            id: 'e1',
            title: 'Cena',
            payerId: 'owner',
            createdAt: now,
            items: const [
              ExpenseItem(
                id: 'i1',
                name: 'Pizza',
                amount: 24,
                categoryId: 'food',
                allocations: [
                  SplitAllocation(userId: 'owner', percentage: 50),
                  SplitAllocation(userId: 'friend', percentage: 50),
                ],
              ),
              ExpenseItem(
                id: 'i2',
                name: 'Bebidas',
                amount: 12,
                categoryId: 'food',
                allocations: [
                  SplitAllocation(userId: 'owner', percentage: 50),
                  SplitAllocation(userId: 'friend', percentage: 50),
                ],
              ),
            ],
          ),
        ],
        createdAt: now,
        updatedAt: now,
        isClosed: false,
      );

      final archived = group.archived(at: now.add(const Duration(hours: 1)));

      expect(archived.isClosed, isTrue);
      expect(archived.closedAt, now.add(const Duration(hours: 1)));
      expect(totalGroupSpend(archived), 0);
      expect(
        archived.expenses.expand((expense) => expense.items).every((item) => item.amount == 0),
        isTrue,
      );
    });
  });

  group('expense totals', () {
    test('totalExpense sums all subexpenses stored as items', () {
      final expense = ExpenseRecord(
        id: 'e2',
        title: 'Compra',
        payerId: 'owner',
        createdAt: DateTime(2026, 3, 17, 12),
        items: const [
          ExpenseItem(
            id: 'i1',
            name: 'Fruta',
            amount: 8.40,
            categoryId: 'groceries',
            allocations: [SplitAllocation(userId: 'owner', percentage: 100)],
          ),
          ExpenseItem(
            id: 'i2',
            name: 'Pan',
            amount: 2.10,
            categoryId: 'groceries',
            allocations: [SplitAllocation(userId: 'owner', percentage: 100)],
          ),
        ],
      );

      expect(totalExpense(expense), closeTo(10.5, 0.001));
    });
  });
}
