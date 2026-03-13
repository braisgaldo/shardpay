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

  List<GroupMember> get _sortedSelectableMembers => sortedMembersByName(widget.group.selectableMembers);
  List<GroupMember> get _sortedPayerMembers => sortedMembersByName(widget.group.activeMembers);

  @override
  void initState() {
    super.initState();
    _selectedMembers = {for (final member in widget.group.selectableMembers) member.userId};
    _payerId = widget.group.activeMembers.any((member) => member.userId == widget.user.id)
        ? widget.user.id
        : widget.group.activeMembers.first.userId;
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
                  TextField(controller: _titleController, decoration: InputDecoration(labelText: tr(context, es: 'Concepto principal', en: 'Main concept', gl: 'Concepto principal', fr: 'Concept principal', it: 'Voce principale', pt: 'Conceito principal'), hintText: tr(context, es: 'Cena, gasolina, compra...', en: 'Dinner, fuel, groceries...', gl: 'Cea, gasolina, compra...', fr: 'Diner, essence, courses...', it: 'Cena, carburante, spesa...', pt: 'Jantar, combustivel, compras...'))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    decoration: InputDecoration(labelText: tr(context, es: 'Importe total', en: 'Total amount', gl: 'Importe total', fr: 'Montant total', it: 'Importo totale', pt: 'Valor total'), hintText: '0,00'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
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
                  Text(tr(context, es: 'Quién pagó y categoría', en: 'Payer and category', gl: 'Quen pagou e categoria', fr: 'Payeur et categorie', it: 'Chi ha pagato e categoria', pt: 'Quem pagou e categoria'), style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _payerId,
                    decoration: InputDecoration(labelText: tr(context, es: 'Pagó', en: 'Paid by', gl: 'Pagou', fr: 'Paye par', it: 'Pagato da', pt: 'Pago por')),
                    items: _sortedPayerMembers.map((member) => DropdownMenuItem(value: member.userId, child: Text(member.name))).toList(),
                    onChanged: (value) => setState(() => _payerId = value ?? _payerId),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: InputDecoration(labelText: tr(context, es: 'Categoría', en: 'Category', gl: 'Categoria', fr: 'Categorie', it: 'Categoria', pt: 'Categoria')),
                    items: categories.map((category) => DropdownMenuItem(value: category.id, child: Text(category.name))).toList(),
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

  Future<void> _saveExpense() async {
    if (widget.group.isClosed || _saving) {
      return;
    }
    setState(() => _saving = true);
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final members = widget.group.selectableMembers.where((member) => _selectedMembers.contains(member.userId)).toList();
    if (_titleController.text.trim().isEmpty || amount <= 0 || members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, es: 'Revisa el concepto, el importe y las personas participantes.', en: 'Check the concept, amount and selected participants.', gl: 'Revisa o concepto, o importe e as persoas participantes.', fr: 'Verifiez le concept, le montant et les participants selectionnes.', it: 'Controlla voce, importo e partecipanti selezionati.', pt: 'Revê o conceito, o valor e as pessoas participantes.'))));
      setState(() => _saving = false);
      return;
    }

    try {
      final expense = ExpenseRecord(
        id: _uuid.v4(),
        title: _titleController.text.trim(),
        payerId: _payerId,
        createdAt: DateTime.now(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        items: [
          ExpenseItem(
            id: _uuid.v4(),
            name: _titleController.text.trim(),
            amount: amount,
            categoryId: _categoryId,
            allocations: equalAllocations(members),
          ),
        ],
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