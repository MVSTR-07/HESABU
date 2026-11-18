import 'package:hesabu/app.dart';
import 'package:hesabu/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_store.dart';

void main() {
  testWidgets('Stage 5 screens render on a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryStore();
    final controller = AppController(store)
      ..enterDemo('test@example.test', create: true)
      ..setDemoPaid(true);

    for (final page in [
      AppPage.profit,
      AppPage.debts,
      AppPage.imports,
      AppPage.reports,
    ]) {
      controller.navigate(page);
      await tester.pumpWidget(HesabuApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$page initial layout');
      expect(find.byTooltip('Back to dashboard'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to dashboard'));
      await tester.pumpAndSettle();
      expect(controller.page, AppPage.dashboard);
    }
  });

  testWidgets('Stage 4 screens render sample analysis on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryStore();
    final controller = AppController(store)
      ..enterDemo('test@example.test', create: true);

    for (final page in [AppPage.sales, AppPage.expenses, AppPage.stock]) {
      controller.navigate(page);
      await tester.pumpWidget(HesabuApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$page initial layout');

      final action = switch (page) {
        AppPage.sales => 'Use fabricated sales',
        AppPage.expenses => 'Use fabricated expenses',
        AppPage.stock => 'Use fabricated stock',
        _ => throw StateError('Unexpected Stage 4 page'),
      };
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$page sample layout');

      final title = switch (page) {
        AppPage.sales => 'Sales records',
        AppPage.expenses => 'Expense records',
        AppPage.stock => 'Inventory records',
        _ => throw StateError('Unexpected Stage 4 page'),
      };
      await tester.scrollUntilVisible(
        find.text(title),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$page records layout');
    }
  });
}
