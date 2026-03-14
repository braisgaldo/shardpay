import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_text.dart';
import '../../app/preferences.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/defaults.dart';
import '../../core/expense_math.dart';
import '../../models/app_models.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/manual/user_manual_sheet.dart';
import '../balances/global_balances_screen.dart';
import '../groups/group_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final AppLinks _appLinks = AppLinks();
  int _index = 0;
  bool _manualQueued = false;
  StreamSubscription<Uri>? _inviteSubscription;
  String? _pendingInvite;

  @override
  void initState() {
    super.initState();
    _listenForInviteLinks();
  }

  @override
  void dispose() {
    _inviteSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider);
    _queueManualIfNeeded(preferences);

    final pages = [
      _GroupsView(
        user: widget.user,
        pendingInvite: _pendingInvite,
        onInviteHandled: _clearPendingInvite,
      ),
      GlobalBalancesScreen(user: widget.user),
      StatsScreen(user: widget.user),
      SettingsScreen(user: widget.user),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.grid_view_rounded), label: tr(context, es: 'Grupos', en: 'Groups', gl: 'Grupos', fr: 'Groupes', it: 'Gruppi', pt: 'Grupos')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_rounded), label: tr(context, es: 'Balance global', en: 'Global balance', gl: 'Balance global', fr: 'Solde global', it: 'Bilancio globale', pt: 'Saldo global')),
          NavigationDestination(icon: const Icon(Icons.query_stats_rounded), label: tr(context, es: 'Estadísticas', en: 'Stats', gl: 'Estatisticas', fr: 'Stats', it: 'Statistiche', pt: 'Estatisticas')),
          NavigationDestination(icon: const Icon(Icons.tune_rounded), label: tr(context, es: 'Ajustes', en: 'Settings', gl: 'Axustes', fr: 'Reglages', it: 'Impostazioni', pt: 'Ajustes')),
        ],
      ),
    );
  }

  void _queueManualIfNeeded(AppPreferences preferences) {
    if (preferences.hasSeenManual || _manualQueued) {
      return;
    }
    _manualQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await showUserManualSheet(context);
      if (mounted) {
        ref.read(appPreferencesProvider.notifier).markManualSeen();
      }
    });
  }

  Future<void> _listenForInviteLinks() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _queueInvite(initialUri);
    }

    _inviteSubscription = _appLinks.uriLinkStream.listen(
      _queueInvite,
      onError: (_) {},
    );
  }

  void _queueInvite(Uri uri) {
    if (!_isSupportedInviteUri(uri)) {
      return;
    }

    final rawInvite = uri.toString();
    if (_pendingInvite == rawInvite || !mounted) {
      return;
    }

    setState(() {
      _pendingInvite = rawInvite;
      _index = 0;
    });
  }

  bool _isSupportedInviteUri(Uri uri) {
    final hasGroup = uri.queryParameters['group']?.isNotEmpty ?? false;
    if (!hasGroup) {
      return false;
    }

    final isCustomJoin = uri.scheme == 'shardpay' && uri.host == 'join';
    final isWebJoin = uri.scheme == 'https' && uri.host == 'shardpay.app' && uri.path.startsWith('/join');
    return isCustomJoin || isWebJoin;
  }

  void _clearPendingInvite(String rawInvite) {
    if (!mounted || _pendingInvite != rawInvite) {
      return;
    }
    setState(() => _pendingInvite = null);
  }
}

class _GroupsView extends ConsumerStatefulWidget {
  const _GroupsView({required this.user, this.pendingInvite, required this.onInviteHandled});

  final AppUser user;
  final String? pendingInvite;
  final ValueChanged<String> onInviteHandled;

  @override
  ConsumerState<_GroupsView> createState() => _GroupsViewState();
}

class _GroupsViewState extends ConsumerState<_GroupsView> {
  final _searchController = TextEditingController();
  final Set<String> _expandedGroupIds = <String>{};
  String _query = '';
  _SearchScope _searchScope = _SearchScope.groups;
  bool _isConsumingInvite = false;
  OverlayEntry? _joinToastEntry;
  Timer? _joinToastTimer;

