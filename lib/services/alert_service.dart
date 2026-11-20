import 'dart:async';

import 'package:flutter/services.dart';

/// State change of the native voice-note player.
class PlayerEvent {
  const PlayerEvent({required this.state, this.source, this.durationMs = 0, this.error});

  factory PlayerEvent.fromMap(Map<dynamic, dynamic> m) {
    final d = m['durationMs'];
    return PlayerEvent(
      state: m['state']?.toString() ?? 'stopped',
      source: m['source']?.toString(),
      durationMs: d is num ? d.toInt() : 0,
      error: m['error']?.toString(),
    );
  }

  /// loading | playing | paused | completed | stopped | error
  final String state;
  final String? source;
  final int durationMs;
  final String? error;
}

/// Playback position snapshot.
class PlayerPosition {
  const PlayerPosition({this.positionMs = 0, this.durationMs = 0, this.playing = false, this.source});

  final int positionMs;
  final int durationMs;
  final bool playing;
  final String? source;
}

/// Bridge to the Android side (MainActivity): call-style job alerts with the
/// 8Speedy ringtone, notification permissions and the voice-note player.
///
/// Every call is failure-safe: if the platform side is missing (tests, other
/// platforms) the methods return sensible defaults instead of throwing.
class AlertService {
  AlertService._() {
    _channel.setMethodCallHandler(_onNative);
  }

  static final AlertService instance = AlertService._();

  static const MethodChannel _channel = MethodChannel('com.speedyservice.partner/alerts');

  final StreamController<String> _taps = StreamController<String>.broadcast();
  final StreamController<PlayerEvent> _player = StreamController<PlayerEvent>.broadcast();

  /// Booking ids of job alerts the mechanic tapped (app already running).
  Stream<String> get incomingTaps => _taps.stream;

  /// Voice-note player state changes.
  Stream<PlayerEvent> get playerEvents => _player.stream;

  Future<dynamic> _onNative(MethodCall call) async {
    switch (call.method) {
      case 'onIncomingTap':
        final id = call.arguments?.toString();
        if (id != null && id.isNotEmpty) _taps.add(id);
      case 'onPlayer':
        final m = call.arguments;
        if (m is Map) _player.add(PlayerEvent.fromMap(m));
    }
    return null;
  }

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  Future<bool> notificationsAllowed() async =>
      await _invoke<bool>('notificationsAllowed') ?? true;

  /// Asks for the Android 13+ notification permission (no-op when granted).
  Future<bool> requestNotifications() async =>
      await _invoke<bool>('requestNotifications') ?? true;

  /// Android 14+: whether job alerts may open full screen over the lock screen.
  Future<bool> canUseFullScreen() async => await _invoke<bool>('canFullScreen') ?? true;

  Future<void> openFullScreenSettings() => _invoke<void>('openFullScreenSettings');

  Future<void> openNotificationSettings() => _invoke<void>('openNotificationSettings');

  // ---------------------------------------------------------------------------
  // Job alerts
  // ---------------------------------------------------------------------------

  /// Rings like a phone call (full-screen / heads-up). Returns false when
  /// notifications are blocked.
  Future<bool> showIncoming({
    required String bookingId,
    required String title,
    required String body,
  }) async {
    return await _invoke<bool>('showIncoming', <String, String>{
          'bookingId': bookingId,
          'title': title,
          'body': body,
        }) ??
        false;
  }

  Future<void> cancelIncoming() => _invoke<void>('cancelIncoming');

  Future<void> startRinging() => _invoke<void>('startRinging');

  Future<void> stopRinging() => _invoke<void>('stopRinging');

  /// Booking id when the app was cold-started from a job alert.
  Future<String?> takeLaunchRequest() => _invoke<String>('takeLaunchRequest');

  /// Show the app over the lock screen (only while a job alert is open).
  Future<void> setLockScreenMode(bool on) => _invoke<void>('setLockScreenMode', on);

  // ---------------------------------------------------------------------------
  // Voice notes
  // ---------------------------------------------------------------------------

  Future<void> playAudio(String httpsUrl) => _invoke<void>('playAudio', httpsUrl);

  Future<void> pauseAudio() => _invoke<void>('pauseAudio');

  Future<void> resumeAudio() => _invoke<void>('resumeAudio');

  Future<void> stopAudio() => _invoke<void>('stopAudio');

  Future<PlayerPosition> audioPosition() async {
    final m = await _invoke<Map<dynamic, dynamic>>('audioPosition');
    if (m == null) return const PlayerPosition();
    int asInt(dynamic v) => v is num ? v.toInt() : 0;
    return PlayerPosition(
      positionMs: asInt(m['positionMs']),
      durationMs: asInt(m['durationMs']),
      playing: m['playing'] == true,
      source: m['source']?.toString(),
    );
  }
}
