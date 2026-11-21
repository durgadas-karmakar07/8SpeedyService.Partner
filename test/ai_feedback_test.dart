import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:speedy_partner/widgets/ai_feedback.dart';

void main() {
  Future<List<(String, String?)>> pumpBar(WidgetTester tester) async {
    final calls = <(String, String?)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AiFeedbackBar(
              onSubmit: (feedback, note) async => calls.add((feedback, note)),
            ),
          ),
        ),
      ),
    );
    return calls;
  }

  testWidgets('thumbs up sends "helpful" and thanks the user', (
    WidgetTester tester,
  ) async {
    final calls = await pumpBar(tester);
    expect(find.text('Was this helpful?'), findsOneWidget);

    await tester.tap(find.byTooltip('Helpful'));
    await tester.pumpAndSettle();

    expect(calls, <(String, String?)>[('helpful', null)]);
    expect(find.text('Thanks for your feedback'), findsOneWidget);
    // The user can still report after rating.
    expect(find.text('Report'), findsOneWidget);
  });

  testWidgets('report sheet sends the reason and the note', (
    WidgetTester tester,
  ) async {
    final calls = await pumpBar(tester);

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Report this answer'), findsOneWidget);

    // Nothing is sent until a reason is picked.
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.text('Unsafe advice'));
    await tester.enterText(
      find.byType(TextField),
      '  Told me to ride with no brakes ',
    );
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();

    expect(calls, <(String, String?)>[
      ('unsafe', 'Told me to ride with no brakes'),
    ]);
    expect(find.text('Reported — thank you'), findsOneWidget);
    expect(find.text('Report'), findsNothing);
    expect(
      find.text('Thanks. Our team will review this answer.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed send keeps the buttons and shows an error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiFeedbackBar(
            onSubmit: (feedback, note) async =>
                throw StateError('Too many reports in a short time.'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Not helpful'));
    await tester.pumpAndSettle();

    expect(find.text('Was this helpful?'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
