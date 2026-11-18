import '../expenses/expense_analysis.dart';
import '../sales/sales_analysis.dart';

/// An intentionally simple cash-record summary. It excludes stock valuation,
/// tax, debtors and creditors because the current records do not contain enough
/// dated accounting detail to calculate those items reliably.
class ProfitAndLossSummary {
  const ProfitAndLossSummary({
    required this.from,
    required this.through,
    required this.salesMinor,
    required this.expensesMinor,
    required this.operatingSurplusMinor,
    required this.salesCount,
    required this.expenseCount,
  });

  final DateTime from;
  final DateTime through;
  final int salesMinor;
  final int expensesMinor;
  final int operatingSurplusMinor;
  final int salesCount;
  final int expenseCount;

  double? get surplusMargin =>
      salesMinor == 0 ? null : operatingSurplusMinor / salesMinor;
}

class ProfitAndLossAnalyser {
  const ProfitAndLossAnalyser();

  ProfitAndLossSummary analyse({
    required Iterable<SaleRecord> sales,
    required Iterable<ExpenseRecord> expenses,
    required DateTime from,
    required DateTime through,
  }) {
    final start = _kenyaDate(from);
    final end = _kenyaDate(through);
    if (end.isBefore(start)) {
      throw const FormatException('The report end date is before its start.');
    }
    final salesInRange = sales.where((row) {
      final date = _kenyaDate(row.soldAt);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final expensesInRange = expenses.where((row) {
      final date = _kenyaDate(row.spentAt);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final income = const SalesAnalyser().analyse(salesInRange).revenueMinor;
    final costs = const ExpenseAnalyser().analyse(expensesInRange).totalMinor;
    return ProfitAndLossSummary(
      from: start,
      through: end,
      salesMinor: income,
      expensesMinor: costs,
      operatingSurplusMinor: income - costs,
      salesCount: salesInRange.length,
      expenseCount: expensesInRange.length,
    );
  }
}

DateTime _kenyaDate(DateTime date) {
  final local = date.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(local.year, local.month, local.day);
}
