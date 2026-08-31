part of 'bil_workout_routines_page.dart';

/// An audience view over verified workout metadata.
///
/// This is deliberately not an exercise-eligibility or health rule. Content
/// publishers declare the audience explicitly; legacy tags are consulted only
/// when the typed metadata remains neutral.
enum _WorkoutPresenterFilter { all, men, women }

enum _WorkoutPresenter { man, woman }

const _malePresenterTags = <String>{
  'presenter:male',
  'presenter:man',
  'presenter:adult-male',
  'presenter:adult-man',
};

const _femalePresenterTags = <String>{
  'presenter:female',
  'presenter:woman',
  'presenter:adult-female',
  'presenter:adult-woman',
};

const _menAudienceTags = <String>{'audience:men'};

const _womenAudienceTags = <String>{'audience:women'};

const _adultPresenterTags = <String>{
  'presenter:adult',
  'presenter:adult-male',
  'presenter:adult-man',
  'presenter:adult-female',
  'presenter:adult-woman',
};

const _generatedPreviewTags = <String>{
  'preview:generated',
  'media:generated',
  'origin:generated',
  'generated-preview',
  'ai-generated',
};

Set<String> _normalizedWorkoutTags(WellnessContentItem item) => item.tags
    .map((tag) => tag.trim().toLowerCase())
    .where((tag) => tag.isNotEmpty)
    .toSet();

_WorkoutPresenter? _workoutPresenter(WellnessContentItem item) {
  switch (item.presenter) {
    case WellnessWorkoutPresenter.adultMale:
      return _WorkoutPresenter.man;
    case WellnessWorkoutPresenter.adultFemale:
      return _WorkoutPresenter.woman;
    case WellnessWorkoutPresenter.neutral:
      break;
  }
  final tags = _normalizedWorkoutTags(item);
  if (tags.any(_malePresenterTags.contains)) return _WorkoutPresenter.man;
  if (tags.any(_femalePresenterTags.contains)) return _WorkoutPresenter.woman;
  return null;
}

_WorkoutPresenterFilter _workoutAudience(WellnessContentItem item) {
  switch (item.audience) {
    case WellnessWorkoutAudience.men:
      return _WorkoutPresenterFilter.men;
    case WellnessWorkoutAudience.women:
      return _WorkoutPresenterFilter.women;
    case WellnessWorkoutAudience.all:
      break;
  }
  final tags = _normalizedWorkoutTags(item);
  if (tags.any(_menAudienceTags.contains)) return _WorkoutPresenterFilter.men;
  if (tags.any(_womenAudienceTags.contains)) {
    return _WorkoutPresenterFilter.women;
  }
  return _WorkoutPresenterFilter.all;
}

bool _matchesWorkoutPresenter(
  WellnessContentItem item,
  _WorkoutPresenterFilter filter,
) => switch (filter) {
  _WorkoutPresenterFilter.all => true,
  _WorkoutPresenterFilter.men =>
    _workoutAudience(item) != _WorkoutPresenterFilter.women &&
        _workoutPresenter(item) != _WorkoutPresenter.woman,
  _WorkoutPresenterFilter.women =>
    _workoutAudience(item) != _WorkoutPresenterFilter.men &&
        _workoutPresenter(item) != _WorkoutPresenter.man,
};

bool _hasAdultPresenter(WellnessContentItem item) {
  if (item.presenter == WellnessWorkoutPresenter.adultMale ||
      item.presenter == WellnessWorkoutPresenter.adultFemale) {
    return true;
  }
  final tags = _normalizedWorkoutTags(item);
  return tags.any(_adultPresenterTags.contains);
}

bool _hasGeneratedPreview(WellnessContentItem item) {
  if (item.syntheticPerformer) {
    return item.videoMedia?.mediaRole == WellnessMediaRole.preview;
  }
  final tags = _normalizedWorkoutTags(item);
  return tags.any(_generatedPreviewTags.contains);
}

class _WorkoutPresenterFilterPanel extends StatelessWidget {
  const _WorkoutPresenterFilterPanel({
    required this.value,
    required this.onChanged,
  });

