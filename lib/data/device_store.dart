import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'encrypted_database.dart';
import 'local_store.dart';

abstract interface class KeyVault {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> delete();
}

class DeviceKeyVault implements KeyVault {
  static const _keyName = 'bizlens.database.key.v1';
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _keyName);
  @override
  Future<void> write(String key) => _storage.write(key: _keyName, value: key);
  @override
  Future<void> delete() => _storage.delete(key: _keyName);
}

/// Owns exactly one private directory outside the OneDrive project tree.
/// No imported business files should ever be copied into the OS temp folder.
class DeviceStore implements LocalStore {
  DeviceStore._(this._root, this._vault);
  final Directory _root;
  final KeyVault _vault;
  EncryptedDatabase? _database;
  bool _deleting = false;

  static Future<DeviceStore> open({Directory? root, KeyVault? vault}) async {
    final base = await _resolveRoot(root);
    final store = DeviceStore._(base, vault ?? DeviceKeyVault());
    await store._openDatabase();
    return store;
  }

  /// Recovery must be preceded by destructive confirmation in the startup UI.
  static Future<DeviceStore> resetOnDevice() async {
    final root = await _resolveRoot(null);
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
      base = Directory(p.join(local, 'BizLens', 'private'));
    } else if (Platform.isAndroid) {
      base = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'private'),
      );
    } else {
      throw UnsupportedError('BizLens currently supports Windows and Android.');
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

  String get _databasePath => p.join(_root.path, 'bizlens.db');
  EncryptedDatabase get _db {
    if (_deleting || _database == null) throw StateError('Storage is locked.');
    return _database!;
  }

  Future<void> _openDatabase() async {
    await _root.create(recursive: true);
    var key = await _vault.read();
    if (key == null) {
      // Never replace the key for existing data: that would hide data loss.
      if (await File(_databasePath).exists()) {
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
