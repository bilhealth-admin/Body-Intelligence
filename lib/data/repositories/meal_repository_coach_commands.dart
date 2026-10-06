part of 'meal_repository.dart';

extension CoachMealCommands on MealRepository {
  /// A command, its item readbacks and its retry journal commit together.
  /// No receipt is returned until the transaction and durable readback finish.
  Future<CoachMealCommit> commitCoachMeal({
    required CoachMealCommand command,
    required CoachMealOwnerScope scope,
  }) async {
    scope.check(_database.localOwnerId);
    final replayed = await _database.transaction(() async {
      scope.check(_database.localOwnerId);
      final existing = await _readCoachJournal(command.operationId, scope);
      if (existing != null) {
        if (existing.toolId != command.toolId ||
            existing.argumentsDigest != command.argumentsDigest ||
            existing.kind != command.kind) {
          throw const CoachMealConflict(
            CoachMealConflictReason.operationMismatch,
          );
        }
        // This also covers an already-undone operation. A retry must never
        // silently apply the original command a second time.
        return true;
      }
      final before = <CoachMealSnapshot>[];
      final createdMeals = <Meal>[];
      final itemIds = <int>[];
      if (command.kind == CoachMealCommandKind.quickMacros) {
        itemIds.add(await _insertCoachMacros(command, scope, createdMeals));
      } else if (command.kind == CoachMealCommandKind.foods) {
        itemIds.addAll(await _insertCoachFoods(command, scope, createdMeals));
      } else {
        final expected = command.expectedItem!;
        final snapshot = await _requireCoachSnapshot(expected.id, scope);
        if (snapshot.item.deletedAt != null ||
            snapshot.item.uuid != expected.uuid ||
            snapshot.item.revision != expected.revision) {
          throw const CoachMealConflict(CoachMealConflictReason.staleItem);
        }
        if (snapshot.meal.deletedAt != null) {
          throw const CoachMealConflict(CoachMealConflictReason.missingMeal);
        }
        await _requireCoachOpenDay(snapshot.meal.dayKey, scope);
        before.add(snapshot);
        await _mutateCoachItem(command, snapshot, scope, createdMeals);
        itemIds.add(expected.id);
      }
      final after = <CoachMealSnapshot>[];
      for (final id in itemIds) {
        after.add(await _requireCoachSnapshot(id, scope));
      }
      _verifyCoachFoodReadback(command, after);
      final journal = _CoachMealJournal(
        operationId: command.operationId,
        toolId: command.toolId,
        argumentsDigest: command.argumentsDigest,
        ownerScope: _coachOwnerKey,
        kind: command.kind,
        committedAt: DateTime.now(),
        before: before,
        after: after,
        createdMeals: createdMeals,
      );
      await _writeCoachJournal(journal, scope);
      scope.check(_database.localOwnerId);
      return false;
    });
    return _coachCommitReadback(command.operationId, scope, replayed: replayed);
  }

  /// Recovery reads the same durable journal used by command retry and Undo.
  Future<CoachMealCommit?> readCoachMealOperation({
    required String operationId,
    required CoachMealOwnerScope scope,
  }) async {
    scope.check(_database.localOwnerId);
    if (await _readCoachJournal(operationId, scope) == null) return null;
    return _coachCommitReadback(operationId, scope, replayed: true);
  }
}

extension _CoachMealCommandWrites on MealRepository {
  Future<int> _insertCoachMacros(
    CoachMealCommand command,
    CoachMealOwnerScope scope,
    List<Meal> createdMeals,
  ) async {
    final args = command.arguments;
    final day = args['day']! as String;
    await _requireCoachOpenDay(day, scope);
    final date = DateTime.parse(day);
    final clock = args['occurredAt'] == null
        ? DateTime.now()
        : DateTime.parse(args['occurredAt']! as String);
    final timestamp = DateTime(
      date.year,
      date.month,
      date.day,
      clock.hour,
      clock.minute,
    );
    final meal = await _coachDestination(
      date: timestamp,
      type: args['mealType']! as String,
      scope: scope,
      createdMeals: createdMeals,
    );
    double? value(String key) => (args[key] as num?)?.toDouble();
    final mask = NutrientEvidenceMask.fromValues(
      calories: value('calories'),
      protein: value('protein'),
      carbohydrates: value('carbohydrates'),
      fat: value('fat'),
    );
    final label =
        'Quick Add • ${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
    final foodId = await _coachAwait(
      () => _database
          .into(_database.foods)
          .insert(
            FoodsCompanion.insert(
              name: label,
              category: const Value('quick_add'),
              servingSize: const Value(1),
              servingUnit: const Value('entry'),
              calories: value('calories') ?? 0,
              protein: value('protein') ?? 0,
              carbs: value('carbohydrates') ?? 0,
              fats: value('fat') ?? 0,
              nutrientEvidenceMask: Value(mask),
              isCustom: const Value(true),
              source: const Value('quick_add'),
              verified: const Value(false),
            ),
          ),
      scope,
    );
    final position = await _nextCoachPosition(meal.id, scope);
    return _coachAwait(
      () => _database
          .into(_database.mealItems)
          .insert(
            MealItemsCompanion.insert(
              mealId: meal.id,
              foodId: foodId,
              quantity: const Value(1),
              position: Value(position),
              calories: Value(value('calories') ?? 0),
              protein: Value(value('protein') ?? 0),
              carbs: Value(value('carbohydrates') ?? 0),
              fats: Value(value('fat') ?? 0),
              nutrientEvidenceMask: Value(mask),
              foodSourceSnapshot: const Value('quick_add'),
              foodVerifiedSnapshot: const Value(false),
              servingSizeSnapshot: const Value(1),
              servingUnitSnapshot: const Value('entry'),
              syncStatus: const Value('pending'),
            ),
          ),
      scope,
    );
  }

