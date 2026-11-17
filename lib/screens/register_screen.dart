import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../core/legal_content.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/partner_service.dart';
import 'account_gate.dart';
import 'account_screen.dart';
import 'legal_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'pending_screen.dart';

/// New mechanic self-registration. Account starts unverified; admin approves
/// it in Supabase (mechanics.is_verified = true).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _shopController = TextEditingController();
  final Set<String> _specialties = <String>{'two_wheeler'};
  bool _agreed = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _shopController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    if (_specialties.isEmpty) {
      setState(() => _error = 'Select at least one vehicle type.');
      return;
    }
    if (!_agreed) {
      setState(() => _error = 'Please accept the Partner Terms.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await PartnerService().register(
        fullName: name,
        shopName: _shopController.text.trim(),
        vehicleSpecialties: _specialties.toList(),
      );
      if (!mounted) return;
      if (status.state == AccountState.verified && status.profile != null) {
        goTo(context, HomeScreen(profile: status.profile!));
      } else {
        goTo(context, PendingScreen(profile: status.profile));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHelper.friendly(e);
      });
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
      appBar: AppBar(
        title: const Text('Partner Registration'),
        actions: <Widget>[
          PopupMenuButton<String>(
            enabled: !_loading,
            onSelected: (v) => v == 'delete' ? confirmAndDeleteAccount(context) : _logout(),
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'logout', child: Text('Logout')),
              PopupMenuItem(value: 'delete', child: Text('Delete account')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const Text(
              'Fill in your details. Our team will verify and activate your account (usually within 24 hours).',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...<Widget>[
              ErrorBox(message: _error!),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _nameController,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Full name *',
                prefixIcon: Icon(Icons.person_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _shopController,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Shop / garage name (optional)',
                prefixIcon: Icon(Icons.storefront_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Which vehicles do you repair? *',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PartnerConstants.vehicleTypes.map((v) {
                final selected = _specialties.contains(v.key);
                return FilterChip(
                  avatar: Icon(v.icon, size: 18),
                  label: Text(v.title),
                  selected: selected,
                  onSelected: _loading
                      ? null
                      : (on) => setState(() {
                            if (on) {
                              _specialties.add(v.key);
                            } else {
                              _specialties.remove(v.key);
                            }
                          }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _agreed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _loading ? null : (v) => setState(() => _agreed = v ?? false),
              title: const Text(
                'I will charge customers fairly, never start work without the Start OTP, and I agree to share my location while online.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalScreen(doc: LegalContent.partnerTerms),
                  ),
                ),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Read Partner Terms'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Submit for Verification'),
            ),
          ],
        ),
      ),
    );
  }
}
