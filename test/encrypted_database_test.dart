import 'dart:convert';
import 'dart:io';

import 'package:hesabu/data/encrypted_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  final key = List.filled(64, 'a').join();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'hesabu-encryption-test-',
    );
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'database persists encrypted settings and rejects a wrong key',
    () async {
      final path = p.join(directory.path, 'fixture.db');
      var db = EncryptedDatabase.open(path, key);
      db.writeSetting('email', 'fabricated@example.test');
      db.seedSamples();
      db.seedSamples();
      expect(
        db.sampleCount,
        12,
        reason: 'Sample generation must be idempotent.',
      );
      db.close();
      final raw = latin1.decode(await File(path).readAsBytes());
      expect(raw.startsWith('SQLite format 3'), isFalse);
      expect(raw.contains('fabricated@example.test'), isFalse);
      expect(
        () => EncryptedDatabase.open(path, List.filled(64, 'b').join()),
        throwsA(anything),
      );
      db = EncryptedDatabase.open(path, key);
      expect(db.readSetting('email'), 'fabricated@example.test');
      expect(db.sampleCount, 12);
      db.close();
    },
  );

  test('invalid keys are rejected before opening a file', () {
    final path = p.join(directory.path, 'invalid.db');
    expect(() => EncryptedDatabase.open(path, 'short'), throwsArgumentError);
    expect(File(path).existsSync(), isFalse);
  });
}