  Future<void> _mutateCoachItem(
    CoachMealCommand command,
    CoachMealSnapshot snapshot,
    CoachMealOwnerScope scope,
    List<Meal> createdMeals,
  ) async {
    final item = snapshot.item;
    final now = DateTime.now();
    switch (command.kind) {
      case CoachMealCommandKind.quickMacros:
      case CoachMealCommandKind.foods:
        throw StateError('A Quick Add creates a new item');
      case CoachMealCommandKind.replacement:
        final portion = CoachFoodPortion.fromJson(
          command.arguments['replacement'],
        );
        _checkCoachFoodOwner(portion, scope);
        final foodId = await _insertCoachFoodBasis(portion, scope);
        await _writeCoachItemVersion(
          item,
          _coachFoodValues(portion).copyWith(
            foodId: Value(foodId),
            updatedAt: Value(now),
            revision: Value(item.revision + 1),
          ),
          scope,
        );
      case CoachMealCommandKind.quantity:
        await _coachAwait(
          () => updateMealItem(
            id: item.id,
            quantity: (command.arguments['quantity']! as num).toDouble(),
          ),
          scope,
        );
      case CoachMealCommandKind.remove:
        await _writeCoachItemVersion(
          item,
          MealItemsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            revision: Value(item.revision + 1),
            syncStatus: const Value('pendingDelete'),
          ),
          scope,
        );
      case CoachMealCommandKind.move:
        final destination = await _coachDestination(
          date: snapshot.meal.date,
          type: command.arguments['mealType']! as String,
          scope: scope,
          createdMeals: createdMeals,
        );
        if (destination.id == snapshot.meal.id) return;
        final position = await _nextCoachPosition(destination.id, scope);
        await _writeCoachItemVersion(
          item,
          MealItemsCompanion(
            mealId: Value(destination.id),
            position: Value(position),
            updatedAt: Value(now),
            revision: Value(item.revision + 1),
            syncStatus: const Value('pending'),
          ),
          scope,
        );
    }
  }

  Future<Meal> _coachDestination({
    required DateTime date,
    required String type,
    required CoachMealOwnerScope scope,
    required List<Meal> createdMeals,
  }) async {
    final day = dayKeyFor(date);
    final existing = await _coachAwait(
      () =>
          (_database.select(_database.meals)
                ..where(
                  (row) =>
                      row.dayKey.equals(day) &
                      row.type.equals(type) &
                      row.deletedAt.isNull(),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.id)])
                ..limit(1))
              .getSingleOrNull(),
      scope,
    );
    if (existing != null) return existing;
    final id = await _coachAwait(
      () => _database
          .into(_database.meals)
          .insert(
            MealsCompanion.insert(
              date: date,
              dayKey: day,
              name: Value(type),
              type: Value(type),
              syncStatus: const Value('pending'),
            ),
          ),
      scope,
    );
    final created = await _coachAwait(
      () => (_database.select(
        _database.meals,
      )..where((row) => row.id.equals(id))).getSingle(),
      scope,
    );
    createdMeals.add(created);
    return created;
  }

  Future<int> _nextCoachPosition(int mealId, CoachMealOwnerScope scope) async {
    final last = await _coachAwait(
      () =>
          (_database.select(_database.mealItems)
                ..where(
                  (row) => row.mealId.equals(mealId) & row.deletedAt.isNull(),
                )
                ..orderBy([(row) => OrderingTerm.desc(row.position)])
                ..limit(1))
              .getSingleOrNull(),
      scope,
    );
    return (last?.position ?? 0) + 1;
  }

  Future<void> _writeCoachItemVersion(
    MealItem expected,
    MealItemsCompanion values,
    CoachMealOwnerScope scope,
  ) async {
    final affected = await _coachAwait(
      () =>
          (_database.update(_database.mealItems)..where(
                (row) =>
                    row.id.equals(expected.id) &
                    row.uuid.equals(expected.uuid) &
                    row.revision.equals(expected.revision),
              ))
              .write(values),
      scope,
    );
    if (affected != 1) {
      throw const CoachMealConflict(CoachMealConflictReason.staleItem);
    }
  }
}
