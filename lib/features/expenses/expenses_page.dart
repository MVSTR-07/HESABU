import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_controller.dart';
import '../../core/expenses/expense_analysis.dart';
import '../../data/operations_repository.dart';
import '../../ui/formatters.dart';
import '../operations/operations_widgets.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  late final OperationsRepository _repository;
  List<ExpenseRecord> _expenses = [];

  @override
  void initState() {
    super.initState();
    _repository = OperationsRepository(widget.controller.store);
    _refresh();
  }

  void _refresh() => setState(() => _expenses = _repository.expenses());

  Future<void> _addExpense([ExpenseRecord? existing]) async {
    final category = TextEditingController(text: existing?.category ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final amount = TextEditingController(
      text: existing == null
          ? ''
          : (existing.amountMinor / 100).toStringAsFixed(2),
    );
    final payee = TextEditingController(text: existing?.payee ?? '');
    var date = existing?.spentAt ?? DateTime.now().toUtc();
    var error = '';
    final expense = await showDialog<ExpenseRecord>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(existing == null ? 'Add an expense' : 'Edit expense'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: category,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g. Transport',
                    ),
                  ),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(
                      labelText: 'What was it for?',
                    ),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (KES)',
                    ),
                  ),
                  TextField(
                    controller: payee,
                    decoration: const InputDecoration(
                      labelText: 'Supplier / payee (optional)',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await pickOperationDate(context, date);
                        if (picked != null) updateDialog(() => date = picked);
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('Date · ${formatKenyaDate(date)}'),
                    ),
                  ),
                  if (error.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = parseKesAmount(amount.text);
                if (category.text.trim().isEmpty ||
                    description.text.trim().isEmpty) {
                  updateDialog(
                    () => error = 'Enter an expense category and description.',
                  );
                  return;
                }
                if (value == null) {
                  updateDialog(() => error = 'Enter a positive KES amount.');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  ExpenseRecord(
                    id: existing?.id ?? operationId('EXPENSE'),
                    spentAt: date,
                    category: category.text.trim(),
                    description: description.text.trim(),
                    amountMinor: value,
                    payee: payee.text.trim(),
                  ),
                );
              },
              child: Text(existing == null ? 'Save expense' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    category.dispose();
    description.dispose();
    amount.dispose();
    payee.dispose();
    if (expense == null || !mounted) return;
    try {
      _repository.saveExpense(expense);
      _refresh();
    } on FormatException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Expense could not be saved to encrypted local storage.');
    }
  }

  Future<void> _deleteExpense(ExpenseRecord expense) async {
    if (!await confirmOperationDelete(context, expense.description) ||
        !mounted) {
      return;
    }
    _repository.deleteExpense(expense.id);
    _refresh();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final result = _repository.analyseExpenses();
    return OperationsPageFrame(
      title: 'Expense analyser',
      subtitle: 'See where business money goes and which costs are increasing.',
      actions: [
        FilledButton.icon(
          onPressed: widget.controller.busy ? null : _addExpense,
          icon: const Icon(Icons.add),
          label: const Text('Add expense'),
        ),
        OutlinedButton.icon(
          onPressed: widget.controller.busy
              ? null
              : () {
                  _repository.addExpenseSamples();
                  _refresh();
                  _showMessage('Fabricated expenses added on this device.');
                },
          icon: const Icon(Icons.science_outlined),
          label: const Text('Use fabricated expenses'),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OperationMetric('Total expenses', moneyLabel(result.totalMinor)),
            OperationMetric('Expense records', '${result.count}'),
            OperationMetric('Average expense', moneyLabel(result.averageMinor)),
            OperationMetric(
              'Largest expense',
              result.largest == null
                  ? moneyLabel(0)
                  : moneyLabel(result.largest!.amountMinor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OperationsSection(
          title: 'Expenses by category',
          child: result.categories.isEmpty
              ? const OperationEmpty(
                  'No expenses yet. Add an expense or use fabricated data to preview the breakdown.',
                )
              : Column(
                  children: [
                    for (final category in result.categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(category.category)),
                                Text(moneyLabel(category.amountMinor)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: result.totalMinor == 0
                                  ? 0
                                  : category.amountMinor / result.totalMinor,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            Text('${category.count} records'),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        OperationsSection(
          title: 'Monthly spending · KES',
          child: result.months.isEmpty
              ? const OperationEmpty('Monthly totals will appear here.')
              : Column(
                  children: [
                    for (final month in result.months)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(DateFormat('MMM yyyy').format(month.month)),
                        trailing: Text(moneyLabel(month.amountMinor)),
                      ),
                  ],
                ),
        ),
        OperationsSection(
          title: 'Expense records',
          child: _expenses.isEmpty
              ? const OperationEmpty('No saved expense records.')
              : Column(
                  children: [
                    for (final expense in _expenses.take(100))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(expense.description),
                        subtitle: Text(
                          '${formatKenyaDate(expense.spentAt)} · ${expense.category} · ${moneyLabel(expense.amountMinor)}${expense.payee.isEmpty ? '' : ' · ${expense.payee}'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Expense actions',
                          onSelected: (action) => action == 'edit'
                              ? _addExpense(expense)
                              : _deleteExpense(expense),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    if (_expenses.length > 100)
                      const Text('Showing the latest 100 saved records.'),
                  ],
                ),
        ),
      ],
    );
  }
}
