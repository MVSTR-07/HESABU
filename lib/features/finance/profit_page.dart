import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_controller.dart';
import '../../data/operations_repository.dart';
import '../../ui/formatters.dart';
import '../operations/operations_widgets.dart';

class ProfitPage extends StatelessWidget {
  const ProfitPage({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final repository = OperationsRepository(controller.store);
    final today = DateTime.now().toUtc().add(const Duration(hours: 3));
    final from = DateTime.utc(today.year, 1, 1);
    final through = DateTime.utc(today.year, today.month, today.day);
    final result = repository.analyseProfitAndLoss(
      from: from,
      through: through,
    );
    final money = NumberFormat('#,##0.00');
    return OperationsPageFrame(
      title: 'Profit and loss',
      subtitle:
          'Year to date · ${formatKenyaDate(from)} to ${formatKenyaDate(through)}',
      actions: const [],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OperationMetric('Recorded sales', moneyLabel(result.salesMinor)),
            OperationMetric(
              'Recorded expenses',
              moneyLabel(result.expensesMinor),
            ),
            OperationMetric(
              'Operating surplus',
              moneyLabel(result.operatingSurplusMinor),
            ),
            OperationMetric(
              'Surplus margin',
              result.surplusMargin == null
                  ? '—'
                  : '${(result.surplusMargin! * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        const SizedBox(height: 16),
        OperationsSection(
          title: 'Summary',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Sales · ${result.salesCount} records'),
                trailing: Text('KES ${money.format(result.salesMinor / 100)}'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Expenses · ${result.expenseCount} records'),
                trailing: Text(
                  'KES ${money.format(result.expensesMinor / 100)}',
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Operating surplus'),
                trailing: Text(
                  'KES ${money.format(result.operatingSurplusMinor / 100)}',
                ),
              ),
            ],
          ),
        ),
        const OperationsSection(
          title: 'How to read this',
          child: Text(
            'This is a simple local summary of saved sales minus saved expenses. It does not include inventory cost, tax, outstanding debts, or unrecorded transactions, so use it as a working view rather than a statutory financial statement.',
          ),
        ),
      ],
    );
  }
}
