part of 'reference_preferences_pages.dart';

Future<bool> _saveAdditionalGoal(
  BuildContext context,
  PreferencesRepository repository,
  String key,
  String draft,
  Map<String, double> defaults,
  bool Function() isCurrent,
) async {
  final stored = await repository
      .watchSnapshot(NutritionGoalSnapshot.storageKeys)
      .first;
  if (!isCurrent()) throw StateError('preference_owner_changed');
  final candidate = NutritionGoalSnapshot.resolve({
    ...stored,
    key: draft,
  }, defaults).goals[key]!;
  if (candidate.status == NutritionGoalStatus.invalid) {
    throw const FormatException('Invalid target');
  }
  if (candidate.reviewToken != null) {
    if (!context.mounted) return false;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BilPearlMaterialAlertDialog(
        title: Text(ar ? 'مراجعة الهدف المخصص' : 'Review custom target'),
        content: Text(
          ar
              ? 'هذه القيمة تحتاج مراجعة: $draft ${candidate.unit}. راجع الوحدة والمراجع في كتاب الصفحة. هل تريد اعتماد هذا التخصيص رغم التنبيه؟'
              : 'This value needs review: $draft ${candidate.unit}. Check its unit and the page book references. Keep this customization despite the warning?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            key: const Key('confirm-unusual-goal'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ar ? 'اعتماد تخصيصي' : 'Keep my target'),
          ),
        ],
      ),
    );
    if (accepted != true || !isCurrent()) return false;
  }
  final committed = await repository.mutateIfUnchanged(
    isCurrent: isCurrent,
    expected: {
      for (final target in NutritionGoalSnapshot.storageKeys)
        target: stored[target],
    },
    set: {
      key: draft,
      'goal.origin.$key': 'manual_override',
      if (candidate.reviewToken != null)
        'goal.confirmed.$key': candidate.reviewToken!,
    },
    remove: candidate.reviewToken == null ? ['goal.confirmed.$key'] : const [],
  );
  if (!committed) throw StateError('Goals changed while editing. Retry.');
  return isCurrent();
}

/// Explicit, atomic reset only after reviewing the complete scope. Unknown old
/// percent keys are preserved with the backup; no denominator is invented.
Future<bool> _restoreAllNutritionGoals(
  BuildContext context,
  PreferencesRepository repository,
  bool Function() isCurrent,
) async {
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => BilPearlMaterialAlertDialog(
      title: Text(ar ? 'استعادة الأهداف' : 'Restore targets'),
      content: Text(
        ar
            ? 'سيُستعاد اقتراح السعرات والماكروز من ملفك والمراجع الغذائية الرسمية، وستُزال الأقفال والتخصيصات الحالية. المغذيات التي لا تملك مرجعًا محددًا تبقى غير محددة.'
            : 'Restore profile calorie/macro suggestions and official nutrient references, replacing current overrides and locks. Fields with no established reference stay unspecified.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.strings.text('Cancel')),
        ),
        FilledButton(
          key: const Key('confirm-all-goal-restore'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(ar ? 'استعادة' : 'Restore'),
        ),
      ],
    ),
  );
  if (confirmed != true || !isCurrent()) return false;
  final stored = await repository
      .watchSnapshot(NutritionGoalSnapshot.storageKeys)
      .first;
  if (!isCurrent()) return false;
  final removals = [
    ...NutritionGoalSnapshot.units.keys,
    for (final key in NutritionGoalSnapshot.units.keys) ...[
      'goal.origin.$key',
      'goal.confirmed.$key',
    ],
    'goal.macroEditor.v2',
    'goal.macroLastEdited',
    for (final macro in ['carbs', 'protein', 'fat']) ...[
      'goal.lock.$macro',
      'goal.lockMode.$macro',
    ],
  ];
  final committed = await repository.mutateIfUnchanged(
    isCurrent: isCurrent,
    expected: {
      for (final key in NutritionGoalSnapshot.storageKeys) key: stored[key],
    },
    set: {
      'goal.backup.v1.${DateTime.now().microsecondsSinceEpoch}': jsonEncode({
        'version': 1,
        'reason': 'explicit_restore_all',
        'values': stored,
      }),
      for (final key in NutritionGoalSnapshot.legacyKeys.keys)
        'goal.legacyReviewed.$key': 'true',
    },
    remove: removals,
  );
  if (!committed) throw StateError('Goals changed during restore. Retry.');
  return isCurrent();
}
