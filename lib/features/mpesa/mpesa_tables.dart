import 'package:flutter/material.dart';

import '../../core/mpesa/models.dart';
import '../../ui/formatters.dart';

class TransactionSource extends DataTableSource {
  TransactionSource(this.statement);
  final StoredStatement statement;
  @override
  int get rowCount => statement.transactions.length;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
  @override
  DataRow? getRow(int index) {
    if (index >= rowCount) return null;
    final tx = statement.transactions[index];
    final duplicate = statement.results.duplicateRows.contains(tx.row);
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text('${tx.row}${duplicate ? ' (duplicate excluded)' : ''}')),
        DataCell(Text(formatKenyaDateTime(tx.at))),
        DataCell(SelectableText(tx.receipt)),
        DataCell(
          SizedBox(
            width: 300,
            child: Tooltip(
              message: tx.details,
              child: Text(
                tx.details,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        DataCell(Text(tx.type.label)),
        DataCell(Text(formatKes(tx.paidIn))),
        DataCell(Text(formatKes(tx.withdrawn))),
        DataCell(
          Text(tx.balance == null ? 'Not supplied' : formatKes(tx.balance!)),
        ),
      ],
    );
  }
}

class PeriodSource extends DataTableSource {
  PeriodSource(this.periods);
  final List<CashPeriod> periods;
  @override
  int get rowCount => periods.length;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
  @override
  DataRow? getRow(int index) {
    if (index >= rowCount) return null;
    final p = periods[index];
    final parts = p.key.split('-');
    final label = parts.length == 3
        ? '${parts[2]}/${parts[1]}/${parts[0]}'
        : '${parts[1]}/${parts[0]}';
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(label)),
        DataCell(Text(formatKes(p.moneyIn))),
        DataCell(Text(formatKes(p.moneyOut))),
        DataCell(Text(formatKes(p.net))),
        DataCell(Text('${p.count}')),
      ],
    );
  }
}

class RankingTable extends StatelessWidget {
  const RankingTable({required this.parties, super.key});
  final List<RankedParty> parties;
  @override
  Widget build(BuildContext context) => parties.isEmpty
      ? const Text('No identified counterparties for this direction.')
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Counterparty')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Payments')),
            ],
            rows: parties
                .take(10)
                .map(
                  (p) => DataRow(
                    cells: [
                      DataCell(Text(p.name)),
                      DataCell(Text(formatKes(p.amount))),
                      DataCell(Text('${p.count}')),
                    ],
                  ),
                )
                .toList(),
          ),
        );
}
