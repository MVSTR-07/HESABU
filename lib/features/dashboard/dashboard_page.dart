import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app_controller.dart';
import '../../ui/shared.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) => ContentWidth(
    child: ListView(
      scrollCacheExtent: const ScrollCacheExtent.pixels(560),
      physics: const ClampingScrollPhysics(),
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
        if (controller.workspaces.activeSession() == null) ...[
          _SessionGate(controller: controller),
          const SizedBox(height: 28),
        ],
        if (controller.workspaces.activeSession() != null) ...[
          _DashboardAnalytics(controller: controller),
          const SizedBox(height: 28),
        ],
        const _OverviewInfo(),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class _OverviewInfo extends StatelessWidget {
  const _OverviewInfo();

  @override
  Widget build(BuildContext context) => GlassPanel(
    refraction: false,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inside HESABU', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Useful features, private analysis and occasional member rewards—no external ads.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 28,
            runSpacing: 18,
            children: [
              SizedBox(
                width: 270,
                child: _item(
                  context,
                  Icons.lock_outline,
                  'Private by design',
                  'Your business data stays encrypted on this device.',
                ),
              ),
              SizedBox(
                width: 270,
                child: _item(
                  context,
                  Icons.insights_outlined,
                  'Plain local analysis',
                  'Clear summaries and trends without sending raw records away.',
                ),
              ),
              SizedBox(
                width: 270,
                child: _item(
                  context,
                  Icons.card_giftcard_outlined,
                  'Member rewards',
                  'Invite another business when a reward event is active and earn credit toward a future subscription or tool.',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String body,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.secondary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
      ),
    ],
  );
}

class _SessionGate extends StatelessWidget {
  const _SessionGate({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Create a workspace and session first',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your analysis tools appear only inside a private session. This keeps each client job separated, reviewable and easy to clear when finished.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => controller.navigate(AppPage.workspaces),
            icon: const Icon(Icons.business_center_outlined),
            label: const Text('Open workspaces'),
          ),
        ],
      ),
    ),
  );
}

class _DashboardAnalytics extends StatelessWidget {
  const _DashboardAnalytics({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 680;
      final statements = controller.store.listMpesaStatements();
      final payments = controller.store.sampleCount;
      final cards = [
        _MetricCard(
          title: 'Total income',
          value: payments == 0 ? 'KES 0' : 'KES ${payments * 1250}',
          caption: 'From supported statement imports',
          icon: Icons.south_west,
        ),
        _MetricCard(
          title: 'Total expenses',
          value: statements.isEmpty
              ? 'KES 0'
              : 'KES ${statements.length * 480}',
          caption: 'For the selected period',
          icon: Icons.north_east,
        ),
        _MetricCard(
          title: 'Operating surplus',
          value: payments == 0 ? 'KES 0' : 'KES ${payments * 770}',
          caption: 'Income less recorded expenses',
          icon: Icons.trending_up,
          accent: true,
        ),
      ];
      final metricWidth = compact
          ? constraints.maxWidth
          : (constraints.maxWidth - 28) / 3;
      final metricGrid = Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final card in cards)
            SizedBox(width: metricWidth, height: 132, child: card),
        ],
      );
      final charts = compact
          ? Column(
              children: const [
                _ChartPanel(title: 'Cash in / out', kind: _ChartKind.donut),
                SizedBox(height: 14),
                _ChartPanel(
                  title: 'Monthly income vs expenses',
                  kind: _ChartKind.bars,
                ),
                SizedBox(height: 14),
                _ChartPanel(
                  title: 'Revenue / balance trend',
                  kind: _ChartKind.line,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  child: _ChartPanel(
                    title: 'Cash in / out',
                    kind: _ChartKind.donut,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _ChartPanel(
                    title: 'Monthly income vs expenses',
                    kind: _ChartKind.bars,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _ChartPanel(
                    title: 'Revenue / balance trend',
                    kind: _ChartKind.line,
                  ),
                ),
              ],
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [metricGrid, const SizedBox(height: 14), charts],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    this.accent = false,
  });
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) => GlassPanel(
    radius: 20,
    fillOpacity: .62,
    refractionStrength: 1.6,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: accent
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

enum _ChartKind { donut, bars, line }

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({required this.title, required this.kind});
  final String title;
  final _ChartKind kind;

  @override
  Widget build(BuildContext context) => GlassPanel(
    radius: 20,
    fillOpacity: .5,
    refractionStrength: 1.4,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            child: SizedBox(
              height: 108,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(kind, Theme.of(context).colorScheme),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            kind == _ChartKind.donut
                ? 'Money in   Money out'
                : 'Income   Expenses',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter(this.kind, this.scheme);
  final _ChartKind kind;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final primary = Paint()
      ..color = scheme.primary
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final secondary = Paint()
      ..color = scheme.secondary
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (kind == _ChartKind.donut) {
      final center = Offset(size.width * .28, size.height / 2);
      final radius = size.height * .32;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -.9,
        3.8,
        false,
        primary,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        2.9,
        2.1,
        false,
        secondary,
      );
      return;
    }
    if (kind == _ChartKind.bars) {
      final values = [0.45, .7, .55, .82, .64, .9];
      for (var i = 0; i < values.length; i++) {
        final x = 12 + i * (size.width - 30) / values.length;
        final h = size.height * values[i];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - h, 12, h),
            const Radius.circular(6),
          ),
          Paint()..color = i.isEven ? primary.color : secondary.color,
        );
      }
      return;
    }
    final path = Path()..moveTo(4, size.height * .72);
    for (var i = 1; i < 7; i++) {
      path.lineTo(i * size.width / 6, size.height * (.72 - i * .055));
    }
    canvas.drawPath(path, primary);
    final second = Path()..moveTo(4, size.height * .84);
    for (var i = 1; i < 7; i++) {
      second.lineTo(i * size.width / 6, size.height * (.84 - i * .035));
    }
    canvas.drawPath(second, secondary);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.scheme != scheme;
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => GlassPanel(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 680;
        final activeSession = controller.workspaces.activeSession();
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
              if (controller.workspaces.activeWorkspace() != null) ...[
                Text(
                  'Active workspace: ${controller.workspaces.activeWorkspace()!.name}',
                ),
                if (activeSession != null)
                  Text('Active session: ${activeSession.name}'),
                const SizedBox(height: 10),
              ],
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
                  OutlinedButton.icon(
                    onPressed: () => controller.navigate(AppPage.workspaces),
                    icon: const Icon(Icons.business_center_outlined, size: 18),
                    label: Text(
                      controller.workspaces.activeWorkspace() == null
                          ? 'Create workspace'
                          : 'Switch workspace',
                    ),
                  ),
                  if (activeSession != null)
                    FilledButton.tonalIcon(
                      onPressed: () => controller.navigate(AppPage.tools),
                      icon: const Icon(Icons.play_arrow_outlined, size: 18),
                      label: const Text('Resume session'),
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
