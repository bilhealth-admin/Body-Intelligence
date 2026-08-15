enum IntelligenceActionType {
  navigate,
  readNutritionRemaining,
  readProfileIdentity,
  openDailyLog,
  addWater,
  addWeight,
  reviewMeal,
  reviewWorkout,
  openPlan,
  openReport,
  manageSubscription,
  setThemeMode,
  setLanguage,
  updateGoal,
  saveMeasurements,
  quickAddMacros,
  updateMealItem,
  moveMealItem,
  deleteMealItem,
  requestAccountDeletion,
  saveMemory,
}

class IntelligenceAction {
  const IntelligenceAction({
    required this.id,
    required this.type,
    required this.label,
    required this.requiresConfirmation,
    this.destructive = false,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final IntelligenceActionType type;
  final String label;
  final bool requiresConfirmation;
  final bool destructive;
  final Map<String, Object?> payload;
}
