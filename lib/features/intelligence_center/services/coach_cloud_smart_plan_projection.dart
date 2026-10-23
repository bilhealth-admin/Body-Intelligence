part of 'coach_cloud_privacy_boundary.dart';

Map<String, Object?> _projectSmartPlanWorkout(Map source) {
  bool id(Object? value) =>
      value is String &&
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$').hasMatch(value);
  return {
    if (id(source['templateId'])) 'templateId': source['templateId'],
    if (source['exerciseIds'] is List)
      'exerciseIds': (source['exerciseIds'] as List)
          .where(id)
          .take(12)
          .toList(growable: false),
    if (source['minutes'] is int &&
        (source['minutes'] as int) >= 5 &&
        (source['minutes'] as int) <= 120)
      'minutes': source['minutes'],
    if (source['completed'] is bool) 'completed': source['completed'],
    if (source['completed'] == true &&
        source['effort'] is int &&
        (source['effort'] as int) >= 1 &&
        (source['effort'] as int) <= 10)
      'effort': source['effort'],
  };
}

Map<String, Object?> _projectSmartPlanPreferences(Map source) => {
  if (source['source'] == 'confirmed_plan_setup') 'source': source['source'],
  if (source['updatedAt'] is String &&
      (source['updatedAt'] as String).length <= 35 &&
      DateTime.tryParse(source['updatedAt'] as String) != null)
    'updatedAt': source['updatedAt'],
  if (const {'gym', 'home'}.contains(source['environment']))
    'environment': source['environment'],
  if (const {
    'beginner',
    'regular',
    'experienced',
  }.contains(source['experience']))
    'experience': source['experience'],
  if (source['sessionMinutes'] is int &&
      (source['sessionMinutes'] as int) >= 5 &&
      (source['sessionMinutes'] as int) <= 120)
    'sessionMinutes': source['sessionMinutes'],
  if (source['equipment'] is List)
    'equipment': (source['equipment'] as List)
        .where(
          const {
            'none',
            'exercise mat',
            'dumbbell pair',
            'dumbbell single',
            'long resistance band',
            'mini loop band',
            'flat resistance band',
            'kettlebell single',
            'gym',
          }.contains,
        )
        .take(12)
        .toList(growable: false),
  if (source['preferredTime'] is String &&
      RegExp(
        r'^(?:[01]\d|2[0-3]):[0-5]\d$',
      ).hasMatch(source['preferredTime'] as String))
    'preferredTime': source['preferredTime'],
};
