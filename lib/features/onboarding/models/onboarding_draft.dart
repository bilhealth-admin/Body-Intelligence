import 'dart:convert';

import '../../../core/units/measurement_units.dart';
import '../../../data/repositories/preferences_repository.dart';

class OnboardingDraft {
  const OnboardingDraft({
    this.step = 0,
    this.age = '',
    this.heightCm = 155,
    this.currentWeightKg = 60,
    this.targetWeightKg = 60,
    this.waistCm,
    this.neckCm,
    this.region = '',
    this.gender,
    this.activity,
    this.goalType = 'maintain',
    this.system = MeasurementSystem.metric,
    this.disclaimerAccepted = false,
  });

  static const preferenceKey = 'onboardingDraftV1';

  final int step;
  final String age;
  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final double? waistCm;
  final double? neckCm;
  final String region;
  final String? gender;
  final String? activity;
  final String goalType;
  final MeasurementSystem system;
  final bool disclaimerAccepted;

  String encode() => jsonEncode({
    'version': 1,
    'step': step,
    'age': age,
    'heightCm': heightCm,
    'currentWeightKg': currentWeightKg,
    'targetWeightKg': targetWeightKg,
    'waistCm': waistCm,
    'neckCm': neckCm,
    'region': region,
    'gender': gender,
    'activity': activity,
    'goalType': goalType,
    'system': system.name,
    'disclaimerAccepted': disclaimerAccepted,
  });

  static OnboardingDraft? decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['version'] != 1) return null;
      double number(String key, double fallback) =>
          (value[key] as num?)?.toDouble() ?? fallback;
      double? optionalNumber(String key) => (value[key] as num?)?.toDouble();
      return OnboardingDraft(
        step: switch (value['step']) {
          final int step when step >= 0 && step <= 4 => step,
          _ => 0,
        },
        age: value['age'] is String ? value['age'] as String : '',
        heightCm: number('heightCm', 155),
        currentWeightKg: number('currentWeightKg', 60),
        targetWeightKg: number('targetWeightKg', 60),
        waistCm: optionalNumber('waistCm'),
        neckCm: optionalNumber('neckCm'),
        region: value['region'] is String ? value['region'] as String : '',
        gender: value['gender'] as String?,
        activity: value['activity'] as String?,
        goalType: switch (value['goalType']) {
          'lose' => 'lose',
          'gain' => 'gain',
          _ => 'maintain',
        },
        system: value['system'] == 'imperial'
            ? MeasurementSystem.imperial
            : MeasurementSystem.metric,
        disclaimerAccepted: value['disclaimerAccepted'] == true,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

class OnboardingDraftRepository {
  const OnboardingDraftRepository(this._preferences);

  final PreferencesRepository _preferences;

  Future<OnboardingDraft?> load() async => OnboardingDraft.decode(
    await _preferences.get(OnboardingDraft.preferenceKey),
  );

  Future<void> save(OnboardingDraft draft) =>
      _preferences.set(OnboardingDraft.preferenceKey, draft.encode());

  Future<void> clear() => _preferences.remove(OnboardingDraft.preferenceKey);
}
