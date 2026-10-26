import 'package:sqlite3/sqlite3.dart';

import '../core/sample_data.dart';

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
      if (version > 1) throw StateError('This database needs a newer BizLens.');
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

  void close() => _db.close();
}
