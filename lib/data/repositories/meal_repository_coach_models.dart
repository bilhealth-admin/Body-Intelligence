part of 'meal_repository.dart';

enum CoachMealCommandKind {
  quickMacros,
  quantity,
  remove,
  move,
  foods,
  replacement,
}

enum CoachMealResultState { committed, modified, undone }

enum CoachMealConflictReason {
  ownerChanged,
  operationMismatch,
  staleItem,
  missingItem,
  missingMeal,
  closedDay,
  invalidJournal,
  readbackUnavailable,
  invalidEvidence,
}

/// A rejected precondition is not a successful mutation or compensation.
final class CoachMealConflict implements Exception {
  const CoachMealConflict(this.reason, {this.committed = false});

  final CoachMealConflictReason reason;
  final bool committed;

  @override
  String toString() =>
      'CoachMealConflict(${reason.name}, committed=$committed)';
}

/// Captured by the native owner before any confirmation or repository await.
/// Once cancelled, a later A → B → A transition cannot reactivate this scope.
final class CoachMealOwnerScope {
  CoachMealOwnerScope({required this.ownerId, required this._isCurrent});

  final String? ownerId;
  final bool Function() _isCurrent;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  bool get isCurrent {
    if (_cancelled) return false;
    if (!_isCurrent()) _cancelled = true;
    return !_cancelled;
  }

  void check(String? databaseOwner, {bool committed = false}) {
    if (ownerId != databaseOwner || !isCurrent) {
      _cancelled = true;
      throw CoachMealConflict(
        CoachMealConflictReason.ownerChanged,
        committed: committed,
      );
    }
  }
}

final class CoachMealItemVersion {
  const CoachMealItemVersion({
    required this.id,
    required this.uuid,
    required this.revision,
  });

  factory CoachMealItemVersion.fromItem(MealItem item) => CoachMealItemVersion(
    id: item.id,
    uuid: item.uuid,
    revision: item.revision,
  );

  final int id;
  final String uuid;
  final int revision;

  Map<String, Object?> toJson() => {
    'id': id,
    'uuid': uuid,
    'revision': revision,
  };
}

