import 'dart:typed_data';

import '../core/mpesa/models.dart';
import '../core/sales/sales_analysis.dart';
import '../core/expenses/expense_analysis.dart';
import '../core/stock/stock_analysis.dart';
import '../core/finance/obligation.dart';

abstract interface class LocalStore {
  String? get privateCachePath;
  String? readSetting(String key);
  void writeSetting(String key, String value);
  int get sampleCount;
  void seedSamples();
  List<StatementSummary> listMpesaStatements();
  StoredStatement? loadMpesaStatement(int id);
  int saveMpesaStatement(
    StoredStatement statement,
    Uint8List source,
    String hash,
  );
  void saveMpesaResults(int id, MpesaResults results);
  List<SaleRecord> listSales();
  void saveSale(SaleRecord sale);
  void saveSalesBatch(List<SaleRecord> sales);
  void deleteSale(String id);
  List<ExpenseRecord> listExpenses();
  void saveExpense(ExpenseRecord expense);
  void saveExpensesBatch(List<ExpenseRecord> expenses);
  void deleteExpense(String id);
  List<StockItem> listStockItems();
  void saveStockItem(StockItem item);
  void deleteStockItem(String id);
  List<ObligationRecord> listObligations();
  void saveObligation(ObligationRecord row);
  void saveObligationsBatch(List<ObligationRecord> rows);
  void deleteObligation(String id);
  Future<void> clearCache();
  Future<void> deleteAllData();
  void close();
}
