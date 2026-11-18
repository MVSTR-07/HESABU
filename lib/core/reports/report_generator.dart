import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../finance/obligation.dart';
import '../finance/profit_and_loss.dart';

class ReportGenerator {
  const ReportGenerator();

  Future<Uint8List> profitAndLossPdf(
    ProfitAndLossSummary result,
    List<ObligationRecord> obligations,
  ) async {
    final document = pw.Document();
    final date = DateFormat('dd/MM/yyyy');
    final money = NumberFormat('#,##0.00');
    String kes(int minor) => 'KES ${money.format(minor / 100)}';
    final openDebts = obligations.where((row) => !row.isSettled).toList();
    document.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            'HESABU - Business summary',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Profit and loss: ${date.format(result.from)} to ${date.format(result.through)}',
          ),
          pw.SizedBox(height: 20),
          _pdfLine(
            'Recorded sales (${result.salesCount} rows)',
            kes(result.salesMinor),
          ),
          _pdfLine(
            'Recorded expenses (${result.expenseCount} rows)',
            kes(result.expensesMinor),
          ),
          pw.Divider(),
          _pdfLine(
            'Operating surplus',
            kes(result.operatingSurplusMinor),
            bold: true,
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Open balances',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (openDebts.isEmpty) ...[
            pw.Text('No open debtor or creditor balances recorded.'),
          ] else ...[
            ...openDebts.map(
              (row) => _pdfLine(
                '${row.kind == ObligationKind.debtor ? 'Owed to you' : 'You owe'} - ${row.party} - ${row.description}',
                kes(row.outstandingMinor),
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            'Prepared locally by HESABU. Based only on recorded sales and expenses; excludes stock cost, tax, and unrecorded transactions.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  Uint8List profitAndLossXlsx(
    ProfitAndLossSummary result,
    List<ObligationRecord> obligations,
  ) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'HESABU Summary');
    final sheet = workbook['HESABU Summary'];
    final dates = DateFormat('dd/MM/yyyy');
    final rows = <List<Object?>>[
      ['HESABU - Business summary'],
      [
        'Profit and loss period',
        '${dates.format(result.from)} to ${dates.format(result.through)}',
      ],
      ['Recorded sales', result.salesMinor / 100],
      ['Sales rows', result.salesCount],
      ['Recorded expenses', result.expensesMinor / 100],
      ['Expense rows', result.expenseCount],
      ['Operating surplus', result.operatingSurplusMinor / 100],
      [
        'Basis',
        'Recorded sales less recorded expenses; excludes stock cost and tax',
      ],
      [],
      ['Open balances'],
      [
        'Direction',
        'Party',
        'Description',
        'Original KES',
        'Settled KES',
        'Outstanding KES',
        'Due date',
      ],
    ];
    for (final row in obligations.where((row) => !row.isSettled)) {
      rows.add([
        row.kind == ObligationKind.debtor ? 'Owed to you' : 'You owe',
        row.party,
        row.description,
        row.originalMinor / 100,
        row.settledMinor / 100,
        row.outstandingMinor / 100,
        row.dueAt == null ? '' : dates.format(row.dueAt!),
      ]);
    }
    for (var row = 0; row < rows.length; row++) {
      for (var col = 0; col < rows[row].length; col++) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          _excelCell(rows[row][col]),
        );
      }
    }
    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('The spreadsheet could not be created.');
    }
    return Uint8List.fromList(bytes);
  }
}

CellValue _excelCell(Object? value) => switch (value) {
  null => TextCellValue(''),
  int number => IntCellValue(number),
  double number => DoubleCellValue(number),
  String text => TextCellValue(text),
  _ => TextCellValue('$value'),
};

pw.Widget _pdfLine(String label, String amount, {bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            amount,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
