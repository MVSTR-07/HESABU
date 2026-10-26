import 'package:flutter/material.dart';
import '../../app_controller.dart';
import '../../ui/shared.dart';
import '../tools/tool_registry.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.controller, super.key});
  final AppController controller;

  void _open(BuildContext context, ToolDefinition tool) {
    final locked = tool.paid && !controller.paid;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locked ? 'Paid tool · demo gate' : tool.title),
        content: Text(
          locked
              ? 'This card previews paid access. You can switch to the paid demo in Settings; no payment is collected. The tool itself arrives in Stage ${tool.stage}.'
              : 'This tool will be built in Stage ${tool.stage}. Stage 1 is the workspace and encrypted storage foundation. No analysis is available yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ContentWidth(
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'A clearer view of your business',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('Your tools, together in one private workspace.'),
        const SizedBox(height: 24),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PrivacyNote(),
                const SizedBox(height: 16),
                Text(
                  'Ready when you are',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.store.sampleCount} fabricated demo payments stored locally. Statement import begins in Stage 2.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: controller.seedSamples,
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Load sample data'),
                    ),
                    Chip(
                      label: Text(
                        controller.paid
                            ? 'Paid demo · no billing'
                            : 'Free demo',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Explore your tools',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Preview cards · Tools unlock as each stage is built. Pricing is illustrative.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: tools
                  .map(
                    (tool) => SizedBox(
                      width: width,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(context, tool),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  tool.icon,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 30,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  tool.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(tool.description),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text('Stage ${tool.stage}'),
                                    if (tool.paid)
                                      Text(
                                        controller.paid
                                            ? 'Paid demo'
                                            : 'Paid preview',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
