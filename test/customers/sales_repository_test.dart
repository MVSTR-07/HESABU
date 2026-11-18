import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hesabu/core/customers/customer_analysis.dart';
import 'package:hesabu/core/customers/sales_parser.dart';
import 'package:hesabu/data/customer_repository.dart';
import 'package:hesabu/data/device_store.dart';
import 'package:hesabu/data/mpesa_import_service.dart';
import 'package:hesabu/core/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_store.dart';

Uint8List csv(String body) => Uint8List.fromList(utf8.encode(body));
const sales =
    'Date,Customer Name,Phone,Amount,Sale ID\n01/01/2026,"Amina, Demo",0700000001,1000.50,FAB1\n11/01/2026,Amina Demo,254700000001,1500.00,FAB2\n';
void main() {
  test('sales CSV handles quoted names, dates, positive cents and aliases', () {
    final rows = const CustomerSalesParser().parse(csv(sales));
    expect(rows.first.name, 'Amina, Demo');
    expect(rows.first.amount, 100050);
    expect(rows.first.phone, '+254700000001');
    expect(rows.first.identity, rows.last.identity);
    expect(
      const CustomerSalesParser()
          .parse(csv('Date;Name;Amount\n2026-01-01;Njeri;50.25'))
          .single
          .amount,
      5025,
    );
  });
  test('malformed rows are safe errors and never leak a private cell', () {
    for (final text in [
      '',
      'Date,Name,Amount\n31/02/2026,PRIVATE_CANARY,10',
      'Date,Name,Amount\n01/01/2026,PRIVATE_CANARY,-10',
      'Date,Name,Amount\n01/01/2026,"PRIVATE_CANARY,10',
      'Date,Name,Phone,Amount\n01/01/2026,PRIVATE_CANARY,07***,10',
    ]) {
      try {
        const CustomerSalesParser().parse(csv(text));
        fail('Expected import error');
      } on FormatException catch (e) {
        expect(e.message, isNot(contains('PRIVATE_CANARY')));
      }
    }
  });
  test(
    'same CSV does not duplicate sales; conflicting ID rejects atomically',
    () {
      final store = MemoryStore();
      final repo = CustomerRepository(store)
        ..importSales(csv(sales))
        ..importSales(csv(sales));
      expect(repo.sales.length, 2);
      final before = store.readSetting('customer_workspace');
      expect(
        () => repo.importSales(csv(sales.replaceFirst('1000.50', '2000.00'))),
        throwsFormatException,
      );
      expect(store.readSetting('customer_workspace'), before);
      expect(repo.sales.length, 2);
    },
  );
  test(
    'M-Pesa receipt duplicates across saved statement copies count once',
    () async {
      final store = MemoryStore();
      final importer = MpesaImportService(store);
      await importer.importBytes(
        generateSampleMpesaCsv(),
        format: 'csv',
        label: 'Fabricated',
      );
      final repo = CustomerRepository(store);
      final first = repo.payments();
      expect(first, isNotEmpty);
      expect(first.every((p) => p.phone != null), isTrue);
      // Same logical rows, different bytes, hence a separate encrypted source.
      await importer.importBytes(
        csv('${utf8.decode(generateSampleMpesaCsv())}\n'),
        format: 'csv',
        label: 'Overlapping fabricated',
      );
      expect(CustomerRepository(store).payments().length, first.length);
    },
  );
  test(
    'merge and undo persist; clear cache removes customer identities/sales',
    () async {
      final store = MemoryStore();
      final repo = CustomerRepository(store)
        ..addSamples(DateTime.utc(2026, 10, 27));
      final before = repo.analyse(DateTime.utc(2026, 10, 27)).customers;
      repo.merge(before[0].id, before[1].id);
      expect(
        CustomerRepository(store)
            .analyse(DateTime.utc(2026, 10, 27))
            .customers
            .length,
        before.length - 1,
      );
      final reopened = CustomerRepository(store)..undoMerge();
      expect(
        reopened.analyse(DateTime.utc(2026, 10, 27)).customers.length,
        before.length,
      );
      repo.saveConfig(const DropOffConfig(atRisk: 2, lost: 4), 'Hello {name}');
      await store.clearCache();
      expect(CustomerRepository(store).payments(), isEmpty);
      expect(CustomerRepository(store).aliases, isEmpty);
      expect(CustomerRepository(store).config.atRisk, 2);
    },
  );
  test(
    'customer data persists in SQLCipher and both deletion actions erase it',
    () async {
      final root = await Directory.systemTemp.createTemp('hesabu-customers-');
      final vault = MemoryKeyVault();
      DeviceStore? store;
      try {
        store = await DeviceStore.open(root: root, vault: vault);
        CustomerRepository(store).importSales(csv(sales));
        store.writeSetting('account_email', 'fabricated@example.test');
        store.close();
        final raw = latin1.decode(
          await File('${root.path}/hesabu.db').readAsBytes(),
        );
        expect(raw, isNot(contains('Amina')));
        expect(raw.startsWith('SQLite format 3'), isFalse);
        store = await DeviceStore.open(root: root, vault: vault);
        expect(CustomerRepository(store).sales.length, 2);
        await store.clearCache();
        expect(CustomerRepository(store).sales, isEmpty);
        expect(store.readSetting('account_email'), 'fabricated@example.test');
        CustomerRepository(store).importSales(csv(sales));
        await store.deleteAllData();
        expect(CustomerRepository(store).sales, isEmpty);
        expect(store.readSetting('account_email'), isNull);
      } finally {
        store?.close();
        await root.delete(recursive: true);
      }
    },
  );
}
