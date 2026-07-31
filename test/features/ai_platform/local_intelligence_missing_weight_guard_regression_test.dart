import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_composition_root.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a future-only weight cannot bypass missing-weight safe abstention',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await UserProfileRepository(database).save(
        gender: 'male',
        age: 36,
        height: 181,
        currentWeight: 95,
        targetWeight: 88,
        activityLevel: 'moderate',
        exercises: true,
        waist: 104,
        neck: 43,
      );
      await WeightRepository(
        database,
      ).addWeight(94.5, date: DateTime.utc(2026, 7, 21));

      final output = await const BilLocalIntelligenceCompositionRoot()
          .create(database: database)
          .run(asOf: DateTime.utc(2026, 7, 20));

      expect(output.forecast, isEmpty);
      expect(output.canPresent, isFalse);
      expect(output.brainResult.selectedAction, isNull);
      expect(output.primaryMessage.toLowerCase(), contains('weight'));
    },
  );
}
