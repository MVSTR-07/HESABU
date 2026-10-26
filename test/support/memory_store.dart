import 'package:bizlens/data/device_store.dart';
import 'package:bizlens/data/local_store.dart';

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
  Future<void> clearCache() async {}
  @override
  Future<void> deleteAllData() async {
    values.clear();
    _count = 0;
  }

  @override
  void close() {}
}
