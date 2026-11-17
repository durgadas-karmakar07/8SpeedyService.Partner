import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../core/legal_content.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'account_gate.dart';
import 'legal_screen.dart';
import 'login_screen.dart';

/// Asks for confirmation, deletes the account on the server and returns to
/// the login screen. Used from Account, Pending and Register screens.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  var understood = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: PartnerConstants.dangerColor, size: 36),
        title: const Text('Delete your partner account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '• Your name, phone, shop details and location will be removed permanently.\n'
              '• Past job records are kept without your identity.\n'
              '• This cannot be undone. To work again you will need to register again.',
              style: TextStyle(height: 1.45, fontSize: 13.5),
            ),
            CheckboxListTile(
              value: understood,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setLocal(() => understood = v ?? false),
              title: const Text('I understand', style: TextStyle(fontSize: 13.5)),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PartnerConstants.dangerColor,
              minimumSize: const Size(100, 44),
            ),
            onPressed: understood ? () => Navigator.pop(ctx, true) : null,
            child: const Text('Delete'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await LocationService.instance.stop();
    await AuthService().deleteAccount();
    if (!context.mounted) return;
    goTo(context, const LoginScreen());
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // progress
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ErrorHelper.friendly(e, fallback: 'Could not delete the account.'))),
    );
  }
}

/// Partner profile, legal links and account deletion.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.profile});

  final MechanicProfile profile;

  void _openDoc(BuildContext context, LegalDoc doc) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LegalScreen(doc: doc)));
  }

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final specs = profile.vehicleSpecialties.map((k) => PartnerConstants.vehicleFor(k).title).join(', ');
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(profile.phone, style: TextStyle(color: Colors.blueGrey.shade600)),
                if (profile.shopName != null) Text(profile.shopName!, style: TextStyle(color: Colors.blueGrey.shade600)),
                const Divider(height: 24),
                Text('Repair: $specs', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  'To change your name or vehicle types, message WhatsApp support.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openDoc(context, LegalContent.privacy),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.handshake_outlined),
                  title: const Text('Partner Terms'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openDoc(context, LegalContent.partnerTerms),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('WhatsApp Support (${PartnerConstants.supportPhoneDisplay})'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _open(context, PartnerConstants.whatsappSupportUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: PartnerConstants.dangerColor),
              title: const Text(
                'Delete my account',
                style: TextStyle(color: PartnerConstants.dangerColor, fontWeight: FontWeight.w600),
              ),
              onTap: () => confirmAndDeleteAccount(context),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${PartnerConstants.appName} v${PartnerConstants.appVersion}',
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
