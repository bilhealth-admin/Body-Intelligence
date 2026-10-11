import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:flutter/material.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_composition_root.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_reality_runtime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first trusted baseline message is localized for an Arabic user',
    () async {
      final previousLocale = AppLocalizations.activeLocale;
      addTearDown(() => AppLocalizations.activate(previousLocale));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await UserProfileRepository(database).save(
        gender: 'male',
        age: 36,
        height: 181,
        currentWeight: 87,
        targetWeight: 80,
        activityLevel: 'moderate',
        exercises: true,
        waist: 100,
        neck: 40,
      );
      final day = DateTime.utc(2026, 7, 20);
      for (final weight in [87.0, 92.8, 104.5]) {
        await WeightRepository(database).addWeight(weight, date: day);
        final output = await const BilLocalIntelligenceCompositionRoot()
            .create(database: database)
            .run(asOf: day);
        final measured = weight.toStringAsFixed(1);
        expect(output.primaryMessage, contains(measured));
        final localized = AppLocalizations(
          const Locale('ar'),
        ).text(output.primaryMessage);
        // Production runtime + localizer, including multiple measured weights
        // to prevent a hardcoded translation for the original 87 kg fixture.
        expect(localized, matches(RegExp(r'[؀-ۿ]')));
        expect(localized, contains(measured));
        expect(
          localized,
          isNot(contains('accepted your first trusted baseline')),
        );
      }
    },
  );

  test('composition root exposes the canonical Reality Runtime only', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final runtime = const BilLocalIntelligenceCompositionRoot().create(
      database: database,
    );

    expect(runtime, isA<BilLocalIntelligenceRealityRuntime>());
  });
}
