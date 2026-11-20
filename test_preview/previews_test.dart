import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speedy_partner/models/models.dart';
import 'package:speedy_partner/screens/incoming_request_screen.dart';
import 'package:speedy_partner/widgets/speedy_loader.dart';
import 'package:speedy_partner/widgets/voice_note_player.dart';

import 'preview_helpers.dart';

OpenRequest _sample() => OpenRequest.fromJson(<String, dynamic>{
      'booking_id': 'b-1',
      'vehicle_type': 'two_wheeler',
      'issue_tags': <String>['Flat Tyre', 'Engine Not Starting'],
      'issue_note': 'Near Junction Mall gate',
      'pickup_address': 'City Centre, Durgapur, West Bengal',
      'pickup_lat': 23.54,
      'pickup_lng': 87.29,
      'distance_meters': 1800,
      'created_at': DateTime.now().toIso8601String(),
      'vehicle_label': 'Honda Activa 6G',
      'vehicle_body_type': 'scooter',
      'voice_note_path': 'u/b-1_1700000000000.m4a',
      'voice_note_seconds': 18,
    });

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('incoming request (call screen)', (tester) async {
    phoneSurface(tester);
    final live = ValueNotifier<Set<String>>(<String>{'b-1'});
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins', useMaterial3: true),
      home: IncomingRequestScreen(request: _sample(), liveIds: live),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/incoming_call.png'));
    // Leave the screen so its timers stop.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('loaders + voice note player', (tester) async {
    phoneSurface(tester, height: 640);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins', useMaterial3: true),
      home: const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              RoadLoader(messages: <String>['Checking your account…']),
              SizedBox(height: 24),
              WheelLoader(size: 48),
              SizedBox(height: 24),
              VoiceNotePlayer(path: 'u/b-1_1700000000000.m4a', seconds: 18),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/partner_loaders.png'));
  });
}
