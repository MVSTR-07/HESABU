import 'dart:typed_data';

import 'package:bizlens/app.dart';
import 'package:bizlens/app_controller.dart';
import 'package:bizlens/core/mpesa/models.dart';
import 'package:bizlens/core/sample_data.dart';
import 'package:bizlens/data/local_statement_picker.dart';
import 'package:bizlens/data/mpesa_import_service.dart';
import 'package:bizlens/data/mpesa_pdf_reader.dart';
import 'package:bizlens/features/mpesa/mpesa_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_store.dart';

class _RejectPassword implements PdfTextReader {
  @override
  Future<String> read(Uint8List bytes, {String? password}) async =>
      throw const StatementImportException(
        'The PDF password is incorrect or missing. Select the file again and retry.',
      );
}

void main() {
  Future<MemoryStore> seed(WidgetTester tester) async {
    final store = MemoryStore();
    await tester.runAsync(
      () => MpesaImportService(store).importBytes(
        generateSampleMpesaCsv(),
        format: 'csv',
        label: 'Fabricated CSV',
      ),
    );
    return store;
  }

  testWidgets('saved results show every functional section', (tester) async {
    final store = await seed(tester);
    final controller = AppController(store)
      ..enterDemo('test@example.test', create: true)
      ..navigate(AppPage.mpesa);
    await tester.pumpWidget(HesabuApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Your data stays on this device'), findsOneWidget);
    for (final section in [
      'Summary · Fabricated CSV',
      'Cash movement by period',
      'Busiest days and hours',
      'Top 10 senders · customer receipts',
      'Top 10 receivers · transfers, tills and agents',
      'Balance trend',
      'Normalised transactions',
    ]) {
      await tester.scrollUntilVisible(
        find.text(section),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(store.statements.values.single.results.moneyIn, 26621000);
  });

  testWidgets('narrow screen and large text can reach results and charts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await seed(tester);
    final controller = AppController(store)
      ..enterDemo('test@example.test', create: true)
      ..navigate(AppPage.mpesa);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: HesabuApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Normalised transactions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'password is obscured, cancel releases lock, wrong password is safe',
    (tester) async {
      final store = MemoryStore();
      final controller = AppController(store);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MpesaPage(
              controller: controller,
              service: MpesaImportService(store, pdfReader: _RejectPassword()),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Use protected sample PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      expect(controller.busy, isTrue);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.busy, isFalse);
      expect(store.statements, isEmpty);
      await tester.tap(find.text('Use protected sample PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(field, 'wrong-fabricated-password');
      await tester.tap(find.text('Open PDF'));
      await tester.pumpAndSettle();
      expect(find.textContaining('password is incorrect'), findsOneWidget);
      expect(find.text('wrong-fabricated-password'), findsNothing);
      expect(controller.busy, isFalse);
      expect(store.statements, isEmpty);
    },
  );

  testWidgets('empty import shows an error without losing navigation', (
    tester,
  ) async {
    final controller = AppController(MemoryStore());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MpesaPage(
            controller: controller,
            picker: () async => SelectedStatement('empty.csv', Uint8List(0)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose PDF / CSV'));
    await tester.pumpAndSettle();
    expect(find.text('The selected file is empty.'), findsOneWidget);
    expect(controller.busy, isFalse);
  });

  testWidgets(
    'Clear cache confirms, erases reports and invalidates report screen',
    (tester) async {
      final store = await seed(tester);
      final controller = AppController(store)
        ..enterDemo('test@example.test', create: true)
        ..navigate(AppPage.settings);
      await tester.pumpWidget(HesabuApp(controller: controller));
      await tester.pumpAndSettle();
      final button = find.text('Clear cache');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.statements.length, 1);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear imports and cache'));
      await tester.pumpAndSettle();
      expect(store.statements, isEmpty);
      expect(controller.email, 'test@example.test');
      controller.navigate(AppPage.mpesa);
      await tester.pumpAndSettle();
      expect(find.text('Summary · Fabricated CSV'), findsNothing);
      expect(find.text('Saved statements'), findsNothing);
    },
  );
}
