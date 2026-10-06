part of 'intelligence_center_page.dart';

final class _PreparedCoachNativeAction {
  _PreparedCoachNativeAction({
    required this.action,
    required this.database,
    required this.repository,
    required this.memoryRepository,
    required this.scope,
    required this.conversationEpoch,
  });

  final IntelligenceAction action;
  final AppDatabase database;
  final CoachNativeCommandRepository repository;
  final CoachMemoryRepository memoryRepository;
  final CoachNativeOwnerScope scope;
  final int conversationEpoch;
  CoachNativeCommand? command;
  StreamSubscription<String?>? subscription;
  ProviderSubscription<AppDatabase>? databaseSubscription;
  bool confirmedCommitInFlight = false;
  bool routeClosed = false;
  bool disposed = false;

  void closeRoute({bool cancelConfirmedCommit = false}) {
    routeClosed = true;
    if (!confirmedCommitInFlight || cancelConfirmedCommit) dispose();
  }

  void finishCommit() {
    confirmedCommitInFlight = false;
    if (routeClosed) dispose();
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    scope.cancel();
    databaseSubscription?.close();
    unawaited(subscription?.cancel());
  }
}

extension _CoachNativePreparation on _IntelligenceCenterPageState {
  Future<_PreparedCoachNativeAction?> _prepareCoachNativeAction(
    IntelligenceAction action,
  ) async {
    if (!const {
          IntelligenceActionType.addWater,
          IntelligenceActionType.addWeight,
          IntelligenceActionType.updateGoal,
          IntelligenceActionType.saveMeasurements,
          IntelligenceActionType.saveMemory,
        }.contains(action.type) ||
        action.type == IntelligenceActionType.addWeight &&
            action.payload['weightKg'] == null) {
      return null;
    }
    final operationId = action.operationId;
    final toolId = action.toolId;
    if (operationId == null || toolId == null) {
      throw const CoachNativeConflict(
        CoachNativeConflictReason.operationMismatch,
      );
    }
    final cached = preparedNativeActions[operationId];
    if (cached != null) {
      if (cached.action.toolId != toolId ||
          cached.action.type != action.type ||
          !mapEquals(cached.action.payload, action.payload)) {
        throw const CoachNativeConflict(
          CoachNativeConflictReason.operationMismatch,
        );
      }
      cached.scope.check(cached.database.localOwnerId);
      return cached;
    }
    final database = ref.read(databaseProvider);
    final water = ref.read(waterRepositoryProvider);
    final weights = ref.read(weightRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);
    final goals = ref.read(goalRepositoryProvider);
    final measurements = ref.read(bodyMeasurementRepositoryProvider);
    final preferences = ref.read(preferencesRepositoryProvider);
    if (!identical(preferences, conversationPreferences) ||
        preferences.localOwnerId != database.localOwnerId) {
      throw const CoachNativeConflict(CoachNativeConflictReason.ownerChanged);
    }
    final witness = ref.read(coachNativeOwnerWitnessProvider);
    final epoch = conversationPersistenceEpoch;
    late final _PreparedCoachNativeAction prepared;
    final scope = CoachNativeOwnerScope(
      ownerId: database.localOwnerId,
      isCurrent: () {
        if (conversationPersistenceEpoch != epoch ||
            witness != null && witness.readOwner() != database.localOwnerId) {
          return false;
        }
        if (!mounted) return prepared.confirmedCommitInFlight;
        return identical(ref.read(databaseProvider), database) &&
            identical(ref.read(waterRepositoryProvider), water) &&
            identical(ref.read(weightRepositoryProvider), weights) &&
            identical(ref.read(userProfileRepositoryProvider), profiles) &&
            identical(ref.read(goalRepositoryProvider), goals) &&
            identical(
              ref.read(bodyMeasurementRepositoryProvider),
              measurements,
            ) &&
            identical(ref.read(preferencesRepositoryProvider), preferences);
      },
    );
    prepared = _PreparedCoachNativeAction(
      action: action,
      database: database,
      repository: CoachNativeCommandRepository(
        database,
        water: water,
        weights: weights,
        profiles: profiles,
        goals: goals,
        measurements: measurements,
        preferences: preferences,
      ),
      memoryRepository: CoachMemoryRepository(preferences: preferences),
      scope: scope,
      conversationEpoch: epoch,
    );
    prepared.subscription = witness?.changes.listen((owner) {
      if (owner != database.localOwnerId) scope.cancel();
    }, onError: (Object _, StackTrace _) => scope.cancel());
    prepared.databaseSubscription = ref.listenManual(databaseProvider, (
      previous,
      next,
    ) {
      if (!identical(next, database)) scope.cancel();
    });
    try {
      prepared.command = await prepared.repository.prepare(
        toolId: toolId,
        operationId: operationId,
        arguments: action.payload,
        scope: scope,
        now: ref.read(intelligenceConversationClockProvider)(),
      );
      scope.check(database.localOwnerId);
      preparedNativeActions[operationId] = prepared;
      return prepared;
    } on Object {
      prepared.dispose();
      rethrow;
    }
  }

  void _disposePreparedCoachNativeActions({
    bool cancelConfirmedCommit = false,
  }) {
    for (final prepared in preparedNativeActions.values) {
      prepared.closeRoute(cancelConfirmedCommit: cancelConfirmedCommit);
    }
    preparedNativeActions.clear();
  }
}
