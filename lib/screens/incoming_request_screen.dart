import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../core/vehicle_view.dart';
import '../models/models.dart';
import '../services/alert_service.dart';
import '../widgets/voice_note_player.dart';

enum IncomingDecision { accept, decline, missed, unavailable }

/// Full-screen "incoming call" style screen for a new customer request.
/// Rings with the 8Speedy ringtone until the mechanic accepts / declines,
/// the request is taken by someone else, or it times out.
class IncomingRequestScreen extends StatefulWidget {
  const IncomingRequestScreen({
    super.key,
    required this.request,
    required this.liveIds,
  });

  final OpenRequest request;

  /// Ids of requests that are still open (updated by the home screen poll).
  final ValueListenable<Set<String>> liveIds;

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: PartnerConstants.incomingRingTimeout,
  );

  bool _ringing = false;
  bool _closing = false;
  bool _gone = false;
  final DateTime _openedAt = DateTime.now();

  /// The mechanic played the voice note -> keep the ringtone off.
  bool _silenced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ringing = true;
    AlertService.instance.startRinging();
    HapticFeedback.heavyImpact();
    _countdown
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _close(IncomingDecision.missed);
      })
      ..forward();
    widget.liveIds.addListener(_onLiveChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closing || _gone) return;
    if (state == AppLifecycleState.resumed) {
      // Animations pause in the background, so check the real time.
      if (DateTime.now().difference(_openedAt) >=
          PartnerConstants.incomingRingTimeout) {
        _close(IncomingDecision.missed);
      } else if (!_ringing && !_silenced) {
        _ringing = true;
        AlertService.instance.startRinging();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Never keep ringing while the mechanic is in another app.
      _stopRinging();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.liveIds.removeListener(_onLiveChanged);
    _stopRinging();
    _pulse.dispose();
    _countdown.dispose();
    AlertService.instance.setLockScreenMode(false);
    super.dispose();
  }

  void _onLiveChanged() {
    if (_closing || _gone) return;
    if (!widget.liveIds.value.contains(widget.request.bookingId)) {
      _stopRinging();
      _countdown.stop();
      setState(() => _gone = true);
      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        _close(IncomingDecision.unavailable);
      });
    }
  }

  void _stopRinging() {
    if (!_ringing) return;
    _ringing = false;
    AlertService.instance.stopRinging();
  }

  void _close(IncomingDecision decision) {
    if (_closing || !mounted) return;
    _closing = true;
    _stopRinging();
    Navigator.of(context).pop(decision);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final vehicle = PartnerConstants.vehicleFor(r.vehicleType);

    return PopScope<IncomingDecision>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(IncomingDecision.decline);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFF1E293B),
                Color(0xFF0B1220),
                Color(0xFF2A1208),
              ],
              stops: <double>[0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: <Widget>[
                  _header(),
                  const SizedBox(height: 14),
                  Text(
                    Fmt.distance(r.distanceMeters),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Text(
                    'away from you',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  Expanded(child: Center(child: _ripple(r))),
                  Text(
                    vehicleName(r.vehicleLabel, r.vehicleType),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (r.vehicleLabel != null)
                    Text(
                      vehicle.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: r.issueTags.map(_tag).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          r.pickupAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (r.issueNote != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      '“${r.issueNote}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (r.aiSummary != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'AI: ${r.aiSummary}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  if (r.voiceNotePath != null) ...<Widget>[
                    const SizedBox(height: 12),
                    VoiceNotePlayer(
                      path: r.voiceNotePath!,
                      seconds: r.voiceNoteSeconds,
                      dark: true,
                      onPlayStart: () {
                        _silenced = true;
                        _stopRinging();
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _gone ? _goneBanner() : _actions(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: <Widget>[
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final on = _pulse.value < 0.5;
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: on
                    ? PartnerConstants.primaryColor
                    : PartnerConstants.primaryColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        const Text(
          'NEW JOB REQUEST',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 44,
          height: 44,
          child: AnimatedBuilder(
            animation: _countdown,
            builder: (context, _) {
              final total = PartnerConstants.incomingRingTimeout.inSeconds;
              final left = (total * (1 - _countdown.value)).ceil();
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CircularProgressIndicator(
                    value: 1 - _countdown.value,
                    strokeWidth: 3.5,
                    color: PartnerConstants.primaryColor,
                    backgroundColor: Colors.white12,
                  ),
                  Text(
                    '$left',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _ripple(OpenRequest r) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => CustomPaint(
        painter: _RipplePainter(_pulse.value, PartnerConstants.primaryColor),
        child: child,
      ),
      child: Container(
        width: 150,
        height: 150,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: PartnerConstants.primaryColor.withValues(alpha: 0.45),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: VehicleImage(
          category: r.vehicleType,
          bodyType: r.vehicleBodyType,
          height: 90,
        ),
      ),
    );
  }

  Widget _tag(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t,
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
      ),
    );
  }

  Widget _goneBanner() {
    return Container(
      key: const ValueKey<String>('gone'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'This request was taken by another partner or cancelled.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _actions() {
    return Row(
      key: const ValueKey<String>('actions'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _CallButton(
          icon: Icons.close_rounded,
          label: 'Decline',
          color: PartnerConstants.dangerColor,
          onTap: () {
            HapticFeedback.mediumImpact();
            _close(IncomingDecision.decline);
          },
        ),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final wobble =
                math.sin(_pulse.value * math.pi * 8) *
                (_pulse.value < 0.35 ? 0.12 : 0.0);
            return Transform.rotate(angle: wobble, child: child);
          },
          child: _CallButton(
            icon: Icons.check_rounded,
            label: 'Accept',
            color: PartnerConstants.successColor,
            big: true,
            onTap: () {
              HapticFeedback.heavyImpact();
              _close(IncomingDecision.accept);
            },
          ),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 82.0 : 70.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          button: true,
          label: label,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 8,
            shadowColor: color.withValues(alpha: 0.6),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: Colors.white, size: size * 0.48),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Expanding rings around the vehicle, like an incoming call.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const base = 75.0;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final radius = base + p * 95;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: (1 - p) * 0.55),
      );
      canvas.drawCircle(
        c,
        radius,
        Paint()..color = color.withValues(alpha: (1 - p) * 0.06),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}
