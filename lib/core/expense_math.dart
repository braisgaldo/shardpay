import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../models/app_models.dart';

/// Redondeo monetario a dos decimales.
///
/// Sustituye al `double.parse(valor.toStringAsFixed(2))` que había repartido
/// por todo el fichero. Aquel truco construía una cadena, la volvía a parsear y
/// generaba basura en el montón, y lo hacía dentro de los bucles que recorren
/// cada asignación de cada línea de cada gasto: en un grupo con doscientos
/// gastos eran decenas de miles de cadenas por recálculo de saldos.
double roundMoney(double value) => (value * 100).round() / 100;

/// Importe por debajo del cual se considera que una deuda está saldada.
///
/// Medio céntimo: por encima de eso el redondeo del reparto ya no lo explica.
const double _settledThreshold = 0.009;

class SettlementEdge {
  const SettlementEdge({required this.fromUserId, required this.toUserId, required this.amount});

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

class GroupCounterpartyBalance {
  const GroupCounterpartyBalance({required this.group, required this.counterpartyId, required this.netAmount});

  final ExpenseGroup group;
  final String counterpartyId;
  final double netAmount;
}

class GlobalCounterpartyBalance {
  GlobalCounterpartyBalance({required this.counterpartyId, required this.currency, required this.groupBreakdown, this.scopedGroupId});

  final String counterpartyId;
  final String currency;
  final List<GroupCounterpartyBalance> groupBreakdown;
  final String? scopedGroupId;

  bool get isScopedToGroup => scopedGroupId != null;

  // Los tres agregados se recorrían enteros en cada acceso, y la interfaz los
  // consulta varias veces por tarjeta. Se calculan una vez por instancia.
  late final double netAmount = roundMoney(groupBreakdown.fold<double>(0, (sum, entry) => sum + entry.netAmount));

  late final double totalIncoming = roundMoney(
    groupBreakdown.where((entry) => entry.netAmount > 0).fold<double>(0, (sum, entry) => sum + entry.netAmount),
  );

  late final double totalOutgoing = roundMoney(
    groupBreakdown.where((entry) => entry.netAmount < 0).fold<double>(0, (sum, entry) => sum + entry.netAmount.abs()),
  );
}

class BalanceSummary {
  const BalanceSummary({
    required this.memberId,
    required this.currency,
    required this.netAmount,
    required this.incomingAmount,
    required this.outgoingAmount,
    this.scopedGroupId,
  });

  final String memberId;
  final String currency;
  final double netAmount;
  final double incomingAmount;
  final double outgoingAmount;
  final String? scopedGroupId;
}

// -----------------------------------------------------------------------------
// Índice del grupo
// -----------------------------------------------------------------------------

/// Cache de índices, una entrada por instancia de [ExpenseGroup].
///
/// Un `Expando` no impide que el grupo se recoja: cuando llega una instantánea
/// nueva de Firestore se construye un `ExpenseGroup` nuevo y el índice viejo
/// desaparece con él. Es decir, la cache se invalida sola y no hay que
/// acordarse de limpiarla.
final Expando<GroupLedger> _ledgers = Expando<GroupLedger>('shardpay.groupLedger');

/// Devuelve el índice del grupo, calculándolo la primera vez.
GroupLedger ledgerOf(ExpenseGroup group) {
  return _ledgers[group] ??= GroupLedger._(group);
}

/// Todo lo que se puede precalcular de un grupo.
///
/// El problema que resuelve: `canonicalGroupUserId` llamaba a
/// `group.visibleMembers` —que reconstruía la lista entera— y se invocaba
/// dentro del bucle más interno del cálculo de saldos, una vez por asignación
/// de cada línea de cada gasto. Y `groupBalanceSummaries` repetía el recorrido
/// completo de los gastos **una vez por miembro**. El coste era
/// O(miembros · gastos · líneas · asignaciones · miembros); aquí se hace una
/// sola pasada y el resto son consultas a mapas.
class GroupLedger {
  GroupLedger._(this.group) {
    for (final member in group.visibleMembers) {
      _membersById[member.userId] = member;
    }
    for (final pending in group.pendingMembers) {
      _pendingIds.add(pending.id);
    }
  }

