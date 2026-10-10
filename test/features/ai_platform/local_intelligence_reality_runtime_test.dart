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
      await WeightRepository(database).addWeight(87, date: day);
      final output = await const BilLocalIntelligenceCompositionRoot()
          .create(database: database)
          .run(asOf: day);
      expect(output.primaryMessage, contains('87.0'));
      final localized = AppLocalizations(
        const Locale('ar'),
      ).text(output.primaryMessage);
      // Exercise the real runtime-produced message and production localizer,
      // rather than a hardcoded fixture or a source-only translation check.
      expect(localized, matches(RegExp(r'[؀-ۿ]')));
      expect(
        localized,
        isNot(contains('accepted your first trusted baseline')),
      );
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
