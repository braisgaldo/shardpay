import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_text.dart';
import '../../app/providers.dart';
import '../../core/defaults.dart';
import '../../core/expense_math.dart';
import '../../models/app_models.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, required this.user, required this.group});

  final AppUser user;
  final ExpenseGroup group;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _uuid = const Uuid();
  bool _saving = false;
  late final Set<String> _selectedMembers;
  late String _payerId;
  late String _categoryId;
  final List<_DraftSubExpense> _subExpenses = [];

  List<GroupMember> get _sortedSelectableMembers => sortedMembersByName(widget.group.selectableMembers);
  List<GroupMember> get _sortedPayerMembers => sortedMembersByName(widget.group.visibleMembers);
  bool get _hasMeaningfulSubExpenses => _subExpenses.any((item) => item.name.trim().isNotEmpty || item.amount > 0);
  double get _subExpenseTotal => _subExpenses.fold<double>(0, (sum, item) => sum + item.amount);

  @override
  void initState() {
    super.initState();
    _selectedMembers = {for (final member in widget.group.selectableMembers) member.userId};
    _payerId = widget.group.visibleMembers.any((member) => member.userId == widget.user.id) ? widget.user.id : widget.group.visibleMembers.first.userId;
    _categoryId = 'food';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = [...buildDefaultCategories(), ...widget.group.customCategories];

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, es: 'Añadir gasto', en: 'Add expense', gl: 'Engadir gasto', fr: 'Ajouter une depense', it: 'Aggiungi spesa', pt: 'Adicionar despesa'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.group.isClosed) ...[
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr(context, es: 'Este grupo está cerrado. Solo puedes consultarlo hasta que un administrador lo reabra.', en: 'This group is closed. You can only review it until an admin reopens it.', gl: 'Este grupo esta pechado. So podes consultalo ata que unha administracion o reabra.', fr: 'Ce groupe est ferme. Vous pouvez seulement le consulter jusqu a sa reouverture.', it: 'Questo gruppo e chiuso. Puoi solo consultarlo finche un admin non lo riapre.', pt: 'Este grupo esta fechado. So o podes consultar ate que a administracao o reabra.')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, es: 'Resumen del gasto', en: 'Expense summary', gl: 'Resumo do gasto', fr: 'Resume de la depense', it: 'Riepilogo spesa', pt: 'Resumo da despesa'), style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: tr(context, es: 'Concepto principal', en: 'Main concept', gl: 'Concepto principal', fr: 'Concept principal', it: 'Voce principale', pt: 'Conceito principal'),
                      hintText: tr(context, es: 'Cena, gasolina, compra...', en: 'Dinner, fuel, groceries...', gl: 'Cea, gasolina, compra...', fr: 'Diner, essence, courses...', it: 'Cena, carburante, spesa...', pt: 'Jantar, combustivel, compras...'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    enabled: !_hasMeaningfulSubExpenses,
                    decoration: InputDecoration(
                      labelText: tr(context, es: 'Importe total', en: 'Total amount', gl: 'Importe total', fr: 'Montant total', it: 'Importo totale', pt: 'Valor total'),
                      hintText: '0,00',
                      helperText: _hasMeaningfulSubExpenses
                          ? tr(context, es: 'Se calcula automáticamente con la suma de los subgastos.', en: 'It is calculated automatically from the subexpenses sum.', gl: 'Calcúlase automaticamente coa suma dos subgastos.', fr: 'Il est calcule automatiquement a partir de la somme des sous-depenses.', it: 'Viene calcolato automaticamente dalla somma delle sottospese.', pt: 'E calculado automaticamente pela soma dos subgastos.')
                          : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  if (_hasMeaningfulSubExpenses) ...[
                    const SizedBox(height: 12),
                    _ComputedTotalCard(currency: widget.group.currency, total: _subExpenseTotal),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: _noteController, decoration: InputDecoration(labelText: tr(context, es: 'Nota opcional', en: 'Optional note', gl: 'Nota opcional', fr: 'Note facultative', it: 'Nota opzionale', pt: 'Nota opcional'))),
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
                        child: Text(tr(context, es: 'Subgastos', en: 'Subexpenses', gl: 'Subgastos', fr: 'Sous-depenses', it: 'Sottospese', pt: 'Subgastos'), style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _subExpenses.add(const _DraftSubExpense())),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(tr(context, es: 'Añadir', en: 'Add', gl: 'Engadir', fr: 'Ajouter', it: 'Aggiungi', pt: 'Adicionar')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, es: 'Opcional. Si añades subgastos, el total se calculará automáticamente con su suma.', en: 'Optional. If you add subexpenses, the total will be calculated automatically from their sum.', gl: 'Opcional. Se engades subgastos, o total calcularase automaticamente coa súa suma.', fr: 'Facultatif. Si vous ajoutez des sous-depenses, le total sera calcule automatiquement a partir de leur somme.', it: 'Opzionale. Se aggiungi sottospese, il totale verra calcolato automaticamente dalla loro somma.', pt: 'Opcional. Se adicionares subgastos, o total sera calculado automaticamente pela soma deles.'),
                  ),
                  if (_subExpenses.isEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(tr(context, es: 'Sin subgastos. Puedes guardar un gasto simple con el importe total o desglosarlo aquí.', en: 'No subexpenses yet. You can save a simple expense with the total amount or break it down here.', gl: 'Sen subgastos. Podes gardar un gasto simple co importe total ou desagregalo aquí.', fr: 'Pas encore de sous-depenses. Vous pouvez enregistrer une depense simple avec le montant total ou la détailler ici.', it: 'Nessuna sottospesa. Puoi salvare una spesa semplice con l importo totale o suddividerla qui.', pt: 'Sem subgastos. Podes guardar uma despesa simples com o valor total ou detalha-la aqui.')),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    ..._subExpenses.asMap().entries.map((entry) {
                      final index = entry.key;
                      final subExpense = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
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
                                      initialValue: subExpense.name,
                                      decoration: InputDecoration(labelText: tr(context, es: 'Subgasto', en: 'Subexpense', gl: 'Subgasto', fr: 'Sous-depense', it: 'Sottospesa', pt: 'Subgasto')),
                                      onChanged: (value) => _updateSubExpense(index, subExpense.copyWith(name: value)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => setState(() => _subExpenses.removeAt(index)),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    tooltip: tr(context, es: 'Eliminar subgasto', en: 'Delete subexpense', gl: 'Eliminar subgasto', fr: 'Supprimer la sous-depense', it: 'Elimina sottospesa', pt: 'Eliminar subgasto'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: subExpense.amount <= 0 ? '' : subExpense.amount.toStringAsFixed(2),
                                decoration: InputDecoration(labelText: tr(context, es: 'Importe', en: 'Amount', gl: 'Importe', fr: 'Montant', it: 'Importo', pt: 'Valor')),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) => _updateSubExpense(index, subExpense.copyWith(amount: double.tryParse(value.replaceAll(',', '.')) ?? 0)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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
                  Text(tr(context, es: 'Quién pagó y categoría', en: 'Payer and category', gl: 'Quen pagou e categoria', fr: 'Payeur et categorie', it: 'Chi ha pagato e categoria', pt: 'Quem pagou e categoria'), style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _payerId,
                    decoration: InputDecoration(labelText: tr(context, es: 'Pagó', en: 'Paid by', gl: 'Pagou', fr: 'Paye par', it: 'Pagato da', pt: 'Pago por')),
                    items: _sortedPayerMembers
                        .map(
                          (member) => DropdownMenuItem(
                            value: member.userId,
                            child: Row(
                              children: [
                                Icon(member.isPending ? Icons.person_outline_rounded : Icons.person_rounded, size: 18),
                                const SizedBox(width: 10),
                                SizedBox(width: 180, child: Text(member.name, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _payerId = value ?? _payerId),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: InputDecoration(
                      labelText: tr(context, es: 'Categoría', en: 'Category', gl: 'Categoria', fr: 'Categorie', it: 'Categoria', pt: 'Categoria'),
                      helperText: _hasMeaningfulSubExpenses
                          ? tr(context, es: 'Se aplicará a todos los subgastos de este gasto.', en: 'It will be applied to all subexpenses in this expense.', gl: 'Aplicarase a todos os subgastos deste gasto.', fr: 'Elle sera appliquee a toutes les sous-depenses de cette depense.', it: 'Verra applicata a tutte le sottospese di questa spesa.', pt: 'Sera aplicada a todos os subgastos desta despesa.')
                          : null,
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Row(
                              children: [
                                Icon(categoryIconForKey(category.iconKey), size: 18, color: colorFromHex(category.colorHex)),
                                const SizedBox(width: 10),
                                SizedBox(width: 160, child: Text(category.name, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _categoryId = value ?? _categoryId),
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
                  Text(tr(context, es: 'Quién participa', en: 'Who takes part', gl: 'Quen participa', fr: 'Qui participe', it: 'Chi partecipa', pt: 'Quem participa'), style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(tr(context, es: 'Selecciona las personas que comparten este gasto.', en: 'Select the people who share this expense.', gl: 'Selecciona as persoas que comparten este gasto.', fr: 'Selectionnez les personnes qui partagent cette depense.', it: 'Seleziona le persone che condividono questa spesa.', pt: 'Seleciona as pessoas que partilham esta despesa.')),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _sortedSelectableMembers.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                      itemBuilder: (context, index) {
                        final member = _sortedSelectableMembers[index];
                        final selected = _selectedMembers.contains(member.userId);
                        return CheckboxListTile(
                          value: selected,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(member.name),
                          subtitle: member.isPending ? Text(tr(context, es: 'Pendiente de vincular', en: 'Pending to link', gl: 'Pendiente de vincular', fr: 'En attente de liaison', it: 'In attesa di collegamento', pt: 'Pendente de associacao')) : null,
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedMembers.add(member.userId);
                              } else {
                                _selectedMembers.remove(member.userId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FilledButton.icon(
          onPressed: widget.group.isClosed || _saving ? null : _saveExpense,
          icon: const Icon(Icons.save_rounded),
          label: Text(tr(context, es: 'Guardar gasto', en: 'Save expense', gl: 'Gardar gasto', fr: 'Enregistrer la depense', it: 'Salva spesa', pt: 'Guardar despesa')),
        ),
      ),
    );
  }

  void _updateSubExpense(int index, _DraftSubExpense value) {
    setState(() {
      _subExpenses[index] = value;
    });
  }

  Future<void> _saveExpense() async {
    if (widget.group.isClosed || _saving) {
      return;
    }
    setState(() => _saving = true);
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final members = widget.group.selectableMembers.where((member) => _selectedMembers.contains(member.userId)).toList();
    final meaningfulSubExpenses = _subExpenses.where((item) => item.name.trim().isNotEmpty || item.amount > 0).toList(growable: false);
    final hasInvalidSubExpenses = meaningfulSubExpenses.any((item) => item.name.trim().isEmpty || item.amount <= 0);

    if (_titleController.text.trim().isEmpty || members.isEmpty || (_hasMeaningfulSubExpenses ? hasInvalidSubExpenses : amount <= 0)) {
      final message = _hasMeaningfulSubExpenses
          ? tr(context, es: 'Revisa el concepto, las personas participantes y todos los subgastos añadidos.', en: 'Check the concept, selected participants, and every added subexpense.', gl: 'Revisa o concepto, as persoas participantes e todos os subgastos engadidos.', fr: 'Verifiez le concept, les participants et chaque sous-depense ajoutee.', it: 'Controlla il concetto, i partecipanti selezionati e ogni sottospesa aggiunta.', pt: 'Revê o conceito, as pessoas participantes e cada subgasto adicionado.')
          : tr(context, es: 'Revisa el concepto, el importe y las personas participantes.', en: 'Check the concept, amount and selected participants.', gl: 'Revisa o concepto, o importe e as persoas participantes.', fr: 'Verifiez le concept, le montant et les participants selectionnes.', it: 'Controlla voce, importo e partecipanti selezionati.', pt: 'Revê o conceito, o valor e as pessoas participantes.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _saving = false);
      return;
    }

    try {
      final allocations = equalAllocations(members);
      final items = meaningfulSubExpenses.isNotEmpty
          ? meaningfulSubExpenses
              .map(
                (item) => ExpenseItem(
                  id: _uuid.v4(),
                  name: item.name.trim(),
                  amount: item.amount,
                  categoryId: _categoryId,
                  allocations: allocations,
                ),
              )
              .toList(growable: false)
          : [
              ExpenseItem(
                id: _uuid.v4(),
                name: _titleController.text.trim(),
                amount: amount,
                categoryId: _categoryId,
                allocations: allocations,
              ),
            ];

      final expense = ExpenseRecord(
        id: _uuid.v4(),
        title: _titleController.text.trim(),
        payerId: _payerId,
        createdAt: DateTime.now(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        items: items,
      );

      await ref.read(repositoryProvider).addExpense(groupId: widget.group.id, expense: expense);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _ComputedTotalCard extends StatelessWidget {
  const _ComputedTotalCard({required this.currency, required this.total});

  final String currency;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.functions_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(context, es: 'Total calculado desde los subgastos', en: 'Total calculated from subexpenses', gl: 'Total calculado dende os subgastos', fr: 'Total calcule a partir des sous-depenses', it: 'Totale calcolato dalle sottospese', pt: 'Total calculado a partir dos subgastos'),
            ),
          ),
          Text(
            money(total, currency),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DraftSubExpense {
  const _DraftSubExpense({
    this.name = '',
    this.amount = 0,
  });

  final String name;
  final double amount;

  _DraftSubExpense copyWith({
    String? name,
    double? amount,
  }) {
    return _DraftSubExpense(
      name: name ?? this.name,
      amount: amount ?? this.amount,
    );
  }
}
