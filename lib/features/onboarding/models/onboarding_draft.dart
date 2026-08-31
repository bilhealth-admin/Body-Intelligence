import 'dart:convert';

import '../../../core/units/measurement_units.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../intelligence_center/domain/coach_context_preferences.dart';

enum OnboardingGoal {
  loseWeight,
  maintainWeight,
  gainWeight,
  buildMuscle,
  improveNutrition,
  planMeals,
  activityFitness,
  sleepRecovery,
  fastingHabits,
  stressWellbeing,
}

enum OnboardingRemoteAiConsent { unknown, declined, granted }

enum OnboardingPermissionStatus {
  notRequested,
  requested,
  granted,
  denied,
  unavailable,
  failed,
}

const _notProvided = Object();

/// Canonical, resumable state for the only production onboarding flow.
///
/// Body values are always stored in centimetres/kilograms. Changing the
/// display system therefore cannot round-trip through a lossy conversion.
final class OnboardingDraft {
  const OnboardingDraft({
    this.stepId = 'name',
    this.preferredName = '',
    this.goals = const <OnboardingGoal>{},
    this.activity,
    this.regularExercise = false,
    this.birthDate,
    this.sex,
    this.countryRegion = '',
    this.localeTag = 'en',
    this.system = MeasurementSystem.metric,
    this.heightCm,
    this.currentWeightKg,
    this.targetWeightKg,
    this.weeklyPaceKg,
    this.waistCm,
    this.neckCm,
    this.hipsCm,
    this.healthPermission = OnboardingPermissionStatus.notRequested,
    this.notificationPermission = OnboardingPermissionStatus.notRequested,
    this.remoteAiConsent = OnboardingRemoteAiConsent.unknown,
    this.aiFocuses = const <CoachContextFocus>{
      CoachContextFocus.nutrition,
      CoachContextFocus.training,
      CoachContextFocus.habits,
      CoachContextFocus.analytics,
    },
    this.estimatesAcknowledged = false,
  });

  static const preferenceKey = 'onboardingDraftV2';
  static const legacyPreferenceKey = 'onboardingDraftV1';

  final String stepId;
  final String preferredName;
  final Set<OnboardingGoal> goals;
  final String? activity;
  final bool regularExercise;
  final DateTime? birthDate;
  final String? sex;
  final String countryRegion;
  final String localeTag;
  final MeasurementSystem system;
  final double? heightCm;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final double? weeklyPaceKg;
  final double? waistCm;
  final double? neckCm;
  final double? hipsCm;
  final OnboardingPermissionStatus healthPermission;
  final OnboardingPermissionStatus notificationPermission;
  final OnboardingRemoteAiConsent remoteAiConsent;
  final Set<CoachContextFocus> aiFocuses;
  final bool estimatesAcknowledged;

  String get primaryWeightGoal {
    if (goals.contains(OnboardingGoal.loseWeight)) return 'lose';
    if (goals.contains(OnboardingGoal.gainWeight)) return 'gain';
    return 'maintain';
  }

  OnboardingDraft copyWith({
    String? stepId,
    String? preferredName,
    Set<OnboardingGoal>? goals,
    Object? activity = _notProvided,
    bool? regularExercise,
    Object? birthDate = _notProvided,
    Object? sex = _notProvided,
    String? countryRegion,
    String? localeTag,
    MeasurementSystem? system,
    Object? heightCm = _notProvided,
    Object? currentWeightKg = _notProvided,
    Object? targetWeightKg = _notProvided,
    Object? weeklyPaceKg = _notProvided,
    Object? waistCm = _notProvided,
    Object? neckCm = _notProvided,
    Object? hipsCm = _notProvided,
    OnboardingPermissionStatus? healthPermission,
    OnboardingPermissionStatus? notificationPermission,
    OnboardingRemoteAiConsent? remoteAiConsent,
    Set<CoachContextFocus>? aiFocuses,
    bool? estimatesAcknowledged,
  }) => OnboardingDraft(
    stepId: stepId ?? this.stepId,
    preferredName: preferredName ?? this.preferredName,
    goals: Set.unmodifiable(goals ?? this.goals),
    activity: identical(activity, _notProvided)
        ? this.activity
        : activity as String?,
    regularExercise: regularExercise ?? this.regularExercise,
    birthDate: identical(birthDate, _notProvided)
        ? this.birthDate
        : birthDate as DateTime?,
    sex: identical(sex, _notProvided) ? this.sex : sex as String?,
    countryRegion: countryRegion ?? this.countryRegion,
    localeTag: localeTag ?? this.localeTag,
    system: system ?? this.system,
    heightCm: identical(heightCm, _notProvided)
        ? this.heightCm
        : (heightCm as num?)?.toDouble(),
    currentWeightKg: identical(currentWeightKg, _notProvided)
        ? this.currentWeightKg
        : (currentWeightKg as num?)?.toDouble(),
    targetWeightKg: identical(targetWeightKg, _notProvided)
        ? this.targetWeightKg
        : (targetWeightKg as num?)?.toDouble(),
    weeklyPaceKg: identical(weeklyPaceKg, _notProvided)
        ? this.weeklyPaceKg
        : (weeklyPaceKg as num?)?.toDouble(),
    waistCm: identical(waistCm, _notProvided)
        ? this.waistCm
        : (waistCm as num?)?.toDouble(),
    neckCm: identical(neckCm, _notProvided)
        ? this.neckCm
        : (neckCm as num?)?.toDouble(),
    hipsCm: identical(hipsCm, _notProvided)
        ? this.hipsCm
        : (hipsCm as num?)?.toDouble(),
    healthPermission: healthPermission ?? this.healthPermission,
    notificationPermission:
        notificationPermission ?? this.notificationPermission,
    remoteAiConsent: remoteAiConsent ?? this.remoteAiConsent,
    aiFocuses: Set.unmodifiable(aiFocuses ?? this.aiFocuses),
    estimatesAcknowledged: estimatesAcknowledged ?? this.estimatesAcknowledged,
  );

  String encode() => jsonEncode(<String, Object?>{
    'version': 2,
    'stepId': stepId,
    'preferredName': preferredName,
    'goals': goals.map((value) => value.name).toList()..sort(),
    'activity': activity,
    'regularExercise': regularExercise,
    'birthDate': birthDate?.toIso8601String(),
    'sex': sex,
    'countryRegion': countryRegion,
    'localeTag': localeTag,
    'system': system.name,
    'heightCm': heightCm,
    'currentWeightKg': currentWeightKg,
    'targetWeightKg': targetWeightKg,
    'weeklyPaceKg': weeklyPaceKg,
    'waistCm': waistCm,
    'neckCm': neckCm,
    'hipsCm': hipsCm,
    'healthPermission': healthPermission.name,
    'notificationPermission': notificationPermission.name,
    'remoteAiConsent': remoteAiConsent.name,
    'aiFocuses': aiFocuses.map((value) => value.name).toList()..sort(),
    'estimatesAcknowledged': estimatesAcknowledged,
  });

  static OnboardingDraft? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return null;
      if (value['version'] == 1) return _decodeLegacy(value);
      if (value['version'] != 2) return null;

      T? enumValue<T extends Enum>(Iterable<T> values, Object? name) =>
          values.where((value) => value.name == name).firstOrNull;
      Set<T> enumSet<T extends Enum>(Iterable<T> values, Object? rawValues) {
        if (rawValues is! List) return <T>{};
        final names = rawValues.map((item) => item?.toString()).toSet();
        return values.where((value) => names.contains(value.name)).toSet();
      }

