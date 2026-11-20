import 'package:flutter/material.dart';

import 'ai_service.dart';

/// Per-request disclosure. Calling code must only invoke a provider after this
/// dialog returns an [AiConsent]; dismissing it means keep all data local.
class AiConsentDialog extends StatelessWidget {
  const AiConsentDialog({required this.request, super.key});
  final AiRequest request;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review AI data sharing'),
    content: SingleChildScrollView(child: Text(request.disclosure)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Keep data on this device'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, AiConsent.approve(request)),
        child: const Text('I understand — send listed data'),
      ),
    ],
  );
}
