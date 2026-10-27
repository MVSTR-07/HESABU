import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/shared.dart';
import '../tools/tool_registry.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.controller, super.key});
  final AppController controller;

  void _open(BuildContext context, ToolDefinition tool) {
    final locked = tool.paid && !controller.paid;
    if (!locked && tool.page != null) {
      controller.navigate(tool.page!);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locked ? 'Paid tool · demo gate' : tool.title),
        content: Text(
          locked
              ? tool.page != null
                    ? 'This tool is available in the paid demo. Enable Preview paid plan in Settings; no payment is collected.'
                    : 'This card previews paid access. You can switch to the paid demo in Settings; no payment is collected. The tool itself arrives in Stage ${tool.stage}.'
              : 'This tool will be built in Stage ${tool.stage}. M-Pesa analysis is available from the dashboard; this tool is still a preview.',
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
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.paddingOf(context).bottom + 150,
      ),
      children: [
        Text(
          'A clearer view of your business',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('Your tools, together in one private workspace.'),
        const SizedBox(height: 24),
        _DashboardSummary(controller: controller),
        const SizedBox(height: 28),
        Text(
          'Explore your tools',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'M-Pesa and Customer performance are ready. More tools are coming soon.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            const gap = 16.0;
            final cardWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: constraints.maxWidth < 400 ? 188 : 180,
              ),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                return SizedBox(
                  width: cardWidth,
                  child: GlassPanel(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(context, tool),
                      child: Padding(
                        padding: EdgeInsets.all(
                          constraints.maxWidth < 400 ? 14 : 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: .11),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: .16),
                                    ),
                                  ),
                                  child: Icon(
                                    tool.icon,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    size: 22,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  tool.page != null
                                      ? Icons.north_east
                                      : Icons.more_horiz,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: .65),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tool.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  tool.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  tool.page != null
                                      ? 'Open tool'
                                      : 'Coming soon',
                                ),
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
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => GlassPanel(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 680;
        final content = Padding(
          padding: EdgeInsets.all(wide ? 30 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR PRIVATE WORKSPACE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'A little clarity.\nA lot of possibility.',
                style: TextStyle(
                  fontSize: wide ? 30 : 25,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.8,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const PrivacyNote(),
              const SizedBox(height: 18),
              Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  _stat(
                    context,
                    '${controller.store.listMpesaStatements().length}',
                    'SAVED STATEMENTS',
                  ),
                  _stat(
                    context,
                    '${controller.store.sampleCount}',
                    'DEMO PAYMENTS',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.seedSamples,
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Load sample data'),
                  ),
                  Chip(
                    label: Text(
                      controller.paid ? 'Paid demo · no billing' : 'Free demo',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        return wide
            ? Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(
                    width: 260,
                    height: 265,
                    child: GlassSculpture(),
                  ),
                  const SizedBox(width: 20),
                ],
              )
            : content;
      },
    ),
  );
  Widget _stat(BuildContext context, String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 1.3)),
    ],
  );
}
