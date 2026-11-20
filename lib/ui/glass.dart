import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared Android/Windows glass; grouped filters avoid a blur pass per card.
class GlassPanel extends StatefulWidget {
  static Future<ui.FragmentProgram>? _refractionProgram;

  const GlassPanel({
    required this.child,
    this.color,
    this.clipBehavior = Clip.antiAlias,
    this.radius = 24,
    this.fillOpacity,
    this.refraction = true,
    this.refractionStrength = 2.2,
    this.grouped = true,
    super.key,
  });
  final Widget child;
  final Color? color;
  final Clip clipBehavior;
  final double radius;
  final double? fillOpacity;
  final bool refraction;
  final double refractionStrength;
  final bool grouped;

  @override
  State<GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<GlassPanel> {
  ui.FragmentShader? _shader;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill =
        widget.color ?? (dark ? const Color(0xff142846) : Colors.white);
    final supportsRefraction =
        widget.refraction && ui.ImageFilter.isShaderFilterSupported;
    final programFuture = supportsRefraction
        ? GlassPanel._refractionProgram ??= ui.FragmentProgram.fromAsset(
            'shaders/glass_refraction.frag',
          )
        : null;
    return LayoutBuilder(
      builder: (context, bounds) => FutureBuilder<ui.FragmentProgram>(
        future: programFuture,
        builder: (context, snapshot) {
        ui.ImageFilter? filter;
        if (snapshot.hasData && ui.ImageFilter.isShaderFilterSupported) {
          final shader = _shader ??= snapshot.data!.fragmentShader();
          // The shader works in local panel coordinates. Supplying the actual
          // panel size is essential: without it, the default zero size causes
          // invalid UVs and stretched pixels across the backdrop.
          final width = bounds.maxWidth.isFinite && bounds.maxWidth > 0
              ? bounds.maxWidth
              : 1.0;
          final height = bounds.maxHeight.isFinite && bounds.maxHeight > 0
              ? bounds.maxHeight
              : 1.0;
          shader.setFloat(0, width);
          shader.setFloat(1, height);
          // Keep the optical offset below a few physical pixels even when a
          // caller uses a stronger legacy value. Large offsets create ghosted
          // text at panel edges instead of a glass highlight.
          shader.setFloat(2, widget.refractionStrength.clamp(0.0, 0.24));
          // Keep refraction to one texture lookup and one GPU pass. Bilinear
          // sampling provides slight softness without a second blur pass.
          filter = ui.ImageFilter.shader(shader);
        } else {
          // Avoid expensive backdrop blur on devices without shader support.
          // The translucent surface and highlights remain visible.
          filter = null;
        }
        final glassContent = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                fill.withValues(
                  alpha: widget.fillOpacity ?? (dark ? 0.74 : .88),
                ),
                fill.withValues(
                  alpha: widget.fillOpacity == null
                      ? (dark ? 0.45 : .72)
                      : widget.fillOpacity! * .72,
                ),
              ],
            ),
            border: Border.all(
              color: (dark ? Colors.white : const Color(0xff688dc1)).withValues(
                alpha: dark ? 0.13 : .16,
              ),
            ),
          ),
          child: Material(type: MaterialType.transparency, child: widget.child),
        );
        final Widget backdropFilter;
        if (filter == null) {
          backdropFilter = glassContent;
        } else if (widget.grouped) {
          backdropFilter = BackdropFilter.grouped(
            filter: filter,
            child: glassContent,
          );
        } else {
          backdropFilter = BackdropFilter(filter: filter, child: glassContent);
        }
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.15 : .035),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            clipBehavior: widget.clipBehavior,
            child: backdropFilter,
          ),
        );
        },
      ),
    );
  }
}

