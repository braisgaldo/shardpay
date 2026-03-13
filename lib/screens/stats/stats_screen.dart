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

enum _StatsChartKind { insights, categories, groups, monthly, people }

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
];

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _StatsChartKind _selectedChart = _StatsChartKind.insights;

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsProvider(widget.user.id));

    return SafeArea(
      child: groupsState.when(
        data: (groups) {
          final categories = [...buildDefaultCategories(), ...groups.expand((group) => group.customCategories)]
              .groupListsBy((entry) => entry.id)
              .values
              .map((entries) => entries.first)
              .toList();
          final categoryMap = {for (final category in categories) category.id: category};
          final categoryData = categoryTotals(groups).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final monthly = monthlySpend(groups).entries.toList();
          final groupSpend = {for (final group in groups) group.name: totalGroupSpend(group)}.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final memberSpend = <String, double>{};
          final memberNames = {
            for (final group in groups)
              for (final member in group.visibleMembers) member.userId: member.name,
          };

          for (final group in groups) {
            for (final expense in group.expenses) {
              memberSpend.update(expense.payerId, (value) => value + totalExpense(expense), ifAbsent: () => totalExpense(expense));
            }
          }

          final memberEntries = memberSpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final totalSpend = groups.fold<double>(0, (accumulatedSpend, group) => accumulatedSpend + totalGroupSpend(group));
          final expensesCount = groups.fold<int>(0, (sum, group) => sum + group.expenses.length);
          final peopleCount = groups.fold<int>(0, (sum, group) => sum + group.totalDisplayedMembers);
          final headlineCurrency = groups.isEmpty ? 'EUR' : groups.first.currency;

          return ListView(
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
                              children: [
                                Icon(option.icon),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_chartTitle(context, option.kind), overflow: TextOverflow.ellipsis)),
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
              _buildSelectedChart(
                context,
                totalSpend: totalSpend,
                expensesCount: expensesCount,
                peopleCount: peopleCount,
                groupsCount: groups.length,
                headlineCurrency: headlineCurrency,
                categoryData: categoryData,
                categoryMap: categoryMap,
                groupSpend: groupSpend,
                monthly: monthly,
                memberEntries: memberEntries,
                memberNames: memberNames,
              ),
            ],
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildSelectedChart(
    BuildContext context, {
    required double totalSpend,
    required int expensesCount,
    required int peopleCount,
    required int groupsCount,
    required String headlineCurrency,
    required List<MapEntry<String, double>> categoryData,
    required Map<String, ExpenseCategory> categoryMap,
    required List<MapEntry<String, double>> groupSpend,
    required List<MapEntry<DateTime, double>> monthly,
    required List<MapEntry<String, double>> memberEntries,
    required Map<String, String> memberNames,
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
                  _StatPill(label: tr(context, es: 'Grupos', en: 'Groups', gl: 'Grupos', fr: 'Groupes', it: 'Gruppi', pt: 'Grupos'), value: '$groupsCount'),
                  _StatPill(label: tr(context, es: 'Movimientos', en: 'Entries', gl: 'Movementos', fr: 'Mouvements', it: 'Movimenti', pt: 'Movimentos'), value: '$expensesCount'),
                  _StatPill(label: tr(context, es: 'Personas visibles', en: 'Visible people', gl: 'Persoas visibles', fr: 'Personnes visibles', it: 'Persone visibili', pt: 'Pessoas visiveis'), value: '$peopleCount'),
                ],
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