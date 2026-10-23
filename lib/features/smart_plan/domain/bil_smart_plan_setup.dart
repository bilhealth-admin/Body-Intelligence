part of 'bil_smart_plan.dart';

enum BilPlanEnvironment { gym, home }

enum BilPlanExperience { beginner, regular, experienced }

/// Explicit member choices, not inferred training ability or a prescription.
final class BilPlanSetup {
  BilPlanSetup({
    required this.environment,
    required this.experience,
    required this.sessionMinutes,
    required Iterable<String> equipment,
    this.preferredTime,
    this.goalId,
  }) : equipment = Set.unmodifiable(equipment) {
    if (sessionMinutes < 5 ||
        sessionMinutes > 120 ||
        this.equipment.length > 12 ||
        this.equipment.any((value) => !supportedEquipment.contains(value)) ||
        (preferredTime != null &&
            !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(preferredTime!))) {
      throw const FormatException('smart_plan_invalid_setup');
    }
    if ((environment == BilPlanEnvironment.gym &&
            !this.equipment.contains('gym')) ||
        (environment == BilPlanEnvironment.home &&
            this.equipment.contains('gym'))) {
      throw const FormatException('smart_plan_environment_equipment_mismatch');
    }
    if (goalId != null) _safePlanId(goalId);
  }
  static const supportedEquipment = {
    'none',
    'exercise mat',
    'dumbbell pair',
    'dumbbell single',
    'long resistance band',
    'mini loop band',
    'flat resistance band',
    'kettlebell single',
    'gym',
  };
  final BilPlanEnvironment environment;
  final BilPlanExperience experience;
  final int sessionMinutes;
  final Set<String> equipment;
  final String? preferredTime, goalId;
  Map<String, Object?> toJson() => {
    'environment': environment.name,
    'experience': experience.name,
    'sessionMinutes': sessionMinutes,
    'equipment': equipment.toList()..sort(),
    if (preferredTime != null) 'preferredTime': preferredTime,
    if (goalId != null) 'goalId': goalId,
  };
  factory BilPlanSetup.fromJson(Map<String, dynamic> value) {
    final raw = value['equipment'];
    if (raw is! List ||
        (value.containsKey('preferredTime') &&
            value['preferredTime'] is! String) ||
        (value.containsKey('goalId') && value['goalId'] is! String) ||
        raw.any((e) => e is! String) ||
        raw.toSet().length != raw.length ||
        value.keys.any(
          (key) => !const {
            'environment',
            'experience',
            'sessionMinutes',
            'equipment',
            'preferredTime',
            'goalId',
          }.contains(key),
        )) {
      throw const FormatException('smart_plan_invalid_setup');
    }
    return BilPlanSetup(
      environment: _readPlanEnum(
        BilPlanEnvironment.values,
        value['environment'],
      ),
      experience: _readPlanEnum(BilPlanExperience.values, value['experience']),
      sessionMinutes: _planInt(value['sessionMinutes']),
      equipment: raw.cast<String>(),
      preferredTime: value['preferredTime'] as String?,
      goalId: value['goalId'] as String?,
    );
  }
}
