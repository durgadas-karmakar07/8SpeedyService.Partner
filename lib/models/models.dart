/// Data models for the Partner app. All parsing is defensive because RPCs
/// can return numbers as int/double/string depending on the column type.
library;

double _toDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int _toInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

List<String> _toStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const <String>[];
}

/// Short AI diagnosis summary attached to a booking (`ai_diagnosis` JSON).
String? _aiSummary(dynamic v) {
  if (v is! Map) return null;
  final summary = v['summary']?.toString().trim() ?? '';
  return summary.isEmpty ? null : summary;
}

String? _toStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Row from `public.mechanics` (own row).
class MechanicProfile {
  const MechanicProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.shopName,
    required this.vehicleSpecialties,
    required this.isVerified,
    required this.isOnline,
    required this.rating,
  });

  factory MechanicProfile.fromJson(Map<String, dynamic> json) {
    return MechanicProfile(
      id: json['id'].toString(),
      fullName: json['full_name']?.toString() ?? 'Partner',
      phone: json['phone']?.toString() ?? '',
      shopName: _toStringOrNull(json['shop_name']),
      vehicleSpecialties: _toStringList(json['vehicle_specialties']),
      isVerified: json['is_verified'] == true,
      isOnline: json['is_online'] == true,
      rating: _toDouble(json['rating'], 5.0),
    );
  }

  final String id;
  final String fullName;
  final String phone;
  final String? shopName;
  final List<String> vehicleSpecialties;
  final bool isVerified;
  final bool isOnline;
  final double rating;

  String get firstName => fullName.trim().split(' ').first;
}

enum AccountState { notRegistered, pending, verified }

/// Result of `mechanic_link_account` / `mechanic_register`.
class AccountStatus {
  const AccountStatus({required this.state, this.profile});

  factory AccountStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['state']?.toString() ?? 'NOT_REGISTERED';
    final state = switch (raw) {
      'VERIFIED' => AccountState.verified,
      'PENDING' => AccountState.pending,
      _ => AccountState.notRegistered,
    };
    final m = json['mechanic'];
    return AccountStatus(
      state: state,
      profile: m is Map
          ? MechanicProfile.fromJson(Map<String, dynamic>.from(m))
          : null,
    );
  }

  final AccountState state;
  final MechanicProfile? profile;
}

/// A customer request waiting for a mechanic (`mechanic_get_open_requests`).
class OpenRequest {
  const OpenRequest({
    required this.bookingId,
    required this.vehicleType,
    required this.issueTags,
    required this.issueNote,
    required this.pickupAddress,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.createdAt,
    this.vehicleLabel,
    this.vehicleBodyType,
    this.voiceNotePath,
    this.voiceNoteSeconds,
    this.aiSummary,
  });

  factory OpenRequest.fromJson(Map<String, dynamic> json) {
    return OpenRequest(
      bookingId: json['booking_id'].toString(),
      vehicleType: json['vehicle_type']?.toString() ?? 'two_wheeler',
      issueTags: _toStringList(json['issue_tags']),
      issueNote: _toStringOrNull(json['issue_note']),
      pickupAddress: json['pickup_address']?.toString() ?? '',
      lat: _toDouble(json['pickup_lat']),
      lng: _toDouble(json['pickup_lng']),
      distanceMeters: _toDouble(json['distance_meters']),
      createdAt: _toDate(json['created_at']),
      vehicleLabel: _toStringOrNull(json['vehicle_label']),
      vehicleBodyType: _toStringOrNull(json['vehicle_body_type']),
      voiceNotePath: _toStringOrNull(json['voice_note_path']),
      voiceNoteSeconds: json['voice_note_seconds'] == null
          ? null
          : _toInt(json['voice_note_seconds']),
      aiSummary: _aiSummary(json['ai_diagnosis']),
    );
  }

  /// What the customer's AI diagnosis thinks is wrong (null if none).
  final String? aiSummary;

  final String bookingId;
  final String vehicleType;
  final List<String> issueTags;
  final String? issueNote;
  final String pickupAddress;
  final double lat;
  final double lng;
  final double distanceMeters;
  final DateTime? createdAt;
  final String? vehicleLabel;
  final String? vehicleBodyType;

  /// Customer's recorded description (path in the `voice-notes` bucket).
  final String? voiceNotePath;
  final int? voiceNoteSeconds;
}

/// The job currently assigned to this mechanic (`mechanic_get_active_job`).
class ActiveJob {
  const ActiveJob({
    required this.bookingId,
    required this.status,
    required this.vehicleType,
    required this.issueTags,
    required this.issueNote,
    required this.pickupAddress,
    required this.lat,
    required this.lng,
    required this.customerName,
    required this.customerPhone,
    required this.minVisitCharge,
    this.vehicleLabel,
    this.vehicleBodyType,
    this.voiceNotePath,
    this.voiceNoteSeconds,
    this.aiSummary,
    this.otpAttemptsLeft,
    this.unreadMessages = 0,
  });