class HesabuBackdrop extends StatelessWidget {
  const HesabuBackdrop({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BackdropGroup(
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _Atmosphere(dark)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Atmosphere extends CustomPainter {
  const _Atmosphere(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xff0a1934), Color(0xff060e20), Color(0xff09162b)]
              : const [Color(0xffeef5ff), Color(0xffe6edfb), Color(0xfff4f8ff)],
        ).createShader(rect),
    );
    void glow(Offset point, double radius, Color color) {
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, Colors.transparent])
              .createShader(Rect.fromCircle(center: point, radius: radius)),
      );
    }

    glow(
      Offset(size.width * .9, size.height * .12),
      size.width * .55,
      Color(dark ? 0xff164996 : 0xffc1d8ff).withValues(alpha: dark ? 0.36 : .7),
    );
    glow(
      Offset(size.width * .03, size.height * .58),
      size.width * .38,
      Color(dark ? 0xff137181 : 0xffbce5ef).withValues(alpha: .16),
    );
    glow(
      Offset(size.width * .85, size.height * 1.04),
      size.width * .65,
      Color(dark ? 0xff343e91 : 0xffd8d5fa).withValues(alpha: .18),
    );
    _drawAccountingMotifs(canvas, size, dark);
    final paint = Paint()
      ..color = (dark ? Colors.white : const Color(0xff32558e)).withValues(
        alpha: .022,
      );
    for (var x = 16.0; x < size.width; x += 38) {
      for (var y = 20.0; y < size.height; y += 38) {
        canvas.drawCircle(Offset(x, y), .55, paint);
      }
    }
  }

  void _drawAccountingMotifs(Canvas canvas, Size size, bool dark) {
    final opacity = dark ? .13 : .18;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = (dark ? const Color(0xff9bdcff) : const Color(0xff4775ba))
          .withValues(alpha: opacity);
    final fill = Paint()
      ..color = (dark ? const Color(0xff4c83d5) : const Color(0xff7aa7e8))
          .withValues(alpha: opacity * .48);

    // A faint ledger grid near the upper left, with a frosted total cell.
    final grid = Rect.fromLTWH(size.width * .045, size.height * .13, 106, 66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(grid, const Radius.circular(12)),
      stroke,
    );
    for (var row = 1; row < 4; row++) {
      final y = grid.top + grid.height * row / 4;
      canvas.drawLine(
        Offset(grid.left + 8, y),
        Offset(grid.right - 8, y),
        stroke,
      );
    }
    canvas.drawLine(
      Offset(grid.left + 38, grid.top + 8),
      Offset(grid.left + 38, grid.bottom - 8),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(grid.left + 49, grid.top + 7, 44, 8),
        const Radius.circular(4),
      ),
      fill,
    );

    // Translucent bars and a simple rising trend chart on the right edge.
    final chartLeft = size.width - 116;
    final chartBottom = size.height * .56;
    final bars = [24.0, 43.0, 32.0, 57.0];
    for (var i = 0; i < bars.length; i++) {
      final x = chartLeft + i * 20;
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartBottom - bars[i], 12, bars[i]),
        const Radius.circular(6),
      );
      canvas.drawRRect(bar, fill);
      canvas.drawRRect(bar, stroke);
    }
    final trend = Path()
      ..moveTo(chartLeft - 2, chartBottom - 19)
      ..lineTo(chartLeft + 19, chartBottom - 34)
      ..lineTo(chartLeft + 39, chartBottom - 28)
      ..lineTo(chartLeft + 58, chartBottom - 50)
      ..lineTo(chartLeft + 80, chartBottom - 57);
    canvas.drawPath(trend, stroke..strokeWidth = 1.8);

    // Glass spheres sit in the negative space, away from content panels.
    void sphere(Offset center, double radius, Color color) {
      final bounds = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.4, -.55),
            colors: [
              color.withValues(alpha: opacity * .75),
              Colors.transparent,
            ],
          ).createShader(bounds),
      );
      canvas.drawCircle(center, radius, stroke);
      canvas.drawCircle(
        center.translate(-radius * .28, -radius * .32),
        radius * .08,
        Paint()..color = Colors.white.withValues(alpha: opacity * .8),
      );
    }

    sphere(
      Offset(size.width * .88, size.height * .78),
      30,
      const Color(0xff74dfff),
    );
    sphere(
      Offset(size.width * .10, size.height * .85),
      18,
      const Color(0xff90b8ff),
    );
  }

  @override
  bool shouldRepaint(covariant _Atmosphere old) => old.dark != dark;
}

class HesabuBrand extends StatelessWidget {
  const HesabuBrand({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 32 : 38,
        height: compact ? 32 : 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff81c5ff), Color(0xff3869e1)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff3b7bfc).withValues(alpha: .2),
              blurRadius: 16,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'H',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        'HESABU',
        // The wordmark is a logo, not body copy. Keeping it fixed prevents the
        // app bar from crowding out navigation at large accessibility scales.
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: compact ? 17 : 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 3,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}

/// Original decorative geometry, never a representation of financial data.
class GlassSculpture extends StatelessWidget {
  const GlassSculpture({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _Sculpture(Theme.of(context).brightness == Brightness.dark),
      ),
    ),
  );
}

class _Sculpture extends CustomPainter {
  const _Sculpture(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = (size.width < size.height ? size.width : size.height) / 300;
    canvas.scale(scale);
    canvas.rotate(-.1);
    canvas.drawOval(
      const Rect.fromLTWH(-95, 80, 220, 28),
      Paint()
        ..color = const Color(0xff368dff).withValues(alpha: .2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    void panel(Rect rect) {
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(17));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xffb5e8ff).withValues(alpha: .3),
              const Color(0xff4279ea).withValues(alpha: .12),
              const Color(0xff8ec8ff).withValues(alpha: .22),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffd6f4ff), Color(0xff4d82e7), Color(0xffa3dbff)],
          ).createShader(rect),
      );
      canvas.drawLine(
        Offset(rect.left + 7, rect.top + 22),
        Offset(rect.left + 7, rect.bottom - 22),
        Paint()
          ..color = Colors.white.withValues(alpha: .26)
          ..strokeWidth = 1,
      );
    }

    panel(const Rect.fromLTWH(-104, -76, 64, 175));
    panel(const Rect.fromLTWH(30, -112, 64, 175));
    panel(const Rect.fromLTWH(-50, -25, 95, 48));
    final p = Path()
      ..moveTo(-89, 65)
      ..lineTo(-52, 25)
      ..lineTo(-19, 39)
      ..lineTo(15, -5)
      ..lineTo(61, -47);
    canvas.drawPath(
      p,
      Paint()
        ..color = const Color(0xffa8e9ff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in [
      const Offset(-52, 25),
      const Offset(15, -5),
      const Offset(61, -47),
    ]) {
      canvas.drawCircle(point, 4, Paint()..color = Colors.white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Sculpture old) => old.dark != dark;
}
