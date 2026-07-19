import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/profile_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('optional profile context works on a compact Arabic layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final age = TextEditingController(text: '32');
    final region = TextEditingController();
    final scroll = ScrollController();
    addTearDown(age.dispose);
    addTearDown(region.dispose);
    addTearDown(scroll.dispose);
    double? waist;
    double? neck;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: ProfileStep(
            ageController: age,
            regionController: region,
            scrollController: scroll,
            heightCm: 168,
            currentWeightKg: 71,
            targetWeightKg: 65,
            waistCm: null,
            neckCm: null,
            gender: 'female',
            activity: 'moderate',
            goalType: 'lose',
            system: MeasurementSystem.metric,
            disclaimerAccepted: true,
            draftRestored: false,
            errors: const {},
            onAgeChanged: (_) {},
            onRegionChanged: (_) {},
            onHeightChanged: (_) {},
            onCurrentWeightChanged: (_) {},
            onTargetWeightChanged: (_) {},
            onWaistChanged: (value) => waist = value,
            onNeckChanged: (value) => neck = value,
            onGenderChanged: (_) {},
            onActivityChanged: (_) {},
            onGoalTypeChanged: (_) {},
            onSystemChanged: (_) {},
            onDisclaimerChanged: (_) {},
            onContinue: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'initial profile layout');

    final optional = find.text('سياق الجسم الاختياري');
    await tester.ensureVisible(optional);
    await tester.tap(optional);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'expanded optional layout');
    expect(find.text('الدولة أو المنطقة'), findsOneWidget);
    expect(find.text('محيط الخصر'), findsOneWidget);
    expect(find.text('محيط الرقبة'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'محيط الخصر'),
      '81,4',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'محيط الرقبة'),
      '34.2',
    );
    expect(waist, 81.4);
    expect(neck, 34.2);
    expect(tester.takeException(), isNull);
  });
}