/// Immutable, app-admitted arguments. The operation ID belongs to one proposal,
/// not to a tool type or a generated message label.
final class CoachMealCommand {
  CoachMealCommand._({
    required this.operationId,
    required this.kind,
    required Map<String, Object?> arguments,
    this.expectedItem,
  }) : arguments = _freezeCoachJson(arguments) as Map<String, Object?> {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_:-]{0,127}$').hasMatch(operationId)) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    final expected = expectedItem;
    if (expected != null &&
        (expected.id <= 0 || expected.uuid.isEmpty || expected.revision <= 0)) {
      throw ArgumentError('A mutation requires an existing item version');
    }
  }

  factory CoachMealCommand.quickMacros({
    required String operationId,
    required DateTime date,
    required String mealType,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
    DateTime? occurredAt,
  }) {
    _validateMealType(mealType);
    final values = [calories, protein, carbohydrates, fat];
    final limits = [10000, 2000, 2000, 2000];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value != null &&
          (!value.isFinite || value < 0 || value > limits[index])) {
        throw ArgumentError('Invalid reviewed macro quantity');
      }
    }
    if (!values.any((value) => value != null && value > 0)) {
      throw ArgumentError('At least one known positive nutrient is required');
    }
    return CoachMealCommand._(
      operationId: operationId,
      kind: CoachMealCommandKind.quickMacros,
      arguments: {
        'day': dayKeyFor(date),
        'mealType': mealType,
        'calories': calories,
        'protein': protein,
        'carbohydrates': carbohydrates,
        'fat': fat,
        if (occurredAt != null) 'occurredAt': occurredAt.toIso8601String(),
      },
    );
  }

  factory CoachMealCommand.updateQuantity({
    required String operationId,
    required CoachMealItemVersion expected,
    required double quantity,
    bool quantityInGrams = false,
  }) {
    if (!quantity.isFinite || quantity <= 0 || quantity > 100000) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    return CoachMealCommand._(
      operationId: operationId,
      kind: CoachMealCommandKind.quantity,
      expectedItem: expected,
      arguments: {
        'expected': expected.toJson(),
        'quantity': quantity,
        // Legacy native callers intentionally edit the stored serving unit.
        // A model tool's quantityGrams must never inherit that interpretation.
        // Include the unit in the digest so retry cannot change its meaning.
        if (quantityInGrams) 'quantityUnit': 'g',
      },
    );
  }

  factory CoachMealCommand.foods({
    required String operationId,
    required DateTime date,
    required String mealType,
    required CoachFoodReview review,
    DateTime? occurredAt,
  }) {
    _validateMealType(mealType);
    return CoachMealCommand._(
      operationId: operationId,
      kind: CoachMealCommandKind.foods,
      arguments: {
        'day': dayKeyFor(date),
        'mealType': mealType,
        'portions': review.items.map((item) => item.toJson()).toList(),
        if (occurredAt != null) 'occurredAt': occurredAt.toIso8601String(),
      },
    );
  }

  factory CoachMealCommand.replaceFood({
    required String operationId,
    required CoachMealItemVersion expected,
    required CoachFoodPortion replacement,
  }) => CoachMealCommand._(
    operationId: operationId,
    kind: CoachMealCommandKind.replacement,
    expectedItem: expected,
    arguments: {
      'expected': expected.toJson(),
      'replacement': replacement.toJson(),
    },
  );

  factory CoachMealCommand.deleteItem({
    required String operationId,
    required CoachMealItemVersion expected,
  }) => CoachMealCommand._(
    operationId: operationId,
    kind: CoachMealCommandKind.remove,
    expectedItem: expected,
    arguments: {'expected': expected.toJson()},
  );

  factory CoachMealCommand.moveItem({
    required String operationId,
    required CoachMealItemVersion expected,
    required String mealType,
  }) {
    _validateMealType(mealType);
    return CoachMealCommand._(
      operationId: operationId,
      kind: CoachMealCommandKind.move,
      expectedItem: expected,
      arguments: {'expected': expected.toJson(), 'mealType': mealType},
    );
  }

  final String operationId;
  final CoachMealCommandKind kind;
  final Map<String, Object?> arguments;
  final CoachMealItemVersion? expectedItem;

  String get toolId => switch (kind) {
    CoachMealCommandKind.quickMacros => 'quick_add_macros',
    CoachMealCommandKind.quantity => 'update_meal_item',
    CoachMealCommandKind.remove => 'delete_meal_item',
    CoachMealCommandKind.move => 'move_meal_item',
    CoachMealCommandKind.foods => 'log_foods',
    CoachMealCommandKind.replacement => 'replace_meal_item',
  };

  String get argumentsDigest => sha256
      .convert(utf8.encode(jsonEncode(_canonicalCoachJson(arguments))))
      .toString();

  static void _validateMealType(String mealType) {
    if (!const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(mealType)) {
      throw ArgumentError.value(mealType, 'mealType');
    }
  }
}

Object? _canonicalCoachJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonicalCoachJson(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalCoachJson).toList(growable: false);
  }
  return value;
}

Object? _freezeCoachJson(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freezeCoachJson(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeCoachJson));
  }
  return value;
}

/// A real repository readback; nutrients come from the saved diary item.
final class CoachMealSnapshot {
  const CoachMealSnapshot({
    required this.item,
    required this.meal,
    required this.foodName,
    this.arabicFoodName,
  });

  factory CoachMealSnapshot.fromJson(Map<String, dynamic> json) =>
      CoachMealSnapshot(
        item: MealItem.fromJson(Map<String, dynamic>.from(json['item'] as Map)),
        meal: Meal.fromJson(Map<String, dynamic>.from(json['meal'] as Map)),
        foodName: json['foodName'] as String,
        arabicFoodName: json['arabicFoodName'] as String?,
      );