  final ExpenseGroup group;

  final Map<String, GroupMember> _membersById = <String, GroupMember>{};
  final Set<String> _pendingIds = <String>{};
  final Map<String, String> _canonicalCache = <String, String>{};

  Map<String, double>? _memberBalances;
  Map<String, Map<String, double>>? _pairwise;

  /// Identificador canónico de un usuario dentro de este grupo.
  ///
  /// Memoizado: los mismos identificadores aparecen miles de veces al recorrer
  /// los gastos.
  String canonicalId(String rawUserId) {
    final trimmed = rawUserId.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final cached = _canonicalCache[trimmed];
    if (cached != null) {
      return cached;
    }

    final resolved = _resolveCanonicalId(trimmed);
    _canonicalCache[trimmed] = resolved;
    return resolved;
  }

  String _resolveCanonicalId(String trimmed) {
    if (_membersById.containsKey(trimmed)) {
      return trimmed;
    }

    final legacyPendingId = trimmed.startsWith('pending:') ? trimmed.substring('pending:'.length) : trimmed;

    // Un hueco reservado que ya reclamo alguien apunta a esa persona. Antes esto
    // se resolvia reescribiendo todos los gastos del grupo al entrar; ahora la
    // equivalencia se anota en el grupo y se aplica aqui, que es donde importa.
    // Vease ADR-0009 y `ExpenseGroup.claimedSlots`.
    final claimedBy = group.effectiveClaimedSlots[legacyPendingId];
    if (claimedBy != null && _membersById.containsKey(claimedBy)) {
      return claimedBy;
    }

    if (_pendingIds.contains(legacyPendingId)) {
      return 'pending:$legacyPendingId';
    }

    return trimmed;
  }

  GroupMember? memberFor(String rawUserId) {
    final canonical = canonicalId(rawUserId);
    if (canonical.isEmpty) {
      return null;
    }
    return _membersById[canonical];
  }

  /// Saldo neto de cada miembro frente al grupo.
  Map<String, double> get memberBalances => _memberBalances ??= _computeMemberBalances();

  /// Matriz de deudas entre pares.
  ///
  /// `pairwise[a][b]` es lo que **b le debe a a**. Se calcula de una vez para
  /// todo el grupo, en lugar de recorrer los gastos otra vez por cada miembro
  /// del que se quiera saber el desglose.
  Map<String, Map<String, double>> get pairwiseBalances => _pairwise ??= _computePairwiseBalances();

  Map<String, double> _computeMemberBalances() {
    final balances = <String, double>{for (final member in group.visibleMembers) member.userId: 0};

    for (final expense in group.expenses) {
      final payerId = canonicalId(expense.payerId);
      if (payerId.isNotEmpty) {
        balances.update(payerId, (value) => value + totalExpense(expense), ifAbsent: () => totalExpense(expense));
      }

      for (final item in expense.items) {
        // Un mismo usuario puede aparecer dos veces en las asignaciones de una
        // línea por un arrastre de datos antiguos. Solo cuenta la primera, que
        // es lo que hacía el `firstWhereOrNull` original.
        final counted = <String>{};
        for (final allocation in item.allocations) {
          final userId = canonicalId(allocation.userId);
          if (userId.isEmpty || !_membersById.containsKey(userId) || !counted.add(userId)) {
            continue;
          }
          final owed = (allocation.percentage / 100) * item.amount;
          balances.update(userId, (value) => value - owed, ifAbsent: () => -owed);
        }
      }
    }

    return balances.map((key, value) => MapEntry(key, roundMoney(value)));
  }

