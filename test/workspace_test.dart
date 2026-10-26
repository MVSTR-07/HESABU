import 'package:bizlens/app.dart';
import 'package:bizlens/app_controller.dart';
import 'package:bizlens/ai/ai_service.dart';
import 'package:bizlens/core/sample_data.dart';
import 'package:bizlens/ui/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/memory_store.dart';

void main() {
  test('local profile and entitlement persist, logout does not erase data', () {
    final store = MemoryStore();
    final controller = AppController(store);
    expect(controller.enterDemo('bad', create: true), isNotNull);
    expect(controller.enterDemo('shop@example.test', create: false), isNotNull);
    expect(controller.enterDemo('shop@example.test', create: true), isNull);
    controller.setDemoPaid(true);
    controller.seedSamples();
    controller.signOut();
    expect(
      store.values.keys,
      unorderedEquals(['account_email', 'signed_in', 'demo_paid']),
      reason: 'Demo identity/plan must never persist a password or credential.',
    );
    expect(store.sampleCount, 12);
    final restored = AppController(store);
    expect(restored.signedIn, isFalse);
    expect(restored.paid, isTrue);
    expect(restored.enterDemo('shop@example.test', create: false), isNull);
  });

  test('AI is unavailable and cannot send a request', () async {
    const ai = DisabledAiService();
    expect(ai.isAvailable, isFalse);
    await expectLater(ai.explain('fabricated'), throwsStateError);
  });

  test('fabricated fixtures and Kenyan formatting are deterministic', () {
    expect(generateSamplePayments().length, 12);
    expect(formatKes(123456), contains('1,234.56'));
    expect(formatKes(123456), contains('KES'));
    expect(formatKenyaDate(DateTime.utc(2026, 1, 31, 22)), '01/02/2026');
  });

  testWidgets('intro, demo sign-up, gating and confirmed wipe work', (
    tester,
  ) async {
    final controller = AppController(MemoryStore());
    await tester.pumpWidget(BizLensApp(controller: controller));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'shop@example.test');
    await tester.tap(find.text('Create demo profile'));
    await tester.pumpAndSettle();
    expect(controller.page, AppPage.dashboard);
    await tester.tap(find.text('Load sample data'));
    await tester.pumpAndSettle();
    expect(controller.store.sampleCount, 12);
    await tester.scrollUntilVisible(find.text('Customer performance'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer performance'));
    await tester.pumpAndSettle();
    expect(find.text('Paid tool · demo gate'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    controller.navigate(AppPage.settings);
    await tester.pumpAndSettle();
    final wipe = find.text('Delete all data / clear cache');
    await tester.scrollUntilVisible(wipe, 200);
    await tester.pumpAndSettle();
    await tester.tap(wipe);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.store.sampleCount, 12);
    await tester.tap(wipe);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all data', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(controller.store.sampleCount, 0);
    expect(controller.email, isNull);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('two-column cards tolerate a narrow phone and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController(MemoryStore());
    controller.enterDemo('phone@example.test', create: true);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: BizLensApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Export reports'), 250);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Customer performance')).dx,
      greaterThan(tester.getTopLeft(find.text('M-Pesa statements')).dx),
    );
  });
}
