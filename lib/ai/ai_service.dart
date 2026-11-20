import 'dart:convert';

/// The exact, minimised payload a user may choose to share with a future AI
/// provider. It never reads the database or expands itself into a statement.
class AiRequest {
  AiRequest({
    required this.purpose,
    required this.providerName,
    required this.approvedSummary,
    required List<String> sentFields,
  }) : sentFields = List.unmodifiable(sentFields),
       id = base64Url.encode(
         utf8.encode(
           '$purpose\n$providerName\n$approvedSummary\n${sentFields.join('\n')}',
         ),
       );

  final String id;
  final String purpose;
  final String providerName;
  final String approvedSummary;
  final List<String> sentFields;

  String get disclosure =>
      '''Before anything leaves this device, HESABU will send only the following to $providerName:

${sentFields.map((field) => '• $field').join('\n')}

Purpose: $purpose

Preview of the exact summary: $approvedSummary

HESABU will not send your PDF/CSV file, full transactions, customer list, password, encrypted database, encryption key or device identifier unless a future consent screen explicitly lists it.''';
}

/// Created only after the user approves one [AiRequest]. A consent token cannot
/// be reused if the provider, purpose, fields or summary change.
class AiConsent {
  const AiConsent._(this.requestId, this.approvedAt);

  factory AiConsent.approve(AiRequest request) =>
      AiConsent._(request.id, DateTime.now().toUtc());

  final String requestId;
  final DateTime approvedAt;

  bool approves(AiRequest request) => requestId == request.id;
}

class AiResponse {
  const AiResponse(this.text);
  final String text;
}

/// Provider seam for the optional add-on. The base product supplies no provider,
/// network client, API key, endpoint or background upload implementation.
abstract interface class AiService {
  bool get isAvailable;

  Future<AiResponse> explain(AiRequest request, {required AiConsent consent});
}

/// Production default. It is deliberately unable to transmit anything.
class DisabledAiService implements AiService {
  const DisabledAiService();

  @override
  bool get isAvailable => false;

  @override
  Future<AiResponse> explain(AiRequest request, {required AiConsent consent}) =>
      Future.error(StateError('AI is disabled. No data was sent.'));
}

/// Mandatory boundary for a future provider adapter. It rejects a stale or
/// mismatched consent before the adapter receives the request.
class ConsentGuardedAiService implements AiService {
  const ConsentGuardedAiService(this._delegate);
  final AiService _delegate;

  @override
  bool get isAvailable => _delegate.isAvailable;

  @override
  Future<AiResponse> explain(AiRequest request, {required AiConsent consent}) {
    if (!consent.approves(request)) {
      return Future.error(
        StateError('Fresh consent is required for this exact AI request.'),
      );
    }
    return _delegate.explain(request, consent: consent);
  }
}
