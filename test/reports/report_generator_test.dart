import 'dart:convert';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/finance/obligation.dart';
import 'package:hesabu/core/finance/profit_and_loss.dart';
import 'package:hesabu/core/reports/consolidated_report.dart';
import 'package:hesabu/core/reports/report_generator.dart';

void main() {
  final summary = ProfitAndLossSummary(
    from: DateTime.utc(2026, 1, 1),
    through: DateTime.utc(2026, 10, 31),
    salesMinor: 125000,
    expensesMinor: 50000,
    operatingSurplusMinor: 75000,
    salesCount: 4,
    expenseCount: 2,
  );
  final obligations = [
    ObligationRecord(
      id: 'fixture',
      kind: ObligationKind.debtor,
      party: 'Fabricated customer',
      description: 'Sample goods',
      originalMinor: 20000,
      settledMinor: 5000,
      createdAt: DateTime.utc(2026, 10, 1),
    ),
  ];

  test('generates a readable PDF in memory', () async {
    final bytes = await const ReportGenerator().profitAndLossPdf(
      summary,
      obligations,
    );
    expect(bytes.length, greaterThan(100));
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
  });

  test('generates an Excel summary in memory', () {
    final bytes = const ReportGenerator().profitAndLossXlsx(
      summary,
      obligations,
    );
    final workbook = Excel.decodeBytes(bytes);
    final rows = workbook[workbook.tables.keys.first].rows;
    expect(rows.first.first?.value.toString(), contains('HESABU'));
    expect(
      rows.any(
        (row) => row.any(
          (cell) =>
              cell?.value.toString().contains('Fabricated customer') ?? false,
        ),
      ),
      isTrue,
    );
  });

  test('generates a visual consolidated PDF and workbook in memory', () async {
    final report = ConsolidatedReport(
      from: summary.from,
      through: summary.through,
      profitAndLoss: summary,
      statementCount: 1,
      mpesaMoneyInMinor: 90000,
      mpesaMoneyOutMinor: 40000,
      mpesaFeesMinor: 500,
      mpesaAnomalyCount: 2,
      openDebtorMinor: 15000,
      openCreditorMinor: 0,
      cashFlow: const [
        ReportCashFlowPoint(
          label: '2026-10',
          moneyInMinor: 90000,
          moneyOutMinor: 40000,
        ),
      ],
      openObligations: obligations,
    );
    final generator = const ReportGenerator();
    final pdf = await generator.consolidatedPdf(report);
    final xlsx = generator.consolidatedXlsx(report);

    expect(latin1.decode(pdf.take(5).toList()), '%PDF-');
    final workbook = Excel.decodeBytes(xlsx);
    final rows = workbook['HESABU Report'].rows;
    expect(rows.first.first?.value.toString(), contains('HESABU'));
    expect(
      rows.any(
        (row) => row.any(
          (cell) => cell?.value.toString().contains('M-Pesa money in') ?? false,
        ),
      ),
      isTrue,
    );
  });
}