  Future<void> _refreshGroups() async {
    ref.invalidate(groupsProvider(widget.user.id));
    await ref.read(groupsProvider(widget.user.id).future);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingInvite());
  }

  @override
  void didUpdateWidget(covariant _GroupsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingInvite != oldWidget.pendingInvite) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingInvite());
    }
  }

  @override
  void dispose() {
    _joinToastTimer?.cancel();
    _removeJoinToast();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _consumePendingInvite() async {
    final rawInvite = widget.pendingInvite;
    if (!mounted || rawInvite == null || _isConsumingInvite) {
      return;
    }

    _isConsumingInvite = true;
    try {
      final joinPin = await _promptJoinPin();
      if (!mounted || joinPin == null) {
        return;
      }
      await _resolveJoinFlow(context, rawInvite, joinPin);
    } finally {
      _isConsumingInvite = false;
      if (mounted) {
        widget.onInviteHandled(rawInvite);
      }
    }
  }

  Future<String?> _promptJoinPin() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr(context, es: 'PIN del grupo', en: 'Group PIN', gl: 'PIN do grupo', fr: 'PIN du groupe', it: 'PIN del gruppo', pt: 'PIN do grupo')),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: InputDecoration(labelText: tr(context, es: 'Introduce el PIN de 4 dígitos', en: 'Enter the 4-digit PIN', gl: 'Introduce o PIN de 4 dixitos', fr: 'Saisissez le PIN a 4 chiffres', it: 'Inserisci il PIN a 4 cifre', pt: 'Introduz o PIN de 4 digitos')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()), child: Text(tr(context, es: 'Continuar', en: 'Continue', gl: 'Continuar', fr: 'Continuer', it: 'Continua', pt: 'Continuar'))),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsProvider(widget.user.id));

    return SafeArea(
      child: groupsState.when(
        data: (groups) {
          final sortedGroups = [...groups]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final visibleGroups = sortedGroups.where((group) {
            final haystack = switch (_searchScope) {
              _SearchScope.groups => '${group.name} ${group.description ?? ''}'.toLowerCase(),
              _SearchScope.people => group.visibleMembers.map((member) => member.name).join(' ').toLowerCase(),
            };
            return haystack.contains(_query.toLowerCase());
          }).toList();

          return RefreshIndicator(
            onRefresh: _refreshGroups,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: const ShardPayBrandMark(size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ShardPay', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          Text(
                            tr(
                              context,
                              es: 'Hola, ${widget.user.displayName.split(' ').first}',
                              en: 'Hi, ${widget.user.displayName.split(' ').first}',
                              gl: 'Ola, ${widget.user.displayName.split(' ').first}',
                              fr: 'Salut, ${widget.user.displayName.split(' ').first}',
                              it: 'Ciao, ${widget.user.displayName.split(' ').first}',
                              pt: 'Ola, ${widget.user.displayName.split(' ').first}',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showCreateGroupDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr(context, es: 'Grupo', en: 'Group', gl: 'Grupo', fr: 'Groupe', it: 'Gruppo', pt: 'Grupo')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: _searchScope == _SearchScope.groups
                      ? tr(context, es: 'Buscar grupos', en: 'Search groups', gl: 'Buscar grupos', fr: 'Rechercher groupes', it: 'Cerca gruppi', pt: 'Procurar grupos')
                      : tr(context, es: 'Buscar personas', en: 'Search people', gl: 'Buscar persoas', fr: 'Rechercher personnes', it: 'Cerca persone', pt: 'Procurar pessoas'),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<_SearchScope>(
                segments: [
                  ButtonSegment(value: _SearchScope.groups, icon: const Icon(Icons.grid_view_rounded), label: Text(tr(context, es: 'Grupos', en: 'Groups', gl: 'Grupos', fr: 'Groupes', it: 'Gruppi', pt: 'Grupos'))),
                  ButtonSegment(value: _SearchScope.people, icon: const Icon(Icons.people_alt_rounded), label: Text(tr(context, es: 'Personas', en: 'People', gl: 'Persoas', fr: 'Personnes', it: 'Persone', pt: 'Pessoas'))),
                ],
                selected: {_searchScope},
                onSelectionChanged: (selection) => setState(() => _searchScope = selection.first),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showJoinGroupDialog(context),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(tr(context, es: 'Entrar por enlace o QR', en: 'Join with link or QR', gl: 'Entrar por ligazon ou QR', fr: 'Entrer via lien ou QR', it: 'Entra con link o QR', pt: 'Entrar por link ou QR')),
              ),
              const SizedBox(height: 16),
              if (visibleGroups.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isEmpty
                          ? tr(context, es: 'Todavía no tienes grupos. Crea uno nuevo o entra con una invitación.', en: 'You do not have groups yet. Create one or join with an invite.', gl: 'Ainda non tes grupos. Crea un novo ou entra cun convite.', fr: 'Vous n avez pas encore de groupes. Creez-en un ou rejoignez-en un.', it: 'Non hai ancora gruppi. Creane uno o entra con un invito.', pt: 'Ainda nao tens grupos. Cria um novo ou entra com um convite.')
                          : tr(context, es: 'No hay grupos que coincidan con tu búsqueda.', en: 'No groups match your search.', gl: 'Non hai grupos que coincidan coa busca.', fr: 'Aucun groupe ne correspond a votre recherche.', it: 'Nessun gruppo corrisponde alla ricerca.', pt: 'Nenhum grupo corresponde a pesquisa.'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ...visibleGroups.map((group) {
                final balances = memberBalances(group);
                final myBalance = balances[widget.user.id] ?? 0;
                final expanded = _expandedGroupIds.contains(group.id);
                final balanceTone = _balanceTone(myBalance);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: group.isClosed ? Theme.of(context).colorScheme.surfaceContainerHigh : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () {
                        setState(() {
                          if (expanded) {
                            _expandedGroupIds.remove(group.id);
                          } else {
                            _expandedGroupIds.add(group.id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(groupIconForKey(group.iconKey), color: Theme.of(context).colorScheme.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      if (group.isClosed)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.lock_clock_rounded, size: 14),
                                                const SizedBox(width: 6),
                                                Text(tr(context, es: 'Grupo cerrado', en: 'Closed group', gl: 'Grupo pechado', fr: 'Groupe ferme', it: 'Gruppo chiuso', pt: 'Grupo fechado')),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if ((group.description ?? '').trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            group.description!,
                                            maxLines: expanded ? 2 : 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton.filledTonal(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => GroupDetailScreen(user: widget.user, groupId: group.id),
                                    ),
                                  ),
                                  icon: const Icon(Icons.arrow_outward_rounded),
                                  tooltip: tr(context, es: 'Ir al grupo', en: 'Open group', gl: 'Ir ao grupo', fr: 'Ouvrir le groupe', it: 'Apri gruppo', pt: 'Abrir grupo'),
                                ),
                              ],
                            ),
                            if (expanded) ...[
                              const SizedBox(height: 10),
                              Text(
                                tr(
                                  context,
                                  es: '${group.totalDisplayedMembers} miembros · invite ${group.inviteCode} · actualizado ${DateFormat('dd/MM HH:mm', localeTag(context)).format(group.updatedAt)}',
                                  en: '${group.totalDisplayedMembers} members · invite ${group.inviteCode} · updated ${DateFormat('dd/MM HH:mm', localeTag(context)).format(group.updatedAt)}',
                                  gl: '${group.totalDisplayedMembers} membros · invite ${group.inviteCode} · actualizado ${DateFormat('dd/MM HH:mm', localeTag(context)).format(group.updatedAt)}',
                                  fr: '${group.totalDisplayedMembers} membres · invite ${group.inviteCode} · maj ${DateFormat('dd/MM HH:mm', localeTag(context)).format(group.updatedAt)}',
                                  it: '${group.totalDisplayedMembers} membri · invite ${group.inviteCode} · aggiornato ${DateFormat('dd/MM HH:mm', localeTag(context)).format(group.updatedAt)}',
                                  pt: '${group.totalDisplayedMembers} membros · invite ${group.inviteCode} · atualizado ${DateFormat('dd/MM HH:mm', localeTag(context)).format(group.updatedAt)}',
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(child: _MetricCard(label: tr(context, es: 'Gastado', en: 'Spent', gl: 'Gastado', fr: 'Depense', it: 'Speso', pt: 'Gasto'), value: money(totalGroupSpend(group), group.currency))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      label: tr(context, es: 'Tu balance', en: 'Your balance', gl: 'O teu balance', fr: 'Votre solde', it: 'Il tuo saldo', pt: 'O teu saldo'),
                                      value: '${myBalance >= 0 ? '+' : ''}${money(myBalance, group.currency)}',
                                      valueColor: balanceTone.$1,
                                      backgroundColor: balanceTone.$2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...group.visibleMembers.take(5).map((member) => Chip(label: Text(member.isPending ? '${member.name} · ${tr(context, es: 'pendiente', en: 'pending', gl: 'pendente', fr: 'en attente', it: 'in attesa', pt: 'pendente')}' : member.name))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    final link = _inviteLink(group);
                                    SharePlus.instance.share(ShareParams(text: link, subject: tr(context, es: 'Únete a ${group.name} en ShardPay', en: 'Join ${group.name} on ShardPay', gl: 'Unete a ${group.name} en ShardPay', fr: 'Rejoignez ${group.name} sur ShardPay', it: 'Unisciti a ${group.name} su ShardPay', pt: 'Junta-te a ${group.name} no ShardPay')));
                                  },
                                  icon: const Icon(Icons.share_rounded),
                                  label: Text(tr(context, es: 'Compartir invitación', en: 'Share invite', gl: 'Compartir convite', fr: 'Partager l invitation', it: 'Condividi invito', pt: 'Partilhar convite')),
                                ),
                              ),
                            ],
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

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final controller = TextEditingController();
    final pendingController = TextEditingController();
    final pendingMembers = <PendingGroupMember>[];
    final uuid = const Uuid();
    var currency = 'EUR';
    var iconKey = 'groups';
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(tr(context, es: 'Crear grupo', en: 'Create group', gl: 'Crear grupo', fr: 'Creer un groupe', it: 'Crea gruppo', pt: 'Criar grupo')),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: tr(context, es: 'Nombre del grupo', en: 'Group name', gl: 'Nome do grupo', fr: 'Nom du groupe', it: 'Nome del gruppo', pt: 'Nome do grupo'),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: currency,
                        decoration: InputDecoration(labelText: tr(context, es: 'Divisa', en: 'Currency', gl: 'Divisa', fr: 'Devise', it: 'Valuta', pt: 'Moeda')),
                        items: currencyOptions.map((entry) => DropdownMenuItem(value: entry.code, child: Text('${entry.code} · ${entry.label}'))).toList(),
                        onChanged: (value) => setDialogState(() => currency = value ?? currency),
                      ),
                      const SizedBox(height: 16),
                      Text(tr(context, es: 'Personas pendientes', en: 'Pending people', gl: 'Persoas pendentes', fr: 'Personnes en attente', it: 'Persone in attesa', pt: 'Pessoas pendentes'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(tr(context, es: 'Añade a gente aunque todavía no tenga cuenta. Luego podrá vincularse desde el enlace.', en: 'Add people even if they do not have an account yet. They can link themselves from the invite later.', gl: 'Engade xente ainda que non teña conta. Logo podera vincularse desde a ligazon.', fr: 'Ajoutez des personnes meme sans compte. Elles pourront se lier plus tard via l invitation.', it: 'Aggiungi persone anche senza account. Potranno collegarsi dall invito in seguito.', pt: 'Adiciona pessoas mesmo sem conta. Poderao associar-se mais tarde pelo convite.')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pendingController,
                              decoration: InputDecoration(
                                labelText: tr(context, es: 'Añadir participante', en: 'Add participant', gl: 'Engadir participante', fr: 'Ajouter un participant', it: 'Aggiungi partecipante', pt: 'Adicionar participante'),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                              ),
                              onSubmitted: (_) {
                                final value = pendingController.text.trim();
                                if (value.isEmpty) {
                                  return;
                                }
                                setDialogState(() {
                                  pendingMembers.add(PendingGroupMember(id: uuid.v4(), name: value));
                                  pendingController.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () {
                              final value = pendingController.text.trim();
                              if (value.isEmpty) {
                                return;
                              }
                              setDialogState(() {
                                pendingMembers.add(PendingGroupMember(id: uuid.v4(), name: value));
                                pendingController.clear();
                              });
                            },
                            child: Text(tr(context, es: 'Añadir', en: 'Add', gl: 'Engadir', fr: 'Ajouter', it: 'Aggiungi', pt: 'Adicionar')),
                          ),
                        ],
                      ),
                      if (pendingMembers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sortedMembersByName(pendingMembers.map((entry) => GroupMember(userId: entry.id, name: entry.name, email: '', isPending: true))).map((entry) {
                            return InputChip(
                              label: Text(entry.name),
                              onDeleted: () => setDialogState(() => pendingMembers.removeWhere((item) => item.name == entry.name)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(
                  onPressed: () async {
                    await ref.read(repositoryProvider).createGroup(
                          owner: widget.user,
                          name: controller.text.trim(),
                        iconKey: iconKey,
                          currency: currency,
                          pendingMembers: pendingMembers,
                        );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: Text(tr(context, es: 'Crear', en: 'Create', gl: 'Crear', fr: 'Creer', it: 'Crea', pt: 'Criar')),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, es: 'Grupo creado.', en: 'Group created.', gl: 'Grupo creado.', fr: 'Groupe cree.', it: 'Gruppo creato.', pt: 'Grupo criado.'))));
    }
  }

  Future<void> _showJoinGroupDialog(BuildContext context) async {
    final controller = TextEditingController();
    final pinController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(labelText: tr(context, es: 'Pega enlace o código del grupo', en: 'Paste group link or code', gl: 'Pega a ligazon ou o codigo do grupo', fr: 'Collez le lien ou code du groupe', it: 'Incolla link o codice del gruppo', pt: 'Cola o link ou codigo do grupo')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: InputDecoration(labelText: tr(context, es: 'PIN del grupo (4 dígitos)', en: 'Group PIN (4 digits)', gl: 'PIN do grupo (4 dixitos)', fr: 'PIN du groupe (4 chiffres)', it: 'PIN del gruppo (4 cifre)', pt: 'PIN do grupo (4 digitos)')),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final scanned = await Navigator.of(sheetContext).push<String>(
                          MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
                        );
                        if (scanned != null) {
                          controller.text = scanned;
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(tr(context, es: 'Escanear QR', en: 'Scan QR', gl: 'Escanear QR', fr: 'Scanner QR', it: 'Scansiona QR', pt: 'Ler QR')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async => _resolveJoinFlow(sheetContext, controller.text.trim(), pinController.text.trim()),
                      child: Text(tr(context, es: 'Continuar', en: 'Continue', gl: 'Continuar', fr: 'Continuer', it: 'Continua', pt: 'Continuar')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resolveJoinFlow(BuildContext context, String rawInvite, String joinPin) async {
    final navigator = Navigator.of(context);
    try {
      if (rawInvite.trim().isEmpty) {
        _showJoinToast(
          context,
          tr(context, es: 'El enlace o código para unirte no es correcto.', en: 'The join link or code is not valid.', gl: 'A ligazon ou o codigo para entrar non e correcto.', fr: 'Le lien ou code d invitation n est pas valide.', it: 'Il link o codice di invito non e valido.', pt: 'O link ou codigo para entrar nao e valido.'),
        );
        return;
      }
      if (joinPin.length != 4) {
        _showJoinToast(
          context,
          tr(context, es: 'El PIN para unirte no es correcto.', en: 'The join PIN is not valid.', gl: 'O PIN para entrar non e correcto.', fr: 'Le PIN d invitation n est pas valide.', it: 'Il PIN per entrare non e valido.', pt: 'O PIN para entrar nao e valido.'),
        );
        return;
      }
      final repository = ref.read(repositoryProvider);
      final group = await repository.previewInvite(rawInvite);
      if (!context.mounted) {
        return;
      }
      if (group == null) {
        _showJoinToast(
          context,
          tr(context, es: 'El enlace o código para unirte no es correcto.', en: 'The join link or code is not valid.', gl: 'A ligazon ou o codigo para entrar non e correcto.', fr: 'Le lien ou code d invitation n est pas valide.', it: 'Il link o codice di invito non e valido.', pt: 'O link ou codigo para entrar nao e valido.'),
        );
        return;
      }
      if (group.joinPin != joinPin.trim()) {
        _showJoinToast(
          context,
          tr(context, es: 'El PIN para unirte no es correcto.', en: 'The join PIN is not valid.', gl: 'O PIN para entrar non e correcto.', fr: 'Le PIN d invitation n est pas valide.', it: 'Il PIN per entrare non e valido.', pt: 'O PIN para entrar nao e valido.'),
        );
        return;
      }

      String? selectedPendingMemberId;
      if (group.pendingMembers.isNotEmpty || !group.allowAnonymousJoin) {
        if (!mounted) {
          return;
        }
        selectedPendingMemberId = await _pickInviteIdentity(group);
        if (selectedPendingMemberId == null && !group.allowAnonymousJoin) {
          return;
        }
      }

      await repository.joinGroupByInvite(
        user: widget.user,
        rawInvite: rawInvite,
        joinPin: joinPin,
        pendingMemberId: selectedPendingMemberId,
      );
      if (mounted && context.mounted) {
        navigator.pop();
        _showJoinToast(
          context,
          tr(context, es: 'Has entrado en ${group.name}.', en: 'You joined ${group.name}.', gl: 'Entraches en ${group.name}.', fr: 'Vous avez rejoint ${group.name}.', it: 'Sei entrato in ${group.name}.', pt: 'Entraste em ${group.name}.'),
          isError: false,
        );
      }
    } catch (error) {
      if (mounted && context.mounted) {
        final message = error.toString().replaceFirst('Bad state: ', '');
        if (message.contains('PIN del grupo no es correcto')) {
          _showJoinToast(
            context,
            tr(context, es: 'El PIN para unirte no es correcto.', en: 'The join PIN is not valid.', gl: 'O PIN para entrar non e correcto.', fr: 'Le PIN d invitation n est pas valide.', it: 'Il PIN per entrare non e valido.', pt: 'O PIN para entrar nao e valido.'),
          );
        } else if (message.contains('No se encontró ningún grupo') || message.contains('Invitación no encontrada')) {
          _showJoinToast(
            context,
            tr(context, es: 'El enlace o código para unirte no es correcto.', en: 'The join link or code is not valid.', gl: 'A ligazon ou o codigo para entrar non e correcto.', fr: 'Le lien ou code d invitation n est pas valide.', it: 'Il link o codice di invito non e valido.', pt: 'O link ou codigo para entrar nao e valido.'),
          );
        } else {
          _showJoinToast(context, message);
        }
      }
    }
  }

  void _showJoinToast(BuildContext context, String message, {bool isError = true}) {
    FocusScope.of(context).unfocus();
    _joinToastTimer?.cancel();
    _removeJoinToast();

    final overlay = Overlay.of(this.context, rootOverlay: true);
    final mediaQuery = MediaQuery.of(this.context);
    final topOffset = mediaQuery.padding.top + 18;
    final backgroundColor = isError ? const Color(0xFFF04438) : const Color(0xFF1E8E5A);
    final foregroundColor = colorOn(backgroundColor);
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
    _joinToastEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: topOffset,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: Material(
                type: MaterialType.transparency,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: foregroundColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                message,
                                style: Theme.of(overlayContext).textTheme.bodyMedium?.copyWith(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_joinToastEntry!);
    _joinToastTimer = Timer(const Duration(seconds: 3), _removeJoinToast);
  }

  void _removeJoinToast() {
    _joinToastEntry?.remove();
    _joinToastEntry = null;
  }

  Future<String?> _pickInviteIdentity(ExpenseGroup group) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(sheetContext, es: '¿Quién eres en ${group.name}?', en: 'Who are you in ${group.name}?', gl: 'Quen es en ${group.name}?', fr: 'Qui etes-vous dans ${group.name} ?', it: 'Chi sei in ${group.name}?', pt: 'Quem es em ${group.name}?'), style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                group.allowAnonymousJoin
                    ? tr(sheetContext, es: 'Toca una opción y entrarás directamente al grupo.', en: 'Tap an option and you will join the group immediately.', gl: 'Toca unha opcion e entraras directamente no grupo.', fr: 'Touchez une option et vous rejoindrez directement le groupe.', it: 'Tocca un opzione ed entrerai subito nel gruppo.', pt: 'Toca numa opcao e entraras diretamente no grupo.')
                    : tr(sheetContext, es: 'Toca el nombre que preparó el administrador para vincular tu acceso.', en: 'Tap the name prepared by the admin to link your access.', gl: 'Toca o nome que preparou a persoa administradora para vincular o acceso.', fr: 'Touchez le nom prepare par l administrateur pour lier votre acces.', it: 'Tocca il nome preparato dall amministratore per collegare il tuo accesso.', pt: 'Toca no nome preparado pela administracao para associar o acesso.'),
              ),
              const SizedBox(height: 16),
              if (group.allowAnonymousJoin)
                _IdentityTile(
                  selected: false,
                  title: Text(tr(sheetContext, es: 'Entrar como ${widget.user.displayName}', en: 'Join as ${widget.user.displayName}', gl: 'Entrar como ${widget.user.displayName}', fr: 'Entrer comme ${widget.user.displayName}', it: 'Entra come ${widget.user.displayName}', pt: 'Entrar como ${widget.user.displayName}')),
                  onTap: () => Navigator.of(sheetContext).pop(null),
                ),
              ...group.pendingMembers.map((member) {
                return _IdentityTile(
                  selected: false,
                  title: Text(member.name),
                  subtitle: Text(tr(sheetContext, es: 'Nombre preparado por el administrador', en: 'Prepared by the admin', gl: 'Nome preparado pola administracion', fr: 'Nom prepare par l administrateur', it: 'Nome preparato dall amministratore', pt: 'Nome preparado pela administracao')),
                  onTap: () => Navigator.of(sheetContext).pop(member.id),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

String _inviteLink(ExpenseGroup group) => 'shardpay://join?group=${group.id}&token=${group.inviteCode}';

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, this.valueColor, this.backgroundColor});

  final String label;
  final String value;
  final Color? valueColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = backgroundColor ?? colorScheme.surface;
    final labelColor = colorOn(background, dark: colorScheme.onSurface).withValues(alpha: 0.72);
    final resolvedValueColor = valueColor ?? colorOn(background, dark: colorScheme.onSurface);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: labelColor)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: resolvedValueColor)),
        ],
      ),
    );
  }
}

enum _SearchScope { groups, people }

(Color?, Color?) _balanceTone(double balance) {
  if (balance > 0.009) {
    return (const Color(0xFF1E8E5A), const Color(0xFFE8F7EF));
  }
  if (balance < -0.009) {
    return (const Color(0xFFC62828), const Color(0xFFFFE3E3));
  }
  return (null, null);
}

class _IdentityTile extends StatelessWidget {
  const _IdentityTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

class _QrScannerScreen extends StatelessWidget {
  const _QrScannerScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear invitación')),
      body: MobileScanner(
        onDetect: (capture) {
          final value = capture.barcodes.first.rawValue;
          if (value != null && context.mounted) {
            Navigator.of(context).pop(value);
          }
        },
      ),
    );
  }
}