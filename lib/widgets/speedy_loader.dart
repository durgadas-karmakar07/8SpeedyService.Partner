import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Branded loading animations (no extra packages).
///
/// * [RoadLoader]  – a vehicle riding on a moving road with speed lines and
///   rotating status messages. For splash / full-screen loading.
/// * [WheelLoader] – a spinning tyre with speed streaks. For inline loading.
/// * [DotsLoader]  – three bouncing dots. For loading buttons.

// -----------------------------------------------------------------------------
// RoadLoader
// -----------------------------------------------------------------------------

class RoadLoader extends StatefulWidget {
  const RoadLoader({
    super.key,
    this.asset = 'assets/vehicles/motorcycle.png',
    this.color = const Color(0xFF1E293B),
    this.width = 220,
    this.messages = const <String>[],
  });

  /// Vehicle illustration that rides on the road.
  final String asset;

  /// Colour of the road, speed lines and text.
  final Color color;
  final double width;

  /// Status lines shown one after another under the animation.
  final List<String> messages;

  @override
  State<RoadLoader> createState() => _RoadLoaderState();
}

class _RoadLoaderState extends State<RoadLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * 0.5;
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
              builder: (context, _) {
                final t = _c.value;
                final bounce = (math.sin(t * math.pi * 4)).abs();
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(painter: _RoadPainter(t, widget.color)),
                    ),
                    Positioned(
                      left: w * 0.26,
                      right: w * 0.14,
                      bottom: h * 0.04 + bounce * 3, // wheels sit on the road line
                      child: Transform.rotate(
                        angle: math.sin(t * math.pi * 2) * 0.025,
                        child: Image.asset(
                          widget.asset,
                          fit: BoxFit.contain,
                          height: h * 0.72,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.two_wheeler_rounded,
                            size: h * 0.5,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (widget.messages.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
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

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final roadY = size.height * 0.86;

    // Road surface line
    final road = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, roadY), Offset(size.width, roadY), road);

    // Moving lane dashes (right -> left = vehicle moving forward)
    final dash = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashLen = 18.0;
    const gap = 16.0;
    const period = dashLen + gap;
    final shift = t * period * 2;
    for (double x = -period + (period - shift % period); x < size.width; x += period) {
      final x1 = x.clamp(0.0, size.width);
      final x2 = (x + dashLen).clamp(0.0, size.width);
      if (x2 > x1) {
        canvas.drawLine(Offset(x1, roadY + 8), Offset(x2, roadY + 8), dash);
      }
    }

    // Speed lines behind the vehicle
    final speed = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final phase = (t * 2 + i * 0.33) % 1.0;
      final y = size.height * (0.38 + i * 0.14);
      final len = size.width * (0.10 + 0.10 * math.sin(phase * math.pi));
      final endX = size.width * 0.27 - i * 6;
      speed.color = color.withValues(alpha: 0.15 + 0.45 * (1 - phase));
      canvas.drawLine(Offset(endX - len, y), Offset(endX, y), speed);
    }

    // Dust puffs from the rear wheel
    final puff = Paint();
    for (var i = 0; i < 3; i++) {
      final p = (t * 1.5 + i / 3) % 1.0;
      final x = size.width * 0.30 - p * size.width * 0.18;
      final y = roadY - 6 - p * 10;
      puff.color = color.withValues(alpha: 0.22 * (1 - p));
      canvas.drawCircle(Offset(x, y), 3 + p * 6, puff);
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.t != t || old.color != color;
}

// -----------------------------------------------------------------------------
// WheelLoader
// -----------------------------------------------------------------------------

class WheelLoader extends StatefulWidget {
  const WheelLoader({
    super.key,
    this.size = 44,
    this.color = const Color(0xFFFF5722),
  });

  final double size;
  final Color color;

  @override
  State<WheelLoader> createState() => _WheelLoaderState();
}

class _WheelLoaderState extends State<WheelLoader> with SingleTickerProviderStateMixin {
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
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: widget.size * 1.6,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _WheelPainter(_c.value, widget.color)),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final c = Offset(size.width - r, r);

    // Speed streaks
    final streak = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, r * 0.14);
    for (var i = 0; i < 3; i++) {
      final phase = (t * 2 + i * 0.3) % 1.0;
      final y = r * (0.55 + i * 0.45);
      final len = (size.width - 2 * r) * (0.5 + 0.5 * math.sin(phase * math.pi));
      streak.color = color.withValues(alpha: 0.15 + 0.5 * (1 - phase));
      canvas.drawLine(Offset(c.dx - r - 2 - len, y), Offset(c.dx - r - 2, y), streak);
    }

    // Tyre
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..color = const Color(0xFF1F2937)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.26,
    );
    // Rim
    canvas.drawCircle(c, r * 0.6, Paint()..color = color.withValues(alpha: 0.18));

    // Spokes
    final spoke = Paint()
      ..color = color
      ..strokeWidth = math.max(1.6, r * 0.12)
      ..strokeCap = StrokeCap.round;
    final angle = t * 2 * math.pi;
    for (var i = 0; i < 5; i++) {
      final a = angle + i * 2 * math.pi / 5;
      canvas.drawLine(
        c,
        c + Offset(math.cos(a), math.sin(a)) * r * 0.58,
        spoke,
      );
    }
    canvas.drawCircle(c, r * 0.16, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.t != t || old.color != color;
}

// -----------------------------------------------------------------------------
// DotsLoader
// -----------------------------------------------------------------------------

class DotsLoader extends StatefulWidget {
  const DotsLoader({super.key, this.color = Colors.white, this.size = 8});

  final Color color;
  final double size;

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader> with SingleTickerProviderStateMixin {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(3, (i) {
              final p = (_c.value - i * 0.18) % 1.0;
              final lift = math.max(0.0, math.sin(p * math.pi * 2));
              return Transform.translate(
                offset: Offset(0, -lift * s * 0.6),
                child: Opacity(
                  opacity: 0.45 + 0.55 * lift,
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
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
