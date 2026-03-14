import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_text.dart';
import '../../app/providers.dart';
import '../../core/defaults.dart';
import '../../core/expense_math.dart';
import '../../models/app_models.dart';

class GlobalBalancesScreen extends ConsumerStatefulWidget {
  const GlobalBalancesScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<GlobalBalancesScreen> createState() => _GlobalBalancesScreenState();
}

class _GlobalBalancesScreenState extends ConsumerState<GlobalBalancesScreen> {
  bool _includePendingUsers = false;

  Future<void> _refreshGroups() async {
    ref.invalidate(groupsProvider(widget.user.id));
    await ref.read(groupsProvider(widget.user.id).future);
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsProvider(widget.user.id));

    return SafeArea(
      child: groupsState.when(
        data: (groups) {
          final entries = _buildEntries(groups, widget.user.id, includePendingUsers: _includePendingUsers);
          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshGroups,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                _PendingToggleCard(
                  value: _includePendingUsers,
                  onChanged: (value) => setState(() => _includePendingUsers = value),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr(context, es: 'No tienes deudas ni cobros pendientes ${_includePendingUsers ? 'incluyendo personas pendientes' : 'con cuentas reales'} en tus grupos.', en: 'You have no pending debts or claims ${_includePendingUsers ? 'including pending people' : 'with real accounts'} across your groups.', gl: 'Non tes debedas nin cobros pendentes ${_includePendingUsers ? 'incluindo persoas pendentes' : 'con contas reais'} nos teus grupos.', fr: 'Vous n avez ni dettes ni creances en attente ${_includePendingUsers ? 'y compris avec les personnes en attente' : 'avec des comptes reels'} dans vos groupes.', it: 'Non hai debiti o crediti pendenti ${_includePendingUsers ? 'inclusi gli utenti in attesa' : 'con account reali'} nei tuoi gruppi.', pt: 'Nao tens dividas nem cobrancas pendentes ${_includePendingUsers ? 'incluindo pessoas pendentes' : 'com contas reais'} nos teus grupos.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshGroups,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
              _PendingToggleCard(
                value: _includePendingUsers,
                onChanged: (value) => setState(() => _includePendingUsers = value),
              ),
              const SizedBox(height: 16),
              ...List.generate(entries.length, (index) {
                final entry = entries[index];
                final isTheyOweYou = entry.netAmount > 0;
                final tone = isTheyOweYou ? const Color(0xFFE8F7EF) : const Color(0xFFFFF3E2);
                final accent = isTheyOweYou ? const Color(0xFF1E8E5A) : const Color(0xFFC77600);
                return Padding(
                  padding: EdgeInsets.only(bottom: index == entries.length - 1 ? 0 : 12),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => _showSettlementSheet(context, ref, entry, widget.user.id),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.counterparty.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(isTheyOweYou ? tr(context, es: 'Te debe dinero', en: 'Owes you money', gl: 'Debeche diñeiro', fr: 'Vous doit de l argent', it: 'Ti deve denaro', pt: 'Deve-te dinheiro') : tr(context, es: 'Le debes dinero', en: 'You owe money', gl: 'Debeslle diñeiro', fr: 'Vous lui devez de l argent', it: 'Gli devi denaro', pt: 'Deves-lhe dinheiro')),
                                  const SizedBox(height: 8),
                                  Text(
                                    tr(
                                      context,
                                      es: '${entry.groupBreakdown.length} grupos pendientes',
                                      en: '${entry.groupBreakdown.length} pending groups',
                                      gl: '${entry.groupBreakdown.length} grupos pendentes',
                                      fr: '${entry.groupBreakdown.length} groupes en attente',
                                      it: '${entry.groupBreakdown.length} gruppi pendenti',
                                      pt: '${entry.groupBreakdown.length} grupos pendentes',
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(999)),
                                  child: Text('${isTheyOweYou ? '+' : '-'}${money(entry.netAmount.abs(), entry.currency)}', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  tr(context, es: 'Ver liquidación', en: 'Open settlement', gl: 'Ver liquidacion', fr: 'Voir liquidation', it: 'Vedi liquidazione', pt: 'Ver liquidacao'),
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _showSettlementSheet(BuildContext context, WidgetRef ref, _CounterpartyEntry entry, String currentUserId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.counterparty.name, style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    entry.netAmount >= 0 ? '+${money(entry.netAmount.abs(), entry.currency)}' : '-${money(entry.netAmount.abs(), entry.currency)}',
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _showBalanceHistorySheet(sheetContext, entry, currentUserId),
                      icon: const Icon(Icons.history_rounded),
                      label: Text(tr(sheetContext, es: 'Ver historial', en: 'View history', gl: 'Ver historial', fr: 'Voir historique', it: 'Vedi storico', pt: 'Ver historico')),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: entry.groupBreakdown.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        if (index == entry.groupBreakdown.length) {
                          final totalAccent = entry.netAmount >= 0 ? const Color(0xFF1E8E5A) : const Color(0xFFC77600);
                          return _SettlementCard(
                            title: tr(sheetContext, es: 'Total entre ambos', en: 'Total between both', gl: 'Total entre ambos', fr: 'Total entre les deux', it: 'Totale tra voi', pt: 'Total entre ambos'),
                            subtitle: tr(
                              sheetContext,
                              es: 'Ingresos ${money(entry.totalIncoming, entry.currency)} · Gastos ${money(entry.totalOutgoing, entry.currency)}',
                              en: 'Income ${money(entry.totalIncoming, entry.currency)} · Expenses ${money(entry.totalOutgoing, entry.currency)}',
                              gl: 'Ingresos ${money(entry.totalIncoming, entry.currency)} · Gastos ${money(entry.totalOutgoing, entry.currency)}',
                              fr: 'Entrees ${money(entry.totalIncoming, entry.currency)} · Depenses ${money(entry.totalOutgoing, entry.currency)}',
                              it: 'Entrate ${money(entry.totalIncoming, entry.currency)} · Uscite ${money(entry.totalOutgoing, entry.currency)}',
                              pt: 'Entradas ${money(entry.totalIncoming, entry.currency)} · Gastos ${money(entry.totalOutgoing, entry.currency)}',
                            ),
                            amount: entry.netAmount.abs(),
                            currency: entry.currency,
                            accent: totalAccent,
                            requestEnabled: entry.canRequestAll,
                            payEnabled: entry.canPayAll && entry.groupBreakdown.where((groupDebt) => groupDebt.netAmount.abs() > 0.009).every((groupDebt) => !groupDebt.group.isClosed),
                            requestLabel: tr(sheetContext, es: 'Solicitar todo', en: 'Request all', gl: 'Solicitar todo', fr: 'Demander tout', it: 'Richiedi tutto', pt: 'Solicitar tudo'),
                            payLabel: tr(sheetContext, es: 'Saldar todo', en: 'Settle all', gl: 'Saldar todo', fr: 'Regler tout', it: 'Saldare tutto', pt: 'Liquidar tudo'),
                            leading: const Icon(Icons.summarize_rounded),
                            onRequest: () async {
                              Navigator.of(sheetContext).pop();
                              await _requestAllSettlements(context, ref, entry, currentUserId);
                            },
                            onPay: () async {
                              Navigator.of(sheetContext).pop();
                              await _recordAllSettlements(context, ref, entry, currentUserId);
                            },
                          );
                        }
                        final groupDebt = entry.groupBreakdown[index];
                        final currentUserIsCreditor = groupDebt.netAmount > 0;
                        final accent = currentUserIsCreditor ? const Color(0xFF1E8E5A) : const Color(0xFFC77600);
                        return _SettlementCard(
                          title: groupDebt.group.name,
                          subtitle: tr(sheetContext, es: 'Liquidación del grupo', en: 'Group settlement', gl: 'Liquidacion do grupo', fr: 'Liquidation du groupe', it: 'Liquidazione del gruppo', pt: 'Liquidacao do grupo'),
                          amount: groupDebt.netAmount.abs(),
                          currency: groupDebt.group.currency,
                          accent: accent,
                          leading: Icon(groupIconForKey(groupDebt.group.iconKey), color: accent),
                          requestEnabled: currentUserIsCreditor,
                          payEnabled: !groupDebt.group.isClosed,
                          onRequest: () async {
                            Navigator.of(sheetContext).pop();
                            await _requestGroupSettlement(context, ref, groupDebt, currentUserId);
                          },
                          onPay: () async {
                            Navigator.of(sheetContext).pop();
                            await _recordGroupSettlement(context, ref, groupDebt, currentUserId);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBalanceHistorySheet(BuildContext context, _CounterpartyEntry entry, String currentUserId) async {
    final historyEntries = _buildHistoryEntries(entry, currentUserId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(sheetContext, es: 'Historial con ${entry.counterparty.name}', en: 'History with ${entry.counterparty.name}', gl: 'Historial con ${entry.counterparty.name}', fr: 'Historique avec ${entry.counterparty.name}', it: 'Storico con ${entry.counterparty.name}', pt: 'Historico com ${entry.counterparty.name}'), style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: historyEntries.isEmpty
                        ? Center(
                            child: Text(tr(sheetContext, es: 'Todavía no hay movimientos entre ambas personas.', en: 'There are no movements between both people yet.', gl: 'Ainda non hai movementos entre ambas persoas.', fr: 'Il n y a pas encore de mouvements entre ces deux personnes.', it: 'Non ci sono ancora movimenti tra le due persone.', pt: 'Ainda nao ha movimentos entre ambas as pessoas.')),
                          )
                        : ListView.separated(
                            itemCount: historyEntries.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final item = historyEntries[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(item.title, style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: item.amount >= 0 ? const Color(0xFFE8F7EF) : const Color(0xFFFFF3E2),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '${item.amount >= 0 ? '+' : '-'}${money(item.amount.abs(), item.currency)}',
                                            style: TextStyle(color: item.amount >= 0 ? const Color(0xFF1E8E5A) : const Color(0xFFC77600), fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${item.groupName} · ${DateFormat('dd/MM/yyyy HH:mm', localeTag(sheetContext)).format(item.createdAt)}'),
                                    if (item.note != null && item.note!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(item.note!),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CounterpartyEntry {
  const _CounterpartyEntry({required this.counterparty, required this.groupBreakdown, required this.netAmount, required this.currency});

  final GroupMember counterparty;
  final List<_GroupDebtEntry> groupBreakdown;
  final double netAmount;
  final String currency;

  double get totalIncoming => groupBreakdown.where((entry) => entry.netAmount > 0).fold<double>(0, (sum, entry) => sum + entry.netAmount);

  double get totalOutgoing => groupBreakdown.where((entry) => entry.netAmount < 0).fold<double>(0, (sum, entry) => sum + entry.netAmount.abs());

  bool get canRequestAll => totalIncoming > 0.009;

  bool get canPayAll => groupBreakdown.any((entry) => entry.netAmount.abs() > 0.009);
}

class _GroupDebtEntry {
  const _GroupDebtEntry({required this.group, required this.counterparty, required this.netAmount});

  final ExpenseGroup group;
  final GroupMember counterparty;
  final double netAmount;
}

class _BalanceHistoryEntry {
  const _BalanceHistoryEntry({
    required this.groupName,
    required this.title,
    required this.createdAt,
    required this.amount,
    required this.currency,
    this.note,
  });

  final String groupName;
  final String title;
  final DateTime createdAt;
  final double amount;
  final String currency;
  final String? note;
}

List<_BalanceHistoryEntry> _buildHistoryEntries(_CounterpartyEntry entry, String currentUserId) {
  final history = <_BalanceHistoryEntry>[];

  for (final groupDebt in entry.groupBreakdown) {
    for (final expense in groupDebt.group.expenses) {
      final counterpartAllocations = expense.items.expand((item) => item.allocations).where((allocation) => allocation.userId == entry.counterparty.userId && allocation.percentage > 0);
      final currentAllocations = expense.items.expand((item) => item.allocations).where((allocation) => allocation.userId == currentUserId && allocation.percentage > 0);
      final involvesBoth = expense.payerId == currentUserId
          ? counterpartAllocations.isNotEmpty
          : expense.payerId == entry.counterparty.userId
              ? currentAllocations.isNotEmpty
              : counterpartAllocations.isNotEmpty && currentAllocations.isNotEmpty;
      if (!involvesBoth) {
        continue;
      }

      double signedAmount;
      if (expense.kind == ExpenseRecordKind.settlement) {
        final paidToCounterparty = expense.payerId == currentUserId && counterpartAllocations.isNotEmpty;
        final receivedFromCounterparty = expense.payerId == entry.counterparty.userId && currentAllocations.isNotEmpty;
        final settlementAmount = totalExpense(expense);
        signedAmount = receivedFromCounterparty ? settlementAmount : paidToCounterparty ? -settlementAmount : 0;
      } else {
        final paidByCurrent = expense.payerId == currentUserId;
        final paidByCounterparty = expense.payerId == entry.counterparty.userId;
        final currentShare = memberOwedInExpense(expense, currentUserId);
        final counterpartyShare = memberOwedInExpense(expense, entry.counterparty.userId);
        if (paidByCurrent) {
          signedAmount = counterpartyShare;
        } else if (paidByCounterparty) {
          signedAmount = -currentShare;
        } else {
          signedAmount = 0;
        }
      }

      if (signedAmount.abs() <= 0.009) {
        continue;
      }

      history.add(
        _BalanceHistoryEntry(
          groupName: groupDebt.group.name,
          title: expense.title,
          createdAt: expense.createdAt,
          amount: double.parse(signedAmount.toStringAsFixed(2)),
          currency: groupDebt.group.currency,
          note: expense.note,
        ),
      );
    }
  }

  history.sort((left, right) => right.createdAt.compareTo(left.createdAt));
  return history;
}

List<_CounterpartyEntry> _buildEntries(List<ExpenseGroup> groups, String currentUserId, {required bool includePendingUsers}) {
  final perUserAndCurrency = <String, Map<String, _GroupDebtEntry>>{};
  final userById = <String, GroupMember>{};

  for (final group in groups) {
    final members = includePendingUsers ? group.visibleMembers : group.activeMembers;
    for (final member in members) {
      userById[member.userId] = member;
    }
    final edges = settlementEdges(group, activeAccountsOnly: !includePendingUsers);
    for (final edge in edges.where((entry) => entry.fromUserId == currentUserId || entry.toUserId == currentUserId)) {
      final counterpartyId = edge.fromUserId == currentUserId ? edge.toUserId : edge.fromUserId;
      final counterparty = userById[counterpartyId] ?? members.firstWhereOrNull((member) => member.userId == counterpartyId);
      if (counterparty == null) {
        continue;
      }
      final key = '$counterpartyId|${group.currency}';
      final netDelta = edge.toUserId == currentUserId ? edge.amount : -edge.amount;
      final perGroup = perUserAndCurrency.putIfAbsent(key, () => {});
      final current = perGroup[group.id];
      perGroup[group.id] = _GroupDebtEntry(group: group, counterparty: counterparty, netAmount: double.parse(((current?.netAmount ?? 0) + netDelta).toStringAsFixed(2)));
    }
  }

  return perUserAndCurrency.entries.map((entry) {
    final keyParts = entry.key.split('|');
    final counterparty = userById[keyParts.first]!;
    final groupBreakdown = entry.value.values.where((item) => item.netAmount.abs() > 0.009).sorted((a, b) => b.netAmount.abs().compareTo(a.netAmount.abs())).toList();
    final netAmount = groupBreakdown.fold<double>(0, (total, item) => total + item.netAmount);
    return _CounterpartyEntry(
      counterparty: counterparty,
      groupBreakdown: groupBreakdown,
      netAmount: double.parse(netAmount.toStringAsFixed(2)),
      currency: keyParts.last,
    );
  }).where((entry) => entry.netAmount.abs() > 0.009).sorted((a, b) => b.netAmount.abs().compareTo(a.netAmount.abs())).toList();
}

Future<void> _requestGroupSettlement(BuildContext context, WidgetRef ref, _GroupDebtEntry entry, String currentUserId) async {
  final controller = TextEditingController(text: entry.netAmount.abs().toStringAsFixed(2));
  final amount = await showDialog<double>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(tr(context, es: 'Solicitar dinero', en: 'Request money', gl: 'Solicitar diñeiro', fr: 'Demander argent', it: 'Richiedi denaro', pt: 'Solicitar dinheiro')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr(context, es: 'Cantidad', en: 'Amount', gl: 'Cantidade', fr: 'Montant', it: 'Importo', pt: 'Quantia')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(double.tryParse(controller.text.replaceAll(',', '.'))), child: Text(tr(context, es: 'Enviar', en: 'Send', gl: 'Enviar', fr: 'Envoyer', it: 'Invia', pt: 'Enviar'))),
        ],
      );
    },
  );
  if (amount == null || amount <= 0) {
    return;
  }
  await ref.read(repositoryProvider).requestReimbursement(
        groupId: entry.group.id,
        requesterId: currentUserId,
        targetUserId: entry.counterparty.userId,
        amount: amount,
      );
}

Future<void> _recordGroupSettlement(BuildContext context, WidgetRef ref, _GroupDebtEntry entry, String currentUserId) async {
  final youLabel = tr(context, es: 'Tú', en: 'You', gl: 'Ti', fr: 'Vous', it: 'Tu', pt: 'Tu');
  final controller = TextEditingController(text: entry.netAmount.abs().toStringAsFixed(2));
  final amount = await showDialog<double>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(tr(context, es: 'Registrar pago', en: 'Record payment', gl: 'Rexistrar pago', fr: 'Enregistrer paiement', it: 'Registra pagamento', pt: 'Registar pagamento')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr(context, es: 'Cantidad', en: 'Amount', gl: 'Cantidade', fr: 'Montant', it: 'Importo', pt: 'Quantia')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(double.tryParse(controller.text.replaceAll(',', '.'))), child: Text(tr(context, es: 'Guardar', en: 'Save', gl: 'Gardar', fr: 'Enregistrer', it: 'Salva', pt: 'Guardar'))),
        ],
      );
    },
  );
  if (amount == null || amount <= 0) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  final currentUserIsDebtor = entry.netAmount < 0;
  await _createSettlementExpense(
    context,
    ref,
    group: entry.group,
    debtorId: currentUserIsDebtor ? currentUserId : entry.counterparty.userId,
    creditorId: currentUserIsDebtor ? entry.counterparty.userId : currentUserId,
    amount: amount,
    debtorName: currentUserIsDebtor ? youLabel : entry.counterparty.name,
    creditorName: currentUserIsDebtor ? entry.counterparty.name : youLabel,
  );
}

Future<void> _requestAllSettlements(BuildContext context, WidgetRef ref, _CounterpartyEntry entry, String currentUserId) async {
  final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(tr(context, es: 'Solicitar todo', en: 'Request all', gl: 'Solicitar todo', fr: 'Demander tout', it: 'Richiedi tutto', pt: 'Solicitar tudo')),
            content: Text(tr(context, es: 'Se enviará una solicitud por cada grupo pendiente con ${entry.counterparty.name}.', en: 'A request will be sent for each pending group with ${entry.counterparty.name}.', gl: 'Enviarase unha solicitude por cada grupo pendente con ${entry.counterparty.name}.', fr: 'Une demande sera envoyee pour chaque groupe en attente avec ${entry.counterparty.name}.', it: 'Sarà inviata una richiesta per ogni gruppo pendente con ${entry.counterparty.name}.', pt: 'Será enviado um pedido por cada grupo pendente com ${entry.counterparty.name}.')),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(tr(context, es: 'Enviar', en: 'Send', gl: 'Enviar', fr: 'Envoyer', it: 'Invia', pt: 'Enviar'))),
            ],
          );
        },
      ) ??
      false;
  if (!approved) {
    return;
  }
  for (final groupDebt in entry.groupBreakdown.where((groupDebt) => groupDebt.netAmount > 0)) {
    await ref.read(repositoryProvider).requestReimbursement(
          groupId: groupDebt.group.id,
          requesterId: currentUserId,
          targetUserId: groupDebt.counterparty.userId,
          amount: groupDebt.netAmount.abs(),
        );
  }
}

Future<void> _recordAllSettlements(BuildContext context, WidgetRef ref, _CounterpartyEntry entry, String currentUserId) async {
  final youLabel = tr(context, es: 'Tú', en: 'You', gl: 'Ti', fr: 'Vous', it: 'Tu', pt: 'Tu');
  final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(tr(context, es: 'Marcar todo pagado', en: 'Mark all as paid', gl: 'Marcar todo pagado', fr: 'Tout marquer comme paye', it: 'Segna tutto come pagato', pt: 'Marcar tudo como pago')),
            content: Text(tr(context, es: 'Se registrará una liquidación en cada grupo pendiente con ${entry.counterparty.name}.', en: 'A settlement will be recorded in each pending group with ${entry.counterparty.name}.', gl: 'Rexistrarase unha liquidacion en cada grupo pendente con ${entry.counterparty.name}.', fr: 'Une liquidation sera enregistree dans chaque groupe en attente avec ${entry.counterparty.name}.', it: 'Verrà registrata una liquidazione in ogni gruppo pendente con ${entry.counterparty.name}.', pt: 'Será registada uma liquidacao em cada grupo pendente com ${entry.counterparty.name}.')),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(tr(context, es: 'Guardar', en: 'Save', gl: 'Gardar', fr: 'Enregistrer', it: 'Salva', pt: 'Guardar'))),
            ],
          );
        },
      ) ??
      false;
  if (!approved) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  for (final groupDebt in entry.groupBreakdown.where((groupDebt) => groupDebt.netAmount.abs() > 0.009)) {
    final currentUserIsDebtor = groupDebt.netAmount < 0;
    await _createSettlementExpense(
      context,
      ref,
      group: groupDebt.group,
      debtorId: currentUserIsDebtor ? currentUserId : groupDebt.counterparty.userId,
      creditorId: currentUserIsDebtor ? groupDebt.counterparty.userId : currentUserId,
      amount: groupDebt.netAmount.abs(),
      debtorName: currentUserIsDebtor ? youLabel : groupDebt.counterparty.name,
      creditorName: currentUserIsDebtor ? groupDebt.counterparty.name : youLabel,
    );
  }
}

Future<void> _createSettlementExpense(
  BuildContext context,
  WidgetRef ref, {
  required ExpenseGroup group,
  required String debtorId,
  required String creditorId,
  required double amount,
  required String debtorName,
  required String creditorName,
}) async {
  if (group.isClosed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, es: 'Reabre el grupo antes de registrar una liquidación.', en: 'Reopen the group before recording a settlement.', gl: 'Reabre o grupo antes de rexistrar unha liquidacion.', fr: 'Rouvrez le groupe avant d enregistrer une liquidation.', it: 'Riapri il gruppo prima di registrare una liquidazione.', pt: 'Reabre o grupo antes de registar uma liquidacao.')),
      ),
    );
    return;
  }
  final uuid = const Uuid();
  final expense = ExpenseRecord(
    id: uuid.v4(),
    title: tr(context, es: 'Liquidación de grupo', en: 'Group settlement', gl: 'Liquidacion de grupo', fr: 'Liquidation de groupe', it: 'Liquidazione di gruppo', pt: 'Liquidacao de grupo'),
    payerId: debtorId,
    createdAt: DateTime.now(),
    kind: ExpenseRecordKind.settlement,
    note: tr(context, es: 'Pago entre $debtorName y $creditorName.', en: 'Payment between $debtorName and $creditorName.', gl: 'Pago entre $debtorName e $creditorName.', fr: 'Paiement entre $debtorName et $creditorName.', it: 'Pagamento tra $debtorName e $creditorName.', pt: 'Pagamento entre $debtorName e $creditorName.'),
    items: [
      ExpenseItem(
        id: uuid.v4(),
        name: tr(context, es: 'Pago registrado', en: 'Recorded payment', gl: 'Pago rexistrado', fr: 'Paiement enregistre', it: 'Pagamento registrato', pt: 'Pagamento registado'),
        amount: amount,
        categoryId: 'work',
        allocations: [
          SplitAllocation(userId: creditorId, percentage: 100),
          SplitAllocation(userId: debtorId, percentage: 0),
        ],
      ),
    ],
  );
  await ref.read(repositoryProvider).addExpense(groupId: group.id, expense: expense);
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currency,
    required this.accent,
    required this.requestEnabled,
    required this.payEnabled,
    required this.onRequest,
    required this.onPay,
    this.leading,
    this.requestLabel,
    this.payLabel,
  });

  final String title;
  final String subtitle;
  final double amount;
  final String currency;
  final Color accent;
  final bool requestEnabled;
  final bool payEnabled;
  final Future<void> Function() onRequest;
  final Future<void> Function() onPay;
  final Widget? leading;
  final String? requestLabel;
  final String? payLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                child: Text(money(amount, currency), style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: requestEnabled ? onRequest : null,
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: Text(requestLabel ?? tr(context, es: 'Solicitar dinero', en: 'Request money', gl: 'Solicitar diñeiro', fr: 'Demander argent', it: 'Richiedi denaro', pt: 'Solicitar dinheiro')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: payEnabled ? onPay : null,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(payLabel ?? tr(context, es: 'Ya está pagado', en: 'Already paid', gl: 'Xa esta pagado', fr: 'Deja paye', it: 'Gia pagato', pt: 'Ja esta pago')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingToggleCard extends StatelessWidget {
  const _PendingToggleCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        value: value,
        onChanged: onChanged,
        title: Text(tr(context, es: 'Incluir usuarios pendientes', en: 'Include pending users', gl: 'Incluír usuarios pendentes', fr: 'Inclure les utilisateurs en attente', it: 'Includi utenti in attesa', pt: 'Incluir utilizadores pendentes')),
        subtitle: Text(tr(context, es: 'Muestra deudas y cobros también con personas que todavía no han vinculado su cuenta.', en: 'Also show debts and claims with people who have not linked their account yet.', gl: 'Mostra tamén débedas e cobros con persoas que aínda non vincularon a conta.', fr: 'Affiche aussi les dettes et créances des personnes qui n ont pas encore lié leur compte.', it: 'Mostra anche debiti e crediti delle persone che non hanno ancora collegato il loro account.', pt: 'Mostra também dívidas e cobranças com pessoas que ainda não ligaram a conta.')),
      ),
    );
  }
}