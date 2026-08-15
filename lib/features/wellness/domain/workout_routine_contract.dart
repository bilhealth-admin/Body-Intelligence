class WorkoutRoutineMapping {
  const WorkoutRoutineMapping({
    required this.acceptedMovementIds,
    required this.unavailableMovementIds,
  });

  final List<String> acceptedMovementIds;
  final List<String> unavailableMovementIds;

  bool get canComplete => acceptedMovementIds.isNotEmpty;
  bool get isComplete => unavailableMovementIds.isEmpty;
}

/// Maps a saved routine only to movement ids accepted by the installed,
/// trusted content pack. Video availability is intentionally independent.
WorkoutRoutineMapping validateWorkoutRoutineMapping({
  required Iterable<String> requestedMovementIds,
  required Set<String> trustedMovementIds,
}) {
  final accepted = <String>[];
  final unavailable = <String>[];
  final seen = <String>{};
  for (final rawId in requestedMovementIds) {
    final id = rawId.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    (trustedMovementIds.contains(id) ? accepted : unavailable).add(id);
  }
  return WorkoutRoutineMapping(
    acceptedMovementIds: List.unmodifiable(accepted),
    unavailableMovementIds: List.unmodifiable(unavailable),
  );
}

String workoutRoutineCopy(String languageCode, String key) {
  const copy = <String, Map<String, String>>{
    'completeRoutine': {
      'en': 'Complete routine',
      'ar': 'إكمال الروتين',
      'fr': 'Terminer la routine',
      'es': 'Completar rutina',
      'tr': 'Rutini tamamla',
    },
    'routineCompleted': {
      'en': 'Routine added to today.',
      'ar': 'أُضيف الروتين إلى اليوم.',
      'fr': 'Routine ajoutée à aujourd’hui.',
      'es': 'Rutina añadida a hoy.',
      'tr': 'Rutin bugüne eklendi.',
    },
    'movementsUnavailable': {
      'en': 'Some saved movements are no longer available',
      'ar': 'بعض الحركات المحفوظة لم تعد متاحة',
      'fr': 'Certains mouvements enregistrés ne sont plus disponibles',
      'es': 'Algunos movimientos guardados ya no están disponibles',
      'tr': 'Bazı kayıtlı hareketler artık kullanılamıyor',
    },
    'noAcceptedMovements': {
      'en': 'No trusted movements are available in this routine.',
      'ar': 'لا توجد حركات موثوقة متاحة في هذا الروتين.',
      'fr': 'Aucun mouvement vérifié n’est disponible dans cette routine.',
      'es': 'No hay movimientos verificados disponibles en esta rutina.',
      'tr': 'Bu rutinde güvenilir hareket bulunmuyor.',
    },
  };
  final values = copy[key];
  if (values == null) return key;
  return values[languageCode] ?? values['en']!;
}
