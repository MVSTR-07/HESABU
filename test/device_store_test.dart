import 'dart:io';

import 'package:hesabu/core/expenses/expense_analysis.dart';
import 'package:hesabu/core/sales/sales_analysis.dart';
import 'package:hesabu/core/stock/stock_analysis.dart';
import 'package:hesabu/core/finance/obligation.dart';
import 'package:hesabu/data/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/memory_store.dart';

void main() {
  late Directory parent;
  late Directory root;
  late MemoryKeyVault vault;
  DeviceStore? store;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('hesabu-device-test-');
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
    'Stage 4 records persist encrypted and clear cache removes them',
    () async {
      final date = DateTime.utc(2026, 10, 26, 9);
      store!.saveSale(
        SaleRecord(
          id: 'sale-test',
          soldAt: date,
          product: 'Fabricated flour',
          quantity: 2,
          unitPriceMinor: 18000,
        ),
      );
      store!.saveExpense(
        ExpenseRecord(
          id: 'expense-test',
          spentAt: date,
          category: 'Fabricated transport',
          description: 'Local test record',
          amountMinor: 90000,
        ),
      );
      store!.saveStockItem(
        StockItem(
          id: 'stock-test',
          name: 'Fabricated rice',
          unit: 'bags',
          openingQuantity: 8,
          receivedQuantity: 2,
          soldQuantity: 3,
          damagedQuantity: 0,
          unitCostMinor: 12000,
          reorderLevel: 2,
          updatedAt: date,
        ),
      );
      store!.saveObligation(
        ObligationRecord(
          id: 'balance-test',
          kind: ObligationKind.debtor,
          party: 'Fabricated customer',
          description: 'Fabricated goods',
          originalMinor: 12500,
          settledMinor: 2500,
          createdAt: date,
          dueAt: DateTime.utc(2026, 11, 1),
        ),
      );
      store!.writeSetting('theme', 'dark');

      store!.close();
      store = await DeviceStore.open(root: root, vault: vault);
      expect(store!.listSales().single.product, 'Fabricated flour');
      expect(store!.listExpenses().single.description, 'Local test record');
      expect(store!.listStockItems().single.quantityOnHand, 7);
      expect(store!.listObligations().single.outstandingMinor, 10000);
      expect(store!.readSetting('theme'), 'dark');

      final databaseBytes = await File(p.join(root.path, 'hesabu.db'))
          .readAsBytes();
      expect(
        String.fromCharCodes(databaseBytes),
        isNot(contains('Fabricated flour')),
      );

      await store!.clearCache();
      expect(store!.listSales(), isEmpty);
      expect(store!.listExpenses(), isEmpty);
      expect(store!.listStockItems(), isEmpty);
      expect(store!.listObligations(), isEmpty);
      expect(store!.readSetting('theme'), 'dark');
    },
  );

  test('legacy data folder and database filename migrate intact', () async {
    store!.close();
    store = null;
    final legacyRoot = Directory(p.join(parent.path, 'legacy', 'private'));
    final newRoot = Directory(p.join(parent.path, 'HESABU', 'private'));
    store = await DeviceStore.open(root: legacyRoot, vault: vault);
    store!.writeSetting('account_email', 'fabricated@example.test');
    store!.seedSamples();
    store!.close();
    store = null;

    await File(p.join(legacyRoot.path, 'hesabu.db'))
        .rename(p.join(legacyRoot.path, 'bizlens.db'));
    store = await DeviceStore.open(
      root: newRoot,
      legacyRoot: legacyRoot,
      vault: vault,
    );
    expect(store!.readSetting('account_email'), 'fabricated@example.test');
    expect(store!.sampleCount, 12);
    expect(await File(p.join(newRoot.path, 'hesabu.db')).exists(), isTrue);
    expect(await File(p.join(newRoot.path, 'bizlens.db')).exists(), isFalse);
    expect(await legacyRoot.exists(), isFalse);
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
