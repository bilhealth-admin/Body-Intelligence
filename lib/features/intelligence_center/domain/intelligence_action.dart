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
  openAiCoachSubscription,
  buyAiBoost,
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
  signOut,
  saveMemory,
}

class IntelligenceAction {
  const IntelligenceAction({
    required this.id,
    required this.type,
    required this.label,
    required this.requiresConfirmation,
    this.toolId,
    this.operationId,
    this.requiresFreshConfirmation = false,
    this.destructive = false,
    this.payload = const <String, Object?>{},
  });

  final String id;

  /// Canonical capability identity. [id] remains a legacy presentation key.
  final String? toolId;

  /// App-owned proposal identity, allocated before presentation and persisted
  /// unchanged. Execution and conversation restoration must never re-mint it.
  final String? operationId;

  final IntelligenceActionType type;
  final String label;
  final bool requiresConfirmation;
  final bool requiresFreshConfirmation;
  final bool destructive;
  final Map<String, Object?> payload;

  IntelligenceAction copyWith({
    String? toolId,
    String? operationId,
    bool? requiresConfirmation,
    bool? requiresFreshConfirmation,
    bool? destructive,
    Map<String, Object?>? payload,
  }) => IntelligenceAction(
    id: id,
    toolId: toolId ?? this.toolId,
    operationId: operationId ?? this.operationId,
    type: type,
    label: label,
    requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
    requiresFreshConfirmation:
        requiresFreshConfirmation ?? this.requiresFreshConfirmation,
    destructive: destructive ?? this.destructive,
    payload: payload ?? this.payload,
  );
}
