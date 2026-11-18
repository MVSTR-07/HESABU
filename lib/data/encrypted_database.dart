import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../core/sample_data.dart';
import '../core/mpesa/models.dart';
import '../core/sales/sales_analysis.dart';
import '../core/expenses/expense_analysis.dart';
import '../core/stock/stock_analysis.dart';

/// All database files, journals and settings use SQLCipher. Keys are generated
/// outside this class and never stored in a file or in source control.
class EncryptedDatabase {
  EncryptedDatabase._(this._db);
  final Database _db;

  static EncryptedDatabase open(String path, String keyHex) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(keyHex)) {
      throw ArgumentError('Expected a 256-bit key.');
    }
    final db = sqlite3.open(path);
    try {
      // Fail closed: plain SQLite silently ignores PRAGMA key.
      if (db.select('PRAGMA cipher_version').isEmpty) {
        throw StateError('Encrypted SQLite is unavailable. Storage is locked.');
      }
      db.execute('PRAGMA key = "x\'$keyHex\'"');
      db.select('SELECT count(*) FROM sqlite_master'); // Verify the key now.
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA temp_store = MEMORY');
      db.execute('PRAGMA cipher_memory_security = ON');
      db.execute('PRAGMA secure_delete = ON');
      db.execute('PRAGMA journal_mode = DELETE');
      final version =
          db.select('PRAGMA user_version').first.values.first as int;
      if (version > 3) throw StateError('This database needs a newer HESABU.');
      if (version == 0) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          // Stage 1 fixtures prove encrypted persistence without implementing
          // the statement import or analysis planned for Stage 2.
          db.execute('''CREATE TABLE demo_payments (
            receipt TEXT PRIMARY KEY,
            occurred_at TEXT NOT NULL,
            amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0)
          )''');
          db.execute('PRAGMA user_version = 1');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (version < 2) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute('''CREATE TABLE mpesa_statements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content_hash TEXT NOT NULL UNIQUE,
            label TEXT NOT NULL, format TEXT NOT NULL,
            imported_at TEXT NOT NULL, original BLOB NOT NULL,
            transactions_json TEXT NOT NULL, results_json TEXT NOT NULL,
            warnings_json TEXT NOT NULL
          )''');
          db.execute('PRAGMA user_version = 2');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (version < 3) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute('''CREATE TABLE sales_entries (
            id TEXT PRIMARY KEY,
            sold_at TEXT NOT NULL,
            product TEXT NOT NULL,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor > 0),
            customer_name TEXT NOT NULL DEFAULT ''
          )''');
          db.execute('''CREATE TABLE expense_entries (
            id TEXT PRIMARY KEY,
            spent_at TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL,
            amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
            payee TEXT NOT NULL DEFAULT ''
          )''');
          db.execute('''CREATE TABLE stock_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            sku TEXT NOT NULL DEFAULT '',
            unit TEXT NOT NULL,
            opening_quantity INTEGER NOT NULL CHECK(opening_quantity >= 0),
            received_quantity INTEGER NOT NULL CHECK(received_quantity >= 0),
            sold_quantity INTEGER NOT NULL CHECK(sold_quantity >= 0),
            damaged_quantity INTEGER NOT NULL CHECK(damaged_quantity >= 0),
            unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor >= 0),
            reorder_level INTEGER NOT NULL CHECK(reorder_level >= 0),
            updated_at TEXT NOT NULL,
            CHECK(sold_quantity + damaged_quantity <= opening_quantity + received_quantity)
          )''');
          db.execute(
            'CREATE INDEX sales_entries_date ON sales_entries(sold_at)',
          );
          db.execute(
            'CREATE INDEX expense_entries_date ON expense_entries(spent_at)',
          );
          db.execute('PRAGMA user_version = 3');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      return EncryptedDatabase._(db);
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  String? readSetting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void writeSetting(String key, String value) => _db.execute(
    'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
    [key, value],
  );

  int get sampleCount =>
      _db.select('SELECT count(*) AS n FROM demo_payments').first['n'] as int;

  void seedSamples() {
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final sample in generateSamplePayments()) {
        _db.execute('INSERT OR IGNORE INTO demo_payments VALUES (?, ?, ?)', [
          sample.receipt,
          sample.occurredAt.toIso8601String(),
          sample.amountMinor,
        ]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<StatementSummary> listMpesaStatements() => _db
      .select(
        'SELECT id,label,format,imported_at FROM mpesa_statements ORDER BY id DESC',
      )
      .map(
        (r) => StatementSummary(
          r['id'] as int,
          r['label'] as String,
          r['format'] as String,
          DateTime.parse(r['imported_at'] as String),
        ),
      )
      .toList();

  StoredStatement? loadMpesaStatement(int id) {
    final rows = _db.select(
      'SELECT id,label,format,imported_at,transactions_json,results_json,warnings_json FROM mpesa_statements WHERE id=?',
      [id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return StoredStatement(
      id: r['id'] as int,
      label: r['label'] as String,
      format: r['format'] as String,
      importedAt: DateTime.parse(r['imported_at'] as String),
      transactions: (jsonDecode(r['transactions_json'] as String) as List)
          .map(
            (v) =>
                MpesaTransaction.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
      results: MpesaResults.fromJson(
        jsonDecode(r['results_json'] as String) as Map<String, dynamic>,
      ),
      warnings: (jsonDecode(r['warnings_json'] as String) as List)
          .cast<String>(),
    );
  }

  int saveMpesaStatement(
    StoredStatement statement,
    Uint8List source,
    String hash,
  ) {
    final existing = _db.select(
      'SELECT id FROM mpesa_statements WHERE content_hash=?',
      [hash],
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      saveMpesaResults(id, statement.results);
      return id;
    }
    // One atomic INSERT: a parsing failure never leaves a partial import.
    _db.execute(
      '''INSERT INTO mpesa_statements
      (content_hash,label,format,imported_at,original,transactions_json,results_json,warnings_json)
      VALUES (?,?,?,?,?,?,?,?)''',
      [
        hash,
        statement.label,
        statement.format,
        statement.importedAt.toUtc().toIso8601String(),
        source,
        jsonEncode(statement.transactions.map((v) => v.toJson()).toList()),
        jsonEncode(statement.results.toJson()),
        jsonEncode(statement.warnings),
      ],
    );
    return _db.lastInsertRowId;
  }

  void saveMpesaResults(int id, MpesaResults results) => _db.execute(
    'UPDATE mpesa_statements SET results_json=? WHERE id=?',
    [jsonEncode(results.toJson()), id],
  );

  List<SaleRecord> listSales() => _db
      .select(
        '''SELECT id,sold_at,product,quantity,unit_price_minor,customer_name
        FROM sales_entries ORDER BY sold_at DESC,id''',
      )
      .map(
        (r) => SaleRecord(
          id: r['id'] as String,
          soldAt: DateTime.parse(r['sold_at'] as String),
          product: r['product'] as String,
          quantity: r['quantity'] as int,
          unitPriceMinor: r['unit_price_minor'] as int,
          customerName: r['customer_name'] as String,
        ),
      )
      .toList();

  void saveSale(SaleRecord sale) => _db.execute(
    '''INSERT OR REPLACE INTO sales_entries
      (id,sold_at,product,quantity,unit_price_minor,customer_name)
      VALUES (?,?,?,?,?,?)''',
    [
      sale.id,
      sale.soldAt.toUtc().toIso8601String(),
      sale.product.trim(),
      sale.quantity,
      sale.unitPriceMinor,
      sale.customerName.trim(),
    ],
  );

  void deleteSale(String id) =>
      _db.execute('DELETE FROM sales_entries WHERE id=?', [id]);

  List<ExpenseRecord> listExpenses() => _db
      .select('''SELECT id,spent_at,category,description,amount_minor,payee
        FROM expense_entries ORDER BY spent_at DESC,id''')
      .map(
        (r) => ExpenseRecord(
          id: r['id'] as String,
          spentAt: DateTime.parse(r['spent_at'] as String),
          category: r['category'] as String,
          description: r['description'] as String,
          amountMinor: r['amount_minor'] as int,
          payee: r['payee'] as String,
        ),
      )
      .toList();

  void saveExpense(ExpenseRecord expense) => _db.execute(
    '''INSERT OR REPLACE INTO expense_entries
      (id,spent_at,category,description,amount_minor,payee)
      VALUES (?,?,?,?,?,?)''',
    [
      expense.id,
      expense.spentAt.toUtc().toIso8601String(),
      expense.category.trim(),
      expense.description.trim(),
      expense.amountMinor,
      expense.payee.trim(),
    ],
  );

  void deleteExpense(String id) =>
      _db.execute('DELETE FROM expense_entries WHERE id=?', [id]);

  List<StockItem> listStockItems() => _db
      .select('''SELECT id,name,sku,unit,opening_quantity,received_quantity,
        sold_quantity,damaged_quantity,unit_cost_minor,reorder_level,updated_at
        FROM stock_items ORDER BY name COLLATE NOCASE,id''')
      .map(
        (r) => StockItem(
          id: r['id'] as String,
          name: r['name'] as String,
          sku: r['sku'] as String,
          unit: r['unit'] as String,
          openingQuantity: r['opening_quantity'] as int,
          receivedQuantity: r['received_quantity'] as int,
          soldQuantity: r['sold_quantity'] as int,
          damagedQuantity: r['damaged_quantity'] as int,
          unitCostMinor: r['unit_cost_minor'] as int,
          reorderLevel: r['reorder_level'] as int,
          updatedAt: DateTime.parse(r['updated_at'] as String),
        ),
      )
      .toList();

  void saveStockItem(StockItem item) => _db.execute(
    '''INSERT OR REPLACE INTO stock_items
      (id,name,sku,unit,opening_quantity,received_quantity,sold_quantity,
       damaged_quantity,unit_cost_minor,reorder_level,updated_at)
      VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
    [
      item.id,
      item.name.trim(),
      item.sku.trim(),
      item.unit.trim(),
      item.openingQuantity,
      item.receivedQuantity,
      item.soldQuantity,
      item.damagedQuantity,
      item.unitCostMinor,
      item.reorderLevel,
      item.updatedAt.toUtc().toIso8601String(),
    ],
  );

  void deleteStockItem(String id) =>
      _db.execute('DELETE FROM stock_items WHERE id=?', [id]);

  void clearWorkspaceData() {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('DELETE FROM mpesa_statements');
      _db.execute('DELETE FROM sales_entries');
      _db.execute('DELETE FROM expense_entries');
      _db.execute('DELETE FROM stock_items');
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    // secure_delete is enabled; VACUUM also reclaims encrypted pages/blobs.
    _db.execute('VACUUM');
  }

  void close() => _db.close();
}
