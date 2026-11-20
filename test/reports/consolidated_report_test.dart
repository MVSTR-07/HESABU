import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/reports/consolidated_report.dart';
import 'package:hesabu/core/sample_data.dart';
import 'package:hesabu/data/mpesa_import_service.dart';
import 'package:hesabu/data/operations_repository.dart';

import '../support/memory_store.dart';

void main() {
  test('combines only existing local aggregate results', () async {
    final store = MemoryStore();
    final statement = await MpesaImportService(store).importBytes(
      generateSampleMpesaCsv(),
      format: 'csv',
      label: 'Fabricated M-Pesa CSV',
    );
    final repository = OperationsRepository(store)
      ..addSalesSamples()
      ..addExpenseSamples()
      ..addObligationSamples();
    final profitAndLoss = repository.analyseProfitAndLoss(
      from: DateTime.utc(2026, 1, 1),
      through: DateTime.utc(2026, 12, 31),
    );

    final report = const ConsolidatedReportBuilder().build(
      profitAndLoss: profitAndLoss,
      statements: [statement],
      obligations: repository.obligations(),
    );

    expect(report.statementCount, 1);
    expect(report.mpesaMoneyInMinor, statement.results.moneyIn);
    expect(report.mpesaAnomalyCount, statement.results.anomalies.length);
    expect(report.cashFlow, isNotEmpty);
    expect(report.openObligations, isNotEmpty);
  });
}
