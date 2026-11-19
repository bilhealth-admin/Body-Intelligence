part of 'bil_smart_plan_page.dart';

const _creationRetryErrorPrefix = 'smart_plan_creation_retry:';

// UI-only input recovery, never a saved/approved plan or cloud/AI payload.
// An auth visit change retires it even when the same owner later returns.
final class _PlanCreationAttempt {
  _PlanCreationAttempt(this.owner, this.epoch, this.options);
  final String owner;
  final int epoch;
  final _PlanOptions options;
  BilSmartPlan? generatedPlan;
}

extension _BilSmartPlanCreationFlow on _BilSmartPlanPageState {
  String _failureText() {
    final failure = _error ?? '';
    final code = failure.startsWith(_creationRetryErrorPrefix)
        ? failure.substring(_creationRetryErrorPrefix.length)
        : failure;
    return smartPlanLoadFailureMessage(code, _t);
  }

  bool _currentCreation(_PlanCreationAttempt attempt) =>
      mounted &&
      identical(_creationAttempt, attempt) &&
      _owner == attempt.owner &&
      _ownerEpoch == attempt.epoch &&
      _repository.preferences.localOwnerId == attempt.owner;

  void _finishRecoveredCreation(
    _PlanCreationAttempt attempt,
    BilSmartPlan generated,
  ) {
    if (!_currentCreation(attempt)) return;
    if (_error != null) {
      _mutate(() => _error = _creationRetryErrorPrefix + _error!);
      return;
    }
    if (_plan?.encode() != generated.encode()) {
      throw StateError('smart_plan_revision_conflict');
    }
    _checkAccess();
    // The native caller receives the original committed ID/revision, never a
    // second save. The caller independently validates the receipt and owner.
    _returnReceipt(_plan!);
    _creationAttempt = null;
  }

  Future<void> _retryPlanAction() async {
    if (_busy || _reviewDepth > 0) return;
    final attempt = _creationAttempt;
    if (attempt == null ||
        !_currentCreation(attempt) ||
        !(_error?.startsWith(_creationRetryErrorPrefix) ?? false)) {
      _creationAttempt = null;
      await _load();
      return;
    }
    _mutate(() => _busy = true);
    try {
      final generated = attempt.generatedPlan;
      if (generated != null) {
        // A repository readback can fail after SQLite already committed. Never
        // generate/save another ID until that outcome is read successfully.
        final repository = _repository;
        final saved = await repository.readFor(attempt.owner);
        if (!_currentCreation(attempt)) return;
        final draft = await repository.readDraft(attempt.owner);
        if (!_currentCreation(attempt)) return;
        if (saved?.encode() == generated.encode()) {
          _mutate(() => _busy = false);
          await _load(preserveCreationAttempt: true);
          _finishRecoveredCreation(attempt, generated);
          return;
        }
        if (draft?.encode() == generated.encode()) {
          _mutate(() => _busy = false);
          await _openDraft();
          _finishRecoveredCreation(attempt, generated);
          return;
        }
        if (saved?.id == generated.id || draft != null) {
          throw StateError('smart_plan_revision_conflict');
        }
      }
      if (!_currentCreation(attempt)) return;
      _mutate(() => _busy = false);
      // Reopen the same owner's choices for an explicit submit; no hidden
      // retry of generation, safety validation, approval or a storage write.
      await _createPlan(initialOptions: attempt.options);
    } on Object catch (error) {
      if (!_currentCreation(attempt)) return;
      _mutate(() {
        _busy = false;
        _error =
            _creationRetryErrorPrefix + classifySmartPlanWriteFailure(error);
      });
    }
  }

