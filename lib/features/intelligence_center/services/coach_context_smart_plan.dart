part of 'coach_context_provider.dart';

/// Projects only the explicitly shared, currently owned and validated plan.
Future<Map<String, Object?>> _readSavedSmartPlanContext({
  required Ref ref,
  required PreferencesRepository preferences,
  required String? planOwner,
  required DietaryPreferences dietaryPreferences,
  required bool includeNutrition,
  required bool includeTraining,
}) async {
  Map<String, Object?> savedPlanContext = const {};
  try {
    if (planOwner != null &&
        preferences.localOwnerId == planOwner &&
        await preferences.get('smartPlan.shareWithCoach.v1') == 'true') {
      final saved = await BilSmartPlanRepository(
        preferences: preferences,
        currentOwnerId: () =>
            ref.mounted ? ref.read(verifiedEntitlementOwnerIdProvider) : null,
      ).readFor(planOwner);
      if (saved != null &&
          ref.mounted &&
          ref.read(verifiedEntitlementOwnerIdProvider) == planOwner) {
        final extended =
            await preferences.get('smartPlan.shareWithCoach.v2') == 'true';
        await const BilSmartPlanCatalog().validate(saved, dietaryPreferences);
        if (!ref.mounted ||
            ref.read(verifiedEntitlementOwnerIdProvider) != planOwner) {
          throw StateError('smart_plan_owner_changed');
        }
        savedPlanContext = smartPlanContext(
          saved,
          DateTime.now(),
          includeNutrition: includeNutrition,
          includeTraining: includeTraining,
          includeExtendedContext: extended,
        );
      }
    }
  } on Object {
    savedPlanContext = const {};
  }
  return savedPlanContext;
}
