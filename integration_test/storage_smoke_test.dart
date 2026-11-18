import 'dart:convert';
import 'dart:io';

import 'package:hesabu/app_controller.dart';
import 'package:hesabu/data/device_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real device secure vault and encrypted database can reopen', (
    tester,
  ) async {
    // Uses the real app directory. Run only on a development profile/device.
    var store = await DeviceStore.open();
    final vault = DeviceKeyVault();
    final originalKey = await vault.read();
    expect(originalKey, matches(RegExp(r'^[0-9a-f]{64}$')));
    // Only fabricate a profile on a fresh development workspace. Never replace
    // an existing user's identity. Leave the samples for the manual checklist.
    if (store.readSetting('account_email') == null) {
      final demo = AppController(store);
      expect(demo.enterDemo('stage1@example.test', create: true), isNull);
      demo.dispose();
    }
    store.seedSamples();
    store.writeSetting('integration_probe', 'fabricated');
    final samplesBefore = store.sampleCount;
    store.close();
    store = await DeviceStore.open();
    expect(store.readSetting('integration_probe'), 'fabricated');
    expect(store.sampleCount, samplesBefore);
    expect(await vault.read(), originalKey);
    if (Platform.isWindows) {
      final database = File(
        '${Platform.environment['LOCALAPPDATA']}/HESABU/private/hesabu.db',
      );
      final bytes = await database.readAsBytes();
      final raw = latin1.decode(bytes);
      expect(raw.startsWith('SQLite format 3'), isFalse);
      expect(raw.contains('fabricated'), isFalse);
      // Never print the key, user email, SQL values or database bytes.
      debugPrint(
        'WINDOWS_STORAGE_EVIDENCE: process_id=$pid device_key_present=true '
        'key_survives_reopen=true encrypted_file=true '
        'fabricated_probe_readable=true sample_count=$samplesBefore',
      );
    }
    store.writeSetting('integration_probe', '');
    store.close();
  });
}
