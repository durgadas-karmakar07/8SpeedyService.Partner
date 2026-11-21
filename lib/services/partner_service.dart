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

  /// RPC names the server does not have (older database) — skipped next time.
  static final Set<String> _missing = <String>{};

  static bool _isMissing(Object e) =>
      e is PostgrestException && (e.code == 'PGRST202' || e.code == 'PT404');

  /// Calls the first RPC of [names] the server knows (newest first).
  Future<dynamic> _rpcFirst(
    List<String> names, [
    Map<String, dynamic>? params,
  ]) async {
    Object? lastError;
    for (final name in names) {
      if (_missing.contains(name) && name != names.last) continue;
      try {
        return await _client.rpc<dynamic>(name, params: params);
      } catch (e) {
        if (!_isMissing(e)) rethrow;
        _missing.add(name);
        lastError = e;
      }
    }
    throw lastError ?? StateError('Server function missing.');
  }

  /// Open requests near the mechanic (v4 adds the AI summary, v3 the voice
  /// note; older servers fall back automatically).
  Future<List<OpenRequest>> getOpenRequests(int radiusMeters) async {
    final data = await _rpcFirst(
      const <String>[
        'mechanic_get_open_requests_v4',
        'mechanic_get_open_requests_v3',
        'mechanic_get_open_requests_v2',
      ],
      <String, dynamic>{'p_radius_meters': radiusMeters},
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
      throw StateError(
        'Job accepted but details could not load. Please reopen the app.',
      );
    }
    return ActiveJob.fromJson(map);
  }

  /// Active job (v2 has no phone number; the phone is fetched on "Call").
  Future<ActiveJob?> getActiveJob() async {
    final data = await _rpcFirst(const <String>[
      'mechanic_get_active_job_v2',
      'mechanic_get_active_job',
    ]);
    final map = _asMap(data);
    return map == null ? null : ActiveJob.fromJson(map);
  }

  /// Customer's phone for the active job (logged + rate limited on the server).
  Future<String?> getCustomerPhone(ActiveJob job) async {
    try {
      final data = await _client.rpc<dynamic>(
        'mechanic_get_customer_contact',
        params: <String, dynamic>{'p_booking_id': job.bookingId},
      );
      return _asMap(data)?['phone']?.toString();
    } catch (e) {
      if (_isMissing(e)) return job.customerPhone;
      rethrow;
    }
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

  /// Completes the job with the repair bill (labour + parts the customer
  /// paid). Falls back to the old RPC on an older server.
  Future<void> completeJob(
    String bookingId, {
    int? repairAmount,
    String? notes,
  }) async {
    try {
      await _client.rpc<dynamic>(
        'mechanic_complete_job_v2',
        params: <String, dynamic>{
          'p_booking_id': bookingId,
          'p_repair_amount': repairAmount,
          'p_repair_notes': notes?.trim(),
        },
      );
    } catch (e) {
      if (!_isMissing(e)) rethrow;
      await _client.rpc<dynamic>(
        'mechanic_complete_job',
        params: <String, dynamic>{'p_booking_id': bookingId},
      );
    }
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
    final data = await _rpcFirst(const <String>[
      'mechanic_get_stats_v2',
      'mechanic_get_stats',
    ]);
    final map = _asMap(data);
    return PartnerStats.fromJson(map ?? const <String, dynamic>{});
  }

  Future<List<JobHistoryItem>> getHistory({int limit = 50}) async {
    final data = await _rpcFirst(
      const <String>[
        'mechanic_get_job_history_v3',
        'mechanic_get_job_history_v2',
      ],
      <String, dynamic>{'p_limit': limit},
    );
    return _asList(data).map(JobHistoryItem.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // Chat & AI repair guide
  // ---------------------------------------------------------------------------

  Future<ChatThread> getMessages(String bookingId) async {
    final data = await _client.rpc<dynamic>(
      'get_booking_messages',
      params: <String, dynamic>{'p_booking_id': bookingId},
    );
    final map = _asMap(data);
    return map == null
        ? const ChatThread(messages: <ChatMessage>[], open: false)
        : ChatThread.fromJson(map);
  }

  Future<ChatMessage> sendMessage(String bookingId, String body) async {
    final data = await _client.rpc<dynamic>(
      'send_booking_message',
      params: <String, dynamic>{
        'p_booking_id': bookingId,
        'p_body': body.trim(),
      },
    );
    final map = _asMap(data);
    if (map == null) throw StateError('Message could not be sent.');
    return ChatMessage.fromJson(map);
  }

  /// AI repair guide for the active job (the server reads the job itself).
  Future<RepairGuide> getRepairGuide(
    String bookingId, {
    String language = 'en',
  }) async {
    try {
      final response = await _client.functions.invoke(
        'ai-assistant',
        body: <String, dynamic>{
          'mode': 'mechanic',
          'booking_id': bookingId,
          'language': language,
        },
      );
      final data = response.data;
      if (data is Map && data['result'] is Map) {
        return RepairGuide.fromResponse(Map<String, dynamic>.from(data));
      }
      throw StateError(
        data is Map && data['error'] is String
            ? data['error'] as String
            : 'Repair guide not available.',
      );
    } on FunctionException catch (e) {
      final d = e.details;
      throw StateError(
        d is Map && d['error'] is String
            ? d['error'] as String
            : 'Repair guide not available.',
      );
    }
  }

  /// "Helpful / Not helpful / Report" for an AI repair guide (Google Play
  /// AI-generated content policy). `feedback` is one of `helpful`,
  /// `not_helpful`, `wrong`, `unsafe`, `offensive`.
  Future<void> sendAiFeedback(
    String requestId,
    String feedback, {
    String? note,
  }) async {
    await _client.rpc<dynamic>(
      'ai_submit_feedback',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_feedback': feedback,
        'p_note': note,
      },
    );
  }
}
