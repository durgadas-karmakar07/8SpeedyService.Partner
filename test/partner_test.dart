import 'package:flutter_test/flutter_test.dart';

import 'package:speedy_partner/core/constants.dart';
import 'package:speedy_partner/core/error_helper.dart';
import 'package:speedy_partner/models/models.dart';
import 'package:speedy_partner/services/auth_service.dart';

void main() {
  test('AccountStatus parses link RPC result', () {
    final s = AccountStatus.fromJson(<String, dynamic>{
      'state': 'VERIFIED',
      'mechanic': <String, dynamic>{
        'id': 'm1',
        'full_name': 'Raju Das',
        'phone': '+919000000002',
        'vehicle_specialties': <String>['two_wheeler'],
        'is_verified': true,
        'is_online': false,
        'rating': '4.5',
      },
    });
    expect(s.state, AccountState.verified);
    expect(s.profile!.firstName, 'Raju');
    expect(s.profile!.rating, 4.5);
    expect(AccountStatus.fromJson(<String, dynamic>{'state': 'NOT_REGISTERED'}).profile, isNull);
  });

  test('OpenRequest and ActiveJob parse numbers defensively', () {
    final r = OpenRequest.fromJson(<String, dynamic>{
      'booking_id': 'b1',
      'vehicle_type': 'four_wheeler',
      'issue_tags': <String>['Battery Dead'],
      'pickup_address': 'Benachity',
      'pickup_lat': 23.5,
      'pickup_lng': '87.3',
      'distance_meters': 1530,
      'created_at': '2026-11-17T10:00:00Z',
    });
    expect(r.lng, 87.3);
    expect(Fmt.distance(r.distanceMeters), '1.5 km');

    final j = ActiveJob.fromJson(<String, dynamic>{
      'booking_id': 'b1',
      'status': 'ARRIVED',
      'pickup_lat': 23.5,
      'pickup_lng': 87.3,
      'customer_phone': '+919000000001',
    });
    expect(j.customerName, 'Customer');
    expect(j.minVisitCharge, 49);
  });

  test('StartJobResult reads wrong-OTP response', () {
    final res = StartJobResult.fromJson(<String, dynamic>{
      'started': false,
      'message': 'Wrong OTP.',
      'attempts_left': 3,
    });
    expect(res.started, isFalse);
    expect(res.attemptsLeft, 3);
  });

  test('version compare and phone helpers', () {
    expect(PartnerConstants.isVersionOlder('1.0.0', '1.0.1'), isTrue);
    expect(PartnerConstants.isVersionOlder('1.2.0', '1.0.9'), isFalse);
    expect(AuthService.normalizeIndianPhone('98765 43210'), '+919876543210');
    expect(AuthService.isValidIndianMobile('5876543210'), isFalse);
  });
}
