import 'package:flutter/material.dart';

import '../../core/sample_data.dart' show sampleMpesaPassword;

class StatementPasswordDialog extends StatefulWidget {
  const StatementPasswordDialog({this.fabricated = false, super.key});
  final bool fabricated;
  @override
  State<StatementPasswordDialog> createState() =>
      _StatementPasswordDialogState();
}

class _StatementPasswordDialogState extends State<StatementPasswordDialog> {
  final _password = TextEditingController();
  void _submit() {
    final value = _password.text;
    _password.clear();
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Open protected PDF'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your password is used in memory to open this file. It is never saved or logged. Leave blank if the PDF has no password.',
          ),
          if (widget.fabricated)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Fabricated sample password: $sampleMpesaPassword'),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(labelText: 'PDF password'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          _password.clear();
          Navigator.pop(context);
        },
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Open PDF')),
    ],
  );
}