  Future<void> _createPlan({_PlanOptions? initialOptions}) async {
    if (widget.privacyOnly) return;
    final owner = _owner;
    final epoch = _ownerEpoch;
    if (_busy || owner == null) return;
    final existingDraft = _plan == null
        ? null
        : await _repository.readDraft(owner);
    if (!mounted || _owner != owner || epoch != _ownerEpoch) return;
    if (existingDraft != null) {
      await _openDraft();
      return;
    }
    if (!mounted) return;
    final request = await _reviewSurface(
      () => showBilModalBottomSheet<_PlanOptions>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => _PlanCreationSheet(
          isCurrent: () =>
              mounted &&
              _owner == owner &&
              _ownerEpoch == epoch &&
              ref.read(preferencesRepositoryProvider).localOwnerId == owner,
          initialOptions: initialOptions,
          initialHorizon:
              BilPlanHorizon.values
                  .where(
                    (value) =>
                        value.name == widget.toolRequest?.arguments['horizon'],
                  )
                  .firstOrNull ??
              _plan?.horizon,
          initialFocus:
              BilPlanFocus.values
                  .where(
                    (value) =>
                        value.name == widget.toolRequest?.arguments['focus'],
                  )
                  .firstOrNull ??
              _plan?.focus,
          initialSetup: _plan?.setup,
          initialSessionsPerWeek: _plan?.days
              .take(7)
              .where((day) => day.workout != null)
              .length,
        ),
      ),
    );
    if (!mounted ||
        request == null ||
        owner != _owner ||
        epoch != _ownerEpoch) {
      return;
    }
    final attempt = _PlanCreationAttempt(owner, epoch, request);
    _creationAttempt = attempt;
    _mutate(() => _busy = true);
    try {
      _checkAccess();
      final dietary = await ref
          .read(dietaryPreferencesRepositoryProvider)
          .read();
      final catalog = const BilSmartPlanCatalog();
      final gym = request.focus == BilPlanFocus.nutrition
          ? <BilVerifiedWorkout>[]
          : request.setup?.environment == BilPlanEnvironment.home
          ? await catalog.homeSessions(request.setup!)
          : await catalog.gymSessions(
              sessionMinutes: request.setup!.sessionMinutes,
            );
      final recipes = request.focus == BilPlanFocus.training
          ? <BilVerifiedRecipe>[]
          : await catalog.sourcedRecipes(
              dietary: dietary,
              preferences: MealPlanPreferences(diet: request.diet!),
            );
      if (!mounted || _owner != owner || epoch != _ownerEpoch) return;
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getProfile();
      if (!mounted || epoch != _ownerEpoch) return;
      final goal = await ref.read(goalRepositoryProvider).getActive();
      if (!mounted || epoch != _ownerEpoch) return;
      final setup = request.setup == null
          ? null
          : BilPlanSetup(
              environment: request.setup!.environment,
              experience: request.setup!.experience,
              sessionMinutes: request.setup!.sessionMinutes,
              equipment: request.setup!.equipment,
              preferredTime: request.setup!.preferredTime,
              goalId: goal?.uuid,
            );
      final start = ref.read(bilSmartPlanClockProvider)();
      final snapshot = await BilSmartPlanNutritionGoals.readSavedSnapshot(
        _repository.preferences,
      );
      final schedule = await ref
          .read(nutritionGoalScheduleRepositoryProvider)
          .read();
      final nutritionTargets = BilSmartPlanNutritionGoals.forPlan(
        start: start,
        horizon: request.horizon,
        snapshot: snapshot,
        schedule: schedule,
      );
      final latestWeight = await ref
          .read(weightRepositoryProvider)
          .watchLatestWeight()
          .first;
      if (!mounted || epoch != _ownerEpoch) return;
      final targetCalories =
          nutritionTargets.values
              .map((target) => target.values['kcal']!)
              .toList()
            ..sort();
      final creation = BilPlanCreationRequest(
        ownerId: owner,
        planId: const Uuid().v4(),
        startOn: start,
        nutritionTargets: nutritionTargets,
        requestedDailyCalories: targetCalories.firstOrNull?.round(),
        targetWeightKg: goal?.targetWeight,
        currentWeightKg: latestWeight?.weight,
        targetBy: goal?.targetDate,
        horizon: request.horizon,
        focus: request.focus,
        workoutsPerWeek: request.focus == BilPlanFocus.nutrition
            ? 0
            : request.workoutsPerWeek,
        confirmedPreferences: request.confirmedPreferences,
        adultConfirmed: request.confirmedPreferences,
        ageYears: profile?.age,
        workoutCatalog: gym,
        recipeCatalog: recipes,
        highRiskSymptoms: request.highRiskSymptoms,
        underMedicalReview: request.needsMedicalReview,
        setup: setup,
        phases:
            request.focus == BilPlanFocus.nutrition ||
                setup?.environment == BilPlanEnvironment.home
            ? const []
            : await const BilSmartPlanPrescriptions().phases(),
      );
      final safety = BilPlanSafety.assess(creation);
      if (safety.result != BilPlanSafetyResult.ready) {
        throw StateError(
          'smart_plan_requires_review:${safety.reasons.join(',')}',
        );
      }
      final plan = const BilSmartPlanEngine().generate(
        creation,
        ref.read(bilSmartPlanClockProvider)(),
      );
      if (!_currentCreation(attempt)) return;
      attempt.generatedPlan = plan;
      await _save(plan, prior: 0);
      if (_currentCreation(attempt)) {
        if (_error == null && _plan?.id == plan.id) {
          _creationAttempt = null;
        } else if (_error != null) {
          // _save owns general write failures; only this creation caller tags
          // its own error for input recovery, never a later unrelated action.
          _mutate(() => _error = _creationRetryErrorPrefix + _error!);
        }
      }
    } on Object catch (error) {
      if (!_currentCreation(attempt)) return;
      _mutate(() {
        _busy = false;
        _error = _creationRetryErrorPrefix + error.toString();
      });
    }
  }
}