  Map<String, Map<String, double>> _computePairwiseBalances() {
    final matrix = <String, Map<String, double>>{};

    void add(String creditor, String debtor, double amount) {
      matrix.putIfAbsent(creditor, () => <String, double>{}).update(debtor, (value) => value + amount, ifAbsent: () => amount);
    }

    for (final expense in group.expenses) {
      final payerId = canonicalId(expense.payerId);
      for (final item in expense.items) {
        for (final allocation in item.allocations) {
          if (allocation.percentage <= 0) {
            continue;
          }
          final userId = canonicalId(allocation.userId);
          if (userId == payerId) {
            continue;
          }

          final amount = roundMoney((allocation.percentage / 100) * item.amount);
          if (amount <= 0) {
            continue;
          }

          add(payerId, userId, amount);
          add(userId, payerId, -amount);
        }
      }
    }

    return matrix.map((key, value) => MapEntry(key, value.map((innerKey, innerValue) => MapEntry(innerKey, roundMoney(innerValue)))));
  }
}

// -----------------------------------------------------------------------------
// API pública
// -----------------------------------------------------------------------------

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
    final value = isLast ? roundMoney(100 - running) : roundMoney(base);
    running += value;
    allocations.add(SplitAllocation(userId: members[index].userId, percentage: value));
  }
  return allocations;
}

String canonicalGroupUserId(ExpenseGroup group, String rawUserId) {
  return ledgerOf(group).canonicalId(rawUserId);
}

GroupMember? resolveGroupMember(ExpenseGroup group, String rawUserId) {
  return ledgerOf(group).memberFor(rawUserId);
}

double memberOwedInExpense(ExpenseRecord expense, String userId, {ExpenseGroup? group}) {
  final ledger = group == null ? null : ledgerOf(group);
  final normalizedUserId = ledger == null ? userId.trim() : ledger.canonicalId(userId);
  if (normalizedUserId.isEmpty) {
    return 0;
  }

  return expense.items.fold(0, (sum, item) {
    final allocation = item.allocations.firstWhereOrNull((entry) {
      final allocationUserId = ledger == null ? entry.userId.trim() : ledger.canonicalId(entry.userId);
      return allocationUserId == normalizedUserId;
    });
    return sum + ((allocation?.percentage ?? 0) / 100) * item.amount;
  });
}

Map<String, double> memberBalances(ExpenseGroup group) {
  return ledgerOf(group).memberBalances;
}

Map<String, double> directBalancesForMember(ExpenseGroup group, String memberId) {
  final ledger = ledgerOf(group);
  final canonicalMemberId = ledger.canonicalId(memberId);
  final row = ledger.pairwiseBalances[canonicalMemberId];
  if (row == null) {
    return const <String, double>{};
  }

  return <String, double>{
    for (final entry in row.entries)
      if (entry.value.abs() > _settledThreshold) entry.key: entry.value,
  };
}

List<GroupCounterpartyBalance> groupCounterpartyBalances(ExpenseGroup group, String currentUserId, {required bool includePendingUsers}) {
  final eligibleIds = _eligibleMemberIds(group, includePendingUsers: includePendingUsers);

  return directBalancesForMember(group, currentUserId).entries
      .where((entry) => eligibleIds.contains(entry.key))
      .map((entry) => GroupCounterpartyBalance(group: group, counterpartyId: entry.key, netAmount: entry.value))
      .sorted((left, right) => right.netAmount.abs().compareTo(left.netAmount.abs()))
      .toList(growable: false);
}

