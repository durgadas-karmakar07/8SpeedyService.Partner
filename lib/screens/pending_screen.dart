import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import 'account_gate.dart';
import 'login_screen.dart';

/// Shown while the admin hasn't verified the mechanic yet.
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key, this.profile});

  final MechanicProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: PartnerConstants.warningColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      size: 56, color: PartnerConstants.warningColor),
                ),
                const SizedBox(height: 22),
                Text(
                  profile == null
                      ? 'Verification pending'
                      : 'Namaste ${profile!.firstName}!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Aapka partner account verification mein hai. Hamari team aapse call karke documents (Aadhaar, shop photo) check karegi. Verify hote hi aap Online jaakar jobs le sakte hain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => goTo(context, const AccountGateScreen()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Status check karein'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: () => launchUrl(
                    Uri.parse(PartnerConstants.whatsappSupportUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('WhatsApp Support'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (!context.mounted) return;
                    goTo(context, const LoginScreen());
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
