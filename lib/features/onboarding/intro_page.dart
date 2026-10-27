import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/shared.dart';
import '../../ui/welcome_hero.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ContentWidth(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 16),
      children: [
        const SizedBox(height: 12),
        WelcomeHero(
          actions: [
            FilledButton.icon(
              onPressed: () => controller.navigate(AppPage.account),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Get started'),
            ),
            OutlinedButton(
              onPressed: () => controller.navigate(AppPage.settings),
              child: const Text('Settings'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GlassPanel(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A private workspace',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const PrivacyNote(),
                const SizedBox(height: 12),
                const Text(
                  'Analysis runs locally using ordinary code. AI is off and unavailable in this stage.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Demo account · Email only. No cloud account, subscription purchase or payment is connected.',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
