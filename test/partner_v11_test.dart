import 'package:flutter_test/flutter_test.dart';
import 'package:speedy_partner/models/models.dart';

void main() {
  test('open request and active job read the AI summary + chat/OTP info', () {
    final r = OpenRequest.fromJson(<String, dynamic>{
      'booking_id': 'b1',
      'vehicle_type': 'two_wheeler',
      'issue_tags': <String>['Battery Dead'],
      'pickup_address': 'City Centre',
      'pickup_lat': 23.54,
      'pickup_lng': 87.29,
      'distance_meters': 900,
      'ai_diagnosis': <String, dynamic>{
        'summary': 'Weak battery',
        'urgency': 'medium',
      },
    });
    expect(r.aiSummary, 'Weak battery');

    final j = ActiveJob.fromJson(<String, dynamic>{
      'booking_id': 'b1',
      'status': 'ARRIVED',
      'vehicle_type': 'two_wheeler',
      'issue_tags': <String>['Battery Dead'],
      'pickup_address': 'City Centre',
      'pickup_lat': 23.54,
      'pickup_lng': 87.29,
      'customer_name': 'Ravi',
      'otp_attempts_left': 2,
      'unread_messages': 3,
    });
    expect(j.customerPhone, isNull, reason: 'v2 payload has no phone number');
    expect(j.otpAttemptsLeft, 2);
    expect(j.unreadMessages, 3);
  });

  test('earnings stats v2 parse with completion rate and suspension', () {
    final s = PartnerStats.fromJson(<String, dynamic>{
      'today_completed': 2,
      'week_completed': 9,
      'month_completed': 30,
      'total_completed': 120,
      'today_earnings': 700,
      'week_earnings': 4200,
      'month_earnings': 15500,
      'total_earnings': 61000,
      'rating': 4.8,
      'rating_count': 90,
      'released_30d': 3,
      'accepted_30d': 33,
      'suspended_until': DateTime.now()
          .add(const Duration(hours: 3))
          .toUtc()
          .toIso8601String(),
      'daily': <Map<String, dynamic>>[
        <String, dynamic>{'day': '2026-11-20', 'jobs': 4, 'earnings': 1500},
      ],
    });
    expect(s.monthEarnings, 15500);
    expect(s.completionRate, 91);
    expect(s.isSuspended, isTrue);
    expect(s.daily.single.jobs, 4);

    final old = PartnerStats.fromJson(<String, dynamic>{
      'today_completed': 1,
      'rating': 5,
    });
    expect(old.completionRate, 100);
    expect(old.isSuspended, isFalse);
  });

  test('history v3, OTP lock, chat and AI repair guide parse', () {
    final h = JobHistoryItem.fromJson(<String, dynamic>{
      'booking_id': 'b2',
      'status': 'COMPLETED',
      'vehicle_type': 'four_wheeler',
      'issue_tags': <String>['Overheating'],
      'pickup_address': 'Benachity',
      'repair_amount': 850,
      'review_tags': <String>['On time', 'Polite'],
      'completed_at': '2026-11-21T03:00:00Z',
    });
    expect(h.repairAmount, 850);
    expect(h.reviewTags, hasLength(2));

    final otp = StartJobResult.fromJson(<String, dynamic>{
      'started': false,
      'locked': true,
      'attempts_left': 0,
    });
    expect(otp.locked, isTrue);

    final t = ChatThread.fromJson(<String, dynamic>{
      'open': true,
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'm',
          'sender_role': 'customer',
          'body': 'Near the gate',
          'created_at': '2026-11-21T03:01:00Z',
        },
      ],
    });
    expect(t.messages.single.body, 'Near the gate');

    final g = RepairGuide.fromResponse(<String, dynamic>{
      'engine': 'expert',
      'result': <String, dynamic>{
        'summary': 'Check the cooling system',
        'urgency': 'high',
        'likely_causes': <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Low coolant', 'probability': 45},
        ],
        'diagnostic_steps': <String>['Check coolant level after cooling'],
        'tools_and_parts': <String>['Coolant'],
        'estimated_cost': <String, dynamic>{'min_inr': 500, 'max_inr': 5500},
        'avoid': <String>['Opening a hot radiator cap'],
      },
    });
    expect(g.isAi, isFalse);
    expect(g.causes.single.probability, 45);
    expect(g.steps, isNotEmpty);
    expect(g.costMax, 5500);
  });
}
