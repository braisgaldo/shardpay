import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../models/app_models.dart';

class SettlementEdge {
  const SettlementEdge({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  final String fromUserId;
  final String toUserId;
  final double amount;
}

class OutstandingExpenseDebt {
  const OutstandingExpenseDebt({
    required this.expense,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.itemNames,
  });

  final ExpenseRecord expense;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final List<String> itemNames;
}

double totalExpense(ExpenseRecord expense) {
  return expense.items.fold(0, (sum, item) => sum + item.amount);
}

double totalGroupSpend(ExpenseGroup group) {
  return group.expenses.fold(0, (sum, expense) => sum + totalExpense(expense));
}

List<SplitAllocation> equalAllocations(List<GroupMember> members) {
  if (members.isEmpty) {
    return const [];
  }

  final base = 100 / members.length;
  var running = 0.0;
  final allocations = <SplitAllocation>[];

  for (var index = 0; index < members.length; index++) {
    final isLast = index == members.length - 1;
    final value = isLast ? double.parse((100 - running).toStringAsFixed(2)) : double.parse(base.toStringAsFixed(2));
    running += value;
    allocations.add(SplitAllocation(userId: members[index].userId, percentage: value));
  }
  return allocations;
}

double memberOwedInExpense(ExpenseRecord expense, String userId) {
  return expense.items.fold(0, (sum, item) {
    final allocation = item.allocations.firstWhereOrNull((entry) => entry.userId == userId);
    return sum + ((allocation?.percentage ?? 0) / 100) * item.amount;
  });
}

Map<String, double> memberBalances(ExpenseGroup group) {
  final balances = <String, double>{
    for (final member in group.visibleMembers) member.userId: 0,
  };

  for (final expense in group.expenses) {
    balances.update(expense.payerId, (value) => value + totalExpense(expense), ifAbsent: () => totalExpense(expense));
    for (final member in group.visibleMembers) {
      balances.update(member.userId, (value) => value - memberOwedInExpense(expense, member.userId), ifAbsent: () => -memberOwedInExpense(expense, member.userId));
    }
  }

  return balances.map((key, value) => MapEntry(key, double.parse(value.toStringAsFixed(2))));
}

Map<String, double> directBalancesForMember(ExpenseGroup group, String memberId) {
  final balances = <String, double>{};

  for (final expense in group.expenses) {
    for (final item in expense.items) {
      for (final allocation in item.allocations) {
        if (allocation.userId == expense.payerId || allocation.percentage <= 0) {
          continue;
        }

        final amount = double.parse((((allocation.percentage / 100) * item.amount)).toStringAsFixed(2));
        if (amount <= 0) {
          continue;
        }

        if (allocation.userId == memberId) {
          balances.update(expense.payerId, (value) => value - amount, ifAbsent: () => -amount);
        }
        if (expense.payerId == memberId) {
          balances.update(allocation.userId, (value) => value + amount, ifAbsent: () => amount);
        }
      }
    }
  }

  return balances.map((key, value) => MapEntry(key, double.parse(value.toStringAsFixed(2)))).removeNearZero();
}

Map<String, double> categoryTotals(Iterable<ExpenseGroup> groups) {
  final totals = <String, double>{};
  for (final group in groups) {
    for (final expense in group.expenses) {
      for (final item in expense.items) {
        totals.update(item.categoryId, (value) => value + item.amount, ifAbsent: () => item.amount);
      }
    }
  }
  return totals;
}

Map<DateTime, double> monthlySpend(Iterable<ExpenseGroup> groups) {
  final totals = <DateTime, double>{};
  for (final group in groups) {
    for (final expense in group.expenses) {
      final bucket = DateTime(expense.createdAt.year, expense.createdAt.month);
      totals.update(bucket, (value) => value + totalExpense(expense), ifAbsent: () => totalExpense(expense));
    }
  }
  return Map.fromEntries(
    totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

double clampChartMax(Iterable<double> values) {
  if (values.isEmpty) {
    return 100;
  }
  final maxValue = values.reduce(math.max);
  return maxValue <= 0 ? 100 : maxValue * 1.25;
}

List<SettlementEdge> settlementEdges(ExpenseGroup group, {bool activeAccountsOnly = true}) {
  final balances = memberBalances(group);
  final eligibleIds = activeAccountsOnly
      ? group.activeMembers.map((member) => member.userId).where((id) => !id.startsWith('pending:')).toSet()
      : balances.keys.toSet();

  final creditors = balances.entries
      .where((entry) => eligibleIds.contains(entry.key) && entry.value.abs() > 0.009)
      .map((entry) => _UserBalanceInCents(userId: entry.key, amountInCents: _toCents(entry.value)))
      .where((entry) => entry.amountInCents > 0)
      .toList()
    ..sort((left, right) => right.amountInCents.compareTo(left.amountInCents));

  final debtors = balances.entries
      .where((entry) => eligibleIds.contains(entry.key) && entry.value.abs() > 0.009)
      .map((entry) => _UserBalanceInCents(userId: entry.key, amountInCents: _toCents(entry.value)))
      .where((entry) => entry.amountInCents < 0)
      .map((entry) => _UserBalanceInCents(userId: entry.userId, amountInCents: entry.amountInCents.abs()))
      .toList()
    ..sort((left, right) => right.amountInCents.compareTo(left.amountInCents));

  if (creditors.isEmpty || debtors.isEmpty) {
    return const [];
  }

  final edges = <SettlementEdge>[];
  var debtorIndex = 0;
  var creditorIndex = 0;

  while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
    final debtor = debtors[debtorIndex];
    final creditor = creditors[creditorIndex];
    final transferInCents = math.min(debtor.amountInCents, creditor.amountInCents);
    if (transferInCents > 0) {
      edges.add(SettlementEdge(fromUserId: debtor.userId, toUserId: creditor.userId, amount: transferInCents / 100));
      debtor.amountInCents -= transferInCents;
      creditor.amountInCents -= transferInCents;
    }

    if (debtor.amountInCents == 0) {
      debtorIndex += 1;
    }
    if (creditor.amountInCents == 0) {
      creditorIndex += 1;
    }
  }

  return edges;
}

int _toCents(double amount) => (amount * 100).round();

class _UserBalanceInCents {
  _UserBalanceInCents({required this.userId, required this.amountInCents});

  final String userId;
  int amountInCents;
}

extension on Map<String, double> {
  Map<String, double> removeNearZero() {
    return Map<String, double>.fromEntries(
      entries.where((entry) => entry.value.abs() > 0.009),
    );
  }
}

List<OutstandingExpenseDebt> outstandingExpenseDebts(ExpenseGroup group, {bool activeAccountsOnly = true}) {
  final eligibleIds = activeAccountsOnly
      ? group.activeMembers.map((member) => member.userId).where((id) => !id.startsWith('pending:')).toSet()
      : group.visibleMembers.map((member) => member.userId).toSet();
  final openDebts = <_OpenExpenseDebt>[];
  final sortedExpenses = [...group.expenses]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  for (final expense in sortedExpenses) {
    if (expense.kind == ExpenseRecordKind.settlement) {
      for (final item in expense.items) {
        for (final allocation in item.allocations.where((entry) => entry.userId != expense.payerId && entry.percentage > 0)) {
          if (!eligibleIds.contains(expense.payerId) || !eligibleIds.contains(allocation.userId)) {
            continue;
          }
          var remaining = double.parse((((allocation.percentage / 100) * item.amount)).toStringAsFixed(2));
          if (remaining <= 0) {
            continue;
          }

          for (final debt in openDebts.where((entry) => entry.fromUserId == expense.payerId && entry.toUserId == allocation.userId && entry.remainingAmount > 0)) {
            final applied = math.min(debt.remainingAmount, remaining);
            debt.remainingAmount = double.parse((debt.remainingAmount - applied).toStringAsFixed(2));
            remaining = double.parse((remaining - applied).toStringAsFixed(2));
            if (remaining <= 0.009) {
              break;
            }
          }
        }
      }
      continue;
    }

    final expenseDebts = <String, _OpenExpenseDebt>{};
    for (final item in expense.items) {
      for (final allocation in item.allocations.where((entry) => entry.userId != expense.payerId && entry.percentage > 0)) {
        if (!eligibleIds.contains(expense.payerId) || !eligibleIds.contains(allocation.userId)) {
          continue;
        }

        final amount = double.parse((((allocation.percentage / 100) * item.amount)).toStringAsFixed(2));
        if (amount <= 0) {
          continue;
        }

        final key = '${allocation.userId}|${expense.payerId}|${expense.id}';
        final current = expenseDebts[key];
        if (current == null) {
          expenseDebts[key] = _OpenExpenseDebt(
            expense: expense,
            fromUserId: allocation.userId,
            toUserId: expense.payerId,
            remainingAmount: amount,
            itemNames: {item.name.trim().isEmpty ? expense.title : item.name.trim()},
          );
        } else {
          current.remainingAmount = double.parse((current.remainingAmount + amount).toStringAsFixed(2));
          current.itemNames.add(item.name.trim().isEmpty ? expense.title : item.name.trim());
        }
      }
    }
    openDebts.addAll(expenseDebts.values);
  }

  return openDebts
      .where((entry) => entry.remainingAmount > 0.009)
      .map(
        (entry) => OutstandingExpenseDebt(
          expense: entry.expense,
          fromUserId: entry.fromUserId,
          toUserId: entry.toUserId,
          amount: double.parse(entry.remainingAmount.toStringAsFixed(2)),
          itemNames: entry.itemNames.toList(growable: false),
        ),
      )
      .toList(growable: false);
}

class _OpenExpenseDebt {
  _OpenExpenseDebt({
    required this.expense,
    required this.fromUserId,
    required this.toUserId,
    required this.remainingAmount,
    required this.itemNames,
  });

  final ExpenseRecord expense;
  final String fromUserId;
  final String toUserId;
  double remainingAmount;
  final Set<String> itemNames;
}