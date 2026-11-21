import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Branded loading animations (pure Flutter, no extra packages).
///
/// * [RoadLoader]  – "Turbo gauge": a speedometer that revs up with a glowing
///   needle, sparks and a live km/h read-out, plus rotating status messages.
///   For splash / full-screen loading.
/// * [WheelLoader] – spinning gear with an orbiting comet. For inline loading.
/// * [DotsLoader]  – speed dashes that stretch in a wave. For buttons.

const Color _kBrand = Color(0xFFFF5722);
const Color _kAmber = Color(0xFFFFB300);

// -----------------------------------------------------------------------------
// RoadLoader (turbo gauge)
// -----------------------------------------------------------------------------

class RoadLoader extends StatefulWidget {
  const RoadLoader({
    super.key,
    this.asset = 'assets/vehicles/motorcycle.png',
    this.color = const Color(0xFF1E293B),
    this.accent = _kBrand,
    this.width = 220,
    this.messages = const <String>[],
  });

  /// Small vehicle illustration shown inside the gauge.
  final String asset;

  /// Colour of the dial, ticks and text.
  final Color color;

  /// Glow / needle colour.
  final Color accent;
  final double width;

  /// Status lines shown one after another under the gauge.
  final List<String> messages;

  @override
  State<RoadLoader> createState() => _RoadLoaderState();
}

class _RoadLoaderState extends State<RoadLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  Timer? _msgTimer;
  int _msg = 0;

  @override
  void initState() {
    super.initState();
    if (widget.messages.length > 1) {
      _msgTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) setState(() => _msg = (_msg + 1) % widget.messages.length);
      });
    }
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  /// Engine "rev" curve: quick climb, short hold at the top, drop, repeat.
  static double _rev(double t) {
    if (t < 0.42) return Curves.easeOutCubic.transform(t / 0.42);
    if (t < 0.56) return 1 - 0.04 * math.sin((t - 0.42) / 0.14 * math.pi * 3);
    if (t < 0.80) {
      return 1 - 0.72 * Curves.easeInOut.transform((t - 0.56) / 0.24);
    }
    return 0.28 + 0.12 * math.sin((t - 0.80) / 0.20 * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * _GaugePainter.heightFactor;
    final r = w * _GaugePainter.radiusFactor;
    final cy = r * _GaugePainter.centerFactor;
    return Semantics(
      label: widget.messages.isEmpty ? 'Loading' : widget.messages[_msg],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: w,
            height: h,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final v = _rev(_c.value).clamp(0.0, 1.0);
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GaugePainter(
                          value: v,
                          t: _c.value,
                          color: widget.color,
                          accent: widget.accent,
                        ),
                      ),
                    ),
                    Positioned(
                      top: cy + r * 0.20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${(v * 120).round()}',
                            style: TextStyle(
                              color: widget.color,
                              fontSize: w * 0.11,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            'km/h',
                            style: TextStyle(
                              color: widget.color.withValues(alpha: 0.55),
                              fontSize: w * 0.048,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: cy - r * 0.62 - w * 0.065,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          -2 * math.sin(_c.value * math.pi * 8).abs() * v,
                        ),
                        child: child,
                      ),
                    ),
                  ],
                );
              },
              child: Image.asset(
                widget.asset,
                height: w * 0.13,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.two_wheeler_rounded,
                  size: w * 0.12,
                  color: widget.color,
                ),
              ),
            ),
          ),
          if (widget.messages.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 22,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  widget.messages[_msg],
                  key: ValueKey<int>(_msg),
                  style: TextStyle(
                    color: widget.color.withValues(alpha: 0.85),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.t,
    required this.color,
    required this.accent,
  });

  final double value; // 0..1 needle position
  final double t; // 0..1 animation clock
  final Color color;
  final Color accent;

  static const double _start = math.pi * 0.80; // ~144°
  static const double _sweep = math.pi * 1.40; // 252° dial

  /// Shared geometry (widget lays out the read-out with the same numbers).
  static const double radiusFactor = 0.40; // r = width * 0.40
  static const double centerFactor =
      1.14; // centre y = r * 1.14 (room for the glow)
  static const double heightFactor = 0.78; // height = width * 0.78

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * radiusFactor;
    final c = Offset(size.width / 2, r * centerFactor);
    final stroke = r * 0.11;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Track
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.10),
    );

    // Glow + gradient fill up to the needle
    final fillSweep = _sweep * value;
    if (fillSweep > 0.001) {
      final shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(_start - 0.05),
        colors: <Color>[_kAmber, accent, const Color(0xFFE11D48)],
        stops: <double>[
          0.0,
          _sweep / (2 * math.pi) * 0.55,
          _sweep / (2 * math.pi),
        ],
      ).createShader(rect);
      canvas.drawArc(
        rect,
        _start,
        fillSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.9
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.18 * value)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.9),
      );
      canvas.drawArc(
        rect,
        _start,
        fillSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }

    // Ticks
    const ticks = 25;
    for (var i = 0; i <= ticks; i++) {
      final f = i / ticks;
      final a = _start + _sweep * f;
      final major = i % 5 == 0;
      final lit = f <= value;
      final inner = r - stroke * (major ? 1.9 : 1.45);
      final outer = r - stroke * 0.85;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * inner,
        c + Offset(math.cos(a), math.sin(a)) * outer,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = major ? r * 0.025 : r * 0.014
          ..color = lit ? accent : color.withValues(alpha: major ? 0.35 : 0.2),
      );
    }

    // Needle
    final na = _start + _sweep * value;
    final dir = Offset(math.cos(na), math.sin(na));
    final perp = Offset(-dir.dy, dir.dx);
    final tip = c + dir * (r - stroke * 1.2);
    final base = r * 0.055;
    final needle = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((c + perp * base).dx, (c + perp * base).dy)
      ..lineTo((c - dir * r * 0.12).dx, (c - dir * r * 0.12).dy)
      ..lineTo((c - perp * base).dx, (c - perp * base).dy)
      ..close();
    canvas.drawPath(
      needle,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );
    canvas.drawPath(needle, Paint()..color = accent);

    // Sparks off the needle tip near the red line
    if (value > 0.7) {
      final intensity = (value - 0.7) / 0.3;
      final rnd = math.Random(7);
      for (var i = 0; i < 7; i++) {
        final life = (t * 6 + i / 7) % 1.0;
        final spread = (rnd.nextDouble() - 0.5) * 1.6;
        final d = dir * math.cos(spread) + perp * math.sin(spread);
        final p = tip + d * (life * r * 0.35);
        canvas.drawCircle(
          p,
          r * 0.018 * (1 - life),
          Paint()
            ..color = Color.lerp(
              _kAmber,
              accent,
              life,
            )!.withValues(alpha: intensity * (1 - life)),
        );
      }
    }

    // Hub
    canvas.drawCircle(c, r * 0.085, Paint()..color = color);
    canvas.drawCircle(c, r * 0.04, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value ||
      old.t != t ||
      old.color != color ||
      old.accent != accent;
}

