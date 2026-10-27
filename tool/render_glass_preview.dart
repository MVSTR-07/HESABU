// Original styling previews using fabricated data and an in-memory store only.
// Run: .\tool\flutter.ps1 test tool/render_glass_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bizlens/app.dart';
import 'package:bizlens/app_controller.dart';
import 'package:bizlens/core/sample_data.dart';
import 'package:bizlens/data/customer_repository.dart';
import 'package:bizlens/data/mpesa_import_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/memory_store.dart';

void main() {
  testWidgets('render dark glass desktop and phone layouts', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final file = File('C:/Windows/Fonts/arial.ttf');
      if (await file.exists()) {
        // Native widgets use the platform system font; the widget test uses
        // Flutter's default test font to preserve glyph coverage/metrics.
      }
      await MpesaImportService(store).importBytes(
        generateSampleMpesaCsv(),
        format: 'csv',
        label: 'Fabricated M-Pesa sample',
      );
      CustomerRepository(store).addSamples(DateTime.now().toUtc());
    });
    final controller = AppController(store);
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
        final target = File('docs/previews/$name.png');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await capture('hesabu-glass-desktop-intro');
    controller.navigate(AppPage.account);
    await tester.pumpAndSettle();
    await capture('hesabu-glass-account');
    controller.enterDemo('preview@example.test', create: true);
    controller.setDemoPaid(true);
    controller.seedSamples();
    await tester.pumpAndSettle();
    await capture('hesabu-glass-desktop-dashboard');
    controller.navigate(AppPage.mpesa);
    await tester.pumpAndSettle();
    await capture('hesabu-glass-mpesa');
    controller.navigate(AppPage.customers);
    await tester.pumpAndSettle();
    await capture('hesabu-glass-customers');
    controller.navigate(AppPage.settings);
    await tester.pumpAndSettle();
    await capture('hesabu-glass-settings');
    tester.view.physicalSize = const Size(390, 844);
    controller.navigate(AppPage.dashboard);
    await tester.pumpAndSettle();
    await capture('hesabu-glass-phone-dashboard');
    controller.navigate(AppPage.intro);
    await tester.pumpAndSettle();
    await capture('hesabu-glass-phone-intro');
    tester.view.physicalSize = const Size(1440, 1100);
    controller.setTheme(ThemeMode.light);
    controller.navigate(AppPage.dashboard);
    await tester.pumpAndSettle();
    await capture('hesabu-glass-light-dashboard');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