List<GlobalCounterpartyBalance> globalCounterpartyBalances(
  Iterable<ExpenseGroup> groups,
  String currentUserId, {
  required bool includePendingUsers,
}) {
  final grouped = <String, List<GroupCounterpartyBalance>>{};
  final scopedGroupIds = <String, String?>{};

  for (final group in groups) {
    for (final balance in groupCounterpartyBalances(group, currentUserId, includePendingUsers: includePendingUsers)) {
      final isPendingCounterparty = balance.counterpartyId.startsWith('pending:');
      final key = isPendingCounterparty
          ? '${balance.counterpartyId}|${group.currency}|${group.id}'
          : '${balance.counterpartyId}|${group.currency}';
      grouped.putIfAbsent(key, () => <GroupCounterpartyBalance>[]).add(balance);
      scopedGroupIds[key] = isPendingCounterparty ? group.id : null;
    }
  }

  return grouped.entries
      .map((entry) {
        final parts = entry.key.split('|');
        return GlobalCounterpartyBalance(
          counterpartyId: parts.first,
          currency: parts[1],
          groupBreakdown: entry.value
              .sorted((left, right) => right.netAmount.abs().compareTo(left.netAmount.abs()))
              .toList(growable: false),
          scopedGroupId: scopedGroupIds[entry.key],
        );
      })
      .where((entry) => entry.netAmount.abs() > _settledThreshold)
      .sorted((left, right) => right.netAmount.abs().compareTo(left.netAmount.abs()))
      .toList(growable: false);
}

List<BalanceSummary> groupBalanceSummaries(ExpenseGroup group, {bool includePendingUsers = true}) {
  final ledger = ledgerOf(group);
  final eligibleMembers = includePendingUsers ? group.visibleMembers : group.activeMembers;
  final eligibleIds = _eligibleMemberIds(group, includePendingUsers: includePendingUsers);
  final netBalances = ledger.memberBalances;
  final pairwise = ledger.pairwiseBalances;

  return eligibleMembers
      .map((member) {
        // Antes esto recorría los gastos del grupo entero una vez por miembro.
        // Ahora consulta la fila del miembro en la matriz ya calculada.
        final row = pairwise[member.userId];
        var incomingAmount = 0.0;
        var outgoingAmount = 0.0;

        if (row != null) {
          for (final entry in row.entries) {
            if (!eligibleIds.contains(entry.key) || entry.value.abs() <= _settledThreshold) {
              continue;
            }
            if (entry.value > 0) {
              incomingAmount += entry.value;
            } else {
              outgoingAmount += entry.value.abs();
            }
          }
        }

        return BalanceSummary(
          memberId: member.userId,
          currency: group.currency,
          netAmount: roundMoney(netBalances[member.userId] ?? 0),
          incomingAmount: roundMoney(incomingAmount),
          outgoingAmount: roundMoney(outgoingAmount),
        );
      })
      .sorted((left, right) => right.netAmount.abs().compareTo(left.netAmount.abs()))
      .toList(growable: false);
}

