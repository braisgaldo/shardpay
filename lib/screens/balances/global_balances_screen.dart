import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_text.dart';
import '../../app/providers.dart';
import '../../core/defaults.dart';
import '../../core/expense_math.dart';
import '../../models/app_models.dart';

class GlobalBalancesScreen extends ConsumerWidget {
  const GlobalBalancesScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(groupsProvider(user.id));

    return SafeArea(
      child: groupsState.when(
        data: (groups) {
          final entries = _buildEntries(groups, user.id);
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(context, es: 'No tienes deudas ni cobros pendientes con cuentas reales en tus grupos.', en: 'You have no pending debts or claims with real accounts across your groups.', gl: 'Non tes debedas nin cobros pendentes con contas reais nos teus grupos.', fr: 'Vous n avez ni dettes ni creances en attente avec des comptes reels.', it: 'Non hai debiti o crediti pendenti con account reali.', pt: 'Nao tens dividas nem cobrancas pendentes com contas reais nos teus grupos.'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final counterparty = entry.counterparty;
              final isTheyOweYou = entry.netAmount > 0;
              final tone = isTheyOweYou ? const Color(0xFFE8F7EF) : const Color(0xFFFFF3E2);
              final accent = isTheyOweYou ? const Color(0xFF1E8E5A) : const Color(0xFFC77600);
              return Card(
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  title: Text(counterparty.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  subtitle: Text(isTheyOweYou ? tr(context, es: 'Te debe dinero', en: 'Owes you money', gl: 'Debeche diñeiro', fr: 'Vous doit de l argent', it: 'Ti deve denaro', pt: 'Deve-te dinheiro') : tr(context, es: 'Le debes dinero', en: 'You owe money', gl: 'Debeslle diñeiro', fr: 'Vous lui devez de l argent', it: 'Gli devi denaro', pt: 'Deves-lhe dinheiro')),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(999)),
                    child: Text('${isTheyOweYou ? '+' : '-'}${money(entry.netAmount.abs(), entry.currency)}', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                  ),
                  children: entry.groupBreakdown.map((groupEntry) {
                    final myDirection = groupEntry.fromUserId == user.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(groupEntry.group.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(myDirection ? tr(context, es: 'Debes ${money(groupEntry.amount, groupEntry.group.currency)} en este grupo.', en: 'You owe ${money(groupEntry.amount, groupEntry.group.currency)} in this group.', gl: 'Debes ${money(groupEntry.amount, groupEntry.group.currency)} neste grupo.', fr: 'Vous devez ${money(groupEntry.amount, groupEntry.group.currency)} dans ce groupe.', it: 'Devi ${money(groupEntry.amount, groupEntry.group.currency)} in questo gruppo.', pt: 'Deves ${money(groupEntry.amount, groupEntry.group.currency)} neste grupo.') : tr(context, es: 'Te deben ${money(groupEntry.amount, groupEntry.group.currency)} en este grupo.', en: 'You are owed ${money(groupEntry.amount, groupEntry.group.currency)} in this group.', gl: 'Debenche ${money(groupEntry.amount, groupEntry.group.currency)} neste grupo.', fr: 'On vous doit ${money(groupEntry.amount, groupEntry.group.currency)} dans ce groupe.', it: 'Ti devono ${money(groupEntry.amount, groupEntry.group.currency)} in questo gruppo.', pt: 'Devem-te ${money(groupEntry.amount, groupEntry.group.currency)} neste grupo.')),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: groupEntry.group.isClosed ? null : () => _requestSettlement(context, ref, groupEntry, user.id, counterparty),
                                  icon: const Icon(Icons.notifications_active_rounded),
                                  label: Text(tr(context, es: 'Solicitar', en: 'Request', gl: 'Solicitar', fr: 'Demander', it: 'Richiedi', pt: 'Solicitar')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: groupEntry.group.isClosed ? null : () => _recordSettlement(context, ref, groupEntry, user, counterparty),
                                  icon: const Icon(Icons.payments_rounded),
                                  label: Text(tr(context, es: 'Reembolsar', en: 'Reimburse', gl: 'Reembolsar', fr: 'Rembourser', it: 'Rimborsa', pt: 'Reembolsar')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _recordSettlement(BuildContext context, WidgetRef ref, _GroupDebtEntry entry, AppUser user, GroupMember counterparty) async {
    final messenger = ScaffoldMessenger.of(context);
    final reimbursementTitle = tr(context, es: 'Reembolso', en: 'Reimbursement', gl: 'Reembolso', fr: 'Remboursement', it: 'Rimborso', pt: 'Reembolso');
    final reimbursementNote = tr(context, es: 'Ajuste directo entre ${user.displayName} y ${counterparty.name}.', en: 'Direct settlement between ${user.displayName} and ${counterparty.name}.', gl: 'Axuste directo entre ${user.displayName} e ${counterparty.name}.', fr: 'Reglement direct entre ${user.displayName} et ${counterparty.name}.', it: 'Regolazione diretta tra ${user.displayName} e ${counterparty.name}.', pt: 'Ajuste direto entre ${user.displayName} e ${counterparty.name}.');
    final reimbursementItemName = tr(context, es: 'Reembolso a ${counterparty.name}', en: 'Reimbursement to ${counterparty.name}', gl: 'Reembolso a ${counterparty.name}', fr: 'Remboursement a ${counterparty.name}', it: 'Rimborso a ${counterparty.name}', pt: 'Reembolso a ${counterparty.name}');
    final controller = TextEditingController(text: entry.amount.toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr(context, es: 'Registrar reembolso', en: 'Record reimbursement', gl: 'Rexistrar reembolso', fr: 'Enregistrer remboursement', it: 'Registra rimborso', pt: 'Registar reembolso')),
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

    final uuid = const Uuid();
    final myDirection = entry.fromUserId == user.id;
    final payerId = myDirection ? user.id : counterparty.userId;
    final debtorId = myDirection ? counterparty.userId : user.id;
    final expense = ExpenseRecord(
      id: uuid.v4(),
      title: reimbursementTitle,
      payerId: payerId,
      createdAt: DateTime.now(),
      kind: ExpenseRecordKind.settlement,
      note: reimbursementNote,
      items: [
        ExpenseItem(
          id: uuid.v4(),
          name: reimbursementItemName,
          amount: amount,
          categoryId: 'work',
          allocations: [
            SplitAllocation(userId: debtorId, percentage: 100),
            SplitAllocation(userId: payerId, percentage: 0),
          ],
        ),
      ],
    );
    await ref.read(repositoryProvider).addExpense(groupId: entry.group.id, expense: expense);
    if (!context.mounted) {
      return;
    }
    messenger.hideCurrentSnackBar();
  }

  Future<void> _requestSettlement(BuildContext context, WidgetRef ref, _GroupDebtEntry entry, String currentUserId, GroupMember counterparty) async {
    final controller = TextEditingController(text: entry.amount.toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr(context, es: 'Solicitar reembolso', en: 'Request reimbursement', gl: 'Solicitar reembolso', fr: 'Demander remboursement', it: 'Richiedi rimborso', pt: 'Solicitar reembolso')),
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
    if (!context.mounted) {
      return;
    }
    await ref.read(repositoryProvider).requestReimbursement(groupId: entry.group.id, requesterId: currentUserId, targetUserId: counterparty.userId, amount: amount);
  }
}

class _CounterpartyEntry {
  const _CounterpartyEntry({required this.counterparty, required this.groupBreakdown, required this.netAmount, required this.currency});

  final GroupMember counterparty;
  final List<_GroupDebtEntry> groupBreakdown;
  final double netAmount;
  final String currency;
}

class _GroupDebtEntry {
  const _GroupDebtEntry({required this.group, required this.fromUserId, required this.toUserId, required this.amount});

  final ExpenseGroup group;
  final String fromUserId;
  final String toUserId;
  final double amount;
}

List<_CounterpartyEntry> _buildEntries(List<ExpenseGroup> groups, String currentUserId) {
  final perUser = <String, List<_GroupDebtEntry>>{};
  final userById = <String, GroupMember>{};

  for (final group in groups) {
    for (final member in group.activeMembers) {
      userById[member.userId] = member;
    }
    final settlements = settlementEdges(group, activeAccountsOnly: true);
    for (final settlement in settlements.where((entry) => entry.fromUserId == currentUserId || entry.toUserId == currentUserId)) {
      final counterpartyId = settlement.fromUserId == currentUserId ? settlement.toUserId : settlement.fromUserId;
      final counterparty = userById[counterpartyId] ?? group.activeMembers.firstWhereOrNull((member) => member.userId == counterpartyId);
      if (counterparty == null) {
        continue;
      }
      perUser.putIfAbsent(counterpartyId, () => []).add(_GroupDebtEntry(group: group, fromUserId: settlement.fromUserId, toUserId: settlement.toUserId, amount: settlement.amount));
    }
  }

  return perUser.entries.map((entry) {
    final breakdown = entry.value;
    final net = breakdown.fold<double>(0, (runningBalance, item) => runningBalance + (item.toUserId == currentUserId ? item.amount : -item.amount));
    return _CounterpartyEntry(
      counterparty: userById[entry.key]!,
      groupBreakdown: breakdown,
      netAmount: double.parse(net.toStringAsFixed(2)),
      currency: breakdown.first.group.currency,
    );
  }).where((entry) => entry.netAmount.abs() > 0.009).sorted((a, b) => b.netAmount.abs().compareTo(a.netAmount.abs())).toList();
}
