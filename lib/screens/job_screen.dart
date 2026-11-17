import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../core/vehicle_view.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../services/partner_service.dart';
import 'account_gate.dart';
import 'home_screen.dart';
import '../widgets/speedy_loader.dart';

/// Active job flow: Navigate -> Arrived -> Start OTP -> Complete.
class JobScreen extends StatefulWidget {
  const JobScreen({super.key, required this.job, required this.profile});

  final ActiveJob job;
  final MechanicProfile profile;

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> with WidgetsBindingObserver {
  final PartnerService _api = PartnerService();
  final LocationService _location = LocationService.instance;
  final MapController _mapController = MapController();
  final TextEditingController _otpController = TextEditingController();

  late ActiveJob _job = widget.job;
  bool _busy = false;
  bool _closed = false;
  bool _mapReady = false;
  String? _otpError;
  Timer? _pollTimer;

  LatLng get _pickup => LatLng(_job.lat, _job.lng);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureTracking();
    _pollTimer = Timer.periodic(PartnerConstants.jobPollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _poll();
  }

  /// Customer tracks us live during the job, so location must be running
  /// (e.g. after the app was restarted mid-job).
  Future<void> _ensureTracking() async {
    if (_location.isTracking) {
      _location.pushNow();
      return;
    }
    final issue = await _location.ensurePermission();
    if (issue != LocationIssue.none) {
      _snack('Please allow location — the customer tracks you live.');
      return;
    }
    final pos = await _location.currentPosition();
    try {
      await _api.setStatus(isOnline: true, lat: pos?.latitude, lng: pos?.longitude);
    } catch (_) {}
    _location.start();
  }

  // ---------------------------------------------------------------------------
  // Server sync
  // ---------------------------------------------------------------------------

  Future<void> _poll() async {
    if (_closed || _busy) return;
    try {
      final job = await _api.getActiveJob();
      if (!mounted || _closed) return;
      if (job == null || job.bookingId != _job.bookingId) {
        await _onJobGone();
        return;
      }
      setState(() => _job = job);
    } catch (e) {
      await _handleFatal(e);
    }
  }

  Future<void> _onJobGone() async {
    if (_closed) return;
    _closed = true;
    _pollTimer?.cancel();
    String status = 'UNAVAILABLE';
    try {
      status = await _api.getBookingStatus(_job.bookingId);
    } catch (_) {}
    if (!mounted) return;

    final message = switch (status) {
      PartnerConstants.statusCancelled => 'The customer has cancelled this booking.',
      PartnerConstants.statusCompleted => 'This job is already completed.',
      _ => 'This job is no longer assigned to you.',
    };
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded, color: PartnerConstants.warningColor),
        title: const Text('Job closed'),
        content: Text(message),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    _goHome();
  }

  void _goHome() {
    if (!mounted) return;
    goTo(context, HomeScreen(profile: widget.profile));
  }

