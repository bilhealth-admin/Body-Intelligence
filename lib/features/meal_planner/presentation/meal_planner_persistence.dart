part of 'meal_planner_page.dart';

extension _MealPlannerPersistence on _MealPlannerPageState {
  bool _isActiveRepository(PreferencesRepository repository) {
    if (!mounted ||
        !identical(ref.read(preferencesRepositoryProvider), repository)) {
      return false;
    }
    if (!AppEnvironment.supabaseRuntimeReady) return true;
    final activeOwner = Supabase.instance.client.auth.currentUser?.id.trim();
    final normalized = activeOwner == null || activeOwner.isEmpty
        ? null
        : activeOwner;
    return repository.localOwnerId == normalized;
  }

  bool _isCurrent(int epoch, PreferencesRepository repository) =>
      mounted &&
      _loadEpoch == epoch &&
      identical(_boundRepository, repository) &&
      _isActiveRepository(repository);

  void _adoptRepository(PreferencesRepository next) {
    if (!mounted ||
        identical(next, _boundRepository) ||
        !identical(ref.read(preferencesRepositoryProvider), next)) {
      return;
    }
    // The previous owner's asynchronous work must never populate this page.
    _updateMealPlannerState(() {
      _loadEpoch++;
      _boundRepository = next;
      _readSnapshot = null;
      _preferences = const MealPlanPreferences();
      _dietaryPreferences = const DietaryPreferences();
      _plan = null;
      _checkedGrocery.clear();
      _loadInFlight = false;
      _grocerySaveInFlight = false;
      _loading = true;
      _saving = false;
      _loadError = null;
      _saveError = null;
    });
    _load();
  }

  Future<void> _load({bool retry = false}) async {
    if (_loadInFlight) return;
    final repository = _boundRepository;
    if (repository == null || !_isActiveRepository(repository)) return;
    final epoch = ++_loadEpoch;
    _loadInFlight = true;
    if (retry) {
      _updateMealPlannerState(() {
        _loading = _plan == null;
        _loadError = null;
      });
    }
    try {
      final values = await Future.wait([
        repository.get(_MealPlannerPageState._preferencesKey),
        repository.get(_MealPlannerPageState._planKey),
        repository.get(_MealPlannerPageState._groceryChecksKey),
        repository.get(DietaryPreferences.storageKey),
        repository.get('dietApproach'),
      ]);
      // Decode everything before one commit. A malformed final key cannot
      // partially install a new plan, dietary values, or grocery checks.
      final preferences = values[0] == null
          ? const MealPlanPreferences()
          : MealPlanPreferences.fromJson(
              jsonDecode(values[0]!) as Map<String, dynamic>,
            );
      final plan = values[1] == null ? null : WeeklyMealPlan.decode(values[1]!);
      final checks = values[2] == null
          ? <String>{}
          : (jsonDecode(values[2]!) as List).cast<String>().toSet();
      final dietary = DietaryPreferences.decode(
        values[3],
        legacyApproach: values[4],
      );
      if (!_isCurrent(epoch, repository)) return;
      _updateMealPlannerState(() {
        _preferences = preferences;
        _plan = plan;
        _checkedGrocery
          ..clear()
          ..addAll(checks);
        _dietaryPreferences = dietary;
        _readSnapshot = {
          _MealPlannerPageState._preferencesKey: values[0],
          _MealPlannerPageState._planKey: values[1],
          _MealPlannerPageState._groceryChecksKey: values[2],
          DietaryPreferences.storageKey: values[3],
          'dietApproach': values[4],
        };
        _loading = false;
        _loadError = null;
        _saveError = null;
      });
    } catch (_) {
      if (_isCurrent(epoch, repository)) {
        _updateMealPlannerState(() {
          _loading = false;
          _loadError = 'loadFailed';
        });
      }
    } finally {
      if (_loadEpoch == epoch) {
        _loadInFlight = false;
        if (mounted) _updateMealPlannerState(() {});
      }
    }
  }

