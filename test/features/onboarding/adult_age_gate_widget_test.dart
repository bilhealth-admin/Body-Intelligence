import 'package:body_intelligence_log/features/onboarding/bil_flagship_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('date-of-birth gate blocks a fully completed minor profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    var calculations = 0;
    final draft = BilOnboardingDraft()
      ..birthDate = DateTime(now.year - 17, now.month, now.day)
      ..weight = 70
      ..height = 175
      ..sexConfirmed = true
      ..goalConfirmed = true
      ..activityConfirmed = true;

    await tester.pumpWidget(
      MaterialApp(
        home: BilFlagshipOnboarding(
          showWelcome: false,
          initialDraft: draft,
          calculatePlan: (_) async {
            calculations++;
            return const BilInitialPlan(
              calories: 2000,
              protein: 150,
              carbs: 220,
              fat: 65,
              weeklyPace: 0,
            );
          },
          onComplete: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('BIL is available only to adults aged 18 or older.'),
      findsOneWidget,
    );
    final action = find.ancestor(
      of: find.text('Complete required details'),
      matching: find.byType(InkWell),
    );
    expect(action, findsOneWidget);
    expect(tester.widget<InkWell>(action).onTap, isNull);
    expect(calculations, 0);
  });
}
