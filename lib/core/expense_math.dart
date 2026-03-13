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

  final balanceEntries = balances.entries
      .where((entry) => eligibleIds.contains(entry.key) && entry.value.abs() > 0.009)
      .map((entry) => MapEntry(entry.key, _toCents(entry.value)))
      .toList();

  if (balanceEntries.isEmpty) {
    return const [];
  }

  final userIds = balanceEntries.map((entry) => entry.key).toList(growable: false);
  final cents = balanceEntries.map((entry) => entry.value).toList(growable: false);
  final solution = _settlementEdgesExact(cents, userIds, 0);
  return solution
      .map(
        (entry) => SettlementEdge(
          fromUserId: entry.fromUserId,
          toUserId: entry.toUserId,
          amount: entry.amountInCents / 100,
        ),
      )
      .toList(growable: false);
}

int _toCents(double amount) => (amount * 100).round();

class _SettlementEdgeInCents {
  const _SettlementEdgeInCents({
    required this.fromUserId,
    required this.toUserId,
    required this.amountInCents,
  });

  final String fromUserId;
  final String toUserId;
  final int amountInCents;
}

List<_SettlementEdgeInCents> _settlementEdgesExact(List<int> balances, List<String> userIds, int startIndex) {
  var firstOpenIndex = startIndex;
  while (firstOpenIndex < balances.length && balances[firstOpenIndex] == 0) {
    firstOpenIndex += 1;
  }

  if (firstOpenIndex >= balances.length) {
    return const [];
  }

  List<_SettlementEdgeInCents>? best;
  final seen = <int>{};

  for (var index = firstOpenIndex + 1; index < balances.length; index++) {
    final first = balances[firstOpenIndex];
    final candidate = balances[index];
    if (first == 0 || candidate == 0 || first.sign == candidate.sign || !seen.add(candidate)) {
      continue;
    }

    final transferInCents = math.min(first.abs(), candidate.abs());
    final nextBalances = List<int>.from(balances);
    _SettlementEdgeInCents currentEdge;

    if (first < 0) {
      nextBalances[firstOpenIndex] += transferInCents;
      nextBalances[index] -= transferInCents;
      currentEdge = _SettlementEdgeInCents(
        fromUserId: userIds[firstOpenIndex],
        toUserId: userIds[index],
        amountInCents: transferInCents,
      );
    } else {
      nextBalances[firstOpenIndex] -= transferInCents;
      nextBalances[index] += transferInCents;
      currentEdge = _SettlementEdgeInCents(
        fromUserId: userIds[index],
        toUserId: userIds[firstOpenIndex],
        amountInCents: transferInCents,
      );
    }

    final nextStartIndex = nextBalances[firstOpenIndex] == 0 ? firstOpenIndex + 1 : firstOpenIndex;
    final tail = _settlementEdgesExact(nextBalances, userIds, nextStartIndex);
    final candidateSolution = [currentEdge, ...tail];

    if (best == null || candidateSolution.length < best.length) {
      best = candidateSolution;
      if (best.length == 1) {
        break;
      }
    }
  }

  return best ?? const [];
}