import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'encrypted_database.dart';
import 'local_store.dart';
import '../core/mpesa/models.dart';
import '../core/sales/sales_analysis.dart';
import '../core/expenses/expense_analysis.dart';
import '../core/stock/stock_analysis.dart';

abstract interface class KeyVault {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> delete();
}

class DeviceKeyVault implements KeyVault {
  DeviceKeyVault({this.keyName = 'hesabu.database.key.v1'});
  final String keyName;
  final _storage = const FlutterSecureStorage();

  // A prior release stored the DPAPI-encrypted key map in this app-support
  // directory. Move the encrypted file as-is when the Windows product identity
  // changes; never decrypt or print its contents during migration.
  static const _legacyCompanyName = 'ke.co.bizlens';
  static const _legacyProductName = 'bizlens';
  static const _legacyKeyName = 'bizlens.database.key.v1';
  static const _secureStoreFileName = 'flutter_secure_storage.dat';

  Future<void> _migrateLegacyWindowsStore() async {
    if (!Platform.isWindows) return;
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return;
    final destination = File(
      p.join(
        (await getApplicationSupportDirectory()).path,
        _secureStoreFileName,
      ),
    );
    final legacy = File(
      p.join(
        appData,
        _legacyCompanyName,
        _legacyProductName,
        _secureStoreFileName,
      ),
    );
    final hasDestination = await destination.exists();
    final hasLegacy = await legacy.exists();
    if (hasDestination && hasLegacy) {
      throw StateError(
        'Both HESABU and the previous secure-storage locations contain data. '
        'Storage is locked to avoid replacing either key store.',
      );
    }
    if (!hasDestination && hasLegacy) {
      await destination.parent.create(recursive: true);
      await legacy.rename(destination.path);
    }
  }

  @override
  Future<String?> read() async {
    await _migrateLegacyWindowsStore();
    final current = await _storage.read(key: keyName);
    if (current != null) return current;
    final legacy = await _storage.read(key: _legacyKeyName);
    if (legacy == null) return null;
    await _storage.write(key: keyName, value: legacy);
    await _storage.delete(key: _legacyKeyName);
    return legacy;
  }

  @override
  Future<void> write(String key) async {
    await _migrateLegacyWindowsStore();
    await _storage.write(key: keyName, value: key);
    await _storage.delete(key: _legacyKeyName);
  }

  @override
  Future<void> delete() async {
    await _migrateLegacyWindowsStore();
    await _storage.delete(key: keyName);
    await _storage.delete(key: _legacyKeyName);
  }
}

/// Owns exactly one private directory outside the OneDrive project tree.
/// No imported business files should ever be copied into the OS temp folder.
class DeviceStore implements LocalStore {
  DeviceStore._(this._root, this._vault);
  final Directory _root;
  final KeyVault _vault;
  EncryptedDatabase? _database;
  bool _deleting = false;

  static Future<DeviceStore> open({
    Directory? root,
    Directory? legacyRoot,
    KeyVault? vault,
  }) async {
    final base = await _resolveRoot(root);
    await _migrateLegacyRoot(base, legacyRoot ?? _resolveLegacyRoot(root));
    final store = DeviceStore._(base, vault ?? DeviceKeyVault());
    await store._openDatabase();
    return store;
  }

  /// Recovery must be preceded by destructive confirmation in the startup UI.
  static Future<DeviceStore> resetOnDevice() async {
    final root = await _resolveRoot(null);
    await _migrateLegacyRoot(root, _resolveLegacyRoot(null));
    final store = DeviceStore._(root, DeviceKeyVault());
    await root.create(recursive: true);
    await store.deleteAllData();
    return store;
  }

