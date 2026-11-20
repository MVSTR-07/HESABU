import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'consolidated_report.dart';
import '../finance/obligation.dart';
import '../finance/profit_and_loss.dart';

class ReportGenerator {
  const ReportGenerator();

  /// Produces a local, visual report made only from already-calculated local
  /// results. No raw source file or transaction detail is embedded by default.
  Future<Uint8List> consolidatedPdf(ConsolidatedReport report) async {
    final document = pw.Document();
    final date = DateFormat('dd/MM/yyyy');
    String kes(int minor) =>
        'KES ${NumberFormat('#,##0.00').format(minor / 100)}';
    final cashMax = report.cashFlow.fold<int>(
      1,
      (max, point) => [
        max,
        point.moneyInMinor,
        point.moneyOutMinor,
      ].reduce((a, b) => a > b ? a : b),
    );
    document.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey)),
          ),
          child: pw.Text(
            'HESABU - PRIVATE LOCAL REPORT',
            style: pw.TextStyle(
              color: PdfColors.blue900,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 18),
          pw.Text(
            'Business performance report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${date.format(report.from)} to ${date.format(report.through)}',
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _metricCard(
                'Recorded sales',
                kes(report.profitAndLoss.salesMinor),
                PdfColors.blue700,
              ),
              pw.SizedBox(width: 8),
              _metricCard(
                'Expenses',
                kes(report.profitAndLoss.expensesMinor),
                PdfColors.orange700,
              ),
              pw.SizedBox(width: 8),
              _metricCard(
                'Operating surplus',
                kes(report.profitAndLoss.operatingSurplusMinor),
                PdfColors.green700,
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          _sectionTitle('Cash movement - supported statement imports'),
          pw.Text(
            '${report.statementCount} saved statement(s) - ${report.mpesaAnomalyCount} rule flag(s) for review',
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 150,
                height: 150,
                child: report.mpesaMoneyInMinor + report.mpesaMoneyOutMinor == 0
                    ? pw.Center(child: pw.Text('No M-Pesa cash-flow data'))
                    : pw.Chart(
                        grid: pw.PieGrid(),
                        datasets: [
                          pw.PieDataSet(
                            value: report.mpesaMoneyInMinor,
                            legend: 'Money in',
                            color: PdfColors.green400,
                            innerRadius: 30,
                            legendPosition: pw.PieLegendPosition.none,
                          ),
                          pw.PieDataSet(
                            value: report.mpesaMoneyOutMinor,
                            legend: 'Money out',
                            color: PdfColors.red300,
                            innerRadius: 30,
                            legendPosition: pw.PieLegendPosition.none,
                          ),
                        ],
                      ),
              ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfLine(
                      'Money in',
                      kes(report.mpesaMoneyInMinor),
                      bold: true,
                    ),
                    _pdfLine('Money out', kes(report.mpesaMoneyOutMinor)),
                    _pdfLine('M-Pesa fees', kes(report.mpesaFeesMinor)),
                    _pdfLine(
                      'Net movement',
                      kes(report.mpesaMoneyInMinor - report.mpesaMoneyOutMinor),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (report.cashFlow.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Monthly cash-flow trend',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _cashFlowBars(report.cashFlow, cashMax),
          ],
          pw.SizedBox(height: 22),
          _sectionTitle('Open balances'),
          pw.Row(
            children: [
              _metricCard(
                'Customers owe you',
                kes(report.openDebtorMinor),
                PdfColors.blue700,
              ),
              pw.SizedBox(width: 8),
              _metricCard(
                'You owe suppliers',
                kes(report.openCreditorMinor),
                PdfColors.deepOrange700,
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          if (report.openObligations.isEmpty)
            pw.Text('No open debtor or creditor balances recorded.')
          else
            ...report.openObligations
                .take(12)
                .map(
                  (row) => _pdfLine(
                    '${row.kind == ObligationKind.debtor ? 'Owed to you' : 'You owe'} - ${row.party}',
                    kes(row.outstandingMinor),
                  ),
                ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Prepared locally by HESABU. This report contains summaries, not raw statements. It is a working business view, not a statutory financial statement.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  Uint8List consolidatedXlsx(ConsolidatedReport report) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'HESABU Report');
    final summary = workbook['HESABU Report'];
    final dates = DateFormat('dd/MM/yyyy');
    final rows = <List<Object?>>[
      ['HESABU - Business performance report'],
      [
        'Period',
        '${dates.format(report.from)} to ${dates.format(report.through)}',
      ],
      [],
      ['KEY METRIC', 'KES'],
      ['Recorded sales', report.profitAndLoss.salesMinor / 100],
      ['Recorded expenses', report.profitAndLoss.expensesMinor / 100],
      ['Operating surplus', report.profitAndLoss.operatingSurplusMinor / 100],
      ['M-Pesa money in', report.mpesaMoneyInMinor / 100],
      ['M-Pesa money out', report.mpesaMoneyOutMinor / 100],
      ['M-Pesa fees', report.mpesaFeesMinor / 100],
      ['Open debtors', report.openDebtorMinor / 100],
      ['Open creditors', report.openCreditorMinor / 100],
      ['M-Pesa flags for review', report.mpesaAnomalyCount],
      [],
      ['MONTHLY CASH FLOW', 'MONEY IN KES', 'MONEY OUT KES'],
      ...report.cashFlow.map(
        (point) => [
          point.label,
          point.moneyInMinor / 100,
          point.moneyOutMinor / 100,
        ],
      ),
    ];
    for (var row = 0; row < rows.length; row++) {
      for (var col = 0; col < rows[row].length; col++) {
        summary.updateCell(
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

pw.Widget _sectionTitle(String value) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  decoration: pw.BoxDecoration(
    color: PdfColors.blue800,
    borderRadius: pw.BorderRadius.circular(7),
  ),
  child: pw.Text(
    value,
    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
  ),
);

pw.Widget _metricCard(String label, String value, PdfColor color) =>
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color.shade(0.08),
          border: pw.Border.all(color: color.shade(.45)),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );

pw.Widget _cashFlowBars(List<ReportCashFlowPoint> points, int maximum) {
  final displayed = points.length > 8
      ? points.sublist(points.length - 8)
      : points;
  return pw.SizedBox(
    height: 150,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        for (final point in displayed)
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          height: 105 * point.moneyInMinor / maximum,
                          color: PdfColors.green400,
                        ),
                      ),
                      pw.SizedBox(width: 1),
                      pw.Expanded(
                        child: pw.Container(
                          height: 105 * point.moneyOutMinor / maximum,
                          color: PdfColors.red300,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(point.label, style: const pw.TextStyle(fontSize: 6)),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
