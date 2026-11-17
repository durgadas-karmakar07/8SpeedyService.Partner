import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/partner_service.dart';
import 'account_gate.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _needsUpdate = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // Force update check never blocks the app if the network fails.
    try {
      final minVersion = await PartnerService()
          .fetchMinPartnerVersion()
          .timeout(const Duration(seconds: 6));
      if (minVersion != null &&
          PartnerConstants.isVersionOlder(PartnerConstants.appVersion, minVersion)) {
        if (!mounted) return;
        setState(() => _needsUpdate = true);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    final loggedIn = AuthService().currentSession != null;
    goTo(context, loggedIn ? const AccountGateScreen() : const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PartnerConstants.darkColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: PartnerConstants.primaryColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.build_circle_rounded,
                    color: Colors.white, size: 64),
              ),
              const SizedBox(height: 20),
              const Text(
                '8Speedy Partner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mechanic app • ${PartnerConstants.cityName}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 36),
              if (_needsUpdate) ...<Widget>[
                const Text(
                  'Naya version available hai. Continue karne ke liye app update karein.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse(PartnerConstants.playStoreUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Update Now'),
                ),
              ] else
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
