import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_body_profile_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves body profile identity, values, and edit commands', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var profileEdits = 0;
    var planEdits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardBodyProfileSnapshot(
              arabic: false,
              weight: '81.5 kg',
              height: '178.0 cm',
              target: '76.0 kg',
              calorieTarget: '2100 kcal',
              proteinTarget: '150 g',
              waterTarget: '2800 ml',
              dailyMetabolism: '2450 kcal',
              neckCircumference: '39.0 cm',
              waistCircumference: '91.0 cm',
              bodyMassIndex: '25.7 BMI',
              bodyFatPercentage: '18.2%',
              leanBodyMass: '66.7 kg',
              onEditProfile: () => profileEdits++,
              onEditPlan: () => planEdits++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('dashboard-body-profile')), findsOneWidget);
    expect(find.byKey(const Key('bil-body-profile-svg')), findsOneWidget);
    expect(find.text('Body Identity'), findsOneWidget);
    expect(
      find.text('Your current local baseline and active plan.'),
      findsOneWidget,
    );
    expect(find.text('81.5 kg'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Edit plan'), findsOneWidget);

    await tester.tap(find.text('Edit profile'));
    await tester.tap(find.text('Edit plan'));

    expect(profileEdits, 1);
    expect(planEdits, 1);
  });

  testWidgets('preserves Arabic labels without changing numeric direction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardBodyProfileSnapshot(
              arabic: true,
              weight: '81.5 kg',
              height: '178.0 cm',
              target: '76.0 kg',
              calorieTarget: '2100 kcal',
              proteinTarget: '150 g',
              waterTarget: '2800 ml',
              dailyMetabolism: '2450 kcal',
              neckCircumference: '39.0 cm',
              waistCircumference: '91.0 cm',
              bodyMassIndex: '25.7 BMI',
              bodyFatPercentage: '18.2%',
              leanBodyMass: '66.7 kg',
              onEditProfile: () {},
              onEditPlan: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('هوية الجسم'), findsOneWidget);
    expect(find.text('خط أساسك المحلي الحالي وخطتك النشطة.'), findsOneWidget);
    expect(find.text('الوزن الحالي'), findsOneWidget);
    expect(find.text('81.5 kg'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(
            find
                .ancestor(
                  of: find.text('81.5 kg'),
                  matching: find.byType(Directionality),
                )
                .first,
          )
          .textDirection,
      TextDirection.ltr,
    );
  });
}