      double? number(String key) => (value[key] as num?)?.toDouble();
      final date = DateTime.tryParse(value['birthDate']?.toString() ?? '');
      final goals = enumSet(OnboardingGoal.values, value['goals']);
      final hasFocusList = value['aiFocuses'] is List;
      final focuses = enumSet(CoachContextFocus.values, value['aiFocuses']);
      return OnboardingDraft(
        stepId: value['stepId']?.toString() ?? 'name',
        preferredName: value['preferredName']?.toString() ?? '',
        goals: Set.unmodifiable(goals),
        activity:
            const {
              'sedentary',
              'light',
              'moderate',
              'active',
              'veryActive',
            }.contains(value['activity'])
            ? value['activity'] as String
            : null,
        regularExercise: value['regularExercise'] == true,
        birthDate: date,
        sex: const {'male', 'female'}.contains(value['sex'])
            ? value['sex'] as String
            : null,
        countryRegion: value['countryRegion']?.toString() ?? '',
        localeTag: value['localeTag']?.toString() ?? 'en',
        system: value['system'] == 'imperial'
            ? MeasurementSystem.imperial
            : MeasurementSystem.metric,
        heightCm: number('heightCm'),
        currentWeightKg: number('currentWeightKg'),
        targetWeightKg: number('targetWeightKg'),
        weeklyPaceKg: number('weeklyPaceKg'),
        waistCm: number('waistCm'),
        neckCm: number('neckCm'),
        hipsCm: number('hipsCm'),
        healthPermission:
            enumValue(
              OnboardingPermissionStatus.values,
              value['healthPermission'],
            ) ??
            OnboardingPermissionStatus.notRequested,
        notificationPermission:
            enumValue(
              OnboardingPermissionStatus.values,
              value['notificationPermission'],
            ) ??
            OnboardingPermissionStatus.notRequested,
        remoteAiConsent:
            enumValue(
              OnboardingRemoteAiConsent.values,
              value['remoteAiConsent'],
            ) ??
            OnboardingRemoteAiConsent.unknown,
        aiFocuses: !hasFocusList
            ? const <CoachContextFocus>{
                CoachContextFocus.nutrition,
                CoachContextFocus.training,
                CoachContextFocus.habits,
                CoachContextFocus.analytics,
              }
            : Set.unmodifiable(focuses),
        estimatesAcknowledged: value['estimatesAcknowledged'] == true,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Migration intentionally does not invent a birth date from a stored age.
  /// The adult gate asks for the exact date again before completion.
  static OnboardingDraft _decodeLegacy(Map<String, dynamic> value) {
    double? number(String key) => (value[key] as num?)?.toDouble();
    final legacyActivity = value['activity']?.toString();
    final legacyGoal = value['goalType']?.toString();
    final goals = <OnboardingGoal>{
      switch (legacyGoal) {
        'lose' => OnboardingGoal.loseWeight,
        'gain' => OnboardingGoal.gainWeight,
        _ => OnboardingGoal.maintainWeight,
      },
    };
    return OnboardingDraft(
      stepId: 'name',
      goals: goals,
      activity:
          const {
            'sedentary',
            'light',
            'moderate',
            'active',
            'veryActive',
          }.contains(legacyActivity)
          ? legacyActivity
          : null,
      sex: const {'male', 'female'}.contains(value['gender'])
          ? value['gender'] as String
          : null,
      countryRegion: value['region']?.toString() ?? '',
      system: value['system'] == 'imperial'
          ? MeasurementSystem.imperial
          : MeasurementSystem.metric,
      heightCm: number('heightCm'),
      currentWeightKg: number('currentWeightKg'),
      targetWeightKg: number('targetWeightKg'),
      waistCm: number('waistCm'),
      neckCm: number('neckCm'),
      hipsCm: number('hipsCm'),
      estimatesAcknowledged: value['disclaimerAccepted'] == true,
    );
  }
}

class OnboardingDraftRepository {
  const OnboardingDraftRepository(this._preferences);

  final PreferencesRepository _preferences;

  Future<OnboardingDraft?> load() async {
    final current = OnboardingDraft.decode(
      await _preferences.get(OnboardingDraft.preferenceKey),
    );
    if (current != null) return current;
    return OnboardingDraft.decode(
      await _preferences.get(OnboardingDraft.legacyPreferenceKey),
    );
  }

  Future<void> save(OnboardingDraft draft) =>
      _preferences.set(OnboardingDraft.preferenceKey, draft.encode());

  Future<void> clear() => _preferences.removeMany(const <String>{
    OnboardingDraft.preferenceKey,
    OnboardingDraft.legacyPreferenceKey,
  });

  Future<void> clearInCurrentTransaction() =>
      _preferences.removeManyInCurrentTransaction(const <String>{
        OnboardingDraft.preferenceKey,
        OnboardingDraft.legacyPreferenceKey,
      });
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
