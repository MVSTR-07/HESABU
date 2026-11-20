import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/ai/ai_service.dart';
import 'package:hesabu/app.dart';
import 'package:hesabu/app_controller.dart';

import '../support/memory_store.dart';

void main() {
  AiRequest request({String summary = 'Fabricated weekly total: KES 1,200'}) =>
      AiRequest(
        providerName: 'example provider',
        purpose: 'Explain a fabricated total',
        approvedSummary: summary,
        sentFields: const ['Fabricated aggregate summary'],
      );

  test('consent cannot be reused after the exact payload changes', () {
    final original = request();
    final changed = request(summary: 'Fabricated weekly total: KES 9,999');

    expect(AiConsent.approve(original).approves(changed), isFalse);
  });

  test(
    'guard rejects an unapproved payload before a provider sees it',
    () async {
      final provider = _RecordingProvider();
      final gateway = ConsentGuardedAiService(provider);
      final approved = request();
      final changed = request(summary: 'A different fabricated summary');

      await expectLater(
        gateway.explain(changed, consent: AiConsent.approve(approved)),
        throwsStateError,
      );
      expect(provider.requests, isEmpty);
    },
  );

  test('guard forwards only the exact freshly approved request', () async {
    final provider = _RecordingProvider();
    final gateway = ConsentGuardedAiService(provider);
    final approved = request();

    final response = await gateway.explain(
      approved,
      consent: AiConsent.approve(approved),
    );

    expect(response.text, 'fabricated response');
    expect(provider.requests, [approved]);
  });

  testWidgets(
    'AI preview discloses fabricated data and supports local cancel',
    (tester) async {
      final controller = AppController(MemoryStore())
        ..enterDemo('shop@example.test', create: true)
        ..navigate(AppPage.settings);
      await tester.pumpWidget(HesabuApp(controller: controller));
      await tester.pumpAndSettle();

      final preview = find.ancestor(
        of: find.text('Preview consent screen'),
        matching: find.byType(OutlinedButton),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      await tester.tap(preview);
      await tester.pumpAndSettle();

      expect(find.text('Review AI data sharing'), findsOneWidget);
      expect(find.textContaining('Fabricated preview only'), findsOneWidget);
      expect(find.text('Keep data on this device'), findsOneWidget);
      await tester.tap(find.text('Keep data on this device'));
      await tester.pumpAndSettle();
      expect(controller.aiEnabled, isFalse);
    },
  );
}

class _RecordingProvider implements AiService {
  final List<AiRequest> requests = [];

  @override
  bool get isAvailable => true;

  @override
  Future<AiResponse> explain(
    AiRequest request, {
    required AiConsent consent,
  }) async {
    requests.add(request);
    return const AiResponse('fabricated response');
  }
}
