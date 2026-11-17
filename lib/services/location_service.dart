import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import 'partner_service.dart';

enum LocationIssue { none, serviceOff, denied, deniedForever }

/// Tracks the mechanic's GPS while they are online / on a job and uploads it
/// to `mechanics.current_lat/lng` (customer radar + live tracking use it).
///
/// On Android the position stream runs as a foreground service (ongoing
/// notification), so updates and the app's timers keep running when the
/// mechanic switches to Google Maps or locks the phone.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  final PartnerService _api = PartnerService();

  /// Latest known position (null until the first fix).
  final ValueNotifier<LatLng?> position = ValueNotifier<LatLng?>(null);

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  DateTime? _lastUpload;

  bool get isTracking => _sub != null;

  /// Checks GPS + permission, asking the user if needed.
  Future<LocationIssue> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationIssue.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationIssue.deniedForever;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return LocationIssue.denied;
    }
    return LocationIssue.none;
  }

  /// One-shot position fix (used right before going online).
  Future<LatLng?> currentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final ll = LatLng(p.latitude, p.longitude);
      position.value = ll;
      return ll;
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final ll = LatLng(last.latitude, last.longitude);
          position.value = ll;
          return ll;
        }
      } catch (_) {}
      return position.value;
    }
  }

  /// Starts continuous tracking + periodic heartbeat uploads.
  void start() {
    if (_sub != null) return;

    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '8Speedy Partner — Online',
          notificationText:
              'Aap online hain. Nearby requests aur live location chalu hai.',
          enableWakeLock: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      );
    }

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) {
        position.value = LatLng(p.latitude, p.longitude);
        _upload();
      },
      onError: (Object _) {
        // GPS temporarily unavailable; heartbeat keeps last position fresh.
      },
    );

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      PartnerConstants.locationHeartbeat,
      (_) => _upload(force: true),
    );
  }

  /// Stops tracking (removes the ongoing notification).
  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  /// Uploads the latest position immediately.
  Future<void> pushNow() => _upload(force: true);

  Future<void> _upload({bool force = false}) async {
    final p = position.value;
    if (p == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastUpload != null &&
        now.difference(_lastUpload!) < PartnerConstants.minUploadGap) {
      return;
    }
    _lastUpload = now;
    try {
      await _api.setStatus(lat: p.latitude, lng: p.longitude);
    } catch (_) {
      // Network blip — next update / heartbeat will retry.
    }
  }
}
