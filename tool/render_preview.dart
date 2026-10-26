// Optional UI review aid. Uses fabricated data and a fake store, never the
// production database. Run: .\tool\flutter.ps1 test tool/render_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bizlens/app.dart';
import 'package:bizlens/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/memory_store.dart';

void main() {
  testWidgets('render fabricated Stage 1 previews', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    });
    final controller = AppController(MemoryStore());
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: BizLensApp(controller: controller),
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
    }

    await capture('intro');
    controller.enterDemo('shop@example.test', create: true);
    controller.seedSamples();
    await tester.pumpAndSettle();
    await capture('dashboard');
    controller.navigate(AppPage.settings);
    await tester.pumpAndSettle();
    await capture('settings');
    controller.setTheme(ThemeMode.dark);
    controller.navigate(AppPage.dashboard);
    await tester.pumpAndSettle();
    await capture('dashboard-dark');
  });
}
