abstract interface class LocalStore {
  String? readSetting(String key);
  void writeSetting(String key, String value);
  int get sampleCount;
  void seedSamples();
  Future<void> clearCache();
  Future<void> deleteAllData();
  void close();
}
