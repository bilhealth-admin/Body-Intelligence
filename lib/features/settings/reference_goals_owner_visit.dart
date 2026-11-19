part of 'reference_goals_page.dart';

final class _ReferenceGoalVisit {
  const _ReferenceGoalVisit(this.database, this.preferences, this.isCurrent);
  final AppDatabase database;
  final PreferencesRepository preferences;
  final bool Function() isCurrent;
  bool get current => isCurrent();
  void check() {
    if (!current) {
      throw StateError('reference_goals_owner_changed');
    }
  }
}

extension _ReferenceGoalOwnerVisit on _ReferenceGoalsPageState {
  void _watchGoalOwner() {
    ref.listenManual(userProfileProvider, (previous, next) {
      // Loading/error can retain the last data. Retire only when a resolved
      // profile identity actually changes, including resolved deletion.
      final resolved = next.asData;
      if (next.isLoading || next.hasError || resolved == null) {
        return;
      }
      final uuid = resolved.value?.uuid;
      if (_goalResolvedProfileUuid != uuid) {
        _goalResolvedProfileUuid = uuid;
        _retireGoalVisit();
      }
    }, fireImmediately: true);
    ref.listenManual(profileAuthIdentityProvider, (previous, next) {
      if (previous?.asData?.value.ownerId != next.asData?.value.ownerId ||
          previous?.isLoading != next.isLoading ||
          previous?.hasError != next.hasError) {
        _retireGoalVisit();
      }
    });
    ref.listenManual(databaseProvider, (previous, next) {
      if (!identical(previous, next)) {
        _retireGoalVisit();
      }
    });
    ref.listenManual(preferencesRepositoryProvider, (previous, next) {
      if (!identical(previous, next)) {
        _retireGoalVisit();
      }
    });
  }

  void _retireGoalVisit() {
    _goalOwnerEpoch++;
    // Retire synchronously even during a provider rebuild, but notify Flutter
    // after that synchronous build has unwound. No old owner gets one frame.
    weeklyGoal = null;
    weeklyPaceKg = null;
    startingWeight = null;
    startingDate = null;
    activity = null;
    hydrated = false;
    hydrating = false;
    hydrateError = null;
    saving = false;
    scheduleMicrotask(() {
      if (mounted) {
        _setGoalState(() {});
      }
    });
  }

  _ReferenceGoalVisit? _goalVisit(
    UserProfileData profile,
    AppDatabase database,
    AsyncValue<ProfileAuthIdentity> authState,
  ) {
    final repository = ref.read(preferencesRepositoryProvider);
    final identity = authState.asData?.value;
    if (profile.uuid != _goalResolvedProfileUuid ||
        authState.isLoading ||
        authState.hasError ||
        identity == null ||
        database.localOwnerId != identity.ownerId ||
        repository.localOwnerId != database.localOwnerId) {
      return null;
    }
    final epoch = _goalOwnerEpoch;
    bool current() =>
        mounted &&
        epoch == _goalOwnerEpoch &&
        identical(database, ref.read(databaseProvider)) &&
        identical(repository, ref.read(preferencesRepositoryProvider)) &&
        !ref.read(profileAuthIdentityProvider).isLoading &&
        !ref.read(profileAuthIdentityProvider).hasError &&
        ref.read(profileAuthIdentityProvider).asData?.value.ownerId ==
            database.localOwnerId &&
        !ref.read(userProfileProvider).isLoading &&
        !ref.read(userProfileProvider).hasError &&
        ref.read(userProfileProvider).asData?.value?.uuid == profile.uuid;
    return _ReferenceGoalVisit(database, repository, current);
  }

  Future<void> _hydrateGoals(
    UserProfileData profile,
    _ReferenceGoalVisit visit,
  ) async {
    if (hydrated || hydrating || !visit.current) {
      return;
    }
    _setGoalState(() {
      hydrating = true;
      hydrateError = null;
    });
    try {
      final values = await Future.wait<String?>([
        visit.preferences.get('goals.weeklyRate'),
        visit.preferences.get('goals.startingWeight'),
        visit.preferences.get('goals.startingDate'),
        visit.preferences.get(NutritionPaceIntent.storageKey),
      ]);
      if (!visit.current) {
        return;
      }
      WeightEntry? first;
      if (values[1] == null || values[2] == null) {
        first =
            await (visit.database.select(visit.database.weightEntries)
                  ..where((row) => row.deletedAt.isNull())
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.date),
                    (row) => OrderingTerm.asc(row.id),
                  ])
                  ..limit(1))
                .getSingleOrNull();
      }
      if (!visit.current) {
        return;
      }
      final resolved = resolveReferenceGoalPreferences(
        weeklyGoal: values[0],
        startingWeight: values[1],
        startingDate: values[2],
        onboardingPlan: values[3],
        profile: profile,
        firstWeight: first,
        now: DateTime.now(),
      );
      _setGoalState(() {
        weeklyGoal = resolved.weeklyGoal;
        weeklyPaceKg = resolved.weeklyPaceKg;
        startingWeight = resolved.startingWeight;
        startingDate = resolved.startingDate;
        activity = profile.activityLevel;
        hydrated = true;
      });
    } catch (error) {
      if (visit.current) {
        _setGoalState(() => hydrateError = error);
      }
    } finally {
      if (visit.current) {
        _setGoalState(() => hydrating = false);
      }
    }
  }

  Future<bool> _writeGoal(
    _ReferenceGoalVisit visit,
    Future<void> Function() operation, {
    VoidCallback? retry,
  }) async {
    if (saving || !visit.current) {
      return false;
    }
    _setGoalState(() => saving = true);
    try {
      await visit.database.transaction(() async {
        visit.check();
        await operation();
        visit.check();
      });
      return visit.current;
    } catch (_) {
      if (mounted && visit.current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(c('Could not save changes.')),
            action: retry == null
                ? null
                : SnackBarAction(label: c('Retry'), onPressed: retry),
          ),
        );
      }
      return false;
    } finally {
      if (visit.current) {
        _setGoalState(() => saving = false);
      }
    }
  }

  String _goalWeightText(double kilograms, MeasurementSystem system) =>
      '${UnitConverter.weightFromKg(kilograms, system).toStringAsFixed(1)} ${c(UnitConverter.weightUnit(system))}';

  double _currentWeightForGoals(
    UserProfileData profile, {
    AsyncValue<WeightEntry?>? latestState,
  }) {
    final latest = latestState ?? ref.read(latestWeightProvider);
    // Preserve the captured profile fallback and this visit's strict handling
    // of loading/error; do not substitute a provider's retained previous value.
    final measurement = latest == null || latest.isLoading || latest.hasError
        ? null
        : latest.asData?.value?.weight;
    return measurement ?? profile.currentWeight;
  }

  String _goalWeeklyText(double? paceKg, MeasurementSystem system) {
    if (paceKg == null) {
      return '—';
    }
    if (paceKg == 0) {
      return c('Maintain weight');
    }
    final template = c(
      paceKg < 0 ? 'Lose 0.5 kg per week' : 'Gain 0.5 kg per week',
    );
    final value = UnitConverter.weightFromKg(paceKg.abs(), system);
    var amount = system == MeasurementSystem.imperial
        ? value.toStringAsFixed(1)
        : value
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    if (template.contains('0,5')) {
      amount = amount.replaceAll('.', ',');
    }
    return template
        .replaceFirst(RegExp(r'0[.,]5'), amount)
        .replaceAll(c('kg'), c(UnitConverter.weightUnit(system)));
  }
}
