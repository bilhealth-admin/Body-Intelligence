import '../../data/repositories/preferences_repository.dart';
import '../global_platform/health_data/unified_health_data_integration.dart';
import 'package:flutter/foundation.dart';

const foodNameHealthSyncPreferenceKey = 'health.foodNameSyncRequested.v1';

enum FoodNameHealthSyncCapability { supported, unavailable }

class FoodNameHealthSyncStatus {
  const FoodNameHealthSyncStatus({
    required this.requested,
    required this.capability,
    required this.reasonCode,
  });

  final bool requested;
  final FoodNameHealthSyncCapability capability;
  final String reasonCode;

  bool get active =>
      requested && capability == FoodNameHealthSyncCapability.supported;
}

/// Truthful capability gate for exporting individual food names.
///
/// Capability gate for the reviewed nutrition contract. Food names and macro
/// attributes travel beside the canonical calorie value and are only exported
/// after explicit connected-health write consent.
abstract final class FoodNameHealthSyncPolicy {
  static const reasonCode = 'nutrition_write_pipeline_not_available';

  static FoodNameHealthSyncStatus evaluate({
    required bool requested,
    TargetPlatform? platform,
  }) {
    final effectivePlatform = platform ?? defaultTargetPlatform;
    final canWriteNutrition =
        BilHealthScope.write.contains(HealthDataType.nutrition) &&
        effectivePlatform == TargetPlatform.android;
    return FoodNameHealthSyncStatus(
      requested: requested,
      capability: canWriteNutrition
          ? FoodNameHealthSyncCapability.supported
          : FoodNameHealthSyncCapability.unavailable,
      reasonCode: canWriteNutrition ? 'supported' : reasonCode,
    );
  }
}

class FoodNameHealthSyncPreferenceRepository {
  FoodNameHealthSyncPreferenceRepository(this._preferences, {this.platform});

  final PreferencesRepository _preferences;
  final TargetPlatform? platform;

  Stream<FoodNameHealthSyncStatus> watch() => _preferences
      .watch(foodNameHealthSyncPreferenceKey)
      .map(
        (value) => FoodNameHealthSyncPolicy.evaluate(
          requested: value == 'true',
          platform: platform,
        ),
      );

  Future<void> rememberRequest(bool requested) =>
      _preferences.set(foodNameHealthSyncPreferenceKey, '$requested');
}
