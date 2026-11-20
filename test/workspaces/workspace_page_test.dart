import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/app.dart';
import 'package:hesabu/app_controller.dart';

import '../support/memory_store.dart';

void main() {
  testWidgets('a workspace and session can be created through the local UI', (
    tester,
  ) async {
    final controller = AppController(MemoryStore())
      ..enterDemo('shop@example.test', create: true)
      ..navigate(AppPage.workspaces);
    await tester.pumpWidget(HesabuApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create workspace'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Fabricated Bakery');
    await tester.tap(find.text('Save locally'));
    await tester.pumpAndSettle();

    expect(find.text('Fabricated Bakery'), findsOneWidget);
    await tester.tap(find.text('Create session'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'October review');
    await tester.tap(find.text('Save locally'));
    await tester.pumpAndSettle();

    // Creating a session opens the sandbox's tool catalogue immediately.
    expect(controller.page, AppPage.tools);
    controller.navigate(AppPage.workspaces);
    await tester.pumpAndSettle();
    expect(find.text('October review'), findsOneWidget);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.text('completed'), findsOneWidget);
  });
}
