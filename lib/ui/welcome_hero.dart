import 'package:flutter/material.dart';

import 'glass.dart';

class WelcomeHero extends StatelessWidget {
  const WelcomeHero({required this.actions, super.key});
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => GlassPanel(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final short = MediaQuery.sizeOf(context).height < 720;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Chip(
              avatar: Icon(Icons.flag_outlined, size: 16),
              label: Text('BUILT FOR BUSINESS IN KENYA'),
            ),
            SizedBox(
              height: wide
                  ? 24
                  : short
                  ? 4
                  : 12,
            ),
            Text(
              'Your business,\nin clearer focus.',
              style: TextStyle(
                fontSize: wide
                    ? 48
                    : short
                    ? 30
                    : 34,
                height: 1.08,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.7,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(
              height: wide
                  ? 20
                  : short
                  ? 5
                  : 12,
            ),
            Text(
              'Understand your money. Know your customers.\nMove forward with confidence.',
              style: TextStyle(
                fontSize: short ? 14 : 16,
                height: short ? 1.3 : 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(
              height: wide
                  ? 28
                  : short
                  ? 4
                  : 12,
            ),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
            if (!wide && !short)
              const SizedBox(
                height: 140,
                width: double.infinity,
                child: GlassSculpture(),
              ),
          ],
        );
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(
              wide
                  ? 36
                  : short
                  ? 10
                  : 22,
            ),
            child: wide
                ? Row(
                    children: [
                      Expanded(child: content),
                      const SizedBox(width: 16),
                      const SizedBox(
                        width: 230,
                        height: 280,
                        child: GlassSculpture(),
                      ),
                    ],
                  )
                : content,
          ),
        );
      },
    ),
  );
}
