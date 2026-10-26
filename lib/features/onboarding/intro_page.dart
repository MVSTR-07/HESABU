import 'package:flutter/material.dart';
import '../../app_controller.dart';
import '../../ui/shared.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ContentWidth(
    child: ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('BUILT FOR BUSINESS IN KENYA'),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your business,\nin clearer focus.',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        Text(
          'Make sense of M-Pesa, customers, sales and stock.\nYour records stay right here on your device.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
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
        const SizedBox(height: 40),
        Card(
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
                  'Stage 1 preview · Account and subscription screens use local demo profiles. No real sign-up, payment or cloud service is connected.',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
