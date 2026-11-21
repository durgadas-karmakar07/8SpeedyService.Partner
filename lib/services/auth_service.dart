import 'package:supabase_flutter/supabase_flutter.dart';

/// Phone OTP login (same Supabase Auth as the customer app).
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;

  /// Formats a 10-digit Indian number as E.164 (`+91XXXXXXXXXX`).
  static String normalizeIndianPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (input.trim().startsWith('+')) return input.trim();
    return '+91$digits';
  }

  static bool isValidIndianMobile(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final ten = digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(ten);
  }

  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(
      phone: normalizeIndianPhone(phone),
      shouldCreateUser: true,
    );
  }

  Future<AuthResponse> verifyOtp({required String phone, required String otp}) {
    return _client.auth.verifyOTP(
      phone: normalizeIndianPhone(phone),
      token: otp.trim(),
      type: OtpType.sms,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Permanently deletes the account (Google Play requirement). Server
  /// anonymises the partner profile and ends all sessions.
  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke(
      'delete-account',
      body: <String, dynamic>{'confirm': 'DELETE'},
    );
    final data = response.data;
    if (data is Map && data['deleted'] == true) {
      try {
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
      return;
    }
    throw StateError(
      data is Map && data['error'] is String
          ? data['error'] as String
          : 'Could not delete the account. Please try again.',
    );
  }
}
