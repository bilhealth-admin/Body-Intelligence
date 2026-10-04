part of 'profile_settings_page.dart';

extension _ProfileSettingsActions on _ProfileSettingsPageState {
  void hydrate(UserProfileData profile, MeasurementSystem system) {
    if (initialized) return;
    initialized = true;
    measurementSystem = system;
    gender = profile.gender;
    activity = profile.activityLevel;
    exercises = profile.exercises;
    age.text = profile.age.toString();
    height.text = profile.height.toStringAsFixed(1);
    weight.text = profile.currentWeight.toString();
    target.text = profile.targetWeight.toStringAsFixed(1);
    neck.text = _optionalText(profile.neck);
    waist.text = _optionalText(profile.waist);
    chest.text = _optionalText(profile.chest);
    arm.text = _optionalText(profile.arm);
    thigh.text = _optionalText(profile.thigh);
    unawaited(_finishHydration());
  }

  Future<void> _finishHydration() async {
    final generation = ++hydrationGeneration;
    final preferences = ref.read(preferencesRepositoryProvider);
    try {
      final values = await Future.wait<Object?>([
        ref.read(bodyMeasurementRepositoryProvider).getLatest(),
        ref.read(weightRepositoryProvider).watchLatestWeight().first,
        preferences.get('weeklyExerciseSessions'),
        preferences.get('exerciseType'),
        preferences.get('displayName'),
        ref.read(dietaryPreferencesRepositoryProvider).read(),
      ], eagerError: true).timeout(widget.hydrationTimeout);
      if (!mounted || generation != hydrationGeneration) return;
      final latest = values[0] as BodyMeasurementEntry?;
      final latestWeight = values[1] as WeightEntry?;
      final dietary = values[5] as DietaryPreferences;
      _updateState(() {
        if (latest != null) {
          neck.text = _optionalText(latest.neckCm);
          waist.text = _optionalText(latest.waistCm);
          hips.text = _optionalText(latest.hipsCm);
          chest.text = _optionalText(latest.chestCm);
          arm.text = _optionalText(latest.armCm);
          thigh.text = _optionalText(latest.thighCm);
        }
        if (latestWeight != null) weight.text = latestWeight.weight.toString();
        hydratedWeight = double.parse(weight.text);
        final sessions = int.tryParse(values[2] as String? ?? '') ?? 3;
        weeklyExerciseSessions = sessions >= 1 && sessions <= 7 ? sessions : 3;
        final savedExerciseType = values[3] as String?;
        exerciseType =
            const {
              'walking',
              'strength',
              'cardio',
              'swimming',
              'cycling',
              'mixed',
            }.contains(savedExerciseType)
            ? savedExerciseType!
            : 'mixed';
        displayName.text = (values[4] as String?)?.trim() ?? '';
        dietApproach = dietary.approach;
        dietaryPattern = dietary.pattern;
        dietaryRequirements = dietary.requirements.toSet();
        dietaryAllergens = dietary.allergens.toSet();
        dietaryExcludedIngredients = dietary.excludedIngredients.toSet();
        formHydrated = true;
      });
    } catch (_) {
      if (mounted && generation == hydrationGeneration) {
        _updateState(() => hydrationFailed = true);
      }
    }
  }

  String _optionalText(double? centimeters) {
    if (centimeters == null) return '';
    final value = UnitConverter.heightFromCm(centimeters, measurementSystem);
    return value.toStringAsFixed(1);
  }

  double? _optionalNumberCm(TextEditingController controller) {
    final raw = _numericText(controller.text);
    if (raw.isEmpty) return null;
    final value = double.parse(raw);
    return UnitConverter.heightToCm(value, measurementSystem);
  }

  String? validateAge(String? value) {
    final text = _numericText(value ?? '');
    final parsed = RegExp(r'^[0-9]{1,3}$').hasMatch(text)
        ? int.tryParse(text, radix: 10)
        : null;
    return parsed == null || !BilAdultEligibility.isEligibleAge(parsed)
        ? '${BilAdultEligibility.minimumAge} – ${BilAdultEligibility.maximumSupportedAge}'
        : null;
  }

  String _numericText(String value) => value
      .trim()
      .replaceAll(',', '.')
      .replaceAll('٫', '.')
      .replaceAllMapped(RegExp('[٠-٩۰-۹]'), (match) {
        final digit = match[0]!.codeUnitAt(0);
        return (digit - (digit >= 0x06f0 ? 0x06f0 : 0x0660)).toString();
      });

  String? validate(String? value, double min, double max) {
    final parsed = double.tryParse(_numericText(value ?? ''));
    return parsed == null || !parsed.isFinite || parsed < min || parsed > max
        ? '$min – $max'
        : null;
  }

  String? validateOptional(String? value, double min, double max) {
    if ((value ?? '').trim().isEmpty) return null;
    return validate(value, min, max);
  }

  Widget _measurementField(
    TextEditingController controller,
    String english,
    String arabic,
  ) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText:
          '${t(english, arabic)} (${measurementSystem == MeasurementSystem.imperial ? 'in' : 'cm'})',
      prefixIcon: const Icon(Icons.straighten_rounded),
    ),
    validator: (value) => measurementSystem == MeasurementSystem.imperial
        ? validateOptional(value, 8, 120)
        : validateOptional(value, 20, 300),
  );

  Future<void> leave() async {
    if (saving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t('Discard changes?', 'تجاهل التغييرات؟')),
          content: Text(
            t('You have unsaved changes.', 'لديك تغييرات لم تُحفظ.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('Keep editing', 'متابعة التعديل')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t('Discard', 'تجاهل')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  Future<void> save(UserProfileData profile) async {
    if (saving || !formHydrated) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    _updateState(() => saving = true);
    try {
      final database = ref.read(databaseProvider);
      final profiles = ref.read(userProfileRepositoryProvider);
      final measurements = ref.read(bodyMeasurementRepositoryProvider);
      final weights = ref.read(weightRepositoryProvider);
      final goals = ref.read(goalRepositoryProvider);
      final preferences = ref.read(preferencesRepositoryProvider);
      final dietaryRepository = ref.read(dietaryPreferencesRepositoryProvider);
      final nameSync = ref.read(displayNameSyncProvider);
      final editedWeight = double.parse(_numericText(weight.text));
      final weightChanged = editedWeight != hydratedWeight;
      final targetWeight = double.parse(_numericText(target.text));
      final profileAge = int.parse(_numericText(age.text), radix: 10);
      final profileHeight = double.parse(_numericText(height.text));
      final profileGender = gender;
      final profileActivity = activity;
      final profileExercises = exercises;
      final preferenceSnapshot = {
        'weeklyExerciseSessions': exercises
            ? weeklyExerciseSessions.toString()
            : '0',
        'exerciseType': exerciseType,
        ...DisplayNameSync.localEdit(displayName.text),
      };
      final dietary = DietaryPreferences(
        pattern: dietaryPattern,
        approach: dietApproach,
        requirements: dietaryRequirements.toSet(),
        allergens: dietaryAllergens.toSet(),
        excludedIngredients: dietaryExcludedIngredients.toSet(),
      );
      final neckCm = _optionalNumberCm(neck);
      final waistCm = _optionalNumberCm(waist);
      final hipsCm = _optionalNumberCm(hips);
      final chestCm = _optionalNumberCm(chest);
      final armCm = _optionalNumberCm(arm);
      final thighCm = _optionalNumberCm(thigh);
      await database.transaction(() async {
        final latestWeight =
            await (database.select(database.weightEntries)
                  ..where((row) => row.deletedAt.isNull())
                  ..orderBy([(row) => OrderingTerm.desc(row.date)])
                  ..limit(1))
                .getSingleOrNull();
        final currentWeight = weightChanged
            ? editedWeight
            : latestWeight?.weight ?? editedWeight;
        final activeGoal = await goals.getActive();
        await profiles.save(
          gender: profileGender,
          age: profileAge,
          height: profileHeight,
          currentWeight: currentWeight,
          targetWeight: targetWeight,
          activityLevel: profileActivity,
          exercises: profileExercises,
          medicalConditions: profile.medicalConditions,
          waist: waistCm,
          neck: neckCm,
          chest: chestCm,
          arm: armCm,
          thigh: thighCm,
        );
        if (weightChanged) {
          await weights.addWeight(
            currentWeight,
            measurementContext: 'unspecified',
          );
        }
        await measurements.saveForDay(
          date: DateTime.now(),
          neckCm: neckCm,
          waistCm: waistCm,
          hipsCm: hipsCm,
          chestCm: chestCm,
          armCm: armCm,
          thighCm: thighCm,
        );
        await goals.save(
          uuid: activeGoal?.uuid,
          profileUuid: profile.uuid,
          type: targetWeight < currentWeight
              ? 'lose'
              : targetWeight > currentWeight
              ? 'gain'
              : 'maintain',
          targetWeight: targetWeight,
          targetDate: activeGoal?.targetDate,
        );
        await dietaryRepository.saveInCurrentTransaction(dietary);
        await preferences.setManyInCurrentTransaction(preferenceSnapshot);
      });
      unawaited(nameSync.synchronize());
      if (!mounted) return;
      ref.invalidate(bodyMeasurementHistoryProvider);
      ref.invalidate(latestWeightProvider);
      ref.invalidate(weightHistoryProvider);
      ref.invalidate(todayWeightProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeGoalProvider);
      if (!mounted) return;
      _updateState(() => dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Your profile and plan were saved.', 'تم حفظ ملفك وخطتك.'),
          ),
        ),
      );
      context.go('/settings');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Could not save. Your changes are still here. Try again.',
                'تعذّر الحفظ. تغييراتك محفوظة هنا. أعد المحاولة.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) _updateState(() => saving = false);
    }
  }
}
