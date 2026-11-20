import '../finance/obligation.dart';
import '../finance/profit_and_loss.dart';
import '../mpesa/models.dart';

/// A deliberately small, export-safe view of locally calculated results.
/// It carries aggregate values only; raw statement text and transaction rows are
/// never copied into a visual report unless a later explicit export option adds
/// them.
class ConsolidatedReport {
  const ConsolidatedReport({
    required this.from,
    required this.through,
    required this.profitAndLoss,
    required this.statementCount,
    required this.mpesaMoneyInMinor,
    required this.mpesaMoneyOutMinor,
    required this.mpesaFeesMinor,
    required this.mpesaAnomalyCount,
    required this.openDebtorMinor,
    required this.openCreditorMinor,
    required this.cashFlow,
    required this.openObligations,
  });

  final DateTime from;
  final DateTime through;
  final ProfitAndLossSummary profitAndLoss;
  final int statementCount;
  final int mpesaMoneyInMinor;
  final int mpesaMoneyOutMinor;
  final int mpesaFeesMinor;
  final int mpesaAnomalyCount;
  final int openDebtorMinor;
  final int openCreditorMinor;
  final List<ReportCashFlowPoint> cashFlow;
  final List<ObligationRecord> openObligations;
}

class ReportCashFlowPoint {
  const ReportCashFlowPoint({
    required this.label,
    required this.moneyInMinor,
    required this.moneyOutMinor,
  });

  final String label;
  final int moneyInMinor;
  final int moneyOutMinor;
}

/// Combines existing local analyser results. It does not re-parse sources and
/// never performs network or AI work.
class ConsolidatedReportBuilder {
  const ConsolidatedReportBuilder();

  ConsolidatedReport build({
    required ProfitAndLossSummary profitAndLoss,
    required Iterable<StoredStatement> statements,
    required Iterable<ObligationRecord> obligations,
  }) {
    final source = statements.toList(growable: false);
    final open = obligations.where((row) => !row.isSettled).toList();
    final periods = <String, List<int>>{};
    var moneyIn = 0;
    var moneyOut = 0;
    var fees = 0;
    var anomalies = 0;

    for (final statement in source) {
      final result = statement.results;
      moneyIn += result.moneyIn;
      moneyOut += result.moneyOut;
      fees += result.fees;
      anomalies += result.anomalies.length;
      for (final period in result.monthly) {
        final total = periods.putIfAbsent(period.key, () => [0, 0]);
        total[0] += period.moneyIn;
        total[1] += period.moneyOut;
      }
    }
    final cashFlow =
        periods.entries
            .map(
              (entry) => ReportCashFlowPoint(
                label: entry.key,
                moneyInMinor: entry.value[0],
                moneyOutMinor: entry.value[1],
              ),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    return ConsolidatedReport(
      from: profitAndLoss.from,
      through: profitAndLoss.through,
      profitAndLoss: profitAndLoss,
      statementCount: source.length,
      mpesaMoneyInMinor: moneyIn,
      mpesaMoneyOutMinor: moneyOut,
      mpesaFeesMinor: fees,
      mpesaAnomalyCount: anomalies,
      openDebtorMinor: open
          .where((row) => row.kind == ObligationKind.debtor)
          .fold(0, (total, row) => total + row.outstandingMinor),
      openCreditorMinor: open
          .where((row) => row.kind == ObligationKind.creditor)
          .fold(0, (total, row) => total + row.outstandingMinor),
      cashFlow: List.unmodifiable(cashFlow),
      openObligations: List.unmodifiable(open),
    );
  }
}
