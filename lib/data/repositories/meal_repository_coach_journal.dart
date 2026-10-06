part of 'meal_repository.dart';

final class _CoachMealJournal {
  _CoachMealJournal({
    required this.operationId,
    required this.toolId,
    required this.argumentsDigest,
    required this.ownerScope,
    required this.kind,
    required this.committedAt,
    required this.before,
    required this.after,
    required this.createdMeals,
    this.undoneAt,
    this.undoAfter = const [],
  });

  factory _CoachMealJournal.decode(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['schema'] != 1) throw const FormatException('Journal schema');
      List<CoachMealSnapshot> snapshots(String key) => (data[key] as List)
          .map(
            (value) => CoachMealSnapshot.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false);
      final journal = _CoachMealJournal(
        operationId: data['operationId'] as String,
        toolId: data['toolId'] as String,
        argumentsDigest: data['argumentsDigest'] as String,
        ownerScope: data['ownerScope'] as String,
        kind: CoachMealCommandKind.values.byName(data['kind'] as String),
        committedAt: DateTime.parse(data['committedAt'] as String),
        before: snapshots('before'),
        after: snapshots('after'),
        createdMeals: (data['createdMeals'] as List)
            .map(
              (value) => Meal.fromJson(Map<String, dynamic>.from(value as Map)),
            )
            .toList(growable: false),
        undoneAt: data['undoneAt'] == null
            ? null
            : DateTime.parse(data['undoneAt'] as String),
        undoAfter: snapshots('undoAfter'),
      );
      if (journal.after.isEmpty ||
          journal.after.map((row) => row.item.id).toSet().length !=
              journal.after.length ||
          (journal.undoneAt != null &&
              journal.undoAfter.length != journal.after.length)) {
        throw const FormatException('Journal rows');
      }
      return journal;
    } on Object {
      throw const CoachMealConflict(CoachMealConflictReason.invalidJournal);
    }
  }

  final String operationId;
  final String toolId;
  final String argumentsDigest;
  final String ownerScope;
  final CoachMealCommandKind kind;
  final DateTime committedAt;
  final List<CoachMealSnapshot> before;
  final List<CoachMealSnapshot> after;
  final List<Meal> createdMeals;
  final DateTime? undoneAt;
  final List<CoachMealSnapshot> undoAfter;

  _CoachMealJournal compensated(
    DateTime at,
    List<CoachMealSnapshot> readback,
  ) => _CoachMealJournal(
    operationId: operationId,
    toolId: toolId,
    argumentsDigest: argumentsDigest,
    ownerScope: ownerScope,
    kind: kind,
    committedAt: committedAt,
    before: before,
    after: after,
    createdMeals: createdMeals,
    undoneAt: at,
    undoAfter: readback,
  );

  String encode() => jsonEncode({
    'schema': 1,
    'operationId': operationId,
    'toolId': toolId,
    'argumentsDigest': argumentsDigest,
    'ownerScope': ownerScope,
    'kind': kind.name,
    'committedAt': committedAt.toIso8601String(),
    'before': before.map((row) => row.toJson()).toList(growable: false),
    'after': after.map((row) => row.toJson()).toList(growable: false),
    'createdMeals': createdMeals
        .map((row) => row.toJson())
        .toList(growable: false),
    'undoneAt': undoneAt?.toIso8601String(),
    'undoAfter': undoAfter.map((row) => row.toJson()).toList(growable: false),
  });
}

extension _CoachMealJournalStorage on MealRepository {
  String get _coachOwnerKey =>
      LocalDatabaseScope.keyForOwner(_database.localOwnerId);

