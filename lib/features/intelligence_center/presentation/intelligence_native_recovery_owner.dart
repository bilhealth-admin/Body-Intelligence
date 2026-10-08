part of 'intelligence_center_page.dart';

/// A recovered Undo belongs to this visible conversation visit. Unlike an
/// already-confirmed in-flight write, it cannot survive route disposal.
final class _RecoveredCoachNativeOwner {
  _RecoveredCoachNativeOwner({
    required this.database,
    required this.repository,
    required this.memoryRepository,
    required this.scope,
  });

  final AppDatabase database;
  final CoachNativeCommandRepository repository;
  final CoachMemoryRepository memoryRepository;
  final CoachNativeOwnerScope scope;
  final closers = <VoidCallback>[];
  StreamSubscription<String?>? authSubscription;
  bool disposed = false;

  void dispose() {
    if (disposed) return;
    disposed = true;
    scope.cancel();
    unawaited(authSubscription?.cancel());
    authSubscription = null;
    for (final close in closers) {
      close();
    }
    closers.clear();
  }
}

extension _CoachNativeRecoveryOwner on _IntelligenceCenterPageState {
  _RecoveredCoachNativeOwner _captureRecoveredCoachNativeOwner() {
    final database = ref.read(databaseProvider);
    final preferences = ref.read(preferencesRepositoryProvider);
    final water = ref.read(waterRepositoryProvider);
    final weights = ref.read(weightRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);
    final goals = ref.read(goalRepositoryProvider);
    final measurements = ref.read(bodyMeasurementRepositoryProvider);
    final daily = ref.read(dailyLogRepositoryProvider);
    final life = ref.read(lifeContextRepositoryProvider);
    final dietCommand = ref.read(dietPlanCommandProvider);
    final witness = ref.read(coachNativeOwnerWitnessProvider);
    final epoch = conversationPersistenceEpoch;
    final generation = conversationLoadGeneration;
    final conversationId = activeConversationId;
    final scope = CoachNativeOwnerScope(
      ownerId: database.localOwnerId,
      isCurrent: () =>
          mounted &&
          conversationReady &&
          epoch == conversationPersistenceEpoch &&
          generation == conversationLoadGeneration &&
          conversationId == activeConversationId &&
          identical(conversationPreferences, preferences) &&
          preferences.localOwnerId == database.localOwnerId &&
          identical(ref.read(databaseProvider), database) &&
          identical(ref.read(preferencesRepositoryProvider), preferences) &&
          identical(ref.read(waterRepositoryProvider), water) &&
          identical(ref.read(weightRepositoryProvider), weights) &&
          identical(ref.read(userProfileRepositoryProvider), profiles) &&
          identical(ref.read(goalRepositoryProvider), goals) &&
          identical(ref.read(dailyLogRepositoryProvider), daily) &&
          identical(ref.read(lifeContextRepositoryProvider), life) &&
          identical(ref.read(dietPlanCommandProvider), dietCommand) &&
          identical(
            ref.read(bodyMeasurementRepositoryProvider),
            measurements,
          ) &&
          identical(ref.read(coachNativeOwnerWitnessProvider), witness) &&
          (witness == null || witness.readOwner() == database.localOwnerId),
    );
    scope.check(database.localOwnerId);
    final owner = _RecoveredCoachNativeOwner(
      database: database,
      repository: CoachNativeCommandRepository(
        database,
        preferences: preferences,
        water: water,
        weights: weights,
        profiles: profiles,
        goals: goals,
        measurements: measurements,
        healthCommands: _newCoachHealthAdapters(database),
      ),
      memoryRepository: CoachMemoryRepository(preferences: preferences),
      scope: scope,
    );
    void watch<T>(ProviderListenable<T> provider, T original) {
      final subscription = ref.listenManual(provider, (previous, next) {
        if (!identical(next, original)) scope.cancel();
      });
      owner.closers.add(subscription.close);
    }

    try {
      // Delivered A -> B -> A cannot reactivate the same recovered callback.
      owner.authSubscription = witness?.changes.listen((next) {
        if (next != database.localOwnerId) scope.cancel();
      }, onError: (Object _, StackTrace _) => scope.cancel());
      watch(databaseProvider, database);
      watch(preferencesRepositoryProvider, preferences);
      watch(waterRepositoryProvider, water);
      watch(weightRepositoryProvider, weights);
      watch(userProfileRepositoryProvider, profiles);
      watch(goalRepositoryProvider, goals);
      watch(bodyMeasurementRepositoryProvider, measurements);
      watch(dailyLogRepositoryProvider, daily);
      watch(lifeContextRepositoryProvider, life);
      watch(dietPlanCommandProvider, dietCommand);
      watch(coachNativeOwnerWitnessProvider, witness);
      scope.check(database.localOwnerId);
      return owner;
    } on Object {
      owner.dispose();
      rethrow;
    }
  }
}