// -----------------------------------------------------------------------------
// WheelLoader (gear + comet)
// -----------------------------------------------------------------------------

class WheelLoader extends StatefulWidget {
  const WheelLoader({super.key, this.size = 44, this.color = _kBrand});

  final double size;
  final Color color;

  @override
  State<WheelLoader> createState() => _WheelLoaderState();
}

class _WheelLoaderState extends State<WheelLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) =>
              CustomPaint(painter: _GearPainter(_c.value, widget.color)),
        ),
      ),
    );
  }
}

class _GearPainter extends CustomPainter {
  _GearPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);

    // Orbiting comet (fading tail)
    final orbit = r * 0.9;
    final head = t * 2 * math.pi;
    const segments = 14;
    for (var i = 0; i < segments; i++) {
      final f = i / segments;
      final a = head - f * math.pi * 0.9;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * orbit,
        math.max(0.8, r * 0.11 * (1 - f)),
        Paint()..color = color.withValues(alpha: (1 - f) * 0.9),
      );
    }

    // Gear (rotates the other way)
    final gr = r * 0.52;
    const teeth = 8;
    final rot = -t * 2 * math.pi * 0.5;
    final gear = Path();
    for (var i = 0; i < teeth * 2; i++) {
      final a0 = rot + i * math.pi / teeth;
      final a1 = rot + (i + 1) * math.pi / teeth;
      final rad = i.isEven ? gr : gr * 0.78;
      final p0 = c + Offset(math.cos(a0), math.sin(a0)) * rad;
      final p1 = c + Offset(math.cos(a1), math.sin(a1)) * rad;
      if (i == 0) gear.moveTo(p0.dx, p0.dy);
      gear.lineTo(p0.dx, p0.dy);
      gear.lineTo(p1.dx, p1.dy);
    }
    gear.close();
    canvas.drawPath(gear, Paint()..color = const Color(0xFF1F2937));
    canvas.drawCircle(c, gr * 0.42, Paint()..color = color);
    canvas.drawCircle(c, gr * 0.18, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GearPainter old) => old.t != t || old.color != color;
}

// -----------------------------------------------------------------------------
// DotsLoader (speed dashes)
// -----------------------------------------------------------------------------

class DotsLoader extends StatefulWidget {
  const DotsLoader({super.key, this.color = Colors.white, this.size = 8});

  final Color color;
  final double size;

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: s * 5,
        height: s * 2.4,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(3, (i) {
              final p = (_c.value - i * 0.16) % 1.0;
              final wave = math.max(0.0, math.sin(p * math.pi * 2));
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: s * 0.15),
                child: Opacity(
                  opacity: 0.45 + 0.55 * wave,
                  child: Container(
                    width: s * (0.9 + 0.45 * wave),
                    height: s * 0.9,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(s),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
