import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// All server calls of the Partner app. Every write goes through the
/// `mechanic_*` SECURITY DEFINER RPCs (mechanics can't read `bookings`
/// directly, so the customer's start OTP is never exposed).
class PartnerService {
  SupabaseClient get _client => Supabase.instance.client;

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  static List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------

  Future<AccountStatus> linkAccount() async {
    final data = await _client.rpc<dynamic>('mechanic_link_account');
    final map = _asMap(data);
    if (map == null) {
      throw StateError('Account status could not be loaded. Please retry.');
    }
    return AccountStatus.fromJson(map);
  }

  Future<AccountStatus> register({
    required String fullName,
    required String shopName,
    required List<String> vehicleSpecialties,
  }) async {
    final data = await _client.rpc<dynamic>(
      'mechanic_register',
      params: <String, dynamic>{
        'p_full_name': fullName.trim(),
        'p_shop_name': shopName.trim(),
        'p_vehicle_specialties': vehicleSpecialties,
      },
    );
    final map = _asMap(data);
    if (map == null) {
      throw StateError('Registration failed. Please retry.');
    }
    return AccountStatus.fromJson(map);
  }

  /// Minimum Partner app version from `app_config` (null if unavailable).
  Future<String?> fetchMinPartnerVersion() async {
    final row = await _client
        .from('app_config')
        .select('min_partner_version')
        .eq('id', 1)
        .maybeSingle();
    return row?['min_partner_version']?.toString();
  }

  // ---------------------------------------------------------------------------
  // Online status & location
  // ---------------------------------------------------------------------------

  /// [isOnline] null = keep current value (used for location heartbeats).
  Future<void> setStatus({bool? isOnline, double? lat, double? lng}) async {
    await _client.rpc<dynamic>(
      'mechanic_set_status',
      params: <String, dynamic>{
        'p_is_online': isOnline,
        'p_lat': lat,
        'p_lng': lng,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Requests & jobs
  // ---------------------------------------------------------------------------

  Future<List<OpenRequest>> getOpenRequests(int radiusMeters) async {
    final data = await _client.rpc<dynamic>(
      'mechanic_get_open_requests',
      params: <String, dynamic>{'p_radius_meters': radiusMeters},
    );
    return _asList(data).map(OpenRequest.fromJson).toList();
  }

  Future<ActiveJob> acceptBooking(String bookingId) async {
    final data = await _client.rpc<dynamic>(
      'mechanic_accept_booking',
      params: <String, dynamic>{'p_booking_id': bookingId},
    );
    final map = _asMap(data);
    if (map == null) {
      throw StateError('Job accepted but details could not load. Please reopen the app.');
    }
    return ActiveJob.fromJson(map);
  }

  Future<ActiveJob?> getActiveJob() async {
    final data = await _client.rpc<dynamic>('mechanic_get_active_job');
    final map = _asMap(data);
    return map == null ? null : ActiveJob.fromJson(map);
  }

  Future<void> markArrived(String bookingId) async {
    await _client.rpc<dynamic>(
      'mechanic_mark_arrived',
      params: <String, dynamic>{'p_booking_id': bookingId},
    );
  }

  Future<StartJobResult> startJob(String bookingId, String otp) async {
    final data = await _client.rpc<dynamic>(
      'mechanic_start_job',
      params: <String, dynamic>{'p_booking_id': bookingId, 'p_otp': otp.trim()},
    );
    final map = _asMap(data);
    if (map == null) return const StartJobResult(started: false);
    return StartJobResult.fromJson(map);
  }

  Future<void> completeJob(String bookingId) async {
    await _client.rpc<dynamic>(
      'mechanic_complete_job',
      params: <String, dynamic>{'p_booking_id': bookingId},
    );
  }

  Future<void> releaseJob(String bookingId, String reason) async {
    await _client.rpc<dynamic>(
      'mechanic_release_job',
      params: <String, dynamic>{'p_booking_id': bookingId, 'p_reason': reason},
    );
  }

  /// Booking status as seen by this mechanic ('UNAVAILABLE' if not theirs).
  Future<String> getBookingStatus(String bookingId) async {
    final data = await _client.rpc<dynamic>(
      'mechanic_get_booking_status',
      params: <String, dynamic>{'p_booking_id': bookingId},
    );
    return data?.toString() ?? 'UNAVAILABLE';
  }

  // ---------------------------------------------------------------------------
  // Stats & history
  // ---------------------------------------------------------------------------

  Future<PartnerStats> getStats() async {
    final data = await _client.rpc<dynamic>('mechanic_get_stats');
    final map = _asMap(data);
    return PartnerStats.fromJson(map ?? const <String, dynamic>{});
  }

  Future<List<JobHistoryItem>> getHistory({int limit = 50}) async {
    final data = await _client.rpc<dynamic>(
      'mechanic_get_job_history',
      params: <String, dynamic>{'p_limit': limit},
    );
    return _asList(data).map(JobHistoryItem.fromJson).toList();
  }
}
