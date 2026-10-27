import 'dart:convert';
import 'dart:io';

import 'package:bizlens/core/mpesa/models.dart';
import 'package:bizlens/core/mpesa/sample_column_pdf_bytes.dart';


import 'package:bizlens/core/sample_data.dart';
import 'package:bizlens/data/device_store.dart';
import 'package:bizlens/data/mpesa_import_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native PDF/CSV, real vault, persistence, clear cache and full wipe',
    (tester) async {
      // A separately named REAL Windows key prevents touching the user's vault.
      final parent = await Directory.systemTemp.createTemp(
        'bizlens-mpesa-native-',
      );
      final root = Directory(p.join(parent.path, 'private'));
      final vaultName =
          'bizlens.test.mpesa.$pid.${DateTime.now().microsecondsSinceEpoch}';
      final vault = DeviceKeyVault(keyName: vaultName);
      DeviceStore? store;
      try {
        store = await DeviceStore.open(root: root, vault: vault);
        store.writeSetting('account_email', 'fabricated@example.test');
        store.seedSamples();
        final importer = MpesaImportService(store);
        final csv = await importer.importBytes(
          generateSampleMpesaCsv(),
          format: 'csv',
          label: 'Fabricated CSV',
        );
        final pdf = await importer.importBytes(
          generateSampleMpesaPdf(),
          format: 'pdf',
          label: 'Fabricated PDF',
          password: sampleMpesaPassword,
        );
        expect(csv.results.moneyIn, 26621000);
        expect(pdf.results.moneyIn, csv.results.moneyIn);
        expect(pdf.results.uniqueCount, 22);
        expect(pdf.results.duplicateRows.length, 1);
        final columnPdf = await importer.importBytes(
          Uint8List.fromList(base64Decode(sampleMpesaColumnPdfBase64)),
          format: 'pdf',
          label: 'Fabricated column PDF',
          password: sampleMpesaPassword,
        );
        expect(columnPdf.results.moneyIn, csv.results.moneyIn);
        expect(columnPdf.results.moneyOut, csv.results.moneyOut);
        await expectLater(
          importer.importBytes(
            generateSampleMpesaPdf(),
            format: 'pdf',
            label: 'Rejected PDF',
            password: 'wrong-fabricated-password',
          ),
          throwsA(isA<StatementImportException>()),
        );
        expect(store.listMpesaStatements().length, 3);
        final originalKey = await vault.read();
        store.close();
        final raw = latin1.decode(
          await File(p.join(root.path, 'bizlens.db')).readAsBytes(),
        );
        expect(raw.startsWith('SQLite format 3'), isFalse);
        expect(raw.contains('Wanjiku'), isFalse);
        store = await DeviceStore.open(
          root: root,
          vault: DeviceKeyVault(keyName: vaultName),
        );
        expect(await vault.read(), originalKey);
        expect(store.loadMpesaStatement(pdf.id)!.results.fulizaCost, 7000);
        final original = File(p.join(parent.path, 'original.csv'));
        await original.writeAsBytes(generateSampleMpesaCsv());
        final cache = File(p.join(root.path, 'cache', 'fabricated.pdf'));
        await cache.parent.create(recursive: true);
        await cache.writeAsBytes(generateSampleMpesaPdf());
        await store.clearCache();
        expect(store.listMpesaStatements(), isEmpty);
        expect(store.loadMpesaStatement(csv.id), isNull);
        expect(await cache.exists(), isFalse);
        expect(await original.exists(), isTrue);
        expect(store.readSetting('account_email'), 'fabricated@example.test');
        expect(store.sampleCount, 12);
        store.close();
        store = await DeviceStore.open(root: root, vault: vault);
        expect(store.listMpesaStatements(), isEmpty);
        await MpesaImportService(store).importBytes(
          generateSampleMpesaCsv(),
          format: 'csv',
          label: 'Fabricated CSV',
        );
        await store.deleteAllData();
        expect(store.listMpesaStatements(), isEmpty);
        expect(store.sampleCount, 0);
        expect(store.readSetting('account_email'), isNull);
        expect(await vault.read(), isNot(originalKey));
        expect(await original.exists(), isTrue);
        debugPrint(
          'MPESA_WINDOWS_EVIDENCE: protected_pdf=true csv=true wrong_password_safe=true '
          'encrypted_persistence=true clear_cache_erases_imports_and_results=true '
          'full_wipe_rotates_key=true original_files_preserved=true',
        );
      } finally {
        store?.close();
        await vault.delete();
        final absolute = parent.absolute.path;
        if (p.isWithin(Directory.systemTemp.absolute.path, absolute) &&
            p.basename(absolute).startsWith('bizlens-mpesa-native-')) {
          await parent.delete(recursive: true);
        }
      }
    },
  );
}
