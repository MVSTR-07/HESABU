import 'package:flutter/material.dart';

class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.lock_outline, size: 16),
      SizedBox(width: 8),
      Expanded(
        child: Text('On your device. Encrypted. No business data uploaded.'),
      ),
    ],
  );
}

class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: child,
    ),
  );
}
