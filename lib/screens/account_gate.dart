import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/partner_service.dart';
import 'home_screen.dart';
import 'job_screen.dart';
import 'login_screen.dart';
import 'pending_screen.dart';
import 'register_screen.dart';
import '../widgets/speedy_loader.dart';

/// Replaces the whole navigation stack with [screen].
void goTo(BuildContext context, Widget screen) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => screen),
    (_) => false,
  );
}

/// Decides where a logged-in user goes: register / pending / home / job.
class AccountGateScreen extends StatefulWidget {
  const AccountGateScreen({super.key});

  @override
  State<AccountGateScreen> createState() => _AccountGateScreenState();
}

class _AccountGateScreenState extends State<AccountGateScreen> {
  final PartnerService _api = PartnerService();
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _error = null);
    try {
      final status = await _api.linkAccount();
      if (!mounted) return;

      switch (status.state) {
        case AccountState.notRegistered:
          goTo(context, const RegisterScreen());
        case AccountState.pending:
          goTo(context, PendingScreen(profile: status.profile));
        case AccountState.verified:
          final profile = status.profile!;
          final job = await _api.getActiveJob();
          if (!mounted) return;
          goTo(
            context,
            job != null
                ? JobScreen(job: job, profile: profile)
                : HomeScreen(profile: profile),
          );
      }
    } catch (e) {
      if (!mounted) return;
      if (ErrorHelper.isAuthProblem(e)) {
        await AuthService().signOut();
        if (!mounted) return;
        goTo(context, const LoginScreen());
        return;
      }
      setState(() => _error = ErrorHelper.friendly(e));
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    goTo(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? const RoadLoader(
                  messages: <String>[
                    'Checking your account…',
                    'Loading your jobs…',
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: PartnerConstants.warningColor,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _resolve,
                      child: const Text('Retry'),
                    ),
                    TextButton(onPressed: _logout, child: const Text('Logout')),
                  ],
                ),
        ),
      ),
    );
  }
}
