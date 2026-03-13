import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_text.dart';
import '../../app/providers.dart';
import '../../core/defaults.dart';
import '../../core/expense_math.dart';
import '../../models/app_models.dart';
import '../../services/ticket_ocr_service.dart';
import 'add_expense_screen.dart';

enum _GroupMenuAction { toggleClosed, notifySettlements, manageAdmins, transferOwner, leave, delete }

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.user, required this.groupId});

  final AppUser user;
  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupProvider(widget.groupId));

    return groupState.when(
      data: (group) {
        if (group == null) {
          return Scaffold(body: Center(child: Text(tr(context, es: 'Grupo no encontrado.', en: 'Group not found.', gl: 'Grupo non atopado.', fr: 'Groupe introuvable.', it: 'Gruppo non trovato.', pt: 'Grupo nao encontrado.'))));
        }

        final balances = memberBalances(group);
        final categories = [...buildDefaultCategories(), ...group.customCategories];

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(groupIconForKey(group.iconKey), size: 18, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(group.name)),
                      if (group.isClosed) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.lock_clock_rounded, size: 18),
                      ],
                    ],
                  ),
                  if ((group.description ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        group.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  Text(
                    tr(
                      context,
                      es: '${group.totalDisplayedMembers} miembros · invite ${group.inviteCode}',
                      en: '${group.totalDisplayedMembers} members · invite ${group.inviteCode}',
                      gl: '${group.totalDisplayedMembers} membros · invite ${group.inviteCode}',
                      fr: '${group.totalDisplayedMembers} membres · invite ${group.inviteCode}',
                      it: '${group.totalDisplayedMembers} membri · invite ${group.inviteCode}',
                      pt: '${group.totalDisplayedMembers} membros · invite ${group.inviteCode}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                if (group.isAdmin(widget.user.id))
                  IconButton(
                    onPressed: group.isClosed ? null : () => _showJoinSettingsDialog(context, group),
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: tr(context, es: 'Ajustes del grupo', en: 'Group settings', gl: 'Axustes do grupo', fr: 'Parametres du groupe', it: 'Impostazioni del gruppo', pt: 'Definicoes do grupo'),
                  ),
                PopupMenuButton<_GroupMenuAction>(
                  onSelected: (action) async {
                    switch (action) {
                      case _GroupMenuAction.toggleClosed:
                        await _toggleGroupClosed(context, group);
                        break;
                      case _GroupMenuAction.notifySettlements:
                        await _notifyGroupSettlements(context, group);
                        break;
                      case _GroupMenuAction.manageAdmins:
                        await _showManageAdminsDialog(context, group);
                        break;
                      case _GroupMenuAction.transferOwner:
                        await _showTransferOwnershipDialog(context, group);
                        break;
                      case _GroupMenuAction.leave:
                        await _confirmLeaveGroup(context, group);
                        break;
                      case _GroupMenuAction.delete:
                        await _confirmDeleteGroup(context, group);
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<_GroupMenuAction>>[];
                    if (group.isAdmin(widget.user.id)) {
                      items.add(
                        PopupMenuItem(
                          value: _GroupMenuAction.toggleClosed,
                          child: Row(
                            children: [
                              Icon(group.isClosed ? Icons.lock_open_rounded : Icons.lock_rounded, size: 18),
                              const SizedBox(width: 10),
                              Text(group.isClosed ? tr(context, es: 'Reabrir grupo', en: 'Reopen group', gl: 'Reabrir grupo', fr: 'Rouvrir le groupe', it: 'Riapri gruppo', pt: 'Reabrir grupo') : tr(context, es: 'Cerrar grupo', en: 'Close group', gl: 'Pechar grupo', fr: 'Fermer le groupe', it: 'Chiudi gruppo', pt: 'Fechar grupo')),
                            ],
                          ),
                        ),
                      );
                      items.add(
                        PopupMenuItem(
                          value: _GroupMenuAction.notifySettlements,
                          child: Row(
                            children: [
                              const Icon(Icons.campaign_rounded, size: 18),
                              const SizedBox(width: 10),
                              Text(tr(context, es: 'Solicitar pagos al grupo', en: 'Request payments from group', gl: 'Solicitar pagos ao grupo', fr: 'Demander les paiements du groupe', it: 'Richiedi pagamenti al gruppo', pt: 'Solicitar pagamentos ao grupo')),
                            ],
                          ),
                        ),
                      );
                    }
                    if (group.ownerId == widget.user.id && group.members.length > 1) {
                      items.add(
                        PopupMenuItem(
                          value: _GroupMenuAction.manageAdmins,
                          child: Row(
                            children: [
                              const Icon(Icons.manage_accounts_rounded, size: 18),
                              const SizedBox(width: 10),
                              Text(tr(context, es: 'Administradores', en: 'Admins', gl: 'Admins', fr: 'Admins', it: 'Admin', pt: 'Admins')),
                            ],
                          ),
                        ),
                      );
                      items.add(
                        PopupMenuItem(
                          value: _GroupMenuAction.transferOwner,
                          child: Row(
                            children: [
                              const Icon(Icons.admin_panel_settings_rounded, size: 18),
                              const SizedBox(width: 10),
                              Text(tr(context, es: 'Reasignar admin', en: 'Transfer admin', gl: 'Reasignar admin', fr: 'Transferer admin', it: 'Trasferisci admin', pt: 'Reatribuir admin')),
                            ],
                          ),
                        ),
                      );
                    }
                    items.add(
                      PopupMenuItem(
                        value: _GroupMenuAction.leave,
                        child: Row(
                          children: [
                            const Icon(Icons.logout_rounded, size: 18),
                            const SizedBox(width: 10),
                            Text(tr(context, es: 'Abandonar grupo', en: 'Leave group', gl: 'Abandonar grupo', fr: 'Quitter le groupe', it: 'Lascia gruppo', pt: 'Sair do grupo')),
                          ],
                        ),
                      ),
                    );
                    if (group.ownerId == widget.user.id) {
                      items.add(
                        PopupMenuItem(
                          value: _GroupMenuAction.delete,
                          child: Row(
                            children: [
                              const Icon(Icons.delete_forever_rounded, size: 18, color: Color(0xFFC62828)),
                              const SizedBox(width: 10),
                              Text(
                                tr(context, es: 'Eliminar grupo', en: 'Delete group', gl: 'Eliminar grupo', fr: 'Supprimer groupe', it: 'Elimina gruppo', pt: 'Eliminar grupo'),
                                style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return items;
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: tr(context, es: 'Resumen', en: 'Overview', gl: 'Resumo', fr: 'Resume', it: 'Riepilogo', pt: 'Resumo')),
                  Tab(text: tr(context, es: 'Balance', en: 'Balance', gl: 'Balance', fr: 'Solde', it: 'Saldo', pt: 'Saldo')),
                  Tab(text: tr(context, es: 'Gastos', en: 'Expenses', gl: 'Gastos', fr: 'Depenses', it: 'Spese', pt: 'Despesas')),
                  Tab(text: tr(context, es: 'Gráficos', en: 'Charts', gl: 'Graficos', fr: 'Graphiques', it: 'Grafici', pt: 'Graficos')),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OverviewTab(
                  user: widget.user,
                  group: group,
                  balances: balances,
                  categories: categories,
                  onInvite: () => _showInviteSheet(context, group),
                  onCategories: () => _showCategoryDialog(context, group),
                  onAddExpense: () => _openAddExpenseScreen(context, group),
                  onOcrCamera: () => _importTicket(context, group, ImageSource.camera),
                  onOcrGallery: () => _importTicket(context, group, ImageSource.gallery),
                  groupClosed: group.isClosed,
                  onManagePeople: group.isAdmin(widget.user.id) ? () => _showJoinSettingsDialog(context, group) : null,
                ),
                _BalancesTab(group: group, balances: balances, currentUserId: widget.user.id),
                _ExpensesTab(
                  group: group,
                  currentUserId: widget.user.id,
                  categories: categories,
                  allowChanges: !group.isClosed,
                  onEditAllocations: (expense, item) => _editAllocations(context, group, expense, item),
                  onEditExpense: (expense) => _showExpenseEditorDialog(context, group, expense),
                  onDeleteExpense: (expense) => _confirmDeleteExpense(context, group, expense),
                ),
                _GroupChartsTab(group: group, categories: categories, currentUserId: widget.user.id),
              ],
            ),
          ),
        );
      },
      error: (error, _) => Scaffold(body: Center(child: Text(error.toString()))),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }

  Future<void> _showManageAdminsDialog(BuildContext context, ExpenseGroup group) async {
    final selectedAdminIds = group.adminIds.toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(tr(context, es: 'Administradores del grupo', en: 'Group admins', gl: 'Admins do grupo', fr: 'Admins du groupe', it: 'Admin del gruppo', pt: 'Admins do grupo')),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, es: 'La persona propietaria sigue siendo quien puede borrar el grupo o reasignar la propiedad. Aquí puedes añadir o quitar admins adicionales.', en: 'The owner still controls deletion and ownership transfer. Here you can add or remove extra admins.', gl: 'A persoa propietaria segue controlando o borrado e a propiedade. Aqui podes engadir ou quitar admins adicionais.', fr: 'Le proprietaire conserve la suppression et le transfert. Ici vous pouvez ajouter ou retirer des admins supplementaires.', it: 'Il proprietario mantiene eliminazione e trasferimento. Qui puoi aggiungere o rimuovere admin aggiuntivi.', pt: 'A pessoa proprietaria continua a controlar apagar e transferir propriedade. Aqui podes adicionar ou remover admins extra.')),
                      const SizedBox(height: 14),
                      ...group.activeMembers.where((member) => member.userId != group.ownerId).map((member) {
                        return CheckboxListTile.adaptive(
                          value: selectedAdminIds.contains(member.userId),
                          contentPadding: EdgeInsets.zero,
                          title: Text(member.name),
                          subtitle: Text(member.email.isEmpty ? tr(context, es: 'Miembro del grupo', en: 'Group member', gl: 'Membro do grupo', fr: 'Membre du groupe', it: 'Membro del gruppo', pt: 'Membro do grupo') : member.email),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedAdminIds.add(member.userId);
                              } else {
                                selectedAdminIds.remove(member.userId);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(
                  onPressed: () async {
                    await ref.read(repositoryProvider).setGroupAdmins(groupId: group.id, requesterId: widget.user.id, adminIds: selectedAdminIds.toList());
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(tr(context, es: 'Guardar', en: 'Save', gl: 'Gardar', fr: 'Enregistrer', it: 'Salva', pt: 'Guardar')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openAddExpenseScreen(BuildContext context, ExpenseGroup group) async {
    if (group.isClosed) {
      _showGroupClosedMessage(context);
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddExpenseScreen(user: widget.user, group: group)),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, es: 'Gasto guardado.', en: 'Expense saved.', gl: 'Gasto gardado.', fr: 'Depense enregistree.', it: 'Spesa salvata.', pt: 'Despesa guardada.'))));
    }
  }

  void _showInviteSheet(BuildContext context, ExpenseGroup group) {
    final payload = 'shardpay://join?group=${group.id}&token=${group.inviteCode}';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: payload, size: 220, backgroundColor: Colors.white),
              const SizedBox(height: 12),
              SelectableText(payload, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => SharePlus.instance.share(ShareParams(text: payload, subject: tr(context, es: 'Únete a ${group.name} en ShardPay', en: 'Join ${group.name} on ShardPay', gl: 'Unete a ${group.name} en ShardPay', fr: 'Rejoignez ${group.name} sur ShardPay', it: 'Unisciti a ${group.name} su ShardPay', pt: 'Junta-te a ${group.name} no ShardPay'))),
                icon: const Icon(Icons.share_rounded),
                label: Text(tr(context, es: 'Compartir enlace', en: 'Share link', gl: 'Compartir ligazon', fr: 'Partager le lien', it: 'Condividi link', pt: 'Partilhar link')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showJoinSettingsDialog(BuildContext context, ExpenseGroup group) async {
    if (group.isClosed) {
      _showGroupClosedMessage(context);
      return;
    }
    final groupNameController = TextEditingController(text: group.name);
    final groupDescriptionController = TextEditingController(text: group.description ?? '');
    final nameController = TextEditingController();
    final pendingMembers = [...group.pendingMembers];
    var allowAnonymousJoin = group.allowAnonymousJoin;
    var currency = group.currency;
    var iconKey = group.iconKey;
    final uuid = const Uuid();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              title: Text(
                tr(context, es: 'Ajustes del grupo', en: 'Group settings', gl: 'Axustes do grupo', fr: 'Parametres du groupe', it: 'Impostazioni del gruppo', pt: 'Definicoes do grupo'),
                maxLines: 2,
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: groupNameController,
                        decoration: InputDecoration(labelText: tr(context, es: 'Nombre del grupo', en: 'Group name', gl: 'Nome do grupo', fr: 'Nom du groupe', it: 'Nome del gruppo', pt: 'Nome do grupo')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: groupDescriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(labelText: tr(context, es: 'Descripción', en: 'Description', gl: 'Descricion', fr: 'Description', it: 'Descrizione', pt: 'Descricao')),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: iconKey,
                        decoration: InputDecoration(labelText: tr(context, es: 'Icono del grupo', en: 'Group icon', gl: 'Icona do grupo', fr: 'Icone du groupe', it: 'Icona del gruppo', pt: 'Icone do grupo')),
                        items: groupIcons.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(entry.value, size: 18),
                                const SizedBox(width: 10),
                                SizedBox(width: 140, child: Text(groupIconLabelForKey(entry.key), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => iconKey = value ?? iconKey),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        tr(context, es: 'Añade nombres que luego podrá escoger quien entre por invitación. Si activas el acceso libre, también podrá entrar sin indicar quién es.', en: 'Add prepared names so people joining can pick who they are. If open access is enabled, they can also join without choosing one.', gl: 'Engade nomes para que quen entre poida escoller quen e. Se activas o acceso libre, tamen podera entrar sen indicalo.', fr: 'Ajoutez des noms prepares. Si l acces libre est active, l utilisateur peut entrer sans en choisir un.', it: 'Aggiungi nomi preparati. Se attivi l accesso libero, si puo entrare anche senza sceglierne uno.', pt: 'Adiciona nomes preparados. Se ativares o acesso livre, a pessoa pode entrar sem escolher um.'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: allowAnonymousJoin,
                        onChanged: (value) => setDialogState(() => allowAnonymousJoin = value),
                        title: Text(tr(context, es: 'Permitir entrar solo clicando el enlace', en: 'Allow joining directly from the link', gl: 'Permitir entrar so clicando a ligazon', fr: 'Autoriser l entree directe par lien', it: 'Consenti accesso diretto dal link', pt: 'Permitir entrar so clicando no link')),
                        subtitle: Text(tr(context, es: 'Desactivado por defecto. Si se activa, no hará falta elegir un nombre preparado.', en: 'Off by default. When enabled, choosing a prepared identity is optional.', gl: 'Desactivado por defecto. Se se activa, non fara falla escoller unha identidade preparada.', fr: 'Desactive par defaut. Si active, choisir un nom prepare devient optionnel.', it: 'Disattivato di default. Se attivo, scegliere un nome preparato e opzionale.', pt: 'Desativado por defeito. Se ativado, escolher um nome preparado deixa de ser obrigatorio.')),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: currency,
                        decoration: InputDecoration(labelText: tr(context, es: 'Divisa del grupo', en: 'Group currency', gl: 'Divisa do grupo', fr: 'Devise du groupe', it: 'Valuta del gruppo', pt: 'Moeda do grupo')),
                        items: currencyOptions.map((entry) => DropdownMenuItem(value: entry.code, child: Text('${entry.code} · ${entry.label}'))).toList(),
                        onChanged: (value) => setDialogState(() => currency = value ?? currency),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              decoration: InputDecoration(labelText: tr(context, es: 'Añadir participante', en: 'Add participant', gl: 'Engadir participante', fr: 'Ajouter un participant', it: 'Aggiungi partecipante', pt: 'Adicionar participante')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () {
                              final value = nameController.text.trim();
                              if (value.isEmpty) {
                                return;
                              }
                              setDialogState(() {
                                pendingMembers.add(PendingGroupMember(id: uuid.v4(), name: value));
                                nameController.clear();
                              });
                            },
                            child: Text(tr(context, es: 'Añadir', en: 'Add', gl: 'Engadir', fr: 'Ajouter', it: 'Aggiungi', pt: 'Adicionar')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (pendingMembers.isEmpty)
                        Text(tr(context, es: 'Todavía no hay nombres preparados.', en: 'There are no prepared names yet.', gl: 'Ainda non hai nomes preparados.', fr: 'Il n y a pas encore de noms prepares.', it: 'Non ci sono ancora nomi preparati.', pt: 'Ainda nao ha nomes preparados.'))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pendingMembers.map((member) {
                            return InputChip(
                              label: Text(member.name),
                              onDeleted: () => setDialogState(() => pendingMembers.removeWhere((entry) => entry.id == member.id)),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 18),
                      Text(tr(context, es: 'Fechas del grupo', en: 'Group dates', gl: 'Datas do grupo', fr: 'Dates du groupe', it: 'Date del gruppo', pt: 'Datas do grupo'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      _DateLine(label: tr(context, es: 'Creado', en: 'Created', gl: 'Creado', fr: 'Cree', it: 'Creato', pt: 'Criado'), value: DateFormat.yMMMd(localeTag(context)).add_Hm().format(group.createdAt)),
                      _DateLine(label: tr(context, es: 'Última modificación', en: 'Last update', gl: 'Ultima modificacion', fr: 'Derniere mise a jour', it: 'Ultimo aggiornamento', pt: 'Ultima atualizacao'), value: DateFormat.yMMMd(localeTag(context)).add_Hm().format(group.updatedAt)),
                      _DateLine(label: tr(context, es: 'Cierre', en: 'Closed at', gl: 'Peche', fr: 'Fermeture', it: 'Chiusura', pt: 'Fecho'), value: group.closedAt == null ? tr(context, es: 'Sin cierre activo', en: 'No active closure', gl: 'Sen peche activo', fr: 'Aucune fermeture active', it: 'Nessuna chiusura attiva', pt: 'Sem fecho ativo') : DateFormat.yMMMd(localeTag(context)).add_Hm().format(group.closedAt!)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(
                  onPressed: () async {
                    await ref.read(repositoryProvider).updateGroupJoinSettings(
                      groupId: group.id,
                      name: groupNameController.text.trim().isEmpty ? group.name : groupNameController.text.trim(),
                      description: groupDescriptionController.text.trim(),
                      iconKey: iconKey,
                      pendingMembers: pendingMembers,
                      allowAnonymousJoin: allowAnonymousJoin,
                      currency: currency,
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(tr(context, es: 'Guardar', en: 'Save', gl: 'Gardar', fr: 'Enregistrer', it: 'Salva', pt: 'Guardar')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showTransferOwnershipDialog(BuildContext context, ExpenseGroup group) async {
    String? selectedOwnerId = group.members.firstWhereOrNull((entry) => entry.userId != widget.user.id)?.userId;
    if (selectedOwnerId == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(tr(context, es: 'Reasignar administración', en: 'Transfer administration', gl: 'Reasignar administracion', fr: 'Transferer l administration', it: 'Trasferisci amministrazione', pt: 'Reatribuir administracao')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, es: 'Selecciona la persona que pasará a ser admin del grupo.', en: 'Select the person who will become group admin.', gl: 'Selecciona a persoa que pasara a ser admin do grupo.', fr: 'Selectionnez la personne qui deviendra administrateur du groupe.', it: 'Seleziona la persona che diventera admin del gruppo.', pt: 'Seleciona a pessoa que passara a ser admin do grupo.')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedOwnerId,
                    decoration: InputDecoration(labelText: tr(context, es: 'Nuevo admin', en: 'New admin', gl: 'Novo admin', fr: 'Nouvel admin', it: 'Nuovo admin', pt: 'Novo admin')),
                    items: group.members
                        .where((entry) => entry.userId != widget.user.id)
                        .map((member) => DropdownMenuItem(value: member.userId, child: Text(member.name)))
                        .toList(),
                    onChanged: (value) => setDialogState(() => selectedOwnerId = value ?? selectedOwnerId),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(
                  onPressed: () async {
                    await ref.read(repositoryProvider).transferGroupOwnership(groupId: group.id, requesterId: widget.user.id, newOwnerId: selectedOwnerId!);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, es: 'Administración reasignada.', en: 'Administration transferred.', gl: 'Administracion reasignada.', fr: 'Administration transferee.', it: 'Amministrazione trasferita.', pt: 'Administracao reatribuida.'))));
                    }
                  },
                  child: Text(tr(context, es: 'Guardar', en: 'Save', gl: 'Gardar', fr: 'Enregistrer', it: 'Salva', pt: 'Guardar')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmLeaveGroup(BuildContext context, ExpenseGroup group) async {
    final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(tr(context, es: 'Abandonar grupo', en: 'Leave group', gl: 'Abandonar grupo', fr: 'Quitter le groupe', it: 'Lascia gruppo', pt: 'Sair do grupo')),
              content: Text(
                group.ownerId == widget.user.id && group.members.length > 1
                    ? tr(context, es: 'Antes de salir, primero reasigna la administración a otra persona del grupo.', en: 'Before leaving, transfer administration to another group member first.', gl: 'Antes de saires, primeiro reasigna a administracion a outra persoa do grupo.', fr: 'Avant de quitter, transferez d abord l administration a une autre personne.', it: 'Prima di uscire trasferisci l amministrazione a un altra persona del gruppo.', pt: 'Antes de sair, reatribui primeiro a administracao a outra pessoa do grupo.')
                    : tr(context, es: 'Vas a salir de ${group.name}. Si eras la última persona del grupo, se eliminará automáticamente.', en: 'You are leaving ${group.name}. If you are the last person, the group will be deleted automatically.', gl: 'Vas saír de ${group.name}. Se eras a ultima persoa, o grupo eliminarase automaticamente.', fr: 'Vous allez quitter ${group.name}. Si vous etes la derniere personne, le groupe sera supprime automatiquement.', it: 'Stai per lasciare ${group.name}. Se sei l ultima persona, il gruppo verra eliminato automaticamente.', pt: 'Vais sair de ${group.name}. Se fores a ultima pessoa, o grupo sera eliminado automaticamente.'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton.icon(
                  onPressed: group.ownerId == widget.user.id && group.members.length > 1 ? null : () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9B1C1C),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(tr(context, es: 'Salir', en: 'Leave', gl: 'Saír', fr: 'Quitter', it: 'Esci', pt: 'Sair')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!approved) {
      return;
    }

    try {
      await ref.read(repositoryProvider).leaveGroup(groupId: group.id, userId: widget.user.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }

  Future<void> _confirmDeleteGroup(BuildContext context, ExpenseGroup group) async {
    final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(tr(context, es: 'Eliminar grupo', en: 'Delete group', gl: 'Eliminar grupo', fr: 'Supprimer groupe', it: 'Elimina gruppo', pt: 'Eliminar grupo')),
              content: Text(tr(context, es: 'Se eliminarán el grupo, sus gastos y sus invitaciones pendientes. Esta acción no se puede deshacer.', en: 'The group, its expenses and pending invites will be deleted. This action cannot be undone.', gl: 'Eliminaranse o grupo, os seus gastos e os convites pendentes. Esta accion non se pode desfacer.', fr: 'Le groupe, ses depenses et invitations en attente seront supprimes. Cette action est irreversible.', it: 'Il gruppo, le spese e gli inviti pendenti saranno eliminati. Questa azione non puo essere annullata.', pt: 'O grupo, as despesas e os convites pendentes serao eliminados. Esta acao nao pode ser desfeita.')),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: Text(tr(context, es: 'Eliminar', en: 'Delete', gl: 'Eliminar', fr: 'Supprimer', it: 'Elimina', pt: 'Eliminar')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!approved) {
      return;
    }

    await ref.read(repositoryProvider).deleteGroup(groupId: group.id, requesterId: widget.user.id);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showCategoryDialog(BuildContext context, ExpenseGroup group) async {
    final nameController = TextEditingController();
    var selectedIcon = 'receipt';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(tr(context, es: 'Nueva categoría del grupo', en: 'New group category', gl: 'Nova categoria do grupo', fr: 'Nouvelle categorie du groupe', it: 'Nuova categoria del gruppo', pt: 'Nova categoria do grupo')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: InputDecoration(labelText: tr(context, es: 'Nombre', en: 'Name', gl: 'Nome', fr: 'Nom', it: 'Nome', pt: 'Nome'))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categoryIcons.entries.map((entry) {
                        final selected = selectedIcon == entry.key;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(entry.key),
                          avatar: Icon(entry.value, size: 18),
                          onSelected: (_) => setDialogState(() => selectedIcon = entry.key),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(
                  onPressed: () async {
                    await ref.read(repositoryProvider).upsertCategory(
                      groupId: group.id,
                      category: ExpenseCategory(
                        id: nameController.text.trim().toLowerCase().replaceAll(' ', '_'),
                        name: nameController.text.trim(),
                        iconKey: selectedIcon,
                        colorHex: '0xFFE4572E',
                      ),
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(tr(context, es: 'Guardar', en: 'Save', gl: 'Gardar', fr: 'Enregistrer', it: 'Salva', pt: 'Guardar')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _importTicket(BuildContext context, ExpenseGroup group, ImageSource source) async {
    if (group.isClosed) {
      _showGroupClosedMessage(context);
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);

    if (image == null || !context.mounted) {
      return;
    }

    try {
      final parsed = await ref.read(ticketOcrServiceProvider).parseReceipt(
            imagePath: image.path,
            defaultAllocations: equalAllocations(group.selectableMembers),
            defaultCategoryId: 'food',
          );
      if (!context.mounted) {
        return;
      }
      await _showParsedTicketDialog(context, group, parsed, image.path);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showParsedTicketDialog(BuildContext context, ExpenseGroup group, ParsedReceipt parsed, String imagePath) async {
    final items = parsed.items.map((item) => item.copyWith()).toList();
    final payerMembers = sortedMembersByName(group.activeMembers);
    var payerId = payerMembers.any((member) => member.userId == widget.user.id) ? widget.user.id : payerMembers.first.userId;
    final titleController = TextEditingController(text: parsed.title ?? parsed.items.firstOrNull?.name ?? 'Ticket importado');
    final uuid = const Uuid();
    final categories = [...buildDefaultCategories(), ...group.customCategories];
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(tr(context, es: 'Revisar ticket', en: 'Review receipt', gl: 'Revisar ticket', fr: 'Verifier le ticket', it: 'Rivedi scontrino', pt: 'Rever fatura')),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(labelText: tr(context, es: 'Nombre del ticket', en: 'Receipt name', gl: 'Nome do ticket', fr: 'Nom du ticket', it: 'Nome dello scontrino', pt: 'Nome da fatura')),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: payerId,
                        decoration: InputDecoration(labelText: tr(context, es: 'Pagó', en: 'Paid by', gl: 'Pagou', fr: 'Paye par', it: 'Pagato da', pt: 'Pago por')),
                        items: payerMembers.map((member) => DropdownMenuItem(value: member.userId, child: Text(member.name))).toList(),
                        onChanged: (value) => setDialogState(() => payerId = value ?? payerId),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          parsed.note ?? 'Añadido con OCR',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final category = categories.firstWhereOrNull((cat) => cat.id == item.categoryId) ?? categories.first;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item.name,
                                      decoration: InputDecoration(labelText: tr(context, es: 'Item', en: 'Item', gl: 'Item', fr: 'Article', it: 'Voce', pt: 'Item')),
                                      onChanged: (value) => items[index] = items[index].copyWith(name: value),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: items.length == 1 ? null : () => setDialogState(() => items.removeAt(index)),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    tooltip: tr(context, es: 'Eliminar item', en: 'Delete item', gl: 'Eliminar item', fr: 'Supprimer article', it: 'Elimina voce', pt: 'Eliminar item'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: item.amount.toStringAsFixed(2),
                                decoration: InputDecoration(labelText: tr(context, es: 'Importe', en: 'Amount', gl: 'Importe', fr: 'Montant', it: 'Importo', pt: 'Valor')),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) => items[index] = items[index].copyWith(amount: double.tryParse(value.replaceAll(',', '.')) ?? item.amount),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: category.id,
                                decoration: InputDecoration(labelText: tr(context, es: 'Categoría', en: 'Category', gl: 'Categoria', fr: 'Categorie', it: 'Categoria', pt: 'Categoria')),
                                items: categories.map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name))).toList(),
                                onChanged: (value) => items[index] = items[index].copyWith(categoryId: value ?? category.id),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final allocations = await _showAllocationEditor(context, group, item.allocations);
                                    if (allocations != null) {
                                      setDialogState(() => items[index] = items[index].copyWith(allocations: allocations));
                                    }
                                  },
                                  icon: const Icon(Icons.tune_rounded),
                                  label: Text(tr(context, es: 'Ajustar reparto', en: 'Adjust split', gl: 'Axustar reparto', fr: 'Ajuster la repartition', it: 'Regola ripartizione', pt: 'Ajustar divisao')),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              items.add(
                                ExpenseItem(
                                  id: uuid.v4(),
                                  name: '',
                                  amount: 0,
                                  categoryId: categories.first.id,
                                  allocations: equalAllocations(group.selectableMembers),
                                ),
                              );
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: Text(tr(context, es: 'Añadir item', en: 'Add item', gl: 'Engadir item', fr: 'Ajouter article', it: 'Aggiungi voce', pt: 'Adicionar item')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                    final validItems = items.where((item) => item.amount > 0 && item.name.trim().isNotEmpty).toList();
                    if (validItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr(
                              context,
                              es: 'Revisa los items detectados en el ticket.',
                              en: 'Check the items detected on the receipt.',
                              gl: 'Revisa os items detectados no ticket.',
                              fr: 'Verifiez les articles detectes sur le ticket.',
                              it: 'Controlla le voci rilevate nello scontrino.',
                              pt: 'Revê os itens detetados na fatura.',
                            ),
                          ),
                        ),
                      );
                      setDialogState(() => isSaving = false);
                      return;
                    }

                    final receiptSeedExpenseId = uuid.v4();
                    final storedReceipt = await ref.read(receiptStorageServiceProvider).uploadReceipt(
                          groupId: group.id,
                          expenseId: receiptSeedExpenseId,
                          imagePath: imagePath,
                        );
                    final createdAt = DateTime.now();

                    for (var index = 0; index < validItems.length; index++) {
                      final item = validItems[index];
                      final expense = ExpenseRecord(
                        id: index == 0 ? receiptSeedExpenseId : uuid.v4(),
                        title: titleController.text.trim().isEmpty ? item.name.trim() : titleController.text.trim(),
                        payerId: payerId,
                        createdAt: createdAt.add(Duration(milliseconds: index)),
                        note: parsed.note ?? 'Añadido con OCR',
                        receiptLabel: storedReceipt == null ? 'ocr-local' : 'ocr-local-storage',
                        receiptStoragePath: storedReceipt?.storagePath,
                        receiptDownloadUrl: storedReceipt?.downloadUrl,
                        items: [
                          item.copyWith(
                            id: uuid.v4(),
                            name: item.name.trim(),
                          ),
                        ],
                      );
                      await ref.read(repositoryProvider).addExpense(groupId: group.id, expense: expense);
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
                            }
                            if (dialogContext.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: Text(tr(context, es: 'Guardar ticket', en: 'Save receipt', gl: 'Gardar ticket', fr: 'Enregistrer le ticket', it: 'Salva scontrino', pt: 'Guardar fatura')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editAllocations(BuildContext context, ExpenseGroup group, ExpenseRecord expense, ExpenseItem item) async {
    if (group.isClosed) {
      _showGroupClosedMessage(context);
      return;
    }
    final allocations = await _showAllocationEditor(context, group, item.allocations);
    if (allocations == null) {
      return;
    }
    await ref.read(repositoryProvider).updateItemAllocations(
          groupId: group.id,
          expenseId: expense.id,
          itemId: item.id,
          allocations: allocations,
        );
  }

  Future<void> _showExpenseEditorDialog(BuildContext context, ExpenseGroup group, ExpenseRecord expense) async {
    if (group.isClosed) {
      _showGroupClosedMessage(context);
      return;
    }
    final titleController = TextEditingController(text: expense.title);
    final noteController = TextEditingController(text: expense.note ?? '');
    final items = expense.items.map((item) => item.copyWith()).toList();
    final payerMembers = sortedMembersByName(group.activeMembers);
    final categories = [...buildDefaultCategories(), ...group.customCategories];
    final uuid = const Uuid();
    var payerId = payerMembers.any((member) => member.userId == expense.payerId) ? expense.payerId : payerMembers.first.userId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(tr(context, es: 'Editar gasto', en: 'Edit expense', gl: 'Editar gasto', fr: 'Modifier la depense', it: 'Modifica spesa', pt: 'Editar despesa')),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(labelText: tr(context, es: 'Título del gasto', en: 'Expense title', gl: 'Titulo do gasto', fr: 'Titre de la depense', it: 'Titolo della spesa', pt: 'Titulo da despesa')),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: payerId,
                        decoration: InputDecoration(labelText: tr(context, es: 'Pagó', en: 'Paid by', gl: 'Pagou', fr: 'Paye par', it: 'Pagato da', pt: 'Pago por')),
                        items: payerMembers.map((member) => DropdownMenuItem(value: member.userId, child: Text(member.name))).toList(),
                        onChanged: (value) => setDialogState(() => payerId = value ?? payerId),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: InputDecoration(labelText: tr(context, es: 'Nota', en: 'Note', gl: 'Nota', fr: 'Note', it: 'Nota', pt: 'Nota')),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(tr(context, es: 'Items', en: 'Items', gl: 'Items', fr: 'Articles', it: 'Voci', pt: 'Itens'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 10),
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final category = categories.firstWhereOrNull((cat) => cat.id == item.categoryId) ?? categories.first;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item.name,
                                      decoration: InputDecoration(labelText: tr(context, es: 'Item', en: 'Item', gl: 'Item', fr: 'Article', it: 'Voce', pt: 'Item')),
                                      onChanged: (value) => items[index] = items[index].copyWith(name: value),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: items.length == 1 ? null : () => setDialogState(() => items.removeAt(index)),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    tooltip: tr(context, es: 'Eliminar item', en: 'Delete item', gl: 'Eliminar item', fr: 'Supprimer article', it: 'Elimina voce', pt: 'Eliminar item'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: item.amount.toStringAsFixed(2),
                                decoration: InputDecoration(labelText: tr(context, es: 'Importe', en: 'Amount', gl: 'Importe', fr: 'Montant', it: 'Importo', pt: 'Valor')),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) => items[index] = items[index].copyWith(amount: double.tryParse(value.replaceAll(',', '.')) ?? item.amount),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: category.id,
                                decoration: InputDecoration(labelText: tr(context, es: 'Categoría', en: 'Category', gl: 'Categoria', fr: 'Categorie', it: 'Categoria', pt: 'Categoria')),
                                items: categories.map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name))).toList(),
                                onChanged: (value) => items[index] = items[index].copyWith(categoryId: value ?? category.id),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final allocations = await _showAllocationEditor(context, group, item.allocations);
                                    if (allocations != null) {
                                      setDialogState(() => items[index] = items[index].copyWith(allocations: allocations));
                                    }
                                  },
                                  icon: const Icon(Icons.tune_rounded),
                                  label: Text(tr(context, es: 'Ajustar reparto', en: 'Adjust split', gl: 'Axustar reparto', fr: 'Ajuster la repartition', it: 'Regola ripartizione', pt: 'Ajustar divisao')),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              items.add(
                                ExpenseItem(
                                  id: uuid.v4(),
                                  name: '',
                                  amount: 0,
                                  categoryId: categories.first.id,
                                  allocations: equalAllocations(group.selectableMembers),
                                ),
                              );
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: Text(tr(context, es: 'Añadir item', en: 'Add item', gl: 'Engadir item', fr: 'Ajouter article', it: 'Aggiungi voce', pt: 'Adicionar item')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(
                  onPressed: () async {
                    final validItems = items.where((item) => item.amount > 0 && item.name.trim().isNotEmpty).toList();
                    if (titleController.text.trim().isEmpty || validItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, es: 'Revisa el título y los items del gasto.', en: 'Check the title and expense items.', gl: 'Revisa o titulo e os items do gasto.', fr: 'Verifiez le titre et les articles de la depense.', it: 'Controlla il titolo e le voci della spesa.', pt: 'Revê o titulo e os itens da despesa.'))));
                      return;
                    }
                    await ref.read(repositoryProvider).updateExpense(
                          groupId: group.id,
                          expense: expense.copyWith(
                            title: titleController.text.trim(),
                            payerId: payerId,
                            note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                            items: validItems,
                          ),
                        );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(tr(context, es: 'Guardar cambios', en: 'Save changes', gl: 'Gardar cambios', fr: 'Enregistrer les modifications', it: 'Salva modifiche', pt: 'Guardar alteracoes')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteExpense(BuildContext context, ExpenseGroup group, ExpenseRecord expense) async {
    if (group.isClosed) {
      _showGroupClosedMessage(context);
      return;
    }
    final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(tr(context, es: 'Eliminar gasto', en: 'Delete expense', gl: 'Eliminar gasto', fr: 'Supprimer la depense', it: 'Elimina spesa', pt: 'Eliminar despesa')),
              content: Text(tr(context, es: 'Se eliminará "${expense.title}" y ya no contará en balances ni gráficos.', en: '"${expense.title}" will be deleted and will no longer count in balances or charts.', gl: 'Eliminarase "${expense.title}" e xa non contara en balances nin graficos.', fr: '"${expense.title}" sera supprimee et ne comptera plus dans les soldes ni les graphiques.', it: '"${expense.title}" verra eliminata e non comparira piu in saldi o grafici.', pt: '"${expense.title}" sera eliminada e deixara de contar em saldos e graficos.')),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: Text(tr(context, es: 'Eliminar', en: 'Delete', gl: 'Eliminar', fr: 'Supprimer', it: 'Elimina', pt: 'Eliminar')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!approved) {
      return;
    }

    await ref.read(repositoryProvider).deleteExpense(groupId: group.id, expenseId: expense.id);
  }

  Future<List<SplitAllocation>?> _showAllocationEditor(BuildContext context, ExpenseGroup group, List<SplitAllocation> current) async {
    final members = sortedMembersByName(group.visibleMembers);
    final controllers = {
      for (final member in members)
        member.userId: TextEditingController(
          text: (current.firstWhereOrNull((entry) => entry.userId == member.userId)?.percentage ?? 0).toStringAsFixed(0),
        ),
    };

    return showDialog<List<SplitAllocation>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr(context, es: 'Reparto avanzado', en: 'Advanced split', gl: 'Reparto avanzado', fr: 'Repartition avancee', it: 'Ripartizione avanzata', pt: 'Divisao avancada')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, es: 'Decide qué porcentaje paga cada persona. La suma total debe dar 100%.', en: 'Set the percentage paid by each person. The total must be 100%.', gl: 'Decide que porcentaxe paga cada persoa. A suma total debe dar 100%.', fr: 'Decidez quel pourcentage paie chaque personne. Le total doit faire 100 %.', it: 'Decidi quale percentuale paga ogni persona. Il totale deve essere 100%.', pt: 'Decide que percentagem paga cada pessoa. O total deve ser 100%.'), style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                ...members.map((member) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[member.userId],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: '${member.name} (%)'),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final equal = equalAllocations(members);
                for (final allocation in equal) {
                  controllers[allocation.userId]?.text = allocation.percentage.toStringAsFixed(0);
                }
              },
              child: Text(tr(context, es: 'Equitativo', en: 'Equal split', gl: 'Equitativo', fr: 'Egalitaire', it: 'Equo', pt: 'Equitativo')),
            ),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
            FilledButton(
              onPressed: () {
                final allocations = members.map((member) {
                  return SplitAllocation(
                    userId: member.userId,
                    percentage: double.tryParse(controllers[member.userId]!.text.replaceAll(',', '.')) ?? 0,
                  );
                }).toList();
                final sum = allocations.fold<double>(0, (value, item) => value + item.percentage);
                if ((sum - 100).abs() > 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, es: 'La suma de porcentajes debe ser 100%.', en: 'The percentage sum must be 100%.', gl: 'A suma de porcentaxes debe ser 100%.', fr: 'La somme des pourcentages doit etre de 100 %.', it: 'La somma delle percentuali deve essere 100%.', pt: 'A soma das percentagens deve ser 100%.'))));
                  return;
                }
                Navigator.of(dialogContext).pop(allocations);
              },
              child: Text(tr(context, es: 'Guardar', en: 'Save', gl: 'Gardar', fr: 'Enregistrer', it: 'Salva', pt: 'Guardar')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleGroupClosed(BuildContext context, ExpenseGroup group) async {
    final closing = !group.isClosed;
    final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(closing ? tr(context, es: 'Cerrar grupo', en: 'Close group', gl: 'Pechar grupo', fr: 'Fermer le groupe', it: 'Chiudi gruppo', pt: 'Fechar grupo') : tr(context, es: 'Reabrir grupo', en: 'Reopen group', gl: 'Reabrir grupo', fr: 'Rouvrir le groupe', it: 'Riapri gruppo', pt: 'Reabrir grupo')),
              content: Text(closing ? tr(context, es: 'Nadie podrá añadir gastos ni modificar datos mientras el grupo esté cerrado.', en: 'No one will be able to add expenses or modify data while the group is closed.', gl: 'Ninguen podera engadir gastos nin modificar datos mentres o grupo estea pechado.', fr: 'Personne ne pourra ajouter des depenses ni modifier les donnees tant que le groupe sera ferme.', it: 'Nessuno potra aggiungere spese o modificare dati mentre il gruppo e chiuso.', pt: 'Ninguem podera adicionar despesas nem modificar dados enquanto o grupo estiver fechado.') : tr(context, es: 'El grupo volverá a permitir acciones y la fecha de cierre desaparecerá.', en: 'The group will allow actions again and the closed date will be cleared.', gl: 'O grupo volvera permitir accions e a data de peche desaparecera.', fr: 'Le groupe permettra de nouveau les actions et la date de fermeture disparaitra.', it: 'Il gruppo permettera di nuovo le azioni e la data di chiusura verra rimossa.', pt: 'O grupo voltara a permitir acoes e a data de fecho desaparecera.')),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(closing ? tr(context, es: 'Cerrar', en: 'Close', gl: 'Pechar', fr: 'Fermer', it: 'Chiudi', pt: 'Fechar') : tr(context, es: 'Reabrir', en: 'Reopen', gl: 'Reabrir', fr: 'Rouvrir', it: 'Riapri', pt: 'Reabrir'))),
              ],
            );
          },
        ) ??
        false;
    if (!approved) {
      return;
    }
    await ref.read(repositoryProvider).setGroupClosed(groupId: group.id, requesterId: widget.user.id, isClosed: closing);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(closing ? tr(context, es: 'Grupo cerrado.', en: 'Group closed.', gl: 'Grupo pechado.', fr: 'Groupe ferme.', it: 'Gruppo chiuso.', pt: 'Grupo fechado.') : tr(context, es: 'Grupo reabierto.', en: 'Group reopened.', gl: 'Grupo reaberto.', fr: 'Groupe rouvert.', it: 'Gruppo riaperto.', pt: 'Grupo reaberto.')),
          action: closing
              ? SnackBarAction(
                  label: tr(context, es: 'Solicitar pagos', en: 'Request payments', gl: 'Solicitar pagos', fr: 'Demander paiements', it: 'Richiedi pagamenti', pt: 'Solicitar pagamentos'),
                  onPressed: () => _notifyGroupSettlements(context, group),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _notifyGroupSettlements(BuildContext context, ExpenseGroup group) async {
    try {
      final sent = await ref.read(repositoryProvider).requestGroupSettlementNotifications(groupId: group.id, requesterId: widget.user.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent == 0
                ? tr(context, es: 'No hay deudas pendientes que reclamar.', en: 'There are no pending debts to request.', gl: 'Non hai debedas pendentes que reclamar.', fr: 'Il n y a pas de dettes en attente a reclamer.', it: 'Non ci sono debiti pendenti da richiedere.', pt: 'Nao ha dividas pendentes para pedir.')
                : tr(context, es: 'Aviso enviado a $sent integrante(s).', en: 'Notice sent to $sent member(s).', gl: 'Aviso enviado a $sent integrante(s).', fr: 'Avis envoye a $sent membre(s).', it: 'Avviso inviato a $sent membro/i.', pt: 'Aviso enviado a $sent integrante(s).'),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }

  void _showGroupClosedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, es: 'El grupo está cerrado. Solo está disponible en modo consulta.', en: 'The group is closed. It is available in read-only mode.', gl: 'O grupo esta pechado. So esta dispoñible en modo consulta.', fr: 'Le groupe est ferme. Il est disponible en lecture seule.', it: 'Il gruppo e chiuso. E disponibile solo in modalita lettura.', pt: 'O grupo esta fechado. So esta disponivel em modo de consulta.')),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.user,
    required this.group,
    required this.balances,
    required this.categories,
    required this.onInvite,
    required this.onCategories,
    required this.onAddExpense,
    required this.onOcrCamera,
    required this.onOcrGallery,
    required this.groupClosed,
    this.onManagePeople,
  });

  final AppUser user;
  final ExpenseGroup group;
  final Map<String, double> balances;
  final List<ExpenseCategory> categories;
  final VoidCallback onInvite;
  final VoidCallback onCategories;
  final VoidCallback onAddExpense;
  final VoidCallback onOcrCamera;
  final VoidCallback onOcrGallery;
  final bool groupClosed;
  final VoidCallback? onManagePeople;

  @override
  Widget build(BuildContext context) {
    final myBalance = balances[user.id] ?? 0;
    final balancePalette = _summaryBalancePalette(myBalance);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: _SummaryCard(label: tr(context, es: 'Total grupo', en: 'Group total', gl: 'Total do grupo', fr: 'Total du groupe', it: 'Totale gruppo', pt: 'Total do grupo'), value: money(totalGroupSpend(group), group.currency))),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: tr(context, es: 'Tu balance', en: 'Your balance', gl: 'O teu balance', fr: 'Votre solde', it: 'Il tuo saldo', pt: 'O teu saldo'),
                value: '${myBalance >= 0 ? '+' : ''}${money(myBalance, group.currency)}',
                valueColor: balancePalette.foreground,
                backgroundColor: balancePalette.background,
                borderColor: balancePalette.border,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SummaryCard(label: tr(context, es: 'Miembros', en: 'Members', gl: 'Membros', fr: 'Membres', it: 'Membri', pt: 'Membros'), value: '${group.totalDisplayedMembers}')),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: tr(context, es: 'Gastos', en: 'Expenses', gl: 'Gastos', fr: 'Depenses', it: 'Spese', pt: 'Despesas'), value: '${group.expenses.length}')),
          ],
        ),
        const SizedBox(height: 20),
        if (groupClosed) ...[
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tr(context, es: 'Este grupo está cerrado y solo se puede consultar. El administrador puede reabrirlo desde el menú superior.', en: 'This group is closed and can only be viewed. The admin can reopen it from the top menu.', gl: 'Este grupo esta pechado e so se pode consultar. A administracion pode reabrilo desde o menu superior.', fr: 'Ce groupe est ferme et uniquement consultable. L administrateur peut le rouvrir depuis le menu superieur.', it: 'Questo gruppo e chiuso e consultabile soltanto. L admin puo riaprirlo dal menu superiore.', pt: 'Este grupo esta fechado e so pode ser consultado. A administracao pode reabri-lo no menu superior.'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(tr(context, es: 'Acciones rápidas', en: 'Quick actions', gl: 'Accions rapidas', fr: 'Actions rapides', it: 'Azioni rapide', pt: 'Acoes rapidas'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionTile(icon: Icons.qr_code_2_rounded, label: tr(context, es: 'Invitar', en: 'Invite', gl: 'Convidar', fr: 'Inviter', it: 'Invita', pt: 'Convidar'), onTap: onInvite, enabled: !groupClosed),
            _ActionTile(icon: Icons.edit_note_rounded, label: tr(context, es: 'Añadir gasto', en: 'Add expense', gl: 'Engadir gasto', fr: 'Ajouter depense', it: 'Aggiungi spesa', pt: 'Adicionar despesa'), onTap: onAddExpense, enabled: !groupClosed),
            _ActionTile(icon: Icons.category_rounded, label: tr(context, es: 'Categorías', en: 'Categories', gl: 'Categorias', fr: 'Categories', it: 'Categorie', pt: 'Categorias'), onTap: onCategories, enabled: !groupClosed),
            if (onManagePeople != null) _ActionTile(icon: Icons.people_alt_rounded, label: tr(context, es: 'Personas y acceso', en: 'People and access', gl: 'Persoas e acceso', fr: 'Personnes et acces', it: 'Persone e accesso', pt: 'Pessoas e acesso'), onTap: onManagePeople!, enabled: !groupClosed),
            _ActionTile(icon: Icons.photo_library_rounded, label: tr(context, es: 'Subir ticket', en: 'Upload receipt', gl: 'Subir ticket', fr: 'Importer ticket', it: 'Carica scontrino', pt: 'Carregar fatura'), onTap: onOcrGallery, enabled: !groupClosed),
            _ActionTile(icon: Icons.photo_camera_back_rounded, label: tr(context, es: 'Ticket con cámara', en: 'Receipt with camera', gl: 'Ticket con camara', fr: 'Ticket avec camera', it: 'Scontrino con fotocamera', pt: 'Fatura com camara'), onTap: onOcrCamera, enabled: !groupClosed),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, es: 'Personas del grupo', en: 'Group people', gl: 'Persoas do grupo', fr: 'Personnes du groupe', it: 'Persone del gruppo', pt: 'Pessoas do grupo'), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sortedMembersByName(group.visibleMembers).map((member) {
                    final isOwner = !member.isPending && member.userId == group.ownerId;
                    final isAdmin = !member.isPending && group.adminIds.contains(member.userId);
                    final suffix = member.isPending
                        ? tr(context, es: 'pendiente', en: 'pending', gl: 'pendente', fr: 'en attente', it: 'in attesa', pt: 'pendente')
                      : member.isDeletedAccount
                        ? tr(context, es: 'cuenta eliminada', en: 'deleted account', gl: 'conta eliminada', fr: 'compte supprime', it: 'account eliminato', pt: 'conta eliminada')
                        : member.isArchived
                          ? tr(context, es: 'histórico', en: 'historical', gl: 'historico', fr: 'historique', it: 'storico', pt: 'historico')
                        : isOwner
                            ? tr(context, es: 'propietario', en: 'owner', gl: 'propietario', fr: 'proprietaire', it: 'proprietario', pt: 'proprietario')
                            : isAdmin
                              ? tr(context, es: 'admin', en: 'admin', gl: 'admin', fr: 'admin', it: 'admin', pt: 'admin')
                            : null;
                    return Chip(label: Text(suffix == null ? member.name : '${member.name} · $suffix'));
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (group.pendingMembers.isNotEmpty || group.allowAnonymousJoin)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, es: 'Acceso por invitación', en: 'Invite access', gl: 'Acceso por convite', fr: 'Acces par invitation', it: 'Accesso da invito', pt: 'Acesso por convite'), style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(group.allowAnonymousJoin ? tr(context, es: 'El grupo permite entrar solo clicando el enlace.', en: 'The group allows joining directly from the link.', gl: 'O grupo permite entrar so clicando a ligazon.', fr: 'Le groupe autorise l entree directe via le lien.', it: 'Il gruppo consente l accesso diretto dal link.', pt: 'O grupo permite entrar so clicando no link.') : tr(context, es: 'El acceso libre por enlace está desactivado.', en: 'Open link access is disabled.', gl: 'O acceso libre por ligazon esta desactivado.', fr: 'L acces libre par lien est desactive.', it: 'L accesso libero da link e disattivato.', pt: 'O acesso livre por link esta desativado.')),
                  const SizedBox(height: 12),
                  if (group.pendingMembers.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.pendingMembers.map((member) => Chip(label: Text('${member.name} · ${tr(context, es: 'pendiente', en: 'pending', gl: 'pendente', fr: 'en attente', it: 'in attesa', pt: 'pendente')}'))).toList(),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
                Text(tr(context, es: 'Categorías activas', en: 'Active categories', gl: 'Categorias activas', fr: 'Categories actives', it: 'Categorie attive', pt: 'Categorias ativas'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            return Chip(
              avatar: Icon(categoryIcons[category.iconKey] ?? Icons.receipt_long_rounded, size: 18),
              label: Text(category.name),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BalancesTab extends StatelessWidget {
  const _BalancesTab({required this.group, required this.balances, required this.currentUserId});

  final ExpenseGroup group;
  final Map<String, double> balances;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: sortedMembersByName(group.visibleMembers).map((member) {
        final balance = balances[member.userId] ?? 0;
        final tone = balance > 0 ? const Color(0xFFDFF7E8) : balance < 0 ? const Color(0xFFFFE0E0) : const Color(0xFFE9EEF5);
        final foreground = balance > 0 ? const Color(0xFF1E8E3E) : balance < 0 ? const Color(0xFFC62828) : const Color(0xFF607D8B);
        final status = balance > 0 ? tr(context, es: 'Recibe', en: 'Gets back', gl: 'Recibe', fr: 'Recoit', it: 'Riceve', pt: 'Recebe') : balance < 0 ? tr(context, es: 'Debe', en: 'Owes', gl: 'Debe', fr: 'Doit', it: 'Deve', pt: 'Deve') : tr(context, es: 'A cero', en: 'Settled', gl: 'A cero', fr: 'A zero', it: 'In pari', pt: 'A zero');
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _showBalanceSettlementDialog(context, group, member, balance, currentUserId),
              child: Ink(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    CircleAvatar(child: Text(member.name.substring(0, 1).toUpperCase())),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(status, style: TextStyle(color: foreground)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '${balance >= 0 ? '+' : ''}${money(balance, group.currency)}',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

Future<void> _showBalanceSettlementDialog(BuildContext context, ExpenseGroup group, GroupMember member, double balance, String currentUserId) {
  final optimizedEdges = settlementEdges(group);
  final counterparties = optimizedEdges
      .where((edge) => edge.fromUserId == member.userId || edge.toUserId == member.userId)
      .map((edge) {
        final counterpartyId = edge.fromUserId == member.userId ? edge.toUserId : edge.fromUserId;
        final signedAmount = edge.fromUserId == member.userId ? -edge.amount : edge.amount;
        return (member: group.visibleMembers.firstWhereOrNull((candidate) => candidate.userId == counterpartyId), amount: signedAmount);
      })
      .where((entry) => entry.member != null)
      .sorted((left, right) => right.amount.abs().compareTo(left.amount.abs()))
      .toList(growable: false);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (dialogContext) {
      return Consumer(
        builder: (dialogContext, ref, _) {
          return FractionallySizedBox(
            heightFactor: 0.84,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      balance >= 0 ? '+${money(balance, group.currency)}' : '-${money(balance.abs(), group.currency)}',
                      style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    if (counterparties.isEmpty)
                      Text(tr(context, es: 'No queda ninguna transferencia pendiente en el plan mínimo de este grupo.', en: 'There is no pending transfer left in this group\'s minimum plan.', gl: 'Non queda ningunha transferencia pendente no plan minimo deste grupo.', fr: 'Il ne reste aucun transfert dans le plan minimal de ce groupe.', it: 'Non resta alcun trasferimento nel piano minimo di questo gruppo.', pt: 'Nao resta nenhuma transferencia pendente no plano minimo deste grupo.'))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: counterparties.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final entry = counterparties[index];
                            final counterparty = entry.member!;
                            final tappedMemberPays = entry.amount < 0;
                            final debtorId = tappedMemberPays ? member.userId : counterparty.userId;
                            final creditorId = tappedMemberPays ? counterparty.userId : member.userId;
                            final currentUserIsDebtor = currentUserId == debtorId;
                            final currentUserIsCreditor = currentUserId == creditorId;
                            final amount = entry.amount.abs();
                            final accent = tappedMemberPays ? const Color(0xFFC77600) : const Color(0xFF1E8E5A);
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(counterparty.name, style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                            const SizedBox(height: 6),
                                            Text(
                                              tappedMemberPays
                                                  ? tr(context, es: '${member.name} paga a ${counterparty.name}', en: '${member.name} pays ${counterparty.name}', gl: '${member.name} paga a ${counterparty.name}', fr: '${member.name} paie ${counterparty.name}', it: '${member.name} paga ${counterparty.name}', pt: '${member.name} paga a ${counterparty.name}')
                                                  : tr(context, es: '${counterparty.name} paga a ${member.name}', en: '${counterparty.name} pays ${member.name}', gl: '${counterparty.name} paga a ${member.name}', fr: '${counterparty.name} paie ${member.name}', it: '${counterparty.name} paga ${member.name}', pt: '${counterparty.name} paga a ${member.name}'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                                        child: Text(money(amount, group.currency), style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                            onPressed: !currentUserIsCreditor || counterparty.isPending
                                              ? null
                                              : () async {
                                                  Navigator.of(dialogContext).pop();
                                                  await _requestDirectSettlement(context, ref, group, creditorId, debtorId, amount);
                                                },
                                          icon: const Icon(Icons.notifications_active_rounded),
                                          label: Text(tr(context, es: 'Solicitar dinero', en: 'Request money', gl: 'Solicitar diñeiro', fr: 'Demander argent', it: 'Richiedi denaro', pt: 'Solicitar dinheiro')),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                            onPressed: !currentUserIsDebtor || counterparty.isPending
                                              ? null
                                              : () async {
                                                  Navigator.of(dialogContext).pop();
                                                  await _recordDirectSettlement(context, ref, group, debtorId, creditorId, amount, debtorName: tappedMemberPays ? member.name : counterparty.name, creditorName: tappedMemberPays ? counterparty.name : member.name);
                                                },
                                          icon: const Icon(Icons.check_circle_rounded),
                                          label: Text(tr(context, es: 'Ya está pagado', en: 'Already paid', gl: 'Xa esta pagado', fr: 'Deja paye', it: 'Gia pagato', pt: 'Ja esta pago')),
                                        ),
                                      ),
                                    ],
                                  ),
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
    },
  );
}

Future<void> _requestDirectSettlement(
  BuildContext context,
  WidgetRef ref,
  ExpenseGroup group,
  String requesterId,
  String targetUserId,
  double suggestedAmount,
) async {
  final controller = TextEditingController(text: suggestedAmount.toStringAsFixed(2));
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
  if (!context.mounted) {
    return;
  }
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(tr(context, es: 'Confirmar solicitud', en: 'Confirm request', gl: 'Confirmar solicitude', fr: 'Confirmer la demande', it: 'Conferma richiesta', pt: 'Confirmar pedido')),
            content: Text(
              tr(context, es: 'Se enviará una solicitud por ${money(amount, group.currency)}.', en: 'A request for ${money(amount, group.currency)} will be sent.', gl: 'Enviarase unha solicitude por ${money(amount, group.currency)}.', fr: 'Une demande de ${money(amount, group.currency)} sera envoyee.', it: 'Verrà inviata una richiesta di ${money(amount, group.currency)}.', pt: 'Vai ser enviado um pedido de ${money(amount, group.currency)}.'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(tr(context, es: 'Confirmar', en: 'Confirm', gl: 'Confirmar', fr: 'Confirmer', it: 'Conferma', pt: 'Confirmar'))),
            ],
          );
        },
      ) ??
      false;
  if (!confirmed) {
    return;
  }
  await ref.read(repositoryProvider).requestReimbursement(groupId: group.id, requesterId: requesterId, targetUserId: targetUserId, amount: amount);
}

Future<void> _recordDirectSettlement(
  BuildContext context,
  WidgetRef ref,
  ExpenseGroup group,
  String debtorId,
  String creditorId,
  double suggestedAmount, {
  required String debtorName,
  required String creditorName,
}) async {
  final settlementTitle = tr(context, es: 'Liquidación directa', en: 'Direct settlement', gl: 'Liquidacion directa', fr: 'Reglement direct', it: 'Liquidazione diretta', pt: 'Liquidacao direta');
  final settlementNote = tr(context, es: 'Pago entre $debtorName y $creditorName.', en: 'Payment between $debtorName and $creditorName.', gl: 'Pago entre $debtorName e $creditorName.', fr: 'Paiement entre $debtorName et $creditorName.', it: 'Pagamento tra $debtorName e $creditorName.', pt: 'Pagamento entre $debtorName e $creditorName.');
  final settlementItemName = tr(context, es: 'Pago registrado', en: 'Recorded payment', gl: 'Pago rexistrado', fr: 'Paiement enregistre', it: 'Pagamento registrato', pt: 'Pagamento registado');
  final controller = TextEditingController(text: suggestedAmount.toStringAsFixed(2));
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
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(tr(context, es: 'Confirmar pago', en: 'Confirm payment', gl: 'Confirmar pago', fr: 'Confirmer le paiement', it: 'Conferma pagamento', pt: 'Confirmar pagamento')),
            content: Text(
              tr(context, es: 'Se registrará un pago de ${money(amount, group.currency)} entre $debtorName y $creditorName.', en: 'A payment of ${money(amount, group.currency)} between $debtorName and $creditorName will be recorded.', gl: 'Rexistrarase un pago de ${money(amount, group.currency)} entre $debtorName e $creditorName.', fr: 'Un paiement de ${money(amount, group.currency)} entre $debtorName et $creditorName sera enregistre.', it: 'Verrà registrato un pagamento di ${money(amount, group.currency)} tra $debtorName e $creditorName.', pt: 'Vai ser registado um pagamento de ${money(amount, group.currency)} entre $debtorName e $creditorName.'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(tr(context, es: 'Confirmar', en: 'Confirm', gl: 'Confirmar', fr: 'Confirmer', it: 'Conferma', pt: 'Confirmar'))),
            ],
          );
        },
      ) ??
      false;
  if (!confirmed) {
    return;
  }

  final uuid = const Uuid();
  final expense = ExpenseRecord(
    id: uuid.v4(),
    title: settlementTitle,
    payerId: debtorId,
    createdAt: DateTime.now(),
    kind: ExpenseRecordKind.settlement,
    note: settlementNote,
    items: [
      ExpenseItem(
        id: uuid.v4(),
        name: settlementItemName,
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

class _ExpensesTab extends StatefulWidget {
  const _ExpensesTab({
    required this.group,
    required this.currentUserId,
    required this.categories,
    required this.allowChanges,
    required this.onEditAllocations,
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  final ExpenseGroup group;
  final String currentUserId;
  final List<ExpenseCategory> categories;
  final bool allowChanges;
  final Future<void> Function(ExpenseRecord expense, ExpenseItem item) onEditAllocations;
  final Future<void> Function(ExpenseRecord expense) onEditExpense;
  final Future<void> Function(ExpenseRecord expense) onDeleteExpense;

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  String _payerId = 'all';
  String _participantId = 'all';

  bool get _hasActiveFilters => _payerId != 'all' || _participantId != 'all' || _minController.text.trim().isNotEmpty || _maxController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleMembers = sortedMembersByName(widget.group.visibleMembers);
    final minValue = double.tryParse(_minController.text.replaceAll(',', '.'));
    final maxValue = double.tryParse(_maxController.text.replaceAll(',', '.'));
    final filteredExpenses = widget.group.expenses.where((expense) {
      final total = totalExpense(expense);
      final payerMatch = _payerId == 'all' || expense.payerId == _payerId;
      final participantMatch = _participantId == 'all' || expense.items.any((item) => item.allocations.any((allocation) => allocation.userId == _participantId && allocation.percentage > 0));
      final minMatch = minValue == null || total >= minValue;
      final maxMatch = maxValue == null || total <= maxValue;
      return payerMatch && participantMatch && minMatch && maxMatch;
    }).sorted((a, b) => b.createdAt.compareTo(a.createdAt)).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!widget.allowChanges) ...[
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(context, es: 'El grupo está cerrado: puedes revisar gastos, pero no editarlos ni eliminarlos.', en: 'The group is closed: you can review expenses, but not edit or delete them.', gl: 'O grupo esta pechado: podes revisar gastos, pero non editalos nin eliminalos.', fr: 'Le groupe est ferme : vous pouvez consulter les depenses, mais pas les modifier ni les supprimer.', it: 'Il gruppo e chiuso: puoi consultare le spese, ma non modificarle o eliminarle.', pt: 'O grupo esta fechado: podes rever despesas, mas nao edita-las nem elimina-las.')),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: ExpansionTile(
            clipBehavior: Clip.none,
            initiallyExpanded: _hasActiveFilters,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            title: Row(
              children: [
                Expanded(child: Text(tr(context, es: 'Filtros', en: 'Filters', gl: 'Filtros', fr: 'Filtres', it: 'Filtri', pt: 'Filtros'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                if (_hasActiveFilters)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(tr(context, es: 'Activos', en: 'Active', gl: 'Activos', fr: 'Actifs', it: 'Attivi', pt: 'Ativos'), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            children: [
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 420;
                  if (narrow) {
                    return Column(
                      children: [
                        TextField(
                          controller: _minController,
                          decoration: InputDecoration(labelText: tr(context, es: 'Importe mínimo', en: 'Minimum amount', gl: 'Importe minimo', fr: 'Montant minimum', it: 'Importo minimo', pt: 'Valor minimo')),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _maxController,
                          decoration: InputDecoration(labelText: tr(context, es: 'Importe máximo', en: 'Maximum amount', gl: 'Importe maximo', fr: 'Montant maximum', it: 'Importo massimo', pt: 'Valor maximo')),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minController,
                          decoration: InputDecoration(labelText: tr(context, es: 'Importe mínimo', en: 'Minimum amount', gl: 'Importe minimo', fr: 'Montant minimum', it: 'Importo minimo', pt: 'Valor minimo')),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxController,
                          decoration: InputDecoration(labelText: tr(context, es: 'Importe máximo', en: 'Maximum amount', gl: 'Importe maximo', fr: 'Montant maximum', it: 'Importo massimo', pt: 'Valor maximo')),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _payerId,
                decoration: InputDecoration(labelText: tr(context, es: 'Añadido por', en: 'Added by', gl: 'Engadido por', fr: 'Ajoute par', it: 'Aggiunto da', pt: 'Adicionado por')),
                items: [
                  DropdownMenuItem(value: 'all', child: Text(tr(context, es: 'Todas las personas', en: 'Everyone', gl: 'Todas as persoas', fr: 'Toutes les personnes', it: 'Tutte le persone', pt: 'Todas as pessoas'))),
                  ...visibleMembers.map((member) => DropdownMenuItem(value: member.userId, child: Text(member.name))),
                ],
                onChanged: (value) => setState(() => _payerId = value ?? 'all'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _participantId,
                decoration: InputDecoration(labelText: tr(context, es: 'Participó', en: 'Participated', gl: 'Participou', fr: 'A participe', it: 'Ha partecipato', pt: 'Participou')),
                items: [
                  DropdownMenuItem(value: 'all', child: Text(tr(context, es: 'Cualquier participante', en: 'Any participant', gl: 'Calquera participante', fr: 'N importe quel participant', it: 'Qualsiasi partecipante', pt: 'Qualquer participante'))),
                  ...visibleMembers.map((member) => DropdownMenuItem(value: member.userId, child: Text(member.name))),
                ],
                onChanged: (value) => setState(() => _participantId = value ?? 'all'),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      _minController.clear();
                      _maxController.clear();
                      setState(() {
                        _payerId = 'all';
                        _participantId = 'all';
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: Text(tr(context, es: 'Limpiar filtros', en: 'Clear filters', gl: 'Limpar filtros', fr: 'Effacer les filtres', it: 'Pulisci filtri', pt: 'Limpar filtros')),
                  ),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (filteredExpenses.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(tr(context, es: 'No hay gastos que coincidan con los filtros.', en: 'No expenses match the filters.', gl: 'Non hai gastos que coincidan cos filtros.', fr: 'Aucune depense ne correspond aux filtres.', it: 'Nessuna spesa corrisponde ai filtri.', pt: 'Nenhuma despesa corresponde aos filtros.')))),
        ...filteredExpenses.map((expense) {
          final payer = widget.group.visibleMembers.firstWhereOrNull((member) => member.userId == expense.payerId);
          final isPayer = expense.payerId == widget.currentUserId;
          final isParticipant = expense.items.any((item) => item.allocations.any((allocation) => allocation.userId == widget.currentUserId && allocation.percentage > 0));
          final status = isPayer
              ? _ExpenseStatus.paid
              : isParticipant
                  ? _ExpenseStatus.participated
                  : _ExpenseStatus.outside;
          final colors = _expenseStatusPalette(context, status);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colors.border),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                title: Text(expense.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${payer?.name ?? tr(context, es: 'Alguien', en: 'Someone', gl: 'Alguen', fr: 'Quelqu un', it: 'Qualcuno', pt: 'Alguem')} · ${DateFormat('dd/MM/yyyy', localeTag(context)).format(expense.createdAt)}'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: colors.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        _expenseStatusLabel(context, status),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.accent, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                trailing: Text(money(totalExpense(expense), widget.group.currency), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: colors.accent)),
                children: [
                  if (expense.note != null && expense.note!.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(expense.note!),
                      ),
                    ),
                  ...expense.items.map((item) {
                    final category = widget.categories.firstWhereOrNull((entry) => entry.id == item.categoryId);
                    final participants = item.allocations.where((allocation) => allocation.percentage > 0).map((allocation) {
                      final member = widget.group.visibleMembers.firstWhereOrNull((entry) => entry.userId == allocation.userId);
                      return '${member?.name ?? allocation.userId} ${allocation.percentage.toStringAsFixed(0)}%';
                    }).join(' · ');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(item.name, style: Theme.of(context).textTheme.titleMedium)),
                              Text(money(item.amount, widget.group.currency)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(category?.name ?? item.categoryId),
                                avatar: Icon(categoryIcons[category?.iconKey ?? 'receipt'] ?? Icons.receipt_long_rounded, size: 16),
                              ),
                              if (participants.isNotEmpty) Chip(label: Text(participants)),
                              if (expense.receiptDownloadUrl != null)
                                ActionChip(
                                  onPressed: () => SharePlus.instance.share(ShareParams(text: expense.receiptDownloadUrl, subject: 'Ticket de ${expense.title}')),
                                  label: Text(tr(context, es: 'Ticket', en: 'Receipt', gl: 'Ticket', fr: 'Ticket', it: 'Scontrino', pt: 'Fatura')),
                                  avatar: const Icon(Icons.cloud_done_rounded, size: 16),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: widget.allowChanges ? () => widget.onEditExpense(expense) : null,
                                icon: const Icon(Icons.edit_rounded),
                                label: Text(tr(context, es: 'Editar gasto', en: 'Edit expense', gl: 'Editar gasto', fr: 'Modifier depense', it: 'Modifica spesa', pt: 'Editar despesa')),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: widget.allowChanges ? () => widget.onDeleteExpense(expense) : null,
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFC62828)),
                                label: Text(
                                  tr(context, es: 'Eliminar', en: 'Delete', gl: 'Eliminar', fr: 'Supprimer', it: 'Elimina', pt: 'Eliminar'),
                                  style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: widget.allowChanges ? () => widget.onEditAllocations(expense, item) : null,
                              icon: const Icon(Icons.tune_rounded),
                              label: Text(tr(context, es: 'Ajustar reparto', en: 'Adjust split', gl: 'Axustar reparto', fr: 'Ajuster la repartition', it: 'Regola ripartizione', pt: 'Ajustar divisao')),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

enum _ExpenseStatus { paid, participated, outside }

({Color background, Color border, Color accent}) _expenseStatusPalette(BuildContext context, _ExpenseStatus status) {
  switch (status) {
    case _ExpenseStatus.paid:
      return (
        background: const Color(0xFFE8F7EF),
        border: const Color(0xFF6CC08B),
        accent: const Color(0xFF1E8E5A),
      );
    case _ExpenseStatus.participated:
      return (
        background: const Color(0xFFFFF3E2),
        border: const Color(0xFFF0B15C),
        accent: const Color(0xFFC77600),
      );
    case _ExpenseStatus.outside:
      return (
        background: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Theme.of(context).colorScheme.outlineVariant,
        accent: Theme.of(context).colorScheme.onSurfaceVariant,
      );
  }
}

String _expenseStatusLabel(BuildContext context, _ExpenseStatus status) {
  switch (status) {
    case _ExpenseStatus.paid:
      return tr(context, es: 'Lo pagaste', en: 'You paid it', gl: 'Pagachelo ti', fr: 'Vous l avez paye', it: 'L hai pagato tu', pt: 'Pagaste tu');
    case _ExpenseStatus.participated:
      return tr(context, es: 'Participaste', en: 'You joined', gl: 'Participaches', fr: 'Vous avez participe', it: 'Hai partecipato', pt: 'Participaste');
    case _ExpenseStatus.outside:
      return tr(context, es: 'No participaste', en: 'You were not involved', gl: 'Non participaches', fr: 'Vous n etiez pas implique', it: 'Non eri coinvolto', pt: 'Nao participaste');
  }
}

class _GroupChartsTab extends StatefulWidget {
  const _GroupChartsTab({required this.group, required this.categories, required this.currentUserId});

  final ExpenseGroup group;
  final List<ExpenseCategory> categories;
  final String currentUserId;

  @override
  State<_GroupChartsTab> createState() => _GroupChartsTabState();
}

class _GroupChartsTabState extends State<_GroupChartsTab> {
  bool _global = true;
  late String _memberId;

  String _compactAxisAmount(BuildContext context, double value) {
    if (value.abs() < 0.009) {
      return '0';
    }
    final formatter = NumberFormat.compact(locale: localeTag(context));
    return '${value < 0 ? '-' : ''}${formatter.format(value.abs())}';
  }

  Future<void> _showBalanceChartInfo(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr(context, es: 'Cómo leer este gráfico', en: 'How to read this chart', gl: 'Como ler este grafico', fr: 'Comment lire ce graphique', it: 'Come leggere questo grafico', pt: 'Como ler este grafico')),
          content: Text(
            _global
                ? tr(context, es: 'Verde significa saldo a favor y rojo saldo pendiente. El plan mínimo de transferencias aparece en la pestaña anterior al tocar una persona.', en: 'Green means money to receive and red means money to pay. The minimum transfer plan appears in the previous tab when you tap a person.', gl: 'Verde significa saldo a favor e vermello saldo pendente. O plan minimo de transferencias aparece na lapela anterior ao tocar unha persoa.', fr: 'Le vert signifie un solde a recevoir et le rouge un solde a payer. Le plan minimal apparait dans l onglet precedent en touchant une personne.', it: 'Il verde indica saldo da ricevere e il rosso saldo da pagare. Il piano minimo appare nella scheda precedente toccando una persona.', pt: 'Verde significa saldo a favor e vermelho saldo por pagar. O plano minimo aparece no separador anterior ao tocar numa pessoa.')
                : tr(context, es: 'Mide qué parte de tus gastos está cubriendo cada pagador real del grupo.', en: 'It shows how much of your share is being covered by each real payer in the group.', gl: 'Mide que parte dos teus gastos esta a cubrir cada pagador real do grupo.', fr: 'Montre quelle part de vos depenses est couverte par chaque payeur reel du groupe.', it: 'Mostra quale parte della tua quota e coperta da ciascun pagatore reale del gruppo.', pt: 'Mostra que parte da tua quota esta a ser coberta por cada pagador real do grupo.'),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Entendido', en: 'Got it', gl: 'Entendido', fr: 'Compris', it: 'Capito', pt: 'Entendido'))),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _memberId = widget.currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final visibleMembers = sortedMembersByName(widget.group.visibleMembers);
    final categoryMap = {for (final category in widget.categories) category.id: category};
    final categoryTotalsData = <String, double>{};
    final memberBars = <String, double>{};

    for (final expense in widget.group.expenses) {
      for (final item in expense.items) {
        final value = _global ? item.amount : ((item.allocations.firstWhereOrNull((entry) => entry.userId == _memberId)?.percentage ?? 0) / 100) * item.amount;
        if (value <= 0) {
          continue;
        }
        categoryTotalsData.update(item.categoryId, (current) => current + value, ifAbsent: () => value);
      }
    }

    final balances = memberBalances(widget.group);
    if (_global) {
      for (final member in visibleMembers) {
        final balance = balances[member.userId] ?? 0;
        if (balance.abs() > 0.009) {
          memberBars[member.userId] = balance;
        }
      }
    } else {
      for (final expense in widget.group.expenses) {
        final selectedShare = memberOwedInExpense(expense, _memberId);
        if (selectedShare <= 0) {
          continue;
        }
        memberBars.update(expense.payerId, (current) => current + selectedShare, ifAbsent: () => selectedShare);
      }
    }

    final categoryEntries = categoryTotalsData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final memberEntries = memberBars.entries.toList()..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final emptyChartText = tr(context, es: 'Todavía no hay datos suficientes.', en: 'Not enough data yet.', gl: 'Ainda non hai datos suficientes.', fr: 'Pas assez de donnees pour le moment.', it: 'Non ci sono ancora dati sufficienti.', pt: 'Ainda nao ha dados suficientes.');
    final maxBarValue = memberEntries.isEmpty ? 100.0 : clampChartMax(memberEntries.map((entry) => entry.value.abs()));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(tr(context, es: 'Global', en: 'Global', gl: 'Global', fr: 'Global', it: 'Globale', pt: 'Global'))),
            ButtonSegment(value: false, label: Text(tr(context, es: 'Individual', en: 'Individual', gl: 'Individual', fr: 'Individuel', it: 'Individuale', pt: 'Individual'))),
          ],
          selected: {_global},
          onSelectionChanged: (value) => setState(() => _global = value.first),
        ),
        if (!_global) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _memberId,
            decoration: InputDecoration(labelText: tr(context, es: 'Participante', en: 'Participant', gl: 'Participante', fr: 'Participant', it: 'Partecipante', pt: 'Participante')),
            items: visibleMembers.map((member) => DropdownMenuItem(value: member.userId, child: Text(member.name))).toList(),
            onChanged: (value) => setState(() => _memberId = value ?? _memberId),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _global
                      ? tr(context, es: 'Distribución global por categoría', en: 'Overall distribution by category', gl: 'Distribucion global por categoria', fr: 'Distribution globale par categorie', it: 'Distribuzione globale per categoria', pt: 'Distribuicao global por categoria')
                      : tr(context, es: 'Reparto de tu parte por categoría', en: 'Your share by category', gl: 'Reparto da tua parte por categoria', fr: 'Votre part par categorie', it: 'La tua quota per categoria', pt: 'A tua parte por categoria'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 240,
                  child: categoryEntries.isEmpty
                      ? Center(child: Text(emptyChartText))
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 42,
                            sections: categoryEntries.take(5).mapIndexed((index, entry) {
                              final category = categoryMap[entry.key];
                              return PieChartSectionData(
                                value: entry.value,
                                title: '',
                                color: colorFromHex(category?.colorHex ?? '0xFFE4572E'),
                                radius: 92,
                              );
                            }).toList(),
                          ),
                        ),
                ),
                if (categoryEntries.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categoryEntries.take(5).mapIndexed((index, entry) {
                      final category = categoryMap[entry.key];
                      return Chip(
                        avatar: CircleAvatar(radius: 7, backgroundColor: colorFromHex(category?.colorHex ?? '0xFFE4572E')),
                        label: Text('${category?.name ?? entry.key} · ${money(entry.value, widget.group.currency)}'),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _global
                            ? tr(context, es: 'Balance neto por persona', en: 'Net balance by person', gl: 'Balance neto por persoa', fr: 'Solde net par personne', it: 'Saldo netto per persona', pt: 'Saldo liquido por pessoa')
                            : tr(context, es: 'Quién está cubriendo tu parte', en: 'Who is covering your share', gl: 'Quen esta cubrindo a tua parte', fr: 'Qui couvre votre part', it: 'Chi sta coprendo la tua quota', pt: 'Quem esta a cobrir a tua parte'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showBalanceChartInfo(context),
                      icon: const Icon(Icons.help_outline_rounded),
                      tooltip: tr(context, es: 'Cómo leer este gráfico', en: 'How to read this chart', gl: 'Como ler este grafico', fr: 'Comment lire ce graphique', it: 'Come leggere questo grafico', pt: 'Como ler este grafico'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 240,
                  child: memberEntries.isEmpty
                      ? Center(child: Text(emptyChartText))
                      : BarChart(
                          BarChartData(
                            minY: _global ? -maxBarValue : 0,
                            maxY: maxBarValue,
                            alignment: BarChartAlignment.spaceAround,
                            baselineY: 0,
                            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxBarValue / 4),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final visible = widget.group.visibleMembers.firstWhereOrNull((entry) => entry.userId == memberEntries[group.x.toInt()].key);
                                  if (visible == null) {
                                    return null;
                                  }
                                  return BarTooltipItem('${visible.name}\n${money(rod.toY.abs(), widget.group.currency)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700));
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  getTitlesWidget: (value, meta) {
                                    return Text(_compactAxisAmount(context, value), style: Theme.of(context).textTheme.labelSmall);
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= memberEntries.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final visible = widget.group.visibleMembers.firstWhereOrNull((entry) => entry.userId == memberEntries[index].key);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: SizedBox(
                                        width: 48,
                                        child: Text(
                                          visible?.name.split(' ').first ?? 'Miembro',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: memberEntries.mapIndexed((index, entry) {
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value,
                                    color: _global ? (entry.value >= 0 ? const Color(0xFF1E8E5A) : const Color(0xFFC62828)) : const Color(0xFFE4572E),
                                    width: 28,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.enabled = true});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 116,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: enabled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: enabled ? null : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: enabled ? null : Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateLine extends StatelessWidget {
  const _DateLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

({Color background, Color border, Color foreground}) _summaryBalancePalette(double balance) {
  if (balance > 0.009) {
    return (
      background: const Color(0xFFE8F7EF),
      border: const Color(0xFFB7E4C7),
      foreground: const Color(0xFF1E8E5A),
    );
  }
  if (balance < -0.009) {
    return (
      background: const Color(0xFFFFE8E8),
      border: const Color(0xFFF3B5B5),
      foreground: const Color(0xFFC62828),
    );
  }
  return (
    background: const Color(0xFFE9EEF5),
    border: const Color(0xFFD2DCE8),
    foreground: const Color(0xFF607D8B),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, this.valueColor, this.backgroundColor, this.borderColor});

  final String label;
  final String value;
  final Color? valueColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: valueColor)),
        ],
      ),
    );
  }
}