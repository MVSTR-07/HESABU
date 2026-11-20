import 'package:hesabu/app.dart';
import 'package:hesabu/app_controller.dart';
import 'package:hesabu/ai/ai_service.dart';
import 'package:hesabu/core/sample_data.dart';
import 'package:hesabu/ui/formatters.dart';
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
    final request = AiRequest(
      providerName: 'test provider',
      purpose: 'test',
      approvedSummary: 'fabricated',
      sentFields: const ['fabricated summary'],
    );
    expect(ai.isAvailable, isFalse);
    await expectLater(
      ai.explain(request, consent: AiConsent.approve(request)),
      throwsStateError,
    );
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
    await tester.pumpWidget(HesabuApp(controller: controller));
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'shop@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'demo-pass-123');
    await tester.ensureVisible(find.text('Create demo profile'));
    await tester.tap(find.text('Create demo profile'));
    await tester.pumpAndSettle();
    expect(controller.page, AppPage.dashboard);
    final workspace = controller.workspaces.createWorkspace('Demo workspace');
    controller.workspaces.createSession(workspace.id, 'Demo session');
    controller.refresh();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load sample data'), warnIfMissed: false);
    // The control sits below the summary on the default 600px test viewport.
    if (controller.store.sampleCount == 0) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load sample data'));
    }
    await tester.pumpAndSettle();
    expect(controller.store.sampleCount, 12);
    controller.navigate(AppPage.tools);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Customer performance').last, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer performance'));
    await tester.pumpAndSettle();
    expect(find.text('Upgrade to HESABU Premium'), findsOneWidget);
    await tester.tap(find.text('Not now'));
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

  testWidgets('dashboard cards adapt to a narrow phone and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController(MemoryStore());
    controller.enterDemo('phone@example.test', create: true);
    final workspace = controller.workspaces.createWorkspace('Phone workspace');
    controller.workspaces.createSession(workspace.id, 'Phone session');
    controller.refresh();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: HesabuApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    controller.navigate(AppPage.tools);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Export reports').last, 250, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Customer performance')).dy,
      greaterThan(tester.getTopLeft(find.text('Financial statements')).dy),
    );
    expect(find.text('Expense analyser'), findsOneWidget);
  });
}
