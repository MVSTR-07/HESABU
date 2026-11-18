import 'dart:typed_data';

import 'package:hesabu/core/mpesa/models.dart';
import 'package:hesabu/data/device_store.dart';
import 'package:hesabu/data/local_store.dart';
import 'package:hesabu/core/sales/sales_analysis.dart';
import 'package:hesabu/core/expenses/expense_analysis.dart';
import 'package:hesabu/core/stock/stock_analysis.dart';

class MemoryKeyVault implements KeyVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async {
    value = key;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

/// UI tests deliberately bypass native storage; encryption is tested separately.
class MemoryStore implements LocalStore {
  final statements = <int, StoredStatement>{};
  final hashes = <String, int>{};
  final salesRows = <String, SaleRecord>{};
  final expenseRows = <String, ExpenseRecord>{};
  final stockRows = <String, StockItem>{};
  @override
  String? get privateCachePath => null;
  final values = <String, String>{};
  int _count = 0;
  @override
  String? readSetting(String key) => values[key];
  @override
  void writeSetting(String key, String value) {
    values[key] = value;
  }

  @override
  int get sampleCount => _count;
  @override
  void seedSamples() {
    _count = 12;
  }

  @override
  Future<void> clearCache() async {
    values.remove('customer_workspace');
    statements.clear();
    hashes.clear();
    salesRows.clear();
    expenseRows.clear();
    stockRows.clear();
  }

  @override
  Future<void> deleteAllData() async {
    values.clear();
    _count = 0;
    statements.clear();
    hashes.clear();
    salesRows.clear();
    expenseRows.clear();
    stockRows.clear();
  }

  @override
  void close() {}
  @override
  List<StatementSummary> listMpesaStatements() => statements.values
      .map((s) => StatementSummary(s.id, s.label, s.format, s.importedAt))
      .toList()
      .reversed
      .toList();
  @override
  StoredStatement? loadMpesaStatement(int id) => statements[id];
  @override
  int saveMpesaStatement(StoredStatement s, Uint8List source, String hash) {
    final id =
        hashes[hash] ??
        ((statements.keys.fold(0, (a, b) => a > b ? a : b)) + 1);
    hashes[hash] = id;
    statements[id] = StoredStatement(
      id: id,
      label: s.label,
      format: s.format,
      importedAt: s.importedAt,
      transactions: s.transactions,
      results: s.results,
      warnings: s.warnings,
    );
    return id;
  }

  @override
  void saveMpesaResults(int id, MpesaResults results) {
    final s = statements[id]!;
    statements[id] = StoredStatement(
      id: id,
      label: s.label,
      format: s.format,
      importedAt: s.importedAt,
      transactions: s.transactions,
      results: results,
      warnings: s.warnings,
    );
  }

  @override
  List<SaleRecord> listSales() => salesRows.values.toList();
  @override
  void saveSale(SaleRecord sale) => salesRows[sale.id] = sale;
  @override
  void deleteSale(String id) => salesRows.remove(id);
  @override
  List<ExpenseRecord> listExpenses() => expenseRows.values.toList();
  @override
  void saveExpense(ExpenseRecord expense) => expenseRows[expense.id] = expense;
  @override
  void deleteExpense(String id) => expenseRows.remove(id);
  @override
  List<StockItem> listStockItems() => stockRows.values.toList();
  @override
  void saveStockItem(StockItem item) => stockRows[item.id] = item;
  @override
  void deleteStockItem(String id) => stockRows.remove(id);
}
