part of 'intelligence_center_page.dart';

/// The production witness observes delivered auth events as well as the
/// synchronous owner. Tests can exercise A → B → A without remote requests.
final class CoachNativeOwnerWitness {
  const CoachNativeOwnerWitness({
    required this.readOwner,
    required this.changes,
  });

  final String? Function() readOwner;
  final Stream<String?> changes;
}

final coachNativeOwnerWitnessProvider = Provider<CoachNativeOwnerWitness?>((
  ref,
) {
  if (!AppEnvironment.supabaseRuntimeReady) return null;
  final auth = Supabase.instance.client.auth;
  return CoachNativeOwnerWitness(
    readOwner: () => auth.currentUser?.id,
    changes: auth.onAuthStateChange.map((state) => state.session?.user.id),
  );
});

final class _CoachMealOwnerHandle {
  const _CoachMealOwnerHandle({
    required this.database,
    required this.repository,
    required this.scope,
    required this.subscription,
  });

  final AppDatabase database;
  final MealRepository repository;
  final CoachMealOwnerScope scope;
  final StreamSubscription<String?>? subscription;

  void dispose() {
    scope.cancel();
    unawaited(subscription?.cancel());
  }
}

final class _PreparedCoachMealAction {
  _PreparedCoachMealAction({required this.action, required this.owner});

  final IntelligenceAction action;
  final _CoachMealOwnerHandle owner;
  CoachMealCommand? command;

  AppDatabase get database => owner.database;
  MealRepository get repository => owner.repository;
  CoachMealOwnerScope get scope => owner.scope;
  void dispose() => owner.dispose();
}

extension _CoachMealPreparation on _IntelligenceCenterPageState {
  _CoachMealOwnerHandle _captureCoachMealOwner() {
    final database = ref.read(databaseProvider);
    final repository = ref.read(mealRepositoryProvider);
    final witness = ref.read(coachNativeOwnerWitnessProvider);
    final epoch = conversationPersistenceEpoch;
    final scope = CoachMealOwnerScope(
      ownerId: database.localOwnerId,
      isCurrent: () =>
          mounted &&
          conversationReady &&
          epoch == conversationPersistenceEpoch &&
          identical(ref.read(databaseProvider), database) &&
          identical(ref.read(mealRepositoryProvider), repository) &&
          (witness == null || witness.readOwner() == database.localOwnerId),
    );
    final subscription = witness?.changes.listen((owner) {
      if (owner != database.localOwnerId) scope.cancel();
    }, onError: (Object _, StackTrace _) => scope.cancel());
    return _CoachMealOwnerHandle(
      database: database,
      repository: repository,
      scope: scope,
      subscription: subscription,
    );
  }

  Future<_PreparedCoachMealAction?> _prepareCoachMealAction(
    IntelligenceAction action,
  ) async {
    if (!const {
      IntelligenceActionType.quickAddMacros,
      IntelligenceActionType.updateMealItem,
      IntelligenceActionType.deleteMealItem,
      IntelligenceActionType.moveMealItem,
    }.contains(action.type)) {
      return null;
    }
    final operationId = action.operationId;
    if (operationId == null || action.toolId == null) {
      throw const CoachMealConflict(CoachMealConflictReason.operationMismatch);
    }
    final cached = preparedMealActions[operationId];
    if (cached != null) {
      if (cached.action.toolId != action.toolId ||
          cached.action.type != action.type ||
          !mapEquals(cached.action.payload, action.payload)) {
        throw const CoachMealConflict(
          CoachMealConflictReason.operationMismatch,
        );
      }
      cached.scope.check(cached.database.localOwnerId);
      return cached;
    }
    final owner = _captureCoachMealOwner();
    final database = owner.database;
    final repository = owner.repository;
    final scope = owner.scope;
    final prepared = _PreparedCoachMealAction(action: action, owner: owner);
    try {
      scope.check(database.localOwnerId);
      if (action.type == IntelligenceActionType.quickAddMacros) {
        final requestedDate = action.payload['date'];
        final date = requestedDate == null
            ? ref.read(intelligenceConversationClockProvider)()
            : DateTime.parse(requestedDate as String);
        double? number(String key) => (action.payload[key] as num?)?.toDouble();
        prepared.command = CoachMealCommand.quickMacros(
          operationId: operationId,
          date: date,
          mealType: action.payload['mealType']! as String,
          calories: number('calories'),
          protein: number('protein'),
          carbohydrates: number('carbohydrates'),
          fat: number('fat'),
          // A date-only proposal has no reported time of day. Freeze its
          // civil date instead of borrowing the clock from the later commit.
          occurredAt: date,
        );
      } else {
        final item = await repository.getMealItem(
          action.payload['itemId']! as int,
        );
        scope.check(database.localOwnerId);
        final expected = CoachMealItemVersion.fromItem(item);
        prepared.command = switch (action.type) {
          IntelligenceActionType.updateMealItem =>
            CoachMealCommand.updateQuantity(
              operationId: operationId,
              expected: expected,
              quantity: (action.payload['quantityGrams']! as num).toDouble(),
            ),
          IntelligenceActionType.deleteMealItem => CoachMealCommand.deleteItem(
            operationId: operationId,
            expected: expected,
          ),
          IntelligenceActionType.moveMealItem => CoachMealCommand.moveItem(
            operationId: operationId,
            expected: expected,
            mealType: action.payload['mealType']! as String,
          ),
          _ => throw StateError('Unexpected meal action'),
        };
      }
      if (prepared.command!.toolId != action.toolId) {
        throw const CoachMealConflict(
          CoachMealConflictReason.operationMismatch,
        );
      }
      scope.check(database.localOwnerId);
      preparedMealActions[operationId] = prepared;
      return prepared;
    } on Object {
      prepared.dispose();
      rethrow;
    }
  }

  void _disposePreparedCoachMealActions() {
    for (final prepared in preparedMealActions.values) {
      prepared.dispose();
    }
    preparedMealActions.clear();
    for (final owner in recoveredMealOwners) {
      owner.dispose();
    }
    recoveredMealOwners.clear();
  }
}
