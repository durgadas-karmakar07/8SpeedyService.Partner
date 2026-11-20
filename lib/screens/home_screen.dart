import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../core/vehicle_view.dart';
import '../models/models.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/partner_service.dart';
import 'account_gate.dart';
import 'account_screen.dart';
import 'history_screen.dart';
import 'incoming_request_screen.dart';
import 'job_screen.dart';
import 'login_screen.dart';
import '../widgets/speedy_loader.dart';
import '../widgets/voice_note_player.dart';

/// Main screen: Online/Offline switch + live list of nearby customer requests.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});

  final MechanicProfile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PartnerService _api = PartnerService();
  final LocationService _location = LocationService.instance;
  final MapController _mapController = MapController();

  bool _online = false;
  bool _toggling = false;
  bool _mapReady = false;
  bool _firstLoadDone = false;
  LocationIssue _locationIssue = LocationIssue.none;
  String? _pollError;
  String? _acceptingId;
  List<OpenRequest> _requests = const <OpenRequest>[];
  final Set<String> _seenIds = <String>{};
  Timer? _pollTimer;

  // Call-style job alerts
  final ValueNotifier<Set<String>> _liveIds = ValueNotifier<Set<String>>(<String>{});
  StreamSubscription<String>? _tapSub;
  bool _inForeground = true;
  bool _callOpen = false;
  String? _pendingTapId;
  String? _notifiedId;
  bool _notifAllowed = true;
  bool _fullScreenAllowed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _location.position.addListener(_onPositionChanged);
    _tapSub = AlertService.instance.incomingTaps.listen(_onAlertTapped);
    // App was opened by tapping a job alert after it had been closed.
    AlertService.instance.takeLaunchRequest().then((id) {
      if (id != null) _onAlertTapped(id);
    });
    // Coming back from a job, or the server still thinks we're online
    // (app was killed) -> resume online mode without asking again.
    if (widget.profile.isOnline || _location.isTracking) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goOnline(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _location.position.removeListener(_onPositionChanged);
    _pollTimer?.cancel();
    _tapSub?.cancel();
    AlertService.instance.cancelIncoming();
    _liveIds.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) return;
    _refreshAlertPermissions();
    // Opened from the launcher while a job alert was ringing -> show it.
    final ringing = _notifiedId;
    if (ringing != null && !_callOpen) _onAlertTapped(ringing);
    if (_online) {
      _checkActiveJob();
      _refresh();
    }
  }

  void _onPositionChanged() {
    final p = _location.position.value;
    if (p != null && _mapReady && _requests.isEmpty) {
      try {
        _mapController.move(p, 14);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Online / Offline
  // ---------------------------------------------------------------------------

  /// Play Store "prominent disclosure" before asking for location.
  Future<bool> _locationDisclosure() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on_rounded, color: PartnerConstants.primaryColor),
        title: const Text('Location access'),
        content: const Text(
          'When you are Online, 8Speedy Partner uses your location to:\n\n'
          '• show customer requests near you\n'
          '• let the customer track you live\n\n'
          'While Online, location is shared even when the app is in the background (a notification is shown). It stops as soon as you go Offline.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _goOnline({bool silent = false}) async {
    if (_toggling) return;
    if (!silent && !await _locationDisclosure()) return;
    setState(() => _toggling = true);
    try {
      final issue = await _location.ensurePermission();
      if (!mounted) return;
      if (issue != LocationIssue.none) {
        setState(() => _locationIssue = issue);
        if (silent) await _api.setStatus(isOnline: false);
        return;
      }
      final pos = await _location.currentPosition();
      if (!mounted) return;
      if (pos == null) {
        _snack('Could not get your GPS location. Move to an open area and try again.');
        return;
      }
      await _api.setStatus(isOnline: true, lat: pos.latitude, lng: pos.longitude);
      _location.start();
      if (!mounted) return;
      setState(() {
        _online = true;
        _locationIssue = LocationIssue.none;
        _seenIds.clear();
        _firstLoadDone = false;
      });
      _startPolling();
      _setupAlerts();
    } catch (e) {
      if (!await _handleFatal(e)) _snack(ErrorHelper.friendly(e));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _goOffline() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      await _api.setStatus(isOnline: false);
      await _location.stop();
      _pollTimer?.cancel();
      _notifiedId = null;
      AlertService.instance.cancelIncoming();
      if (!mounted) return;
      setState(() {
        _online = false;
        _mapReady = false; // map widget is removed while offline
        _requests = const <OpenRequest>[];
        _pollError = null;
      });
    } catch (e) {
      _snack(ErrorHelper.friendly(e));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Requests
  // ---------------------------------------------------------------------------

  void _startPolling() {
    _pollTimer?.cancel();
    _refresh();
    _pollTimer = Timer.periodic(PartnerConstants.requestPollInterval, (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!_online) return;
    try {
      final list = await _api.getOpenRequests(PartnerConstants.requestRadiusMeters);
      if (!mounted || !_online) return;

      final fresh = list.where((r) => !_seenIds.contains(r.bookingId)).toList();
      final changed = fresh.isNotEmpty || list.length != _requests.length;
      _seenIds.addAll(list.map((r) => r.bookingId));
      final wasFirstLoad = !_firstLoadDone;
      final ids = list.map((r) => r.bookingId).toSet();

      setState(() {
        _requests = list;
        _pollError = null;
        _firstLoadDone = true;
      });
      _liveIds.value = ids;
      if (changed) _fitMap();

      // A ringing notification whose request is gone -> stop it.
      if (_notifiedId != null && !ids.contains(_notifiedId)) {
        _notifiedId = null;
        AlertService.instance.cancelIncoming();
      }

      final pending = _pendingTapId;
      if (pending != null) {
        _pendingTapId = null;
        final match = list.where((r) => r.bookingId == pending).firstOrNull;
        if (match != null) {
          _openCallScreen(match);
        } else {
          AlertService.instance.setLockScreenMode(false);
          _snack('That request is no longer available.');
        }
      } else if (!wasFirstLoad && fresh.isNotEmpty) {
        _announce(fresh);
      }
    } catch (e) {
      if (await _handleFatal(e)) return;
      if (mounted) setState(() => _pollError = ErrorHelper.friendly(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Call-style job alerts
  // ---------------------------------------------------------------------------

  Future<void> _setupAlerts() async {
    final notif = await AlertService.instance.requestNotifications();
    final fullScreen = await AlertService.instance.canUseFullScreen();
    if (!mounted) return;
    setState(() {
      _notifAllowed = notif;
      _fullScreenAllowed = fullScreen;
    });
  }

  Future<void> _refreshAlertPermissions() async {
    final notif = await AlertService.instance.notificationsAllowed();
    final fullScreen = await AlertService.instance.canUseFullScreen();
    if (!mounted) return;
    if (notif != _notifAllowed || fullScreen != _fullScreenAllowed) {
      setState(() {
        _notifAllowed = notif;
        _fullScreenAllowed = fullScreen;
      });
    }
  }

  /// New request(s) arrived: ring like a phone call.
  void _announce(List<OpenRequest> fresh) {
    final nearest = List<OpenRequest>.of(fresh)
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final r = nearest.first;
    if (_inForeground) {
      if (_callOpen) {
        HapticFeedback.heavyImpact();
        return;
      }
      _openCallScreen(r);
      return;
    }
    _notifiedId = r.bookingId;
    final issues = r.issueTags.take(3).join(', ');
    AlertService.instance
        .showIncoming(
          bookingId: r.bookingId,
          title: '🔔 New job • ${Fmt.distance(r.distanceMeters)} away',
          body: '${vehicleName(r.vehicleLabel, r.vehicleType)}'
              '${issues.isEmpty ? '' : ' — $issues'}'
              '${r.voiceNotePath != null ? ' • 🎤 voice note' : ''}',
        )
        .then((shown) {
      if (!shown) SystemSound.play(SystemSoundType.alert);
    });
  }

  /// The mechanic tapped a job alert (or opened the app while it rang).
  Future<void> _onAlertTapped(String bookingId) async {
    _notifiedId = null;
    AlertService.instance.cancelIncoming();
    if (_callOpen || !mounted) return;
    final match = _requests.where((r) => r.bookingId == bookingId).firstOrNull;
    if (match != null) {
      _openCallScreen(match);
      return;
    }
    // Not loaded yet (cold start) -> open it after the next refresh.
    _pendingTapId = bookingId;
    if (_online) await _refresh();
  }

  Future<void> _openCallScreen(OpenRequest r) async {
    if (_callOpen || !mounted || _acceptingId != null) return;
    _callOpen = true;
    _notifiedId = null;
    AlertService.instance.cancelIncoming();
    final decision = await Navigator.of(context).push<IncomingDecision>(
      PageRouteBuilder<IncomingDecision>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => IncomingRequestScreen(request: r, liveIds: _liveIds),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
      ),
    );
    _callOpen = false;
    AlertService.instance.setLockScreenMode(false);
    if (!mounted) return;
    switch (decision) {
      case IncomingDecision.accept:
        await _accept(r);
      case IncomingDecision.missed:
        _snack('Missed a request — it is still in the list if you want it.');
      default:
        break;
    }
  }

  Future<void> _checkActiveJob() async {
    try {
      final job = await _api.getActiveJob();
      if (job != null && mounted) {
        _pollTimer?.cancel();
        goTo(context, JobScreen(job: job, profile: widget.profile));
      }
    } catch (_) {}
  }

  Future<void> _accept(OpenRequest r) async {
    setState(() => _acceptingId = r.bookingId);
    try {
      final job = await _api.acceptBooking(r.bookingId);
      if (!mounted) return;
      _pollTimer?.cancel();
      HapticFeedback.mediumImpact();
      goTo(context, JobScreen(job: job, profile: widget.profile));
    } catch (e) {
      if (await _handleFatal(e)) return;
      _snack(ErrorHelper.friendly(e));
      _refresh();
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  /// Session expired / account un-verified -> back to the account gate.
  Future<bool> _handleFatal(Object e) async {
    final msg = e.toString();
    if (ErrorHelper.isAuthProblem(e) ||
        msg.contains('not verified') ||
        msg.contains('Mechanic account not found')) {
      _pollTimer?.cancel();
      await _location.stop();
      if (mounted) goTo(context, const AccountGateScreen());
      return true;
    }
    return false;
  }

  void _fitMap() {
    if (!_mapReady) return;
    final points = <LatLng>[
      ?_location.position.value,
      ..._requests.map((r) => LatLng(r.lat, r.lng)),
    ];
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _mapController.move(points.first, 14);
        return;
      }
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(40),
          maxZoom: 15,
        ),
      );
    } catch (_) {
      // Map not attached yet; next refresh will fit.
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will go offline and stop receiving requests.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (ok != true) return;
    _pollTimer?.cancel();
    AlertService.instance.cancelIncoming();
    try {
      await _api.setStatus(isOnline: false);
    } catch (_) {}
    await _location.stop();
    await AuthService().signOut();
    if (!mounted) return;
    goTo(context, const LoginScreen());
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${p.firstName}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'My Jobs',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => HistoryScreen(profile: p)),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'account') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => AccountScreen(profile: widget.profile)),
                );
              } else if (v == 'support') {
                launchUrl(
                  Uri.parse(PartnerConstants.whatsappSupportUrl),
                  mode: LaunchMode.externalApplication,
                );
              } else if (v == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'account', child: Text('Account & Privacy')),
              PopupMenuItem(value: 'support', child: Text('WhatsApp Support')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _statusCard(),
          if (_locationIssue != LocationIssue.none) _locationBanner(),
          if (_online && (!_notifAllowed || !_fullScreenAllowed)) _alertsBanner(),
          Expanded(child: _online ? _onlineBody() : _offlineBody()),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final color = _online ? PartnerConstants.successColor : Colors.blueGrey;
    return Container(
      color: PartnerConstants.darkColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _online ? 'You are ONLINE' : 'You are OFFLINE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  Text(
                    _online
                        ? 'Nearby requests will appear here'
                        : 'Go online to receive jobs',
                    style: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade600),
                  ),
                ],
              ),
            ),
            if (_toggling)
              const WheelLoader(size: 24)
            else
              Transform.scale(
                scale: 1.2,
                child: Switch(
                  value: _online,
                  activeTrackColor: PartnerConstants.successColor,
                  onChanged: (v) => v ? _goOnline() : _goOffline(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _locationBanner() {
    final (String text, String action, Future<bool> Function() open) = switch (_locationIssue) {
      LocationIssue.serviceOff => (
          'Your phone\'s GPS / location is turned off.',
          'Turn on',
          Geolocator.openLocationSettings,
        ),
      LocationIssue.deniedForever => (
          'Location permission is blocked. Allow it in Settings.',
          'Settings',
          Geolocator.openAppSettings,
        ),
      _ => (
          'Location permission is required to go online.',
          'Retry',
          () async {
            await _goOnline();
            return true;
          },
        ),
    };
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.location_off_rounded, color: PartnerConstants.warningColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          TextButton(onPressed: open, child: Text(action)),
        ],
      ),
    );
  }

  Widget _alertsBanner() {
    final notificationsOff = !_notifAllowed;
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFEDD5),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.ring_volume_rounded, color: PartnerConstants.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notificationsOff
                  ? 'Notifications are off — new jobs cannot ring when the app is in the background.'
                  : 'Allow full-screen alerts so new jobs ring like a phone call, even on the lock screen.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (notificationsOff) {
                final ok = await AlertService.instance.requestNotifications();
                if (!ok) await AlertService.instance.openNotificationSettings();
              } else {
                await AlertService.instance.openFullScreenSettings();
              }
              _refreshAlertPermissions();
            },
            child: Text(notificationsOff ? 'Turn on' : 'Allow'),
          ),
        ],
      ),
    );
  }

  Widget _offlineBody() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 24),
        Icon(Icons.power_settings_new_rounded, size: 84, color: Colors.blueGrey.shade300),
        const SizedBox(height: 16),
        const Text(
          'You are offline',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Turn on the switch above. Customer requests within ${PartnerConstants.requestRadiusMeters ~/ 1000} km will appear instantly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey.shade600, height: 1.4),
        ),
        const SizedBox(height: 24),
        _tip(Icons.ring_volume_rounded,
            'New requests ring like a phone call — even when the screen is off.'),
        _tip(Icons.notifications_active_rounded,
            'While online, do not swipe the app away from recent apps.'),
        _tip(Icons.battery_saver_rounded,
            'Set 8Speedy Partner to "Unrestricted" in battery settings.'),
        _tip(Icons.pin_rounded,
            'Always take the customer\'s 4-digit Start OTP before starting work.'),
      ],
    );
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: PartnerConstants.primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }

  Widget _onlineBody() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          SizedBox(height: 200, child: _map()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: <Widget>[
                Text(
                  'Nearby requests (${_requests.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (!_firstLoadDone)
                  const WheelLoader(size: 14),
              ],
            ),
          ),
          if (_pollError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorBox(message: _pollError!),
            ),
          if (_firstLoadDone && _requests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: <Widget>[
                  Icon(Icons.radar_rounded, size: 56, color: Colors.blueGrey.shade300),
                  const SizedBox(height: 10),
                  const Text(
                    'No requests right now.\nYour phone will ring when a new request arrives.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ..._requests.map(_requestCard),
        ],
      ),
    );
  }

  Widget _map() {
    return ValueListenableBuilder<LatLng?>(
      valueListenable: _location.position,
      builder: (context, me, _) {
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: me ?? const LatLng(PartnerConstants.defaultLat, PartnerConstants.defaultLng),
            initialZoom: 14,
            onMapReady: () {
              _mapReady = true;
              _fitMap();
            },
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: PartnerConstants.osmTileUrl,
              userAgentPackageName: PartnerConstants.osmUserAgentPackageName,
            ),
            MarkerLayer(
              markers: <Marker>[
                ..._requests.map(
                  (r) => Marker(
                    point: LatLng(r.lat, r.lng),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on_rounded,
                        color: PartnerConstants.primaryColor, size: 40),
                  ),
                ),
                if (me != null)
                  Marker(
                    point: me,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _requestCard(OpenRequest r) {
    final vehicle = PartnerConstants.vehicleFor(r.vehicleType);
    final accepting = _acceptingId == r.bookingId;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 72,
                  child: VehicleImage(
                    category: r.vehicleType,
                    bodyType: r.vehicleBodyType,
                    height: 44,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(vehicleName(r.vehicleLabel, r.vehicleType),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (r.vehicleLabel != null)
                        Text(vehicle.title,
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
                      Text(Fmt.ago(r.createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: PartnerConstants.darkColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Fmt.distance(r.distanceMeters),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.issueTags
                  .map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            if (r.issueNote != null) ...<Widget>[
              const SizedBox(height: 6),
              Text('“${r.issueNote}”',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey.shade700)),
            ],
            if (r.voiceNotePath != null) ...<Widget>[
              const SizedBox(height: 8),
              VoiceNotePlayer(path: r.voiceNotePath!, seconds: r.voiceNoteSeconds),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.place_outlined, size: 18, color: Colors.blueGrey.shade500),
                const SizedBox(width: 6),
                Expanded(child: Text(r.pickupAddress, style: const TextStyle(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _acceptingId != null ? null : () => _accept(r),
              style: FilledButton.styleFrom(
                backgroundColor: PartnerConstants.successColor,
                minimumSize: const Size.fromHeight(48),
              ),
              child: accepting
                  ? const DotsLoader()
                  : const Text('Accept Job'),
            ),
          ],
        ),
      ),
    );
  }
}
