// Fabricated-only visual verification; never opens the production database.
// Run: .\tool\flutter.ps1 test tool/render_mpesa_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bizlens/app.dart';
import 'package:bizlens/app_controller.dart';
import 'package:bizlens/core/sample_data.dart';
import 'package:bizlens/data/mpesa_import_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/memory_store.dart';

void main() {
  testWidgets('render fabricated M-Pesa functional screens', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final fontFile = File('C:/Windows/Fonts/segoeui.ttf');
      if (await fontFile.exists()) {
        final bytes = await fontFile.readAsBytes();
        for (final family in ['Roboto', 'Segoe UI', 'Arial']) {
          await (FontLoader(
            family,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
      }
      await MpesaImportService(store).importBytes(
        generateSampleMpesaCsv(),
        format: 'csv',
        label: 'Fabricated CSV',
      );
    });
    final controller = AppController(store)
      ..enterDemo('preview@example.test', create: true)
      ..navigate(AppPage.mpesa);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: HesabuApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('docs/previews/$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await capture('stage-2-import');
    await tester.scrollUntilVisible(
      find.text('Cash movement by period'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture('stage-2-analysis');
    await tester.scrollUntilVisible(
      find.text('Normalised transactions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture('stage-2-transactions');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
