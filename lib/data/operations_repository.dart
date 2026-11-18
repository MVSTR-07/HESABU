import '../core/expenses/expense_analysis.dart';
import '../core/sample_data.dart';
import '../core/sales/sales_analysis.dart';
import '../core/stock/stock_analysis.dart';
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