  factory ActiveJob.fromJson(Map<String, dynamic> json) {
    return ActiveJob(
      bookingId: json['booking_id'].toString(),
      status: json['status']?.toString() ?? 'ACCEPTED',
      vehicleType: json['vehicle_type']?.toString() ?? 'two_wheeler',
      issueTags: _toStringList(json['issue_tags']),
      issueNote: _toStringOrNull(json['issue_note']),
      pickupAddress: json['pickup_address']?.toString() ?? '',
      lat: _toDouble(json['pickup_lat']),
      lng: _toDouble(json['pickup_lng']),
      customerName: json['customer_name']?.toString() ?? 'Customer',
      customerPhone: _toStringOrNull(json['customer_phone']),
      minVisitCharge: _toInt(json['min_visit_charge'], 49),
      vehicleLabel: _toStringOrNull(json['vehicle_label']),
      vehicleBodyType: _toStringOrNull(json['vehicle_body_type']),
      voiceNotePath: _toStringOrNull(json['voice_note_path']),
      voiceNoteSeconds: json['voice_note_seconds'] == null
          ? null
          : _toInt(json['voice_note_seconds']),
      aiSummary: _aiSummary(json['ai_diagnosis']),
      otpAttemptsLeft: json['otp_attempts_left'] == null
          ? null
          : _toInt(json['otp_attempts_left']),
      unreadMessages: _toInt(json['unread_messages']),
    );
  }

  final String? aiSummary;

  /// Start-OTP tries left (v2 payload only).
  final int? otpAttemptsLeft;

  /// Customer messages not read yet (v2 payload only).
  final int unreadMessages;

  final String bookingId;
  final String status;
  final String vehicleType;
  final List<String> issueTags;
  final String? issueNote;
  final String pickupAddress;
  final double lat;
  final double lng;
  final String customerName;
  final String? customerPhone;
  final int minVisitCharge;
  final String? vehicleLabel;
  final String? vehicleBodyType;
  final String? voiceNotePath;
  final int? voiceNoteSeconds;
}

/// Result of `mechanic_start_job` (OTP check).
class StartJobResult {
  const StartJobResult({
    required this.started,
    this.message,
    this.attemptsLeft,
    this.locked = false,
  });

  factory StartJobResult.fromJson(Map<String, dynamic> json) {
    return StartJobResult(
      started: json['started'] == true,
      message: _toStringOrNull(json['message']),
      attemptsLeft: json['attempts_left'] == null
          ? null
          : _toInt(json['attempts_left']),
      locked: json['locked'] == true,
    );
  }

  /// Too many wrong OTPs: the customer must create a new OTP.
  final bool locked;
  final bool started;
  final String? message;
  final int? attemptsLeft;
}

/// One day in the 7-day earnings chart.
class DailyEarning {
  const DailyEarning({
    required this.day,
    required this.jobs,
    required this.earnings,
  });

  factory DailyEarning.fromJson(Map<String, dynamic> json) => DailyEarning(
    day: _toDate(json['day']) ?? DateTime.now(),
    jobs: _toInt(json['jobs']),
    earnings: _toInt(json['earnings']),
  );

  final DateTime day;
  final int jobs;
  final int earnings;
}

class PartnerStats {
  const PartnerStats({
    required this.todayCompleted,
    required this.weekCompleted,
    required this.totalCompleted,
    required this.rating,
    required this.ratingCount,
    this.monthCompleted = 0,
    this.todayEarnings = 0,
    this.weekEarnings = 0,
    this.monthEarnings = 0,
    this.totalEarnings = 0,
    this.released30d = 0,
    this.accepted30d = 0,
    this.suspendedUntil,
    this.daily = const <DailyEarning>[],
  });

