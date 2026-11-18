import 'package:hesabu/app.dart';
import 'package:hesabu/app_controller.dart';
import 'package:hesabu/data/customer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_store.dart';

void main() {
  testWidgets('customer report sections render on desktop and narrow screens', (
    tester,
  ) async {
    final store = MemoryStore();
    CustomerRepository(store).addSamples(DateTime.now().toUtc());
    final controller = AppController(store)
      ..enterDemo('demo@example.test', create: true)
      ..setDemoPaid(true)
      ..navigate(AppPage.customers);
    await tester.pumpWidget(HesabuApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Customer Performance and Drop-off'), findsOneWidget);
    for (final section in [
      'Ranked clients · total spent',
      'At Risk / Recently Dropped',
      'Monthly retention / churn',
      'Merge duplicate identities',
    ]) {
      await tester.scrollUntilVisible(
        find.text(section),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Ranked clients · total spent'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('customer tool enforces demo paid gate', (tester) async {
    final controller = AppController(MemoryStore())
      ..enterDemo('demo@example.test', create: true)
      ..navigate(AppPage.customers);
    await tester.pumpWidget(HesabuApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enable Preview paid plan'), findsOneWidget);
  });
}
