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
      profile: m is Map ? MechanicProfile.fromJson(Map<String, dynamic>.from(m)) : null,
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
    );
  }

  final String bookingId;
  final String vehicleType;
  final List<String> issueTags;
  final String? issueNote;
  final String pickupAddress;
  final double lat;
  final double lng;
  final double distanceMeters;
  final DateTime? createdAt;
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
    );
  }

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
}

/// Result of `mechanic_start_job` (OTP check).
class StartJobResult {
  const StartJobResult({required this.started, this.message, this.attemptsLeft});

  factory StartJobResult.fromJson(Map<String, dynamic> json) {
    return StartJobResult(
      started: json['started'] == true,
      message: _toStringOrNull(json['message']),
      attemptsLeft: json['attempts_left'] == null ? null : _toInt(json['attempts_left']),
    );
  }

  final bool started;
  final String? message;
  final int? attemptsLeft;
}

class PartnerStats {
  const PartnerStats({
    required this.todayCompleted,
    required this.weekCompleted,
    required this.totalCompleted,
    required this.rating,
    required this.ratingCount,
  });

  factory PartnerStats.fromJson(Map<String, dynamic> json) {
    return PartnerStats(
      todayCompleted: _toInt(json['today_completed']),
      weekCompleted: _toInt(json['week_completed']),
      totalCompleted: _toInt(json['total_completed']),
      rating: _toDouble(json['rating'], 5.0),
      ratingCount: _toInt(json['rating_count']),
    );
  }

  final int todayCompleted;
  final int weekCompleted;
  final int totalCompleted;
  final double rating;
  final int ratingCount;
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
      when: _toDate(json['completed_at']) ??
          _toDate(json['cancelled_at']) ??
          _toDate(json['accepted_at']),
    );
  }

  final String bookingId;
  final String status;
  final String vehicleType;
  final List<String> issueTags;
  final String pickupAddress;
  final int? rating;
  final String? reviewText;
  final String? cancelledBy;
  final DateTime? when;

  bool get isCompleted => status == 'COMPLETED';
}
