import 'dart:typed_data';

import '../core/mpesa/models.dart';

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
  Future<void> clearCache();
  Future<void> deleteAllData();
  void close();
}
