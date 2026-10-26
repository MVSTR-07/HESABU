/// No provider, HTTP client, API key or consent-to-send implementation in Stage 1.
/// Stage 6 must add explicit per-request disclosure/consent before any provider.
abstract interface class AiService {
  bool get isAvailable;
  Future<String> explain(String approvedSummary);
}

class DisabledAiService implements AiService {
  const DisabledAiService();
  @override
  bool get isAvailable => false;
  @override
  Future<String> explain(String approvedSummary) =>
      Future.error(StateError('AI is disabled. No data was sent.'));
}
