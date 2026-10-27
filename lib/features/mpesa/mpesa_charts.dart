import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/mpesa/models.dart';
import '../../ui/formatters.dart';

class CashFlowChart extends StatelessWidget {
  const CashFlowChart({required this.periods, super.key});
  final List<CashPeriod> periods;
  @override
  Widget build(BuildContext context) {
    final visible = periods.length > 31
        ? periods.sublist(periods.length - 31)
        : periods;
    final maxValue = visible.fold<int>(
      0,
      (m, p) => math.max(m, math.max(p.moneyIn, p.moneyOut)),
    );
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Money in / out · up to the latest 31 periods · scale 0–${formatKes(maxValue)}',
        ),
        const SizedBox(height: 8),
        Semantics(
          label:
              'Cash movement chart. Exact values appear in the period table.',
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _CashPainter(visible, colors.primary, colors.secondary),
            ),
          ),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.square, size: 12, color: colors.primary),
                const Text(' Money in'),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.square, size: 12, color: colors.secondary),
                const Text(' Money out'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CashPainter extends CustomPainter {
  _CashPainter(this.periods, this.inColor, this.outColor);
  final List<CashPeriod> periods;
  final Color inColor, outColor;
  @override
  void paint(Canvas canvas, Size size) {
    if (periods.isEmpty) return;
    final maxValue = periods.fold<int>(
      1,
      (m, p) => math.max(m, math.max(p.moneyIn, p.moneyOut)),
    );
    final slot = size.width / periods.length;
    final bar = math.max(1.0, slot * .32);
    for (var i = 0; i < periods.length; i++) {
      final x = i * slot + slot * .1;
      for (final pair in [
        (periods[i].moneyIn, inColor, x),
        (periods[i].moneyOut, outColor, x + bar),
      ]) {
        final height = (size.height - 8) * pair.$1 / maxValue;
        canvas.drawRect(
          Rect.fromLTWH(pair.$3, size.height - height, bar, height),
          Paint()..color = pair.$2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CashPainter old) => true;
}

class BalanceTrendChart extends StatelessWidget {
  const BalanceTrendChart({required this.points, super.key});
  final List<BalancePoint> points;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('No observed balances were supplied.');
    }
    final minimum = points.map((v) => v.balance).reduce(math.min);
    final maximum = points.map((v) => v.balance).reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Observed balance · ${formatKes(minimum)} to ${formatKes(maximum)}',
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Observed balance trend. Missing balances are not inferred.',
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _BalancePainter(
                points,
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        Text(
          '${formatKenyaDate(points.first.at)} – ${formatKenyaDate(points.last.at)}',
        ),
      ],
    );
  }
}

class _BalancePainter extends CustomPainter {
  _BalancePainter(this.points, this.color);
  final List<BalancePoint> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final minimum = points.map((v) => v.balance).reduce(math.min);
    final maximum = points.map((v) => v.balance).reduce(math.max);
    final start = points.first.at.millisecondsSinceEpoch;
    final duration = points.last.at.millisecondsSinceEpoch - start;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = duration == 0
          ? size.width / 2
          : (size.width - 8) *
                    (points[i].at.millisecondsSinceEpoch - start) /
                    duration +
                4;
      final y = maximum == minimum
          ? size.height / 2
          : size.height -
                4 -
                (size.height - 8) *
                    (points[i].balance - minimum) /
                    (maximum - minimum);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      if (points.length == 1) {
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BalancePainter old) => true;
}
