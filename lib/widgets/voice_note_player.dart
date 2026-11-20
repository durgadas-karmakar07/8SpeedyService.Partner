import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../services/alert_service.dart';

/// Plays the customer's recorded description of the vehicle problem.
///
/// The audio lives in the private `voice-notes` bucket. A short-lived signed
/// URL is created only when the mechanic taps play, and the server decides
/// (RLS) whether this mechanic may hear it.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.path,
    this.seconds,
    this.dark = false,
    this.onPlayStart,
  });

  /// Object path inside the `voice-notes` bucket.
  final String path;
  final int? seconds;

  /// White-on-dark style (used on the incoming-request screen).
  final bool dark;

  /// Called right before playback starts (e.g. to stop the ringtone).
  final VoidCallback? onPlayStart;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

enum _PlayState { idle, loading, playing, paused, error }

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  static final Map<String, ({String url, DateTime until})> _urlCache =
      <String, ({String url, DateTime until})>{};

  final AlertService _audio = AlertService.instance;
  StreamSubscription<PlayerEvent>? _sub;
  Timer? _ticker;
  _PlayState _state = _PlayState.idle;
  String? _myUrl;
  int _posMs = 0;
  int _durMs = 0;

  @override
  void initState() {
    super.initState();
    _durMs = (widget.seconds ?? 0) * 1000;
    _sub = _audio.playerEvents.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    if (_state == _PlayState.playing ||
        _state == _PlayState.paused ||
        _state == _PlayState.loading) {
      _audio.stopAudio();
    }
    super.dispose();
  }

  void _onEvent(PlayerEvent e) {
    if (!mounted) return;
    final mine = _myUrl != null && e.source == _myUrl;
    if (!mine) {
      // Another note started playing -> this one is idle again.
      if (_state != _PlayState.idle && _state != _PlayState.error) {
        _ticker?.cancel();
        setState(() {
          _state = _PlayState.idle;
          _posMs = 0;
        });
      }
      return;
    }
    switch (e.state) {
      case 'loading':
        setState(() => _state = _PlayState.loading);
      case 'playing':
        if (e.durationMs > 0) _durMs = e.durationMs;
        setState(() => _state = _PlayState.playing);
        _startTicker();
      case 'paused':
        _ticker?.cancel();
        setState(() => _state = _PlayState.paused);
      case 'completed':
      case 'stopped':
        _ticker?.cancel();
        setState(() {
          _state = _PlayState.idle;
          _posMs = 0;
        });
      case 'error':
        _ticker?.cancel();
        setState(() => _state = _PlayState.error);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final p = await _audio.audioPosition();
      if (!mounted || p.source != _myUrl) return;
      setState(() {
        _posMs = p.positionMs;
        if (p.durationMs > 0) _durMs = p.durationMs;
      });
    });
  }

  Future<String> _signedUrl() async {
    final cached = _urlCache[widget.path];
    if (cached != null && cached.until.isAfter(DateTime.now())) return cached.url;
    final url = await Supabase.instance.client.storage
        .from(PartnerConstants.voiceNoteBucket)
        .createSignedUrl(widget.path, 600);
    _urlCache[widget.path] = (url: url, until: DateTime.now().add(const Duration(minutes: 9)));
    return url;
  }

  Future<void> _toggle() async {
    switch (_state) {
      case _PlayState.playing:
        await _audio.pauseAudio();
        return;
      case _PlayState.paused:
        await _audio.resumeAudio();
        return;
      case _PlayState.loading:
        return;
      case _PlayState.idle:
      case _PlayState.error:
        break;
    }
    setState(() => _state = _PlayState.loading);
    try {
      widget.onPlayStart?.call();
      final url = await _signedUrl();
      if (!mounted) return;
      _myUrl = url;
      await _audio.playAudio(url);
    } catch (_) {
      if (mounted) setState(() => _state = _PlayState.error);
    }
  }

  String _fmt(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = dark ? Colors.white : PartnerConstants.darkColor;
    final bg = dark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFFFF3EE);
    final progress = _durMs > 0 ? (_posMs / _durMs).clamp(0.0, 1.0) : 0.0;
    final playing = _state == _PlayState.playing;

    return Semantics(
      button: true,
      label: playing ? 'Pause customer voice note' : 'Play customer voice note',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: PartnerConstants.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: _state == _PlayState.loading
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        height: 22,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _WavePainter(
                            seed: widget.path.hashCode,
                            progress: progress,
                            active: PartnerConstants.primaryColor,
                            idle: fg.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _state == _PlayState.error
                            ? 'Could not play. Tap to retry.'
                            : '🎤 Customer voice note',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _state == _PlayState.error
                              ? PartnerConstants.dangerColor
                              : fg.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _state == _PlayState.idle ? _fmt(_durMs) : _fmt(_posMs),
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative waveform; bars left of [progress] are highlighted.
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.seed,
    required this.progress,
    required this.active,
    required this.idle,
  });

  final int seed;
  final double progress;
  final Color active;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    const bars = 32;
    final gap = size.width / bars;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, gap * 0.5);
    for (var i = 0; i < bars; i++) {
      final shape = 0.35 + 0.65 * math.sin((i / bars) * math.pi);
      final h = size.height * (0.2 + 0.8 * shape * (0.45 + 0.55 * rnd.nextDouble()));
      final x = gap * (i + 0.5);
      paint.color = (i / bars) <= progress ? active : idle;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.seed != seed || old.idle != idle;
}