  final _WorkoutPresenterFilter value;
  final ValueChanged<_WorkoutPresenterFilter> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: _presenterFilterSemantics(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _presenterFilterHeading(context),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _presenterFilterDisclaimer(context),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _WorkoutPresenterFilter.values)
              ChoiceChip(
                key: ValueKey('workout-presenter-filter-${filter.name}'),
                label: Text(_presenterFilterChoice(context, filter)),
                selected: value == filter,
                onSelected: (_) => onChanged(filter),
              ),
          ],
        ),
      ],
    ),
  );
}

List<({IconData icon, String text})> _workoutPresenterMetadata(
  BuildContext context,
  WellnessContentItem item,
) {
  final result = <({IconData icon, String text})>[];
  if (_hasAdultPresenter(item)) {
    result.add((
      icon: Icons.person_rounded,
      text: _adultPresenterLabel(context, _workoutPresenter(item)),
    ));
  }
  if (_hasGeneratedPreview(item)) {
    result.add((
      icon: Icons.auto_awesome_rounded,
      text: _generatedPreviewLabel(context),
    ));
  }
  return result;
}

String _presenterFilterHeading(BuildContext context) =>
    switch (Localizations.localeOf(context).languageCode) {
      'ar' => 'جمهور التمارين',
      'fr' => 'Public des entraînements',
      'es' => 'Público de los entrenamientos',
      'tr' => 'Antrenman kitlesi',
      _ => 'Workout audience',
    };

String _presenterFilterChoice(
  BuildContext context,
  _WorkoutPresenterFilter filter,
) {
  final language = Localizations.localeOf(context).languageCode;
  return switch ((language, filter)) {
    ('ar', _WorkoutPresenterFilter.all) => 'الكل',
    ('ar', _WorkoutPresenterFilter.men) => 'رجال',
    ('ar', _WorkoutPresenterFilter.women) => 'نساء',
    ('fr', _WorkoutPresenterFilter.all) => 'Tous',
    ('fr', _WorkoutPresenterFilter.men) => 'Hommes',
    ('fr', _WorkoutPresenterFilter.women) => 'Femmes',
    ('es', _WorkoutPresenterFilter.all) => 'Todos',
    ('es', _WorkoutPresenterFilter.men) => 'Hombres',
    ('es', _WorkoutPresenterFilter.women) => 'Mujeres',
    ('tr', _WorkoutPresenterFilter.all) => 'Tümü',
    ('tr', _WorkoutPresenterFilter.men) => 'Erkekler',
    ('tr', _WorkoutPresenterFilter.women) => 'Kadınlar',
    (_, _WorkoutPresenterFilter.all) => 'All',
    (_, _WorkoutPresenterFilter.men) => 'Men',
    (_, _WorkoutPresenterFilter.women) => 'Women',
  };
}

String _presenterFilterDisclaimer(BuildContext context) =>
    ReleasePolishRuntimeCopy.textForLocale(
      ReleasePolishRuntimeCopy.presenterSuitability,
      Localizations.localeOf(context),
    );

String _presenterFilterSemantics(BuildContext context) =>
    '${_presenterFilterHeading(context)}. ${_presenterFilterDisclaimer(context)}';

String _adultPresenterLabel(
  BuildContext context,
  _WorkoutPresenter? presenter,
) {
  final language = Localizations.localeOf(context).languageCode;
  return switch ((language, presenter)) {
    ('ar', _WorkoutPresenter.man) => 'مقدّم بالغ',
    ('ar', _WorkoutPresenter.woman) => 'مقدّمة بالغة',
    ('ar', null) => 'مقدّم بالغ',
    ('fr', _) => 'Présentateur adulte',
    ('es', _) => 'Presentador adulto',
    ('tr', _) => 'Yetişkin sunucu',
    (_, _WorkoutPresenter.man) => 'Adult male presenter',
    (_, _WorkoutPresenter.woman) => 'Adult female presenter',
    (_, null) => 'Adult presenter',
  };
}

String _generatedPreviewLabel(BuildContext context) =>
    switch (Localizations.localeOf(context).languageCode) {
      'ar' => 'معاينة مولّدة',
      'fr' => 'Aperçu généré',
      'es' => 'Vista previa generada',
      'tr' => 'Oluşturulmuş önizleme',
      _ => 'Generated preview',
    };
