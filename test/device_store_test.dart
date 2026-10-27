import 'dart:io';

import 'package:bizlens/data/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/memory_store.dart';

void main() {
  late Directory parent;
  late Directory root;
  late MemoryKeyVault vault;
  DeviceStore? store;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('bizlens-device-test-');
    root = Directory(p.join(parent.path, 'private'));
    vault = MemoryKeyVault();
    store = await DeviceStore.open(root: root, vault: vault);
  });
  tearDown(() async {
    store?.close();
    await parent.delete(recursive: true);
  });

  test(
    'wipe rotates the key, clears data and cache, and preserves outside files',
    () async {
      final oldKey = vault.value;
      final outside = File(p.join(parent.path, 'original.csv'));
      await outside.writeAsString('fabricated original');
      final cached = File(p.join(root.path, 'cache', 'demo.tmp'));
      await cached.parent.create(recursive: true);
      await cached.writeAsString('fabricated cache');
      store!.writeSetting('account_email', 'test@example.test');
      store!.seedSamples();
      await store!.deleteAllData();
      expect(vault.value, isNot(oldKey));
      expect(store!.sampleCount, 0);
      expect(store!.readSetting('account_email'), isNull);
      expect(await cached.exists(), isFalse);
      expect(await outside.readAsString(), 'fabricated original');
      store!.close();
      store = await DeviceStore.open(root: root, vault: vault);
      expect(store!.sampleCount, 0);
    },
  );

  test('clear cache preserves the encrypted database', () async {
    store!.seedSamples();
    final cached = File(p.join(root.path, 'cache', 'demo.tmp'));
    await cached.parent.create(recursive: true);
    await cached.writeAsString('fabricated');
    await store!.clearCache();
    expect(await cached.exists(), isFalse);
    expect(store!.sampleCount, 12);
  });

  test(
    'cleanup deletes a cache link without following it outside storage',
    () async {
      final outside = Directory(p.join(parent.path, 'outside'));
      await outside.create();
      final original = File(p.join(outside.path, 'keep.csv'));
      await original.writeAsString('fabricated original');
      final cacheLink = Link(p.join(root.path, 'cache'));
      await cacheLink.create(outside.path);
      await store!.clearCache();
      expect(await cacheLink.exists(), isFalse);
      expect(await original.readAsString(), 'fabricated original');
    },
  );

  test(
    'missing device key locks existing storage instead of replacing it',
    () async {
      store!.seedSamples();
      store!.close();
      store = null;
      final original = vault.value;
      vault.value = null;
      await expectLater(
        DeviceStore.open(root: root, vault: vault),
        throwsStateError,
      );
      expect(vault.value, isNull);
      vault.value = original;
      store = await DeviceStore.open(root: root, vault: vault);
      expect(store!.sampleCount, 12);
    },
  );
}
