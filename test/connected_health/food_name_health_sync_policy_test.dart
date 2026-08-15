import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/connected_health/food_name_health_sync_policy.dart';
import 'package:body_intelligence_log/features/global_platform/health_data/unified_health_data_integration.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reviewed nutrition scope can activate explicit food-name sync', () {
    expect(BilHealthScope.write, contains(HealthDataType.nutrition));
    final status = FoodNameHealthSyncPolicy.evaluate(
      requested: true,
      platform: TargetPlatform.android,
    );
    expect(status.requested, isTrue);
    expect(status.capability, FoodNameHealthSyncCapability.supported);
    expect(status.active, isTrue);
    expect(status.reasonCode, 'supported');
  });

  test('remembered opt-in activates the reviewed nutrition contract', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FoodNameHealthSyncPreferenceRepository(
      PreferencesRepository(database),
      platform: TargetPlatform.android,
    );

    await repository.rememberRequest(true);
    final status = await repository.watch().first;

    expect(status.requested, isTrue);
    expect(status.active, isTrue);
  });

  test(
    'iOS fails closed because the reviewed Apple boundary is weight-only',
    () {
      final status = FoodNameHealthSyncPolicy.evaluate(
        requested: true,
        platform: TargetPlatform.iOS,
      );

      expect(status.requested, isTrue);
      expect(status.capability, FoodNameHealthSyncCapability.unavailable);
      expect(status.active, isFalse);
      expect(status.reasonCode, 'nutrition_write_pipeline_not_available');
    },
  );

  test('food-name sync surface has direct copy for every extended locale', () {
    const keys = <String>{
      'Food names in connected health',
      'With your permission, BIL can export a meal name, calories, and macros to connected health. You can revoke access at any time.',
      'Sync food names and nutrition',
      'Food-name and nutrition sync is enabled',
      'Turn on to request connected-health nutrition access.',
      'Nutrition export is unavailable on this platform.',
      'This platform does not support BIL nutrition export. Your local meal records are unchanged.',
    };
    for (final key in keys) {
      final translated = ExtendedRuntimeCopy.values[key];
      expect(translated, isNotNull, reason: 'missing surface key: $key');
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = translated![locale];
        expect(value?.trim(), isNotEmpty, reason: '$key missing $locale');
        expect(value, isNot(key), reason: '$key leaked English in $locale');
      }
    }
  });
}