  factory PartnerStats.fromJson(Map<String, dynamic> json) {
    return PartnerStats(
      todayCompleted: _toInt(json['today_completed']),
      weekCompleted: _toInt(json['week_completed']),
      totalCompleted: _toInt(json['total_completed']),
      rating: _toDouble(json['rating'], 5.0),
      ratingCount: _toInt(json['rating_count']),
      monthCompleted: _toInt(json['month_completed']),
      todayEarnings: _toInt(json['today_earnings']),
      weekEarnings: _toInt(json['week_earnings']),
      monthEarnings: _toInt(json['month_earnings']),
      totalEarnings: _toInt(json['total_earnings']),
      released30d: _toInt(json['released_30d']),
      accepted30d: _toInt(json['accepted_30d']),
      suspendedUntil: _toDate(json['suspended_until'])?.toLocal(),
      daily: (json['daily'] is List ? json['daily'] as List : const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => DailyEarning.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  final int todayCompleted;
  final int weekCompleted;
  final int totalCompleted;
  final double rating;
  final int ratingCount;
  final int monthCompleted;
  final int todayEarnings;
  final int weekEarnings;
  final int monthEarnings;
  final int totalEarnings;
  final int released30d;
  final int accepted30d;
  final DateTime? suspendedUntil;
  final List<DailyEarning> daily;

  bool get isSuspended =>
      suspendedUntil != null && suspendedUntil!.isAfter(DateTime.now());

  /// Share of accepted jobs that were finished (not released), last 30 days.
  int get completionRate => accepted30d == 0
      ? 100
      : ((accepted30d - released30d) * 100 / accepted30d).round();
}

class JobHistoryItem {
  const JobHistoryItem({
    required this.bookingId,
    required this.status,
    required this.vehicleType,
    required this.issueTags,
    required this.pickupAddress,
    required this.rating,
    required this.reviewText,
    required this.cancelledBy,
    required this.when,
    this.vehicleLabel,
    this.vehicleBodyType,
    this.repairAmount,
    this.reviewTags = const <String>[],
  });

  factory JobHistoryItem.fromJson(Map<String, dynamic> json) {
    return JobHistoryItem(
      bookingId: json['booking_id'].toString(),
      status: json['status']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? 'two_wheeler',
      issueTags: _toStringList(json['issue_tags']),
      pickupAddress: json['pickup_address']?.toString() ?? '',
      rating: json['rating'] == null ? null : _toInt(json['rating']),
      reviewText: _toStringOrNull(json['review_text']),
      cancelledBy: _toStringOrNull(json['cancelled_by']),
      when:
          _toDate(json['completed_at']) ??
          _toDate(json['cancelled_at']) ??
          _toDate(json['accepted_at']),
      vehicleLabel: _toStringOrNull(json['vehicle_label']),
      vehicleBodyType: _toStringOrNull(json['vehicle_body_type']),
      repairAmount: json['repair_amount'] == null
          ? null
          : _toInt(json['repair_amount']),
      reviewTags: _toStringList(json['review_tags']),
    );
  }

  /// Bill entered at completion (paid by the customer to the mechanic).
  final int? repairAmount;
  final List<String> reviewTags;

  final String bookingId;
  final String status;
  final String vehicleType;
  final List<String> issueTags;
  final String pickupAddress;
  final int? rating;
  final String? reviewText;
  final String? cancelledBy;
  final DateTime? when;
  final String? vehicleLabel;
  final String? vehicleBodyType;

  bool get isCompleted => status == 'COMPLETED';
}

/// In-app chat message (customer <-> mechanic).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderRole,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '',
    senderRole: json['sender_role']?.toString() ?? 'system',
    body: json['body']?.toString() ?? '',
    createdAt: _toDate(json['created_at'])?.toLocal() ?? DateTime.now(),
    readAt: _toDate(json['read_at'])?.toLocal(),
  );

  final String id;
  final String senderRole;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
}

class ChatThread {
  const ChatThread({required this.messages, required this.open});

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    messages:
        (json['messages'] is List
                ? json['messages'] as List
                : const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
    open: json['open'] == true,
  );

  final List<ChatMessage> messages;
  final bool open;
}

/// AI repair guide for the mechanic's active job (`ai-assistant`, mode mechanic).
class RepairGuide {
  const RepairGuide({
    required this.isAi,
    required this.summary,
    required this.urgency,
    required this.causes,
    required this.steps,
    required this.tools,
    required this.costMin,
    required this.costMax,
    required this.safety,
  });

  factory RepairGuide.fromResponse(Map<String, dynamic> json) {
    final r = json['result'] is Map
        ? Map<String, dynamic>.from(json['result'] as Map)
        : <String, dynamic>{};
    final cost = r['estimated_cost'] is Map
        ? Map<String, dynamic>.from(r['estimated_cost'] as Map)
        : <String, dynamic>{};
    final causes =
        (r['likely_causes'] is List
                ? r['likely_causes'] as List
                : const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (c) => (
                title: c['title']?.toString() ?? '',
                probability: _toInt(c['probability']).clamp(1, 100).toInt(),
              ),
            )
            .where((c) => c.title.isNotEmpty)
            .toList();
    return RepairGuide(
      isAi: json['engine'] == 'ai',
      summary: r['summary']?.toString() ?? '',
      urgency: r['urgency']?.toString() ?? 'medium',
      causes: causes,
      steps: _toStringList(r['diagnostic_steps']),
      tools: _toStringList(r['tools_and_parts']),
      costMin: _toInt(cost['min_inr']),
      costMax: _toInt(cost['max_inr']),
      safety: _toStringList(r['avoid']),
    );
  }

  final bool isAi;
  final String summary;
  final String urgency;
  final List<({String title, int probability})> causes;
  final List<String> steps;
  final List<String> tools;
  final int costMin;
  final int costMax;
  final List<String> safety;
}
