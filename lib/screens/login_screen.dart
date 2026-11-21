import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../services/auth_service.dart';
import 'account_gate.dart';
import '../widgets/speedy_loader.dart';

/// Phone + 6-digit SMS OTP login for mechanics.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _auth = AuthService();

  bool _otpSent = false;
  bool _loading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  String? _error;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(
        () => _resendSeconds = _resendSeconds <= 1 ? 0 : _resendSeconds - 1,
      );
      if (_resendSeconds == 0) t.cancel();
    });
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    if (!AuthService.isValidIndianMobile(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHelper.friendly(
          e,
          fallback: 'Could not send the OTP. Please try again.',
        );
      });
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the 6-digit OTP from the SMS.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _auth.verifyOtp(
        phone: _phoneController.text.trim(),
        otp: otp,
      );
      if (!mounted) return;
      if (res.session == null) {
        setState(() {
          _loading = false;
          _error = 'Verification failed. Please retry.';
        });
        return;
      }
      goTo(context, const AccountGateScreen());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHelper.friendly(
          e,
          fallback: 'The OTP is wrong or has expired.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _otpSent ? 'Enter OTP' : 'Partner Login',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: PartnerConstants.darkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'We sent an SMS to +91 ${_phoneController.text.trim()}.'
                    : 'Log in as an 8SpeedyService mechanic partner with your mobile number.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.blueGrey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...<Widget>[
                ErrorBox(message: _error!),
                const SizedBox(height: 16),
              ],
              if (!_otpSent)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !_loading,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '9876543210',
                    counterText: '',
                    prefixText: '+91  ',
                  ),
                )
              else ...<Widget>[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_loading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: '6-Digit OTP',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              _resendTimer?.cancel();
                              setState(() {
                                _otpSent = false;
                                _resendSeconds = 0;
                                _otpController.clear();
                                _error = null;
                              });
                            },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Change number'),
                    ),
                    TextButton(
                      onPressed: (_loading || _resendSeconds > 0)
                          ? null
                          : _sendOtp,
                      child: Text(
                        _resendSeconds > 0
                            ? 'Resend ${_resendSeconds}s'
                            : 'Resend OTP',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                child: _loading
                    ? const DotsLoader()
                    : Text(_otpSent ? 'Verify & Continue' : 'Send OTP'),
              ),
              const SizedBox(height: 24),
              Text(
                'New mechanic? Log in, fill the registration form, and start getting jobs after verification.',
                style: TextStyle(
                  color: Colors.blueGrey.shade600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red error box used across screens.
class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