  Future<bool> _handleFatal(Object e) async {
    final msg = e.toString();
    if (ErrorHelper.isAuthProblem(e) ||
        msg.contains('not verified') ||
        msg.contains('Mechanic account not found')) {
      _closed = true;
      _pollTimer?.cancel();
      if (mounted) goTo(context, const AccountGateScreen());
      return true;
    }
    return false;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!await _handleFatal(e)) _snack(ErrorHelper.friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _markArrived() => _run(() async {
        await _api.markArrived(_job.bookingId);
        final job = await _api.getActiveJob();
        if (job != null && mounted) setState(() => _job = job);
        _snack('The customer has been told that you have arrived.');
      });

  Future<void> _startJob() async {
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(otp)) {
      setState(() => _otpError = 'Enter the 4-digit OTP shown in the customer\'s app.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _otpError = null);
    await _run(() async {
      final res = await _api.startJob(_job.bookingId, otp);
      if (!mounted) return;
      if (res.started) {
        HapticFeedback.mediumImpact();
        _otpController.clear();
        final job = await _api.getActiveJob();
        if (job != null && mounted) setState(() => _job = job);
        _snack('OTP verified. You can start the work! 🔧');
      } else {
        final left = res.attemptsLeft;
        setState(() => _otpError = [
              res.message ?? 'Wrong OTP.',
              if (left != null) '$left attempts left.',
            ].join(' '));
      }
    });
  }

  Future<void> _complete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Job complete?'),
        content: const Text(
          'Is the vehicle fixed and have you collected the repair payment from the customer?',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PartnerConstants.successColor,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, complete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _run(() async {
      await _api.completeJob(_job.bookingId);
      _closed = true;
      _pollTimer?.cancel();
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.verified_rounded,
              color: PartnerConstants.successColor, size: 56),
          title: const Text('Great job! Job completed 🎉'),
          content: const Text('The customer will now rate you. Better ratings mean more jobs.'),
          actions: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Next job'),
            ),
          ],
        ),
      );
      _goHome();
    });
  }

  Future<void> _release() async {
    const reasons = <String>[
      'My vehicle broke down',
      'The location is too far',
      'Customer is not answering the phone',
      'Personal emergency',
      'I cannot do this repair',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Choose a reason for releasing the job. The booking will go to another mechanic. Releasing jobs often can get your account suspended.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            ...reasons.map(
              (r) => ListTile(
                leading: const Icon(Icons.chevron_right_rounded),
                title: Text(r),
                onTap: () => Navigator.pop(ctx, r),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;

    await _run(() async {
      await _api.releaseJob(_job.bookingId, reason);
      _closed = true;
      _pollTimer?.cancel();
      if (!mounted) return;
      _snack('Job released.');
      _goHome();
    });
  }

  Future<void> _callCustomer() async {
    final phone = _job.customerPhone;
    if (phone == null) {
      _snack('Customer\'s number is not available.');
      return;
    }
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok) _snack('Could not place the call. Number: $phone');
  }

  Future<void> _navigate() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_job.lat},${_job.lng}&travelmode=driving',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Could not open Google Maps.');
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _fitMap(LatLng? me) {
    if (!_mapReady) return;
    if (me == null) {
      _mapController.move(_pickup, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: <LatLng>[_pickup, me],
        padding: const EdgeInsets.all(50),
        maxZoom: 16,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Current Job'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Support',
              icon: const Icon(Icons.support_agent_rounded),
              onPressed: () => launchUrl(
                Uri.parse(PartnerConstants.whatsappSupportUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            SizedBox(height: 230, child: _map()),
            Expanded(child: _panel()),
          ],
        ),
      ),
    );
  }

  Widget _map() {
    return ValueListenableBuilder<LatLng?>(
      valueListenable: _location.position,
      builder: (context, me, _) {
        return Stack(
          children: <Widget>[
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pickup,
                initialZoom: 15,
                onMapReady: () {
                  _mapReady = true;
                  _fitMap(me);
                },
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: PartnerConstants.osmTileUrl,
                  userAgentPackageName: PartnerConstants.osmUserAgentPackageName,
                ),
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: _pickup,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_on_rounded,
                          color: PartnerConstants.primaryColor, size: 44),
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
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'fit',
                backgroundColor: Colors.white,
                onPressed: () => _fitMap(me),
                child: const Icon(Icons.center_focus_strong_rounded,
                    color: PartnerConstants.darkColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _panel() {
    final vehicle = PartnerConstants.vehicleFor(_job.vehicleType);
    final status = _job.status;
    final beforeStart = status == PartnerConstants.statusAccepted ||
        status == PartnerConstants.statusArrived;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        _stepper(status),
        const SizedBox(height: 16),
        // Customer card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 24,
                backgroundColor: PartnerConstants.darkColor,
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_job.customerName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(_job.customerPhone ?? '',
                        style: TextStyle(color: Colors.blueGrey.shade600)),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: _callCustomer,
                style: IconButton.styleFrom(backgroundColor: PartnerConstants.successColor),
                icon: const Icon(Icons.call_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Job details
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 88,
                    child: VehicleImage(
                      category: _job.vehicleType,
                      bodyType: _job.vehicleBodyType,
                      height: 52,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          vehicleName(_job.vehicleLabel, _job.vehicleType),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                        ),
                        Text(vehicle.title,
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
                        if (vehiclePlate(_job.vehicleLabel) != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF9C3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: PartnerConstants.darkColor, width: 1.2),
                            ),
                            child: Text(
                              vehiclePlate(_job.vehicleLabel)!,
                              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _job.issueTags
                    .map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
              if (_job.issueNote != null) ...<Widget>[
                const SizedBox(height: 6),
                Text('“${_job.issueNote}”',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey.shade700)),
              ],
              const Divider(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.place_outlined, size: 20, color: Colors.blueGrey.shade500),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_job.pickupAddress)),
                ],
              ),
              if (status == PartnerConstants.statusAccepted) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _navigate,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Navigate with Google Maps'),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Minimum visit charge: ₹${_job.minVisitCharge} (repair charges are separate — collect directly from the customer)',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._actions(status),
        if (beforeStart) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _release,
            style: TextButton.styleFrom(foregroundColor: PartnerConstants.dangerColor),
            child: const Text('Can\'t make it — release job'),
          ),
        ],
      ],
    );
  }

  List<Widget> _actions(String status) {
    Widget busyChild(String label) => _busy
        ? const DotsLoader()
        : Text(label);

    switch (status) {
      case PartnerConstants.statusAccepted:
        return <Widget>[
          FilledButton(
            onPressed: _busy ? null : _markArrived,
            child: busyChild('I have arrived'),
          ),
        ];
      case PartnerConstants.statusArrived:
        return <Widget>[
          const Text(
            'Ask the customer for the 4-digit Start OTP',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otpController,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 14),
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '••••',
              counterText: '',
              errorText: _otpError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : _startJob,
            child: busyChild('Verify OTP & start work'),
          ),
        ];
      case PartnerConstants.statusInProgress:
        return <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PartnerConstants.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.build_rounded, color: PartnerConstants.successColor),
                SizedBox(width: 10),
                Expanded(child: Text('Work in progress. Tap below when the job is done.')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _complete,
            style: FilledButton.styleFrom(backgroundColor: PartnerConstants.successColor),
            child: busyChild('Job Complete'),
          ),
        ];
      default:
        return const <Widget>[];
    }
  }

  Widget _stepper(String status) {
    const steps = <String>['Accepted', 'Arrived', 'Working', 'Done'];
    final current = switch (status) {
      PartnerConstants.statusAccepted => 0,
      PartnerConstants.statusArrived => 1,
      PartnerConstants.statusInProgress => 2,
      _ => 3,
    };
    return Row(
      children: List<Widget>.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < current;
          return Expanded(
            child: Container(
              height: 3,
              color: done ? PartnerConstants.successColor : Colors.blueGrey.shade200,
            ),
          );
        }
        final index = i ~/ 2;
        final done = index < current;
        final active = index == current;
        return Column(
          children: <Widget>[
            CircleAvatar(
              radius: 13,
              backgroundColor: done
                  ? PartnerConstants.successColor
                  : active
                      ? PartnerConstants.primaryColor
                      : Colors.blueGrey.shade200,
              child: done
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text('${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(height: 4),
            Text(
              steps[index],
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      );
}
