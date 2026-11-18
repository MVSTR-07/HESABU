import '../core/expenses/expense_analysis.dart';
import '../core/sales/sales_analysis.dart';
import '../core/stock/stock_analysis.dart';
import '../core/finance/obligation.dart';
import '../core/finance/profit_and_loss.dart';
import '../core/imports/tabular_importer.dart';
import '../core/sample_data.dart';
import 'local_store.dart';

/// Persists ordinary sales, expenses, and stock records in SQLCipher.
/// Summaries are recalculated from local rows rather than cached separately.
class OperationsRepository {
  OperationsRepository(this.store);
  final LocalStore store;

  List<SaleRecord> sales() => store.listSales();
  List<ExpenseRecord> expenses() => store.listExpenses();
  List<StockItem> stock() => store.listStockItems();

  SalesSummary analyseSales() => const SalesAnalyser().analyse(sales());
  ExpenseSummary analyseExpenses() =>
      const ExpenseAnalyser().analyse(expenses());
  StockSummary analyseStock() => const StockAnalyser().analyse(stock());

  List<ObligationRecord> obligations() => store.listObligations();
  ObligationSummary analyseObligations({DateTime? asOf}) =>
      ObligationAnalyser().analyse(obligations(), asOf: asOf);

  ProfitAndLossSummary analyseProfitAndLoss({
    required DateTime from,
    required DateTime through,
  }) => ProfitAndLossAnalyser().analyse(
    sales: sales(),
    expenses: expenses(),
    from: from,
    through: through,
  );

  void saveSale(SaleRecord record) {
    const SalesAnalyser().analyse([record]);
    store.saveSale(record);
  }

  void deleteSale(String id) => store.deleteSale(id);

  void saveExpense(ExpenseRecord record) {
    const ExpenseAnalyser().analyse([record]);
    store.saveExpense(record);
  }

  void deleteExpense(String id) => store.deleteExpense(id);

  void saveStockItem(StockItem item) {
    const StockAnalyser().analyse([item]);
    store.saveStockItem(item);
  }

  void deleteStockItem(String id) => store.deleteStockItem(id);

  void saveObligation(ObligationRecord row) {
    const ObligationAnalyser().analyse([row]);
    store.saveObligation(row);
  }

  void deleteObligation(String id) => store.deleteObligation(id);

  void addObligationSamples() {
    store.saveObligationsBatch(generateSampleObligations());
  }

  int importRows(ImportPreview preview) {
    if (!preview.canImport) {
      throw const FormatException('There are no clean rows to import.');
    }
    if (preview.target == ImportTarget.sales) {
      final records = preview.rows
          .map(
            (row) => SaleRecord(
              id: row.id,
              soldAt: row.date,
              product: row.description,
              quantity: row.quantity,
              unitPriceMinor: row.unitPriceMinor,
              customerName: row.party,
            ),
          )
          .toList();
      const SalesAnalyser().analyse(records);
      store.saveSalesBatch(records);
      return records.length;
    }
    final records = preview.rows
        .map(
          (row) => ExpenseRecord(
            id: row.id,
            spentAt: row.date,
            category: row.category,
            description: row.description,
            amountMinor: row.amountMinor,
            payee: row.party,
          ),
        )
        .toList();
    const ExpenseAnalyser().analyse(records);
    store.saveExpensesBatch(records);
    return records.length;
  }

  void addSalesSamples() {
    for (final record in generateSampleSales()) {
      store.saveSale(record);
    }
  }

  void addExpenseSamples() {
    for (final record in generateSampleExpenses()) {
      store.saveExpense(record);
    }
  }

  void addStockSamples() {
    for (final record in generateSampleStock()) {
      store.saveStockItem(record);
    }
  }
}