  Future<void> _generate() async {
    if (_saving ||
        _grocerySaveInFlight ||
        _loadInFlight ||
        _loadError != null ||
        _saveError == 'planChanged' ||
        _readSnapshot == null) {
      return;
    }
    final repository = _boundRepository;
    if (repository == null || !_isActiveRepository(repository)) return;
    final epoch = _loadEpoch;
    final preferences = _preferences;
    final dietaryPreferences = _dietaryPreferences;
    final expected = Map<String, String?>.from(_readSnapshot!);
    _updateMealPlannerState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final plan = _engine.generate(
        preferences,
        dietaryPreferences: dietaryPreferences,
      );
      if (!_isCurrent(epoch, repository)) return;
      final storedPreferences = jsonEncode(preferences.toJson());
      final storedPlan = plan.encode();
      // One owner-guarded transaction compares the entire read snapshot
      // before atomically installing a new week and resetting grocery checks.
      // A failed write leaves the previous saved week intact.
      final committed = await repository.mutateIfUnchanged(
        expected: expected,
        set: {
          _MealPlannerPageState._preferencesKey: storedPreferences,
          _MealPlannerPageState._planKey: storedPlan,
        },
        remove: [_MealPlannerPageState._groceryChecksKey],
        isCurrent: () => _isCurrent(epoch, repository),
      );
      if (!_isCurrent(epoch, repository)) return;
      if (!committed) {
        _updateMealPlannerState(() => _saveError = 'planChanged');
        return;
      }
      _updateMealPlannerState(() {
        _plan = plan;
        _checkedGrocery.clear();
        _readSnapshot = {
          ...expected,
          _MealPlannerPageState._preferencesKey: storedPreferences,
          _MealPlannerPageState._planKey: storedPlan,
          _MealPlannerPageState._groceryChecksKey: null,
        };
        _saveError = null;
      });
    } catch (_) {
      if (_isCurrent(epoch, repository)) {
        _updateMealPlannerState(() => _saveError = 'generateFailed');
      }
    } finally {
      if (_isCurrent(epoch, repository)) {
        _updateMealPlannerState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleGrocery(String key, bool checked) async {
    if (_saving ||
        _grocerySaveInFlight ||
        _loadInFlight ||
        _loadError != null ||
        _readSnapshot == null) {
      return;
    }
    final repository = _boundRepository;
    if (repository == null || !_isActiveRepository(repository)) return;
    final epoch = _loadEpoch;
    final before = Set<String>.from(_checkedGrocery);
    final expected = Map<String, String?>.from(_readSnapshot!);
    final nextChecks = Set<String>.from(before);
    checked ? nextChecks.add(key) : nextChecks.remove(key);
    final encoded = jsonEncode(nextChecks.toList()..sort());
    _updateMealPlannerState(() {
      _grocerySaveInFlight = true;
      _checkedGrocery
        ..clear()
        ..addAll(nextChecks);
    });
    try {
      // One in-flight write and a CAS on week + checks prevent out-of-order
      // taps from restoring an old grocery list or a replaced plan.
      final committed = await repository.mutateIfUnchanged(
        expected: {
          _MealPlannerPageState._planKey:
              expected[_MealPlannerPageState._planKey],
          _MealPlannerPageState._groceryChecksKey:
              expected[_MealPlannerPageState._groceryChecksKey],
        },
        set: {_MealPlannerPageState._groceryChecksKey: encoded},
        isCurrent: () => _isCurrent(epoch, repository),
      );
      if (!_isCurrent(epoch, repository)) return;
      if (!committed) {
        _updateMealPlannerState(() {
          _checkedGrocery
            ..clear()
            ..addAll(before);
          _loadError = 'loadFailed';
        });
        return;
      }
      _updateMealPlannerState(() {
        _readSnapshot = {
          ...expected,
          _MealPlannerPageState._groceryChecksKey: encoded,
        };
      });
    } catch (_) {
      if (!_isCurrent(epoch, repository)) return;
      _updateMealPlannerState(() {
        _checkedGrocery
          ..clear()
          ..addAll(before);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _PlannerCopy(
              Localizations.localeOf(context).languageCode,
            ).text('saveFailed'),
          ),
        ),
      );
    } finally {
      if (_isCurrent(epoch, repository)) {
        _updateMealPlannerState(() => _grocerySaveInFlight = false);
      }
    }
  }
}
