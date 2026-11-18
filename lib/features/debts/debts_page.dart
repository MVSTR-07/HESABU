import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/finance/obligation.dart';
import '../../data/operations_repository.dart';
import '../../ui/formatters.dart';
import '../operations/operations_widgets.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  late final OperationsRepository _repository;
  List<ObligationRecord> _rows = [];
  @override
  void initState() {
    super.initState();
    _repository = OperationsRepository(widget.controller.store);
    _refresh();
  }

  void _refresh() => setState(() => _rows = _repository.obligations());

  Future<void> _add() async {
    final party = TextEditingController();
    final description = TextEditingController();
    final amount = TextEditingController();
    final settled = TextEditingController(text: '0');
    var kind = ObligationKind.debtor;
    DateTime? dueAt;
    var error = '';
    final row = await showDialog<ObligationRecord>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Add an outstanding balance'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ObligationKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Direction'),
                    items: const [
                      DropdownMenuItem(
                        value: ObligationKind.debtor,
                        child: Text('Customer owes me'),
                      ),
                      DropdownMenuItem(
                        value: ObligationKind.creditor,
                        child: Text('I owe supplier'),
                      ),
                    ],
                    onChanged: (value) => update(() => kind = value ?? kind),
                  ),
                  TextField(
                    controller: party,
                    decoration: const InputDecoration(
                      labelText: 'Customer or supplier',
                    ),
                  ),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(
                      labelText: 'What is the balance for?',
                    ),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Original amount · KES',
                    ),
                  ),
                  TextField(
                    controller: settled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Already paid · KES',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueAt ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked != null) {
                          update(
                            () => dueAt = DateTime.utc(
                              picked.year,
                              picked.month,
                              picked.day,
                              9,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        dueAt == null
                            ? 'Set due date (optional)'
                            : 'Due · ${formatKenyaDate(dueAt!)}',
                      ),
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
                final originalMinor = parseKesAmount(amount.text);
                final settledMinor = _parseSettledAmount(settled.text);
                if (party.text.trim().isEmpty ||
                    description.text.trim().isEmpty ||
                    originalMinor == null ||
                    settledMinor == null ||
                    settledMinor < 0 ||
                    settledMinor > originalMinor) {
                  update(
                    () => error = 'Enter a party, description, valid original amount and payment within that amount.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  ObligationRecord(
                    id: operationId('BALANCE'),
                    kind: kind,
                    party: party.text.trim(),
                    description: description.text.trim(),
                    originalMinor: originalMinor,
                    settledMinor: settledMinor,
                    createdAt: DateTime.now().toUtc(),
                    dueAt: dueAt,
                  ),
                );
              },
              child: const Text('Save balance'),
            ),
          ],
        ),
      ),
    );
    party.dispose();
    description.dispose();
    amount.dispose();
    settled.dispose();
    if (row == null || !mounted) return;
    try {
      _repository.saveObligation(row);
      _refresh();
    } on FormatException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Balance could not be saved to encrypted local storage.');
    }
  }

  Future<void> _recordPayment(ObligationRecord row) async {
    final amount = TextEditingController();
    final entered = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record payment'),
        content: TextField(
          controller: amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount · KES'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, parseKesAmount(amount.text)),
            child: const Text('Save payment'),
          ),
        ],
      ),
    );
    amount.dispose();
    if (entered == null || !mounted) return;
    if (entered <= 0 || entered > row.outstandingMinor) {
      _message(
        'Payment must be positive and no greater than the remaining balance.',
      );
      return;
    }
    _repository.saveObligation(
      ObligationRecord(
        id: row.id,
        kind: row.kind,
        party: row.party,
        description: row.description,
        originalMinor: row.originalMinor,
        settledMinor: row.settledMinor + entered,
        createdAt: row.createdAt,
        dueAt: row.dueAt,
        reference: row.reference,
      ),
    );
    _refresh();
  }

  Future<void> _delete(ObligationRecord row) async {
    if (!await confirmOperationDelete(context, row.party) || !mounted) return;
    _repository.deleteObligation(row.id);
    _refresh();
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final summary = _repository.analyseObligations();
    return OperationsPageFrame(
      title: 'Debtors and creditors',
      subtitle: 'Keep track of balances customers owe you and balances you owe suppliers.',
      actions: [
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add balance'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            _repository.addObligationSamples();
            _refresh();
            _message(
              'Fabricated customer and supplier balances added locally.',
            );
          },
          icon: const Icon(Icons.science_outlined),
          label: const Text('Use fabricated balances'),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OperationMetric(
              'Customers owe you',
              moneyLabel(summary.debtorOutstandingMinor),
            ),
            OperationMetric(
              'You owe suppliers',
              moneyLabel(summary.creditorOutstandingMinor),
            ),
            OperationMetric('Open balances', '${summary.openCount}'),
            OperationMetric('Overdue', '${summary.overdueCount}'),
          ],
        ),
        OperationsSection(
          title: 'Balances',
          child: _rows.isEmpty
              ? const OperationEmpty(
                  'No balances recorded. Add a customer or supplier balance to start tracking it on this device.',
                )
              : Column(
                  children: [
                    for (final row in _rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${row.kind == ObligationKind.debtor ? 'Customer owes you' : 'You owe supplier'} · ${row.party}',
                        ),
                        subtitle: Text(
                          '${row.description} · Original ${moneyLabel(row.originalMinor)} · Paid ${moneyLabel(row.settledMinor)}${row.dueAt == null ? '' : ' · Due ${formatKenyaDate(row.dueAt!)}'}${row.isOverdueAt(DateTime.now()) ? ' · OVERDUE' : ''}',
                        ),
                        trailing: row.isSettled
                            ? const Chip(label: Text('Settled'))
                            : Wrap(
                                children: [
                                  Text(moneyLabel(row.outstandingMinor)),
                                  PopupMenuButton<String>(
                                    onSelected: (action) => action == 'payment'
                                        ? _recordPayment(row)
                                        : _delete(row),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'payment',
                                        child: Text('Record payment'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                  ],
                ),
        ),
        const OperationsSection(
          title: 'Privacy',
          child: Text(
            'These records are saved in the encrypted local database. They are separate from sales and M-Pesa cash movements.',
          ),
        ),
      ],
    );
  }
}

int? _parseSettledAmount(String input) {
  if (input.trim().isEmpty) return 0;
  final value = double.tryParse(input.trim().replaceAll(',', ''));
  if (value == null || !value.isFinite || value < 0) return null;
  return (value * 100).round();
}
