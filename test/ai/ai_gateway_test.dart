import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/ai/ai_service.dart';

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