  final MealItem item;
  final Meal meal;
  final String foodName;
  final String? arabicFoodName;

  double? known(TrackedNutrient nutrient, double value) {
    return MealFoodEvidence.read(item).value(nutrient);
  }

  Map<String, Object?> toJson() => {
    'item': item.toJson(),
    'meal': meal.toJson(),
    'foodName': foodName,
    'arabicFoodName': arabicFoodName,
  };

  Map<String, Object?> toReceiptPayload() => {
    'item_id': item.id,
    'item_uuid': item.uuid,
    'revision': item.revision,
    'meal_id': meal.id,
    'meal_uuid': meal.uuid,
    'meal_type': meal.type,
    'day': meal.dayKey,
    'name': foodName,
    'arabic_name': arabicFoodName,
    'quantity': item.quantity,
    'deleted': item.deletedAt != null,
    'calories': known(TrackedNutrient.calories, item.calories),
    'protein': known(TrackedNutrient.protein, item.protein),
    'carbohydrates': known(TrackedNutrient.carbohydrates, item.carbs),
    'fat': known(TrackedNutrient.fat, item.fats),
    'fiber': known(TrackedNutrient.fiber, item.fiber),
    'sodium_mg': known(TrackedNutrient.sodium, item.sodium),
    'potassium_mg': known(TrackedNutrient.potassium, item.potassium),
    'calcium_mg': known(TrackedNutrient.calcium, item.calcium),
    'magnesium_mg': known(TrackedNutrient.magnesium, item.magnesium),
    'phosphorus_mg': known(TrackedNutrient.phosphorus, item.phosphorus),
    'sugar_g': known(TrackedNutrient.sugar, item.sugar),
    'iron_mg': MealFoodEvidence.read(item).fullValue(FoodNutrient.iron),
    'vitamin_c_mg': MealFoodEvidence.read(
      item,
    ).fullValue(FoodNutrient.vitaminC),
    'food_evidence': MealFoodEvidence.read(item).portion?.toJson(),
    'nutrient_evidence_mask': item.nutrientEvidenceMask,
    'source': item.foodSourceSnapshot,
    'source_verified': item.foodVerifiedSnapshot,
    'serving_size': item.servingSizeSnapshot,
    'serving_unit': item.servingUnitSnapshot,
  };
}

final class CoachMealCommit {
  CoachMealCommit._({
    required this.operationId,
    required this.toolId,
    required this.argumentsDigest,
    required this.ownerScope,
    required this.kind,
    required this.committedAt,
    required Iterable<CoachMealSnapshot> before,
    required Iterable<CoachMealSnapshot> after,
    required Iterable<CoachMealSnapshot?> current,
    required this.state,
    required this.replayed,
    this.undoneAt,
  }) : before = List.unmodifiable(before),
       after = List.unmodifiable(after),
       current = List.unmodifiable(current);

  final String operationId;
  final String toolId;
  final String argumentsDigest;
  final String ownerScope;
  final CoachMealCommandKind kind;
  final DateTime committedAt;
  final List<CoachMealSnapshot> before;
  final List<CoachMealSnapshot> after;
  final List<CoachMealSnapshot?> current;
  final CoachMealResultState state;
  final bool replayed;
  final DateTime? undoneAt;

  bool get canUndo => state == CoachMealResultState.committed;

  Map<String, Object?> get beforePayload => {
    'exists': before.isNotEmpty,
    'items': before
        .map((row) => row.toReceiptPayload())
        .toList(growable: false),
  };

  Map<String, Object?> get afterPayload => {
    'state': state.name,
    'replayed': replayed,
    'items': after.map((row) => row.toReceiptPayload()).toList(growable: false),
    'current_items': current
        .map((row) => row?.toReceiptPayload())
        .toList(growable: false),
    'arguments_digest': argumentsDigest,
  };
}