  static Future<Directory> _resolveRoot(Directory? root) async {
    final Directory base;
    if (root != null) {
      base = root;
    } else if (Platform.isWindows) {
      // Application documents may be OneDrive-backed. LocalAppData is local.
      final local = Platform.environment['LOCALAPPDATA'];
      if (local == null) throw StateError('Local app storage is unavailable.');
      base = Directory(p.join(local, 'HESABU', 'private'));
    } else if (Platform.isAndroid) {
      base = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'private'),
      );
    } else {
      throw UnsupportedError('HESABU currently supports Windows and Android.');
    }
    var ancestor = base;
    while (true) {
      if (await FileSystemEntity.type(ancestor.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw StateError('Linked storage directories are not supported.');
      }
      if (p.equals(ancestor.path, ancestor.parent.path)) break;
      ancestor = ancestor.parent;
    }
    return base;
  }

  static Directory? _resolveLegacyRoot(Directory? root) {
    if (root != null || !Platform.isWindows) return null;
    final local = Platform.environment['LOCALAPPDATA'];
    return local == null
        ? null
        : Directory(p.join(local, 'BizLens', 'private'));
  }

  static Future<void> _migrateLegacyRoot(
    Directory current,
    Directory? legacy,
  ) async {
    if (legacy == null ||
        p.equals(p.absolute(current.path), p.absolute(legacy.path))) {
      return;
    }
    if (!await legacy.exists()) return;
    if (await current.exists()) {
      final entries = await current.list(followLinks: false).toList();
      if (entries.isNotEmpty) {
        throw StateError(
          'Both HESABU and the previous data locations contain files. '
          'Storage is locked to preserve both copies.',
        );
      }
      // A failed first launch after branding changes can leave an empty new
      // directory. It contains no user data, so remove only that empty folder
      // before moving the existing encrypted workspace into place.
      await current.delete();
    }
    await current.parent.create(recursive: true);
    await legacy.rename(current.path);
  }

  String get _databasePath => p.join(_root.path, 'hesabu.db');
  String get _legacyDatabasePath => p.join(_root.path, 'bizlens.db');
  @override
  String get privateCachePath => p.join(_root.path, 'cache');
  EncryptedDatabase get _db {
    if (_deleting || _database == null) throw StateError('Storage is locked.');
    return _database!;
  }

  Future<void> _openDatabase() async {
    await _root.create(recursive: true);
    var key = await _vault.read();
    if (key == null) {
      // Never replace the key for existing data: that would hide data loss.
      if (await File(_databasePath).exists() ||
          await File(_legacyDatabasePath).exists()) {
        throw StateError(
          'The device encryption key is missing. Storage is locked.',
        );
      }
      final random = Random.secure();
      key = List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await _vault.write(key);
    }
    final currentDatabase = File(_databasePath);
    final legacyDatabase = File(_legacyDatabasePath);
    if (await currentDatabase.exists() && await legacyDatabase.exists()) {
      throw StateError(
        'Both HESABU and the previous database files exist. '
        'Storage is locked to preserve both copies.',
      );
    }
    if (!await currentDatabase.exists() && await legacyDatabase.exists()) {
      await legacyDatabase.rename(_databasePath);
    }
    _database = EncryptedDatabase.open(_databasePath, key);
  }

  @override
  String? readSetting(String key) => _db.readSetting(key);
  @override
  void writeSetting(String key, String value) => _db.writeSetting(key, value);
  @override
  int get sampleCount => _db.sampleCount;
  @override
  void seedSamples() => _db.seedSamples();
  @override
  List<StatementSummary> listMpesaStatements() => _db.listMpesaStatements();
  @override
  StoredStatement? loadMpesaStatement(int id) => _db.loadMpesaStatement(id);
  @override
  int saveMpesaStatement(
    StoredStatement statement,
    Uint8List source,
    String hash,
  ) => _db.saveMpesaStatement(statement, source, hash);
  @override
  void saveMpesaResults(int id, MpesaResults results) =>
      _db.saveMpesaResults(id, results);

  @override
  List<SaleRecord> listSales() => _db.listSales();
  @override
  void saveSale(SaleRecord sale) => _db.saveSale(sale);
  @override
  void deleteSale(String id) => _db.deleteSale(id);
  @override
  List<ExpenseRecord> listExpenses() => _db.listExpenses();
  @override
  void saveExpense(ExpenseRecord expense) => _db.saveExpense(expense);
  @override
  void deleteExpense(String id) => _db.deleteExpense(id);
  @override
  List<StockItem> listStockItems() => _db.listStockItems();
  @override
  void saveStockItem(StockItem item) => _db.saveStockItem(item);
  @override
  void deleteStockItem(String id) => _db.deleteStockItem(id);

  // Refuse links and unexpected paths; deletion never follows a symlink.
  Future<void> _removeOwnedEntry(FileSystemEntity entry) async {
    final root = p.normalize(p.absolute(_root.path));
    final target = p.normalize(p.absolute(entry.path));
    if (!p.isWithin(root, target)) throw StateError('Unsafe cleanup path.');
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await for (final child in Directory(target).list(followLinks: false)) {
        await _removeOwnedEntry(child);
      }
      await Directory(target).delete();
    } else if (type == FileSystemEntityType.link) {
      await Link(target).delete();
    } else if (type == FileSystemEntityType.file) {
      await File(target).delete();
    }
  }

  @override
  Future<void> clearCache() async {
    _db.writeSetting('customer_workspace', '{}');
    _db.clearWorkspaceData();
    final cache = Directory(p.join(_root.path, 'cache'));
    await _removeOwnedEntry(cache);
  }

  @override
  Future<void> deleteAllData() async {
    if (_deleting) throw StateError('Deletion is already in progress.');
    _deleting = true;
    _database?.close();
    _database = null;
    try {
      // Destroy only our key, never every key belonging to the application.
      await _vault.delete();
      await for (final entry in _root.list(followLinks: false)) {
        await _removeOwnedEntry(entry);
      }
      if (await _root.list().isEmpty == false) {
        throw StateError('Some local files could not be deleted.');
      }
      await _openDatabase(); // Fresh, empty database with a new random key.
    } finally {
      // On failure the DB stays locked; UI never reports a successful wipe.
      _deleting = false;
    }
  }

  @override
  void close() {
    _database?.close();
    _database = null;
  }
}
