import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hesabu/core/mpesa/models.dart';
import 'package:hesabu/core/sample_data.dart';
import 'package:hesabu/data/device_store.dart';
import 'package:hesabu/data/mpesa_import_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/memory_store.dart';

void main() {
  late Directory parent;
  late Directory root;
  late MemoryKeyVault vault;
  DeviceStore? store;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp(
      'hesabu-mpesa-storage-test-',
    );
    root = Directory(p.join(parent.path, 'private'));
    vault = MemoryKeyVault();
    store = await DeviceStore.open(root: root, vault: vault);
  });
  tearDown(() async {
    store?.close();
    await parent.delete(recursive: true);
  });

  Future<StoredStatement> importCsv() => MpesaImportService(store!).importBytes(
    generateSampleMpesaCsv(),
    format: 'csv',
    label: 'Fabricated CSV',
  );

  test('source, transactions and results persist encrypted; identical file is not duplicated', () async {
    final first = await importCsv();
    final again = await importCsv();
    expect(again.id, first.id);
    expect(store!.listMpesaStatements().length, 1);
    store!.close();
    final raw = latin1.decode(
      await File(p.join(root.path, 'hesabu.db')).readAsBytes(),
    );
    expect(raw.contains('Wanjiku'), isFalse);
    expect(raw.contains('Receipt No.'), isFalse);
    expect(raw.contains('26621000'), isFalse);
    store = await DeviceStore.open(root: root, vault: vault);
    final restored = store!.loadMpesaStatement(first.id)!;
    expect(restored.transactions.length, 23);
    expect(restored.results.uniqueCount, 22);
    expect(restored.results.moneyIn, 26621000);
  });

  test('clear cache wipes imported source/results and files but preserves profile and originals', () async {
    final report = await importCsv();
    store!.writeSetting('account_email', 'fabricated@example.test');
    store!.seedSamples();
    final original = File(p.join(parent.path, 'original.csv'));
    await original.writeAsBytes(generateSampleMpesaCsv());
    final cache = File(p.join(root.path, 'cache', 'fabricated.csv'));
    await cache.parent.create(recursive: true);
    await cache.writeAsBytes(generateSampleMpesaCsv());
    await store!.clearCache();
    expect(store!.listMpesaStatements(), isEmpty);
    expect(store!.loadMpesaStatement(report.id), isNull);
    expect(await cache.exists(), isFalse);
    expect(await original.exists(), isTrue);
    expect(store!.readSetting('account_email'), 'fabricated@example.test');
    expect(store!.sampleCount, 12);
    store!.close();
    final db = sqlite3.open(p.join(root.path, 'hesabu.db'));
    db.execute('PRAGMA key = "x\'${vault.value}\'"');
    expect(
      db.select('SELECT count(*) AS n FROM mpesa_statements').first['n'],
      0,
    );
    db.close();
    store = await DeviceStore.open(root: root, vault: vault);
    expect(store!.listMpesaStatements(), isEmpty);
  });

  test(
    'full wipe removes imports/results/profile/cache and rotates the key',
    () async {
      final report = await importCsv();
      final oldKey = vault.value;
      store!.writeSetting('account_email', 'fabricated@example.test');
      final cache = File(p.join(root.path, 'cache', 'fabricated.pdf'));
      await cache.parent.create(recursive: true);
      await cache.writeAsBytes(generateSampleMpesaPdf());
      await store!.deleteAllData();
      expect(vault.value, isNot(oldKey));
      expect(await cache.exists(), isFalse);
      expect(store!.listMpesaStatements(), isEmpty);
      expect(store!.loadMpesaStatement(report.id), isNull);
      expect(store!.readSetting('account_email'), isNull);
    },
  );

  test('failed imports create no source/result records', () async {
    for (final input in [
      (Uint8List(0), 'csv'),
      (Uint8List.fromList(utf8.encode('not a statement')), 'csv'),
      (Uint8List.fromList([1, 2, 3]), 'xlsx'),
    ]) {
      await expectLater(
        MpesaImportService(store!)
            .importBytes(input.$1, format: input.$2, label: 'fabricated'),
        throwsA(isA<StatementImportException>()),
      );
    }
    expect(store!.listMpesaStatements(), isEmpty);
  });

  test(
    'threshold reanalysis persists independently of the original bytes',
    () async {
      final report = await importCsv();
      final updated = await MpesaImportService(store!).reanalyse(
        report,
        const AnomalyThresholds(largeAmount: 1000000000, spikeMultiplier: 2001),
      );
      expect(updated.results.anomalies.single.kind, AnomalyKind.duplicate);
      expect(updated.transactions.length, 23);
    },
  );

  test(
    'Stage 1 schema migrates without losing the signed-off profile or samples',
    () async {
      store!.close();
      store = null;
      final oldRoot = Directory(p.join(parent.path, 'stage1'))..createSync();
      final oldVault = MemoryKeyVault();
      await oldVault.write(List.filled(64, 'c').join());
      final old = sqlite3.open(p.join(oldRoot.path, 'bizlens.db'));
      old.execute('PRAGMA key = "x\'${oldVault.value}\'"');
      old.execute(
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      old.execute(
        'CREATE TABLE demo_payments (receipt TEXT PRIMARY KEY, occurred_at TEXT NOT NULL, amount_minor INTEGER NOT NULL)',
      );
      old.execute('INSERT INTO settings VALUES (?,?)', [
        'account_email',
        'stage1@example.test',
      ]);
      old.execute('INSERT INTO demo_payments VALUES (?,?,?)', [
        'DEMO-OLD',
        '2026-01-01T00:00:00Z',
        10000,
      ]);
      old.execute('PRAGMA user_version=1');
      old.close();
      store = await DeviceStore.open(root: oldRoot, vault: oldVault);
      expect(store!.readSetting('account_email'), 'stage1@example.test');
      expect(store!.sampleCount, 1);
      expect(store!.listMpesaStatements(), isEmpty);
      await importCsv();
      expect(store!.listMpesaStatements().length, 1);
    },
  );
}
