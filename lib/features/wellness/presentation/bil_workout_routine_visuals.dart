part of 'bil_workout_routines_page.dart';

class _WorkoutCoverFallback extends StatelessWidget {
  const _WorkoutCoverFallback({required this.item});
  final WellnessContentItem item;

  @override
  Widget build(BuildContext context) {
    final assetName = _categoryCoverAsset(item.category);
    final placeholder = _WorkoutCoverPlaceholder(category: item.category);
    if (assetName == null) return placeholder;
    return Semantics(
      container: true,
      image: true,
      label: _promotionalWorkoutCoverLabel(context, item.category),
      child: ExcludeSemantics(
        child: Image.asset(
          assetName,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}

class _WorkoutCoverPlaceholder extends StatelessWidget {
  const _WorkoutCoverPlaceholder({required this.category});
  final String? category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
      ),
      child: Icon(
        _categoryIcon(category),
        size: 74,
        color: colors.onPrimaryContainer.withValues(alpha: 0.72),
      ),
    );
  }
}

enum _WorkoutVisualCategory {
  strength,
  cardio,
  mobility,
  hiit,
  kettlebell,
  recovery,
  other,
}

String? _categoryCoverAsset(String? category) =>
    switch (_workoutVisualCategory(category)) {
      _WorkoutVisualCategory.strength =>
        'assets/images/workouts/workout_strength_cover_v1.png',
      _WorkoutVisualCategory.cardio =>
        'assets/images/workouts/workout_cardio_cover_v1.png',
      _WorkoutVisualCategory.mobility =>
        'assets/images/workouts/workout_mobility_cover_v1.png',
      _WorkoutVisualCategory.hiit =>
        'assets/images/workouts/workout_hiit_cover_v1.png',
      _WorkoutVisualCategory.kettlebell =>
        'assets/images/workouts/workout_kettlebell_cover_v1.png',
      _WorkoutVisualCategory.recovery =>
        'assets/images/workouts/workout_recovery_cover_v1.png',
      _WorkoutVisualCategory.other => null,
    };

IconData _categoryIcon(String? category) {
  final value = _normalizeWorkoutCategory(category);
  if (_containsAny(value, const [
    'cycle',
    'cycling',
    'cyclisme',
    'ciclismo',
    'bisiklet',
    'دراجه',
  ])) {
    return Icons.directions_bike_rounded;
  }
  return switch (_workoutVisualCategory(category)) {
    _WorkoutVisualCategory.strength => Icons.fitness_center_rounded,
    _WorkoutVisualCategory.cardio => Icons.directions_run_rounded,
    _WorkoutVisualCategory.mobility => Icons.self_improvement_rounded,
    _WorkoutVisualCategory.hiit => Icons.electric_bolt_rounded,
    _WorkoutVisualCategory.kettlebell => Icons.sports_gymnastics_rounded,
    _WorkoutVisualCategory.recovery => Icons.spa_rounded,
    _WorkoutVisualCategory.other => Icons.sports_gymnastics_rounded,
  };
}

_WorkoutVisualCategory _workoutVisualCategory(String? category) {
  final value = _normalizeWorkoutCategory(category);
  if (_containsAny(value, const [
    'kettlebell',
    'kettle bell',
    'girya',
    'poids russe',
    'pesa rusa',
    'rus agirligi',
    'كيتل بيل',
    'كره حديديه',
  ])) {
    return _WorkoutVisualCategory.kettlebell;
  }
  if (_containsAny(value, const [
    'hiit',
    'high intensity',
    'interval training',
    'fractionne',
    'haute intensite',
    'alta intensidad',
    'intervalos',
    'yuksek yogunluk',
    'aralikli',
    'هيت',
    'عالي الشده',
    'عاليه الشده',
    'متقطع',
  ])) {
    return _WorkoutVisualCategory.hiit;
  }
  if (_containsAny(value, const [
    'recovery',
    'restore',
    'restorative',
    'regeneration',
    'recuperation',
    'toparlanma',
    'yenilenme',
    'iyilesme',
    'استشفاء',
    'تعافي',
    'استعاده',
    'استرخاء',
  ])) {
    return _WorkoutVisualCategory.recovery;
  }
  if (_containsAny(value, const [
    'mobility',
    'flexibility',
    'stretch',
    'yoga',
    'mobilite',
    'souplesse',
    'etirement',
    'movilidad',
    'flexibilidad',
    'estiramiento',
    'hareketlilik',
    'esneklik',
    'germe',
    'يوغا',
    'مرونه',
    'اطاله',
  ])) {
    return _WorkoutVisualCategory.mobility;
  }
  if (_containsAny(value, const [
    'strength',
    'resistance',
    'weight training',
    'bodyweight',
    'dumbbell',
    'musculation',
    'renforcement',
    'force',
    'fuerza',
    'pesas',
    'musculacion',
    'guc',
    'kuvvet',
    'direnc',
    'قوه',
    'مقاومه',
    'اوزان',
    'وزن الجسم',
  ])) {
    return _WorkoutVisualCategory.strength;
  }
  if (_containsAny(value, const [
    'cardio',
    'aerobic',
    'endurance',
    'running',
    'run',
    'cycling',
    'cycle',
    'course',
    'cyclisme',
    'carrera',
    'correr',
    'ciclismo',
    'kardiyo',
    'kosu',
    'bisiklet',
    'كارديو',
    'هوائي',
    'جري',
    'دراجه',
  ])) {
    return _WorkoutVisualCategory.cardio;
  }
  return _WorkoutVisualCategory.other;
}

bool _containsAny(String value, List<String> candidates) =>
    candidates.any(value.contains);

String _normalizeWorkoutCategory(String? category) => (category ?? '')
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[àáâãäå]'), 'a')
    .replaceAll(RegExp(r'[èéêë]'), 'e')
    .replaceAll(RegExp(r'[ìíîïı]'), 'i')
    .replaceAll(RegExp(r'[òóôõö]'), 'o')
    .replaceAll(RegExp(r'[ùúûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

String _promotionalWorkoutCoverLabel(BuildContext context, String? category) {
  final name = category?.trim();
  final visibleName = name == null || name.isEmpty
      ? switch (Localizations.localeOf(context).languageCode) {
          'ar' => 'التمارين',
          'fr' => 'entraînement',
          'es' => 'entrenamiento',
          'tr' => 'egzersiz',
          _ => 'workout',
        }
      : name;
  return switch (Localizations.localeOf(context).languageCode) {
    'ar' => 'صورة ترويجية لفئة $visibleName، وليست تعليمات لأداء الحركة.',
    'fr' =>
      'Image promotionnelle de la catégorie $visibleName ; ce n’est pas une instruction de mouvement.',
    'es' =>
      'Imagen promocional de la categoría $visibleName; no es una instrucción de movimiento.',
    'tr' =>
      '$visibleName kategorisi için tanıtım görseli; hareket talimatı değildir.',
    _ =>
      'Promotional image for the $visibleName category; not an exercise instruction.',
  };
}
