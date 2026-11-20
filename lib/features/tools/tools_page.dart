import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/shared.dart';
import 'tool_registry.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({required this.controller, super.key});
  final AppController controller;

  void _open(BuildContext context, ToolDefinition tool) {
    if (controller.workspaces.activeSession() == null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create a private session first'),
          content: const Text(
            'Create a workspace and analysis session before importing or analysing data. This keeps every client job separated locally.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                controller.navigate(AppPage.workspaces);
              },
              child: const Text('Create workspace'),
            ),
          ],
        ),
      );
      return;
    }
    if (tool.paid && !controller.paid) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Upgrade to HESABU Premium'),
          content: const Text(
            'This tool is part of Premium. Enable the local paid preview in Settings for this demo; no payment is collected.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                controller.navigate(AppPage.settings);
              },
              child: const Text('View upgrade options'),
            ),
          ],
        ),
      );
      return;
    }
    if (tool.page != null) controller.navigate(tool.page!);
  }

  @override
  Widget build(BuildContext context) => ContentWidth(
    child: ListView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.paddingOf(context).bottom + 120),
      children: [
        Text('Tools', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Choose an analysis tool. Your work opens inside the active private session.'),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 560 ? 2 : 1;
            const gap = 16.0;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tools.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: constraints.maxWidth < 400 ? 188 : 180,
              ),
              itemBuilder: (context, index) {
                final tool = tools[index];
                return GlassPanel(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(context, tool),
                    child: Padding(
                      padding: EdgeInsets.all(constraints.maxWidth < 400 ? 14 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: .11),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .16)),
                              ),
                              child: Icon(tool.icon, color: Theme.of(context).colorScheme.primary, size: 22),
                            ),
                            const Spacer(),
                            Icon(tool.page != null ? Icons.north_east : Icons.more_horiz, size: 18),
                          ]),
                          const SizedBox(height: 10),
                          Text(tool.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Expanded(child: Text(tool.description, maxLines: 2, overflow: TextOverflow.ellipsis)),
                          Wrap(spacing: 8, children: [
                            const Text('Open tool'),
                            if (tool.paid) Text(controller.paid ? 'Premium preview' : 'Premium'),
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    ),
  );
}