List<BalanceSummary> globalBalanceSummaries(Iterable<ExpenseGroup> groups, String currentUserId, {required bool includePendingUsers}) {
  return globalCounterpartyBalances(groups, currentUserId, includePendingUsers: includePendingUsers)
      .map(
        (entry) => BalanceSummary(
          memberId: entry.counterpartyId,
          currency: entry.currency,
          netAmount: entry.netAmount,
          incomingAmount: entry.totalIncoming,
          outgoingAmount: entry.totalOutgoing,
          scopedGroupId: entry.scopedGroupId,
        ),
      )
      .toList(growable: false);
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
      final amount = totalExpense(expense);
      totals.update(bucket, (value) => value + amount, ifAbsent: () => amount);
    }
  }
  return Map.fromEntries(totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
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

  final creditors = <_UserBalanceInCents>[];
  final debtors = <_UserBalanceInCents>[];

  for (final entry in balances.entries) {
    if (!eligibleIds.contains(entry.key) || entry.value.abs() <= _settledThreshold) {
      continue;
    }
    final cents = _toCents(entry.value);
    if (cents > 0) {
      creditors.add(_UserBalanceInCents(userId: entry.key, amountInCents: cents));
    } else if (cents < 0) {
      debtors.add(_UserBalanceInCents(userId: entry.key, amountInCents: -cents));
    }
  }

  if (creditors.isEmpty || debtors.isEmpty) {
    return const [];
  }

  creditors.sort((left, right) => right.amountInCents.compareTo(left.amountInCents));
  debtors.sort((left, right) => right.amountInCents.compareTo(left.amountInCents));

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

List<OutstandingExpenseDebt> outstandingExpenseDebts(ExpenseGroup group, {bool activeAccountsOnly = true}) {
  final eligibleIds = _eligibleMemberIds(group, includePendingUsers: !activeAccountsOnly);
  final openDebts = <_OpenExpenseDebt>[];

  // Índice por par deudor-acreedor. La versión anterior recorría *toda* la
  // lista de deudas abiertas por cada asignación de cada reembolso, con coste
  // cuadrático en grupos con historial largo.
  final debtsByPair = <String, List<_OpenExpenseDebt>>{};

  final sortedExpenses = [...group.expenses]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  for (final expense in sortedExpenses) {
    if (expense.kind == ExpenseRecordKind.settlement) {
      for (final item in expense.items) {
        for (final allocation in item.allocations) {
          if (allocation.userId == expense.payerId || allocation.percentage <= 0) {
            continue;
          }
          if (!eligibleIds.contains(expense.payerId) || !eligibleIds.contains(allocation.userId)) {
            continue;
          }

          var remaining = roundMoney((allocation.percentage / 100) * item.amount);
          if (remaining <= 0) {
            continue;
          }

          // Un reembolso de A a B cancela lo que A le debía a B, en orden
          // cronológico.
          final pending = debtsByPair['${expense.payerId}|${allocation.userId}'];
          if (pending == null) {
            continue;
          }

          for (final debt in pending) {
            if (debt.remainingAmount <= 0) {
              continue;
            }
            final applied = math.min(debt.remainingAmount, remaining);
            debt.remainingAmount = roundMoney(debt.remainingAmount - applied);
            remaining = roundMoney(remaining - applied);
            if (remaining <= _settledThreshold) {
              break;
            }
          }
        }
      }
      continue;
    }

    final expenseDebts = <String, _OpenExpenseDebt>{};
    for (final item in expense.items) {
      for (final allocation in item.allocations) {
        if (allocation.userId == expense.payerId || allocation.percentage <= 0) {
          continue;
        }
        if (!eligibleIds.contains(expense.payerId) || !eligibleIds.contains(allocation.userId)) {
          continue;
        }

        final amount = roundMoney((allocation.percentage / 100) * item.amount);
        if (amount <= 0) {
          continue;
        }

        final key = '${allocation.userId}|${expense.payerId}|${expense.id}';
        final current = expenseDebts[key];
        final itemName = item.name.trim().isEmpty ? expense.title : item.name.trim();

        if (current == null) {
          expenseDebts[key] = _OpenExpenseDebt(
            expense: expense,
            fromUserId: allocation.userId,
            toUserId: expense.payerId,
            remainingAmount: amount,
            itemNames: <String>{itemName},
          );
        } else {
          current.remainingAmount = roundMoney(current.remainingAmount + amount);
          current.itemNames.add(itemName);
        }
      }
    }

    for (final debt in expenseDebts.values) {
      openDebts.add(debt);
      debtsByPair.putIfAbsent('${debt.fromUserId}|${debt.toUserId}', () => <_OpenExpenseDebt>[]).add(debt);
    }
  }

  return openDebts
      .where((entry) => entry.remainingAmount > _settledThreshold)
      .map(
        (entry) => OutstandingExpenseDebt(
          expense: entry.expense,
          fromUserId: entry.fromUserId,
          toUserId: entry.toUserId,
          amount: roundMoney(entry.remainingAmount),
          itemNames: entry.itemNames.toList(growable: false),
        ),
      )
      .toList(growable: false);
}

Set<String> _eligibleMemberIds(ExpenseGroup group, {required bool includePendingUsers}) {
  final source = includePendingUsers ? group.visibleMembers : group.activeMembers;
  return <String>{
    for (final member in source)
      if (includePendingUsers || !member.userId.startsWith('pending:')) member.userId,
  };
}

int _toCents(double amount) => (amount * 100).round();

class _UserBalanceInCents {
  _UserBalanceInCents({required this.userId, required this.amountInCents});

  final String userId;
  int amountInCents;
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
