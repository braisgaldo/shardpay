import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_text.dart';
import '../../app/providers.dart';
import '../../core/defaults.dart';
import '../../core/expense_math.dart';
import '../../models/app_models.dart';

enum _StatsChartKind { insights, categories, groups, monthly, people, tickets, weekdays }

class _ChartOption {
  const _ChartOption({required this.kind, required this.icon});

  final _StatsChartKind kind;
  final IconData icon;
}

const _chartOptions = [
  _ChartOption(kind: _StatsChartKind.insights, icon: Icons.insights_rounded),
  _ChartOption(kind: _StatsChartKind.categories, icon: Icons.pie_chart_rounded),
  _ChartOption(kind: _StatsChartKind.groups, icon: Icons.stacked_bar_chart_rounded),
  _ChartOption(kind: _StatsChartKind.monthly, icon: Icons.show_chart_rounded),
  _ChartOption(kind: _StatsChartKind.people, icon: Icons.groups_rounded),
  _ChartOption(kind: _StatsChartKind.tickets, icon: Icons.receipt_long_rounded),
  _ChartOption(kind: _StatsChartKind.weekdays, icon: Icons.calendar_view_week_rounded),
];

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _StatsChartKind _selectedChart = _StatsChartKind.insights;
  final Set<String> _selectedGroupIds = <String>{};

  Future<void> _refreshGroups() async {
    ref.invalidate(groupsProvider(widget.user.id));
    await ref.read(groupsProvider(widget.user.id).future);
  }

  String _groupFilterSummary(BuildContext context, List<ExpenseGroup> sortedGroups) {
    if (_selectedGroupIds.isEmpty) {
      return tr(context, es: 'Todos los grupos', en: 'All groups', gl: 'Todos os grupos', fr: 'Tous les groupes', it: 'Tutti i gruppi', pt: 'Todos os grupos');
    }
    final selectedNames = sortedGroups.where((group) => _selectedGroupIds.contains(group.id)).map((group) => group.name).toList(growable: false);
    return selectedNames.join(', ');
  }

  Future<Set<String>?> _showGroupFilterDialog(BuildContext context, List<ExpenseGroup> sortedGroups) async {
    var search = '';
    final selectedIds = _selectedGroupIds.toSet();

    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final filteredGroups = sortedGroups.where((group) => group.name.toLowerCase().contains(search.toLowerCase())).toList(growable: false);
            return AlertDialog(
              title: Text(tr(context, es: 'Filtrar grupos', en: 'Filter groups', gl: 'Filtrar grupos', fr: 'Filtrer groupes', it: 'Filtra gruppi', pt: 'Filtrar grupos')),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        labelText: tr(context, es: 'Buscar grupo', en: 'Search group', gl: 'Buscar grupo', fr: 'Rechercher un groupe', it: 'Cerca gruppo', pt: 'Pesquisar grupo'),
                      ),
                      onChanged: (value) => setDialogState(() => search = value.trim()),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => setDialogState(selectedIds.clear),
                            child: Text(tr(context, es: 'Todos', en: 'All', gl: 'Todos', fr: 'Tous', it: 'Tutti', pt: 'Todos')),
                          ),
                          TextButton(
                            onPressed: () => setDialogState(() => selectedIds
                              ..clear()
                              ..addAll(sortedGroups.map((group) => group.id))),
                            child: Text(tr(context, es: 'Seleccionar visibles', en: 'Select visible', gl: 'Seleccionar visibles', fr: 'Selectionner visibles', it: 'Seleziona visibili', pt: 'Selecionar visiveis')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: filteredGroups.isEmpty
                          ? Center(
                              child: Text(tr(context, es: 'No hay grupos con ese nombre.', en: 'No groups match that name.', gl: 'Non hai grupos con ese nome.', fr: 'Aucun groupe ne correspond.', it: 'Nessun gruppo corrisponde.', pt: 'Nao ha grupos com esse nome.')),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: filteredGroups.map((group) {
                                final selected = selectedIds.contains(group.id);
                                return CheckboxListTile.adaptive(
                                  value: selected,
                                  contentPadding: EdgeInsets.zero,
                                  secondary: Icon(groupIconForKey(group.iconKey)),
                                  title: Text(group.name),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedIds.add(group.id);
                                      } else {
                                        selectedIds.remove(group.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'))),
                FilledButton(onPressed: () => Navigator.of(dialogContext).pop(selectedIds), child: Text(tr(context, es: 'Aplicar', en: 'Apply', gl: 'Aplicar', fr: 'Appliquer', it: 'Applica', pt: 'Aplicar'))),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsProvider(widget.user.id));

    return Scaffold(
      body: SafeArea(
        child: groupsState.when(
        data: (groups) {
          final sortedGroups = [...groups]..sort((left, right) => left.name.toLowerCase().compareTo(right.name.toLowerCase()));
          final selectedGroups = _selectedGroupIds.isEmpty
              ? sortedGroups
              : sortedGroups.where((group) => _selectedGroupIds.contains(group.id)).toList(growable: false);
          final categories = [...buildDefaultCategories(), ...selectedGroups.expand((group) => group.customCategories)]
              .groupListsBy((entry) => entry.id)
              .values
              .map((entries) => entries.first)
              .toList();
          final categoryMap = {for (final category in categories) category.id: category};
          final categoryData = categoryTotals(selectedGroups).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final monthly = monthlySpend(selectedGroups).entries.toList();
          final groupSpend = {for (final group in selectedGroups) group.name: totalGroupSpend(group)}.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final ticketCounts = {for (final group in selectedGroups) group.name: group.expenses.where((expense) => expense.kind == ExpenseRecordKind.expense).length}.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final memberSpend = <String, double>{};
          final weekdaySpend = <int, double>{};
          final memberNames = {
            for (final group in selectedGroups)
              for (final member in group.visibleMembers) member.userId: member.name,
          };

          for (final group in selectedGroups) {
            for (final expense in group.expenses) {
              if (expense.kind != ExpenseRecordKind.expense) {
                continue;
              }
              memberSpend.update(expense.payerId, (value) => value + totalExpense(expense), ifAbsent: () => totalExpense(expense));
              weekdaySpend.update(expense.createdAt.weekday, (value) => value + totalExpense(expense), ifAbsent: () => totalExpense(expense));
            }
          }

          final memberEntries = memberSpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final weekdayEntries = weekdaySpend.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
          final totalSpend = selectedGroups.fold<double>(0, (accumulatedSpend, group) => accumulatedSpend + totalGroupSpend(group));
          final expensesCount = selectedGroups.fold<int>(0, (sum, group) => sum + group.expenses.length);
          final peopleCount = selectedGroups.fold<int>(0, (sum, group) => sum + group.totalDisplayedMembers);
          final headlineCurrency = selectedGroups.isEmpty ? (groups.isEmpty ? 'EUR' : groups.first.currency) : selectedGroups.first.currency;
          final averageExpense = expensesCount == 0 ? 0.0 : totalSpend / expensesCount;
          final topCategory = categoryData.firstOrNull;
          final topGroup = groupSpend.firstOrNull;
          final topPerson = memberEntries.firstOrNull;
          final busiestWeekday = weekdayEntries.isEmpty ? null : weekdayEntries.reduce((left, right) => left.value >= right.value ? left : right);
          final topMonth = monthly.isEmpty ? null : monthly.reduce((left, right) => left.value >= right.value ? left : right);
          final selectedGroupsLabel = selectedGroups.length == sortedGroups.length ? tr(context, es: 'Todos los grupos', en: 'All groups', gl: 'Todos os grupos', fr: 'Tous les groupes', it: 'Tutti i gruppi', pt: 'Todos os grupos') : '${selectedGroups.length}';

          return RefreshIndicator(
            onRefresh: _refreshGroups,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, es: 'Gráfico activo', en: 'Active chart', gl: 'Grafico activo', fr: 'Graphique actif', it: 'Grafico attivo', pt: 'Grafico ativo'), style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<_StatsChartKind>(
                        initialValue: _selectedChart,
                        decoration: InputDecoration(labelText: tr(context, es: 'Selecciona una vista', en: 'Select a view', gl: 'Selecciona unha vista', fr: 'Selectionnez une vue', it: 'Seleziona una vista', pt: 'Seleciona uma vista')),
                        items: _chartOptions.map((option) {
                          return DropdownMenuItem<_StatsChartKind>(
                            value: option.kind,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(option.icon),
                                const SizedBox(width: 10),
                                SizedBox(width: 170, child: Text(_chartTitle(context, option.kind), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedChart = value);
                          }
                        },
                      ),
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
                      Text(tr(context, es: 'Filtrar grupos', en: 'Filter groups', gl: 'Filtrar grupos', fr: 'Filtrer groupes', it: 'Filtra gruppi', pt: 'Filtrar grupos'), style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        tr(context, es: 'Puedes ver todos, uno o varios grupos a la vez.', en: 'You can view all, one, or several groups at once.', gl: 'Podes ver todos, un ou varios grupos a vez.', fr: 'Vous pouvez voir tous, un ou plusieurs groupes a la fois.', it: 'Puoi vedere tutti, uno o piu gruppi alla volta.', pt: 'Podes ver todos, um ou varios grupos ao mesmo tempo.'),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          final selectedIds = await _showGroupFilterDialog(context, sortedGroups);
                          if (selectedIds == null) {
                            return;
                          }
                          setState(() {
                            _selectedGroupIds
                              ..clear()
                              ..addAll(selectedIds);
                          });
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: tr(context, es: 'Grupos seleccionados', en: 'Selected groups', gl: 'Grupos seleccionados', fr: 'Groupes selectionnes', it: 'Gruppi selezionati', pt: 'Grupos selecionados'),
                            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                          ),
                          child: Text(
                            _groupFilterSummary(context, sortedGroups),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSelectedChart(
                context,
                totalSpend: totalSpend,
                expensesCount: expensesCount,
                peopleCount: peopleCount,
                groupsCount: selectedGroups.length,
                selectedGroupsLabel: selectedGroupsLabel,
                headlineCurrency: headlineCurrency,
                averageExpense: averageExpense,
                categoryData: categoryData,
                categoryMap: categoryMap,
                topCategory: topCategory,
                groupSpend: groupSpend,
                topGroup: topGroup,
                monthly: monthly,
                topMonth: topMonth,
                memberEntries: memberEntries,
                memberNames: memberNames,
                topPerson: topPerson,
                ticketCounts: ticketCounts,
                weekdayEntries: weekdayEntries,
                busiestWeekday: busiestWeekday,
              ),
            ],
          ),
          );
        },
          error: (error, _) => Center(child: Text(error.toString())),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildSelectedChart(
    BuildContext context, {
    required double totalSpend,
    required int expensesCount,
    required int peopleCount,
    required int groupsCount,
    required String selectedGroupsLabel,
    required String headlineCurrency,
    required double averageExpense,
    required List<MapEntry<String, double>> categoryData,
    required Map<String, ExpenseCategory> categoryMap,
    required MapEntry<String, double>? topCategory,
    required List<MapEntry<String, double>> groupSpend,
    required MapEntry<String, double>? topGroup,
    required List<MapEntry<DateTime, double>> monthly,
    required MapEntry<DateTime, double>? topMonth,
    required List<MapEntry<String, double>> memberEntries,
    required Map<String, String> memberNames,
    required MapEntry<String, double>? topPerson,
    required List<MapEntry<String, int>> ticketCounts,
    required List<MapEntry<int, double>> weekdayEntries,
    required MapEntry<int, double>? busiestWeekday,
  }) {
    switch (_selectedChart) {
      case _StatsChartKind.insights:
        return _ChartCard(
          title: _chartTitle(context, _selectedChart),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  context,
                  es: 'Donde hay movimiento, ShardPay lo convierte en lectura clara.',
                  en: 'Where money moves, ShardPay turns it into signal.',
                  gl: 'Onde hai movemento, ShardPay converteo en lectura clara.',
                  fr: 'La ou l argent bouge, ShardPay le transforme en lecture claire.',
                  it: 'Dove si muove il denaro, ShardPay lo rende leggibile.',
                  pt: 'Onde o dinheiro se mexe, o ShardPay transforma-o em leitura clara.',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatPill(label: tr(context, es: 'Gasto total', en: 'Total spend', gl: 'Gasto total', fr: 'Depense totale', it: 'Spesa totale', pt: 'Despesa total'), value: money(totalSpend, headlineCurrency)),
                  _StatPill(label: tr(context, es: 'Ticket medio', en: 'Average receipt', gl: 'Ticket medio', fr: 'Ticket moyen', it: 'Scontrino medio', pt: 'Ticket medio'), value: money(averageExpense, headlineCurrency)),
                  _StatPill(label: tr(context, es: 'Grupos', en: 'Groups', gl: 'Grupos', fr: 'Groupes', it: 'Gruppi', pt: 'Grupos'), value: '$groupsCount'),
                  _StatPill(label: tr(context, es: 'Movimientos', en: 'Entries', gl: 'Movementos', fr: 'Mouvements', it: 'Movimenti', pt: 'Movimentos'), value: '$expensesCount'),
                  _StatPill(label: tr(context, es: 'Personas visibles', en: 'Visible people', gl: 'Persoas visibles', fr: 'Personnes visibles', it: 'Persone visibili', pt: 'Pessoas visiveis'), value: '$peopleCount'),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  final cardWidth = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _InsightPanel(
                          title: tr(context, es: 'Mayor categoría', en: 'Top category', gl: 'Maior categoria', fr: 'Categorie principale', it: 'Categoria principale', pt: 'Categoria principal'),
                          value: topCategory == null ? tr(context, es: 'Sin datos', en: 'No data', gl: 'Sen datos', fr: 'Pas de donnees', it: 'Nessun dato', pt: 'Sem dados') : '${categoryMap[topCategory.key]?.name ?? topCategory.key} · ${money(topCategory.value, headlineCurrency)}',
                          icon: categoryIconForKey(categoryMap[topCategory?.key]?.iconKey ?? 'receipt'),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _InsightPanel(
                          title: tr(context, es: 'Grupo más activo', en: 'Most active group', gl: 'Grupo máis activo', fr: 'Groupe le plus actif', it: 'Gruppo piu attivo', pt: 'Grupo mais ativo'),
                          value: topGroup == null ? tr(context, es: 'Sin datos', en: 'No data', gl: 'Sen datos', fr: 'Pas de donnees', it: 'Nessun dato', pt: 'Sem dados') : '${topGroup.key} · ${money(topGroup.value, headlineCurrency)}',
                          icon: Icons.local_fire_department_rounded,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _InsightPanel(
                          title: tr(context, es: 'Quién adelanta más', en: 'Who advances the most', gl: 'Quen adianta máis', fr: 'Qui avance le plus', it: 'Chi anticipa di piu', pt: 'Quem adianta mais'),
                          value: topPerson == null ? tr(context, es: 'Sin datos', en: 'No data', gl: 'Sen datos', fr: 'Pas de donnees', it: 'Nessun dato', pt: 'Sem dados') : '${memberNames[topPerson.key] ?? topPerson.key} · ${money(topPerson.value, headlineCurrency)}',
                          icon: Icons.emoji_events_rounded,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _InsightPanel(
                          title: tr(context, es: 'Pico temporal', en: 'Peak period', gl: 'Pico temporal', fr: 'Pic temporel', it: 'Picco temporale', pt: 'Pico temporal'),
                          value: topMonth == null
                              ? tr(context, es: 'Sin datos', en: 'No data', gl: 'Sen datos', fr: 'Pas de donnees', it: 'Nessun dato', pt: 'Sem dados')
                              : '${DateFormat.MMMM(localeTag(context)).format(topMonth.key)} · ${money(topMonth.value, headlineCurrency)}',
                          icon: Icons.timeline_rounded,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _InsightPanel(
                          title: tr(context, es: 'Día más cargado', en: 'Busiest weekday', gl: 'Dia máis cargado', fr: 'Jour le plus charge', it: 'Giorno piu intenso', pt: 'Dia mais carregado'),
                          value: busiestWeekday == null ? tr(context, es: 'Sin datos', en: 'No data', gl: 'Sen datos', fr: 'Pas de donnees', it: 'Nessun dato', pt: 'Sem dados') : '${_weekdayLabel(context, busiestWeekday.key)} · ${money(busiestWeekday.value, headlineCurrency)}',
                          icon: Icons.calendar_today_rounded,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      case _StatsChartKind.categories:
        return _ChartCard(
          title: _chartTitle(context, _selectedChart),
          child: Column(
            children: [
              SizedBox(
                height: 300,
                child: categoryData.isEmpty
                    ? _ChartEmpty(message: tr(context, es: 'Todavía no hay datos suficientes.', en: 'Not enough data yet.', gl: 'Ainda non hai datos suficientes.', fr: 'Pas assez de donnees pour le moment.', it: 'Non ci sono ancora dati sufficienti.', pt: 'Ainda nao ha dados suficientes.'))
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 6,
                          centerSpaceRadius: 54,
                          pieTouchData: PieTouchData(enabled: true),
                          sections: categoryData.take(6).mapIndexed((index, entry) {
                            final category = categoryMap[entry.key];
                            return PieChartSectionData(
                              value: entry.value,
                              title: '',
                              color: colorFromHex(category?.colorHex ?? '0xFFE4572E'),
                              radius: 100,
                            );
                          }).toList(),
                        ),
                      ),
              ),
              if (categoryData.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryData.take(6).map((entry) {
                    final category = categoryMap[entry.key];
                    return Chip(
                      avatar: CircleAvatar(radius: 7, backgroundColor: colorFromHex(category?.colorHex ?? '0xFFE4572E')),
                      label: Text('${category?.name ?? entry.key} · ${entry.value.toStringAsFixed(0)}'),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      case _StatsChartKind.groups:
        return _ChartCard(
          title: _chartTitle(context, _selectedChart),
          child: SizedBox(
            height: 280,
            child: groupSpend.isEmpty
                ? _ChartEmpty(message: tr(context, es: 'Todavía no hay grupos con gasto.', en: 'There are no groups with spend yet.', gl: 'Ainda non hai grupos con gasto.', fr: 'Il n y a pas encore de groupes avec depenses.', it: 'Non ci sono ancora gruppi con spese.', pt: 'Ainda nao ha grupos com despesa.'))
                : BarChart(
                    BarChartData(
                      maxY: clampChartMax(groupSpend.map((entry) => entry.value)),
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: clampChartMax(groupSpend.map((entry) => entry.value)) / 4),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= groupSpend.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 56,
                                  child: Text(groupSpend[index].key, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: groupSpend.mapIndexed((index, entry) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              width: 26,
                              gradient: const LinearGradient(colors: [Color(0xFF3A86FF), Color(0xFF7B2CBF)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        );
      case _StatsChartKind.monthly:
        return _ChartCard(
          title: _chartTitle(context, _selectedChart),
          child: SizedBox(
            height: 280,
            child: monthly.isEmpty
                ? _ChartEmpty(message: tr(context, es: 'Todavía no hay meses con gasto.', en: 'There are no months with spend yet.', gl: 'Ainda non hai meses con gasto.', fr: 'Il n y a pas encore de mois avec depenses.', it: 'Non ci sono ancora mesi con spese.', pt: 'Ainda nao ha meses com despesa.'))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: clampChartMax(monthly.map((entry) => entry.value)),
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: clampChartMax(monthly.map((entry) => entry.value)) / 4),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= monthly.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(DateFormat.MMM(localeTag(context)).format(monthly[index].key));
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          barWidth: 5,
                          gradient: const LinearGradient(colors: [Color(0xFFE4572E), Color(0xFFF3C677)]),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [const Color(0xFFE4572E).withValues(alpha: 0.22), Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          dotData: const FlDotData(show: true),
                          spots: monthly.mapIndexed((index, entry) => FlSpot(index.toDouble(), entry.value)).toList(),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      case _StatsChartKind.people:
        return _ChartCard(
          title: _chartTitle(context, _selectedChart),
          child: SizedBox(
            height: 300,
            child: memberEntries.isEmpty
                ? _ChartEmpty(message: tr(context, es: 'Todavía no hay personas con gasto registrado.', en: 'There are no people with registered spend yet.', gl: 'Ainda non hai persoas con gasto rexistrado.', fr: 'Il n y a pas encore de personnes avec des depenses.', it: 'Non ci sono ancora persone con spesa registrata.', pt: 'Ainda nao ha pessoas com despesa registada.'))
                : BarChart(
                    BarChartData(
                      maxY: clampChartMax(memberEntries.map((entry) => entry.value)),
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: clampChartMax(memberEntries.map((entry) => entry.value)) / 4),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= memberEntries.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 52,
                                  child: Text(memberNames[memberEntries[index].key]?.split(' ').first ?? 'User', overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
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
                              width: 26,
                              gradient: const LinearGradient(colors: [Color(0xFF1B998B), Color(0xFF90E0EF)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        );
      case _StatsChartKind.tickets:
        return _ChartCard(
          title: _chartTitle(context, _selectedChart),
          child: SizedBox(
            height: 300,
            child: ticketCounts.isEmpty
                ? _ChartEmpty(message: tr(context, es: 'Todavía no hay tickets registrados.', en: 'There are no receipts yet.', gl: 'Ainda non hai tickets rexistrados.', fr: 'Il n y a pas encore de tickets.', it: 'Non ci sono ancora scontrini registrati.', pt: 'Ainda nao ha faturas registadas.'))
                : BarChart(
                    BarChartData(
                      maxY: clampChartMax(ticketCounts.map((entry) => entry.value.toDouble())),
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: clampChartMax(ticketCounts.map((entry) => entry.value.toDouble())) / 4),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= ticketCounts.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 58,
                                  child: Text(ticketCounts[index].key, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: ticketCounts.mapIndexed((index, entry) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              width: 24,
                              gradient: const LinearGradient(colors: [Color(0xFF2D6CDF), Color(0xFF90CAF9)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        );
      case _StatsChartKind.weekdays:
        return _ChartCard(
          title: _chartTitle(context, _selectedChart),
          child: SizedBox(
            height: 300,
            child: weekdayEntries.isEmpty
                ? _ChartEmpty(message: tr(context, es: 'Todavía no hay gasto suficiente por día.', en: 'There is not enough weekday data yet.', gl: 'Ainda non hai gasto suficiente por dia.', fr: 'Pas assez de donnees par jour.', it: 'Non ci sono ancora dati sufficienti per giorno.', pt: 'Ainda nao ha dados suficientes por dia.'))
                : BarChart(
                    BarChartData(
                      maxY: clampChartMax(weekdayEntries.map((entry) => entry.value)),
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: clampChartMax(weekdayEntries.map((entry) => entry.value)) / 4),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= weekdayEntries.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_weekdayShortLabel(context, weekdayEntries[index].key)),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: weekdayEntries.mapIndexed((index, entry) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              width: 24,
                              gradient: const LinearGradient(colors: [Color(0xFF1B998B), Color(0xFFF3C677)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        );
    }
  }

  String _weekdayShortLabel(BuildContext context, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return tr(context, es: 'Lun', en: 'Mon', gl: 'Lun', fr: 'Lun', it: 'Lun', pt: 'Seg');
      case DateTime.tuesday:
        return tr(context, es: 'Mar', en: 'Tue', gl: 'Mar', fr: 'Mar', it: 'Mar', pt: 'Ter');
      case DateTime.wednesday:
        return tr(context, es: 'Mié', en: 'Wed', gl: 'Mér', fr: 'Mer', it: 'Mer', pt: 'Qua');
      case DateTime.thursday:
        return tr(context, es: 'Jue', en: 'Thu', gl: 'Xov', fr: 'Jeu', it: 'Gio', pt: 'Qui');
      case DateTime.friday:
        return tr(context, es: 'Vie', en: 'Fri', gl: 'Ven', fr: 'Ven', it: 'Ven', pt: 'Sex');
      case DateTime.saturday:
        return tr(context, es: 'Sáb', en: 'Sat', gl: 'Sab', fr: 'Sam', it: 'Sab', pt: 'Sab');
      case DateTime.sunday:
        return tr(context, es: 'Dom', en: 'Sun', gl: 'Dom', fr: 'Dim', it: 'Dom', pt: 'Dom');
      default:
        return '';
    }
  }

  String _weekdayLabel(BuildContext context, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return tr(context, es: 'Lunes', en: 'Monday', gl: 'Luns', fr: 'Lundi', it: 'Lunedi', pt: 'Segunda');
      case DateTime.tuesday:
        return tr(context, es: 'Martes', en: 'Tuesday', gl: 'Martes', fr: 'Mardi', it: 'Martedi', pt: 'Terca');
      case DateTime.wednesday:
        return tr(context, es: 'Miércoles', en: 'Wednesday', gl: 'Mércores', fr: 'Mercredi', it: 'Mercoledi', pt: 'Quarta');
      case DateTime.thursday:
        return tr(context, es: 'Jueves', en: 'Thursday', gl: 'Xoves', fr: 'Jeudi', it: 'Giovedi', pt: 'Quinta');
      case DateTime.friday:
        return tr(context, es: 'Viernes', en: 'Friday', gl: 'Venres', fr: 'Vendredi', it: 'Venerdi', pt: 'Sexta');
      case DateTime.saturday:
        return tr(context, es: 'Sábado', en: 'Saturday', gl: 'Sabado', fr: 'Samedi', it: 'Sabato', pt: 'Sabado');
      case DateTime.sunday:
        return tr(context, es: 'Domingo', en: 'Sunday', gl: 'Domingo', fr: 'Dimanche', it: 'Domenica', pt: 'Domingo');
      default:
        return '';
    }
  }

  String _chartTitle(BuildContext context, _StatsChartKind kind) {
    switch (kind) {
      case _StatsChartKind.insights:
        return 'Insights';
      case _StatsChartKind.categories:
        return tr(context, es: 'Distribución por categoría', en: 'Distribution by category', gl: 'Distribucion por categoria', fr: 'Repartition par categorie', it: 'Distribuzione per categoria', pt: 'Distribuicao por categoria');
      case _StatsChartKind.groups:
        return tr(context, es: 'Qué grupos están moviendo más gasto', en: 'Which groups move the most spend', gl: 'Que grupos moven mais gasto', fr: 'Quels groupes generent le plus de depenses', it: 'Quali gruppi muovono piu spesa', pt: 'Que grupos movem mais despesa');
      case _StatsChartKind.monthly:
        return tr(context, es: 'Gasto mensual', en: 'Monthly spend', gl: 'Gasto mensual', fr: 'Depense mensuelle', it: 'Spesa mensile', pt: 'Despesa mensal');
      case _StatsChartKind.people:
        return tr(context, es: 'Quién está adelantando más', en: 'Who is advancing the most', gl: 'Quen esta adiantando mais', fr: 'Qui avance le plus', it: 'Chi anticipa di piu', pt: 'Quem esta a adiantar mais');
      case _StatsChartKind.tickets:
        return tr(context, es: 'Tickets por grupo', en: 'Receipts per group', gl: 'Tickets por grupo', fr: 'Tickets par groupe', it: 'Scontrini per gruppo', pt: 'Faturas por grupo');
      case _StatsChartKind.weekdays:
        return tr(context, es: 'Gasto por día', en: 'Spend by weekday', gl: 'Gasto por dia', fr: 'Depense par jour', it: 'Spesa per giorno', pt: 'Despesa por dia');
    }
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}