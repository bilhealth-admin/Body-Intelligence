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
    weight.text = profile.currentWeight.toStringAsFixed(1);
    target.text = profile.targetWeight.toStringAsFixed(1);
    neck.text = _optionalText(profile.neck);
    waist.text = _optionalText(profile.waist);
    chest.text = _optionalText(profile.chest);
    arm.text = _optionalText(profile.arm);
    thigh.text = _optionalText(profile.thigh);
    unawaited(_finishHydration());
  }

  Future<void> _finishHydration() async {
    await Future.wait([
      _loadLatestMeasurements(),
      _loadExperiencePreferences(),
    ]);
    if (!mounted) return;
    _updateState(() => formHydrated = true);
  }

  String _optionalText(double? centimeters) {
    if (centimeters == null) return '';
    final value = UnitConverter.heightFromCm(centimeters, measurementSystem);
    return value.toStringAsFixed(1);
  }

  double? _optionalNumberCm(TextEditingController controller) {
    final raw = controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.parse(raw);
    return UnitConverter.heightToCm(value, measurementSystem);
  }

  Future<void> _loadLatestMeasurements() async {
    final latest = await ref
        .read(bodyMeasurementRepositoryProvider)
        .getLatest();
    if (!mounted || latest == null) return;
    _updateState(() {
      neck.text = _optionalText(latest.neckCm);
      waist.text = _optionalText(latest.waistCm);
      hips.text = _optionalText(latest.hipsCm);
      chest.text = _optionalText(latest.chestCm);
      arm.text = _optionalText(latest.armCm);
      thigh.text = _optionalText(latest.thighCm);
    });
  }

  Future<void> _loadExperiencePreferences() async {
    if (experiencePreferencesLoaded) return;
    experiencePreferencesLoaded = true;
    final repository = ref.read(preferencesRepositoryProvider);
    final values = await Future.wait([
      repository.get('weeklyExerciseSessions'),
      repository.get('exerciseType'),
      repository.get('displayName'),
    ]);
    final dietary = await ref.read(dietaryPreferencesRepositoryProvider).read();
    if (!mounted) return;
    _updateState(() {
      weeklyExerciseSessions = int.tryParse(values[0] ?? '') ?? 3;
      exerciseType = values[1] ?? 'mixed';
      dietApproach = dietary.approach;
      dietaryPattern = dietary.pattern;
      dietaryRequirements = dietary.requirements.toSet();
      dietaryAllergens = dietary.allergens.toSet();
      dietaryExcludedIngredients = dietary.excludedIngredients.toSet();
      displayName.text = values[2]?.trim() ?? '';
    });
  }

  String? validate(String? value, double min, double max) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed == null || parsed < min || parsed > max
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
    if (!(formKey.currentState?.validate() ?? false)) return;
    _updateState(() => saving = true);
    try {
      final currentWeight = double.parse(weight.text.replaceAll(',', '.'));
      final targetWeight = double.parse(target.text.replaceAll(',', '.'));
      final neckCm = _optionalNumberCm(neck);
      final waistCm = _optionalNumberCm(waist);
      final hipsCm = _optionalNumberCm(hips);
      final chestCm = _optionalNumberCm(chest);
      final armCm = _optionalNumberCm(arm);
      final thighCm = _optionalNumberCm(thigh);
      await ref
          .read(userProfileRepositoryProvider)
          .save(
            gender: gender,
            age: int.parse(age.text),
            height: double.parse(height.text.replaceAll(',', '.')),
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            activityLevel: activity,
            exercises: exercises,
            medicalConditions: profile.medicalConditions,
            waist: waistCm,
            neck: neckCm,
            chest: chestCm,
            arm: armCm,
            thigh: thighCm,
          );
      await ref
          .read(bodyMeasurementRepositoryProvider)
          .saveForDay(
            date: DateTime.now(),
            neckCm: neckCm,
            waistCm: waistCm,
            hipsCm: hipsCm,
            chestCm: chestCm,
            armCm: armCm,
            thighCm: thighCm,
          );
      ref.invalidate(bodyMeasurementHistoryProvider);
      final activeGoal = ref.read(activeGoalProvider).value;
      await ref
          .read(goalRepositoryProvider)
          .save(
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
      final preferences = ref.read(preferencesRepositoryProvider);
      await preferences.set(
        'weeklyExerciseSessions',
        exercises ? weeklyExerciseSessions.toString() : '0',
      );
      await preferences.set('exerciseType', exerciseType);
      await ref
          .read(dietaryPreferencesRepositoryProvider)
          .save(
            DietaryPreferences(
              pattern: dietaryPattern,
              approach: dietApproach,
              requirements: dietaryRequirements,
              allergens: dietaryAllergens,
              excludedIngredients: dietaryExcludedIngredients,
            ),
          );
      await preferences.set('displayName', displayName.text.trim());
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
    } finally {
      if (mounted) _updateState(() => saving = false);
    }
  }
}