  String _coachJournalKey(String operationId) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_:-]{0,127}$').hasMatch(operationId)) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    return 'coachMealOperationV1.$_coachOwnerKey.$operationId';
  }

  Future<T> _coachAwait<T>(
    Future<T> Function() operation,
    CoachMealOwnerScope scope, {
    bool committed = false,
  }) async {
    scope.check(_database.localOwnerId, committed: committed);
    final result = await operation();
    scope.check(_database.localOwnerId, committed: committed);
    return result;
  }

  Future<_CoachMealJournal?> _readCoachJournal(
    String operationId,
    CoachMealOwnerScope scope, {
    bool committed = false,
  }) async {
    final raw = await _coachAwait(
      () => PreferencesRepository(_database).get(_coachJournalKey(operationId)),
      scope,
      committed: committed,
    );
    if (raw == null) return null;
    final journal = _CoachMealJournal.decode(raw);
    if (journal.ownerScope != _coachOwnerKey ||
        journal.operationId != operationId) {
      throw const CoachMealConflict(CoachMealConflictReason.invalidJournal);
    }
    return journal;
  }

  Future<void> _writeCoachJournal(
    _CoachMealJournal journal,
    CoachMealOwnerScope scope,
  ) => _coachAwait(
    () => PreferencesRepository(_database).setManyInCurrentTransaction({
      _coachJournalKey(journal.operationId): journal.encode(),
    }),
    scope,
  );

  Future<void> _requireCoachOpenDay(
    String dayKey,
    CoachMealOwnerScope scope,
  ) async {
    final log = await _coachAwait(
      () => (_database.select(
        _database.dailyLogs,
      )..where((row) => row.dayKey.equals(dayKey))).getSingleOrNull(),
      scope,
    );
    if (log?.lifecycleState == 'closed' || log?.closedAt != null) {
      throw const CoachMealConflict(CoachMealConflictReason.closedDay);
    }
  }

  Future<CoachMealSnapshot?> _readCoachSnapshot(
    int id,
    CoachMealOwnerScope scope, {
    bool committed = false,
  }) async {
    final item = await _coachAwait(
      () => (_database.select(
        _database.mealItems,
      )..where((row) => row.id.equals(id))).getSingleOrNull(),
      scope,
      committed: committed,
    );
    if (item == null) return null;
    final meal = await _coachAwait(
      () => (_database.select(
        _database.meals,
      )..where((row) => row.id.equals(item.mealId))).getSingleOrNull(),
      scope,
      committed: committed,
    );
    final food = await _coachAwait(
      () => (_database.select(
        _database.foods,
      )..where((row) => row.id.equals(item.foodId))).getSingleOrNull(),
      scope,
      committed: committed,
    );
    if (meal == null || food == null) return null;
    final evidence = MealFoodEvidence.read(item, ownerKey: _coachOwnerKey);
    if (!evidence.isValid) {
      throw CoachMealConflict(
        CoachMealConflictReason.invalidEvidence,
        committed: committed,
      );
    }
    return CoachMealSnapshot(
      item: item,
      meal: meal,
      foodName: evidence.portion?.food.name ?? food.name,
      arabicFoodName: evidence.isModern ? null : food.arabicName,
    );
  }

  Future<CoachMealSnapshot> _requireCoachSnapshot(
    int id,
    CoachMealOwnerScope scope,
  ) async =>
      await _readCoachSnapshot(id, scope) ??
      (throw const CoachMealConflict(CoachMealConflictReason.missingItem));

  // Sync acknowledgements may change metadata without changing the diary
  // version. Every business field and the original identity still must match.
  bool _sameCoachItem(MealItem expected, MealItem actual) =>
      expected.copyWith(
        updatedAt: actual.updatedAt,
        syncStatus: actual.syncStatus,
      ) ==
      actual;

  bool _sameCoachMeal(Meal expected, Meal actual) =>
      expected.copyWith(
        updatedAt: actual.updatedAt,
        syncStatus: actual.syncStatus,
      ) ==
      actual;

  Future<CoachMealCommit> _coachCommitReadback(
    String operationId,
    CoachMealOwnerScope scope, {
    required bool replayed,
  }) async {
    try {
      final result = await _database.transaction(
        () =>
            _readCoachCommittedSnapshot(operationId, scope, replayed: replayed),
      );
      scope.check(_database.localOwnerId, committed: true);
      return result;
    } on CoachMealConflict catch (error) {
      throw CoachMealConflict(error.reason, committed: true);
    } on Object {
      throw const CoachMealConflict(
        CoachMealConflictReason.readbackUnavailable,
        committed: true,
      );
    }
  }

  Future<CoachMealCommit> _readCoachCommittedSnapshot(
    String operationId,
    CoachMealOwnerScope scope, {
    required bool replayed,
  }) async {
    final journal = await _readCoachJournal(
      operationId,
      scope,
      committed: true,
    );
    if (journal == null) {
      throw const CoachMealConflict(
        CoachMealConflictReason.invalidJournal,
        committed: true,
      );
    }
    final expected = journal.undoneAt == null
        ? journal.after
        : journal.undoAfter;
    final current = <CoachMealSnapshot?>[];
    var unchanged = true;
    for (final row in expected) {
      final actual = await _readCoachSnapshot(
        row.item.id,
        scope,
        committed: true,
      );
      current.add(actual);
      unchanged =
          unchanged &&
          actual != null &&
          _sameCoachItem(row.item, actual.item) &&
          _sameCoachMeal(row.meal, actual.meal);
    }
    return CoachMealCommit._(
      operationId: journal.operationId,
      toolId: journal.toolId,
      argumentsDigest: journal.argumentsDigest,
      ownerScope: journal.ownerScope,
      kind: journal.kind,
      committedAt: journal.committedAt,
      before: journal.before,
      after: journal.after,
      current: current,
      state: journal.undoneAt != null
          ? CoachMealResultState.undone
          : (unchanged
                ? CoachMealResultState.committed
                : CoachMealResultState.modified),
      replayed: replayed,
      undoneAt: journal.undoneAt,
    );
  }
}
