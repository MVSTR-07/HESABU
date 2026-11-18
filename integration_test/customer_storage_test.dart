import 'dart:io';

import 'package:hesabu/data/customer_repository.dart';
import 'package:hesabu/data/device_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows customer persistence, merges, config and deletion', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('hesabu-stage3-native-');
    final keyName =
        'hesabu.test.customers.$pid.${DateTime.now().microsecondsSinceEpoch}';
    final vault = DeviceKeyVault(keyName: keyName);
    DeviceStore? store;
    final date = DateTime.utc(2026, 10, 27, 12);
    try {
      store = await DeviceStore.open(root: root, vault: vault);
      store.writeSetting('account_email', 'fabricated@example.test');
      var repo = CustomerRepository(store)..addSamples(date);
      final before = repo.analyse(date);
      expect(before.customers.length, 7);
      final total = before.total;
      repo.merge(before.customers[0].id, before.customers[1].id);
      store.close();
      store = await DeviceStore.open(
        root: root,
        vault: DeviceKeyVault(keyName: keyName),
      );
      repo = CustomerRepository(store);
      expect(repo.analyse(date).customers.length, 6);
      expect(repo.analyse(date).total, total);
      repo.undoMerge();
      expect(repo.analyse(date).customers.length, 7);
      await store.clearCache();
      expect(CustomerRepository(store).payments(), isEmpty);
      expect(store.readSetting('account_email'), 'fabricated@example.test');
      repo = CustomerRepository(store)..addSamples(date);
      final oldKey = await vault.read();
      await store.deleteAllData();
      expect(CustomerRepository(store).sales, isEmpty);
      expect(await vault.read(), isNot(oldKey));
      debugPrint(
        'STAGE3_WINDOWS: encrypted_persistence=true merge_undo=true clear_cache=true full_wipe=true isolated_test_vault=true',
      );
    } finally {
      store?.close();
      await vault.delete();
      if (p.isWithin(Directory.systemTemp.absolute.path, root.absolute.path) &&
          p.basename(root.path).startsWith('hesabu-stage3-native-')) {
        await root.delete(recursive: true);
      }
    }
  });
}
