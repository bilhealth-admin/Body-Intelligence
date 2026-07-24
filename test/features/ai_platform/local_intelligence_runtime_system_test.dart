import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/ai_platform/adapters/local_intelligence_repository_adapter.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_runtime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'local database produces a product-facing Unified Health Brain result',
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
      final weights = WeightRepository(database);
      final water = WaterRepository(database);
      final start = DateTime.utc(2026, 6, 15);
      for (var index = 0; index < 36; index++) {
        final day = start.add(Duration(days: index));
        if (index % 3 == 0) {
          await weights.addWeight(97 - (index * 0.045), date: day);
        }
        await water.add(
          occurredAt: day.add(const Duration(hours: 12)),
          amountMl: 2300,
        );
      }

      final runtime = BilLocalIntelligenceRuntime(
        adapter: LocalIntelligenceRepositoryAdapter(database),
      );
      final output = await runtime.run(asOf: DateTime.utc(2026, 7, 20));

      expect(output.forecast.map((point) => point.days), [7, 14]);
      expect(output.adaptiveTdeeKcal, greaterThan(0));
      expect(output.plateauRisk, inInclusiveRange(0, 1));
      expect(output.brainResult.decisionTrace, isNotEmpty);
      expect(output.primaryMessage, isNotEmpty);
    },
  );
}
