import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/workout_entry_chooser_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPhone(
    WidgetTester tester, {
    required Locale locale,
    required Brightness brightness,
    required Widget home,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final font = locale.languageCode == 'ar'
        ? 'NotoArabicEvidence'
        : 'RobotoEvidence';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWith(
            (ref) async => FreePlan.createState(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: visualEvidenceTheme(
            ThemeData(brightness: brightness, useMaterial3: true),
            fontFamily: font,
          ),
          builder: (context, child) =>
              visualEvidenceTextSurface(child, fontFamily: font),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exercise chooser matches the compact reference hierarchy', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      home: const WorkoutEntryChooserPage(),
    );

    await expectLater(
      find.byType(WorkoutEntryChooserPage),
      matchesGoldenFile(
        '../../goldens/workouts/workout_entry_chooser_phone_ltr_light.png',
      ),
    );
  });

  testWidgets('exercise chooser remains distinct in Arabic dark mode', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      locale: const Locale('ar'),
      brightness: Brightness.dark,
      home: const WorkoutEntryChooserPage(),
    );

    await expectLater(
      find.byType(WorkoutEntryChooserPage),
      matchesGoldenFile(
        '../../goldens/workouts/workout_entry_chooser_phone_rtl_dark.png',
      ),
    );
  });

  testWidgets('unconfigured routine library is visibly honest and offline', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      home: BilWorkoutRoutinesPage(
        offline: true,
        loader: (_) async => const [],
      ),
    );

    await expectLater(
      find.byType(BilWorkoutRoutinesPage),
      matchesGoldenFile(
        '../../goldens/workouts/workout_library_offline_empty_phone.png',
      ),
    );
  });
}
