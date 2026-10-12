part of 'reference_preferences_pages.dart';

Widget _responsiveGoalTile(BuildContext context, ListTile tile) =>
    LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 360 &&
            MediaQuery.textScalerOf(context).scale(16) < 24) {
          return tile;
        }
        return Semantics(
          button: tile.onTap != null,
          child: InkWell(
            key: tile.key,
            onTap: tile.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (tile.leading != null) tile.leading!,
                      Expanded(child: tile.title ?? const SizedBox.shrink()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (tile.trailing != null)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: tile.trailing!,
                    ),
                  if (tile.subtitle != null) tile.subtitle!,
                ],
              ),
            ),
          ),
        );
      },
    );

const _nutritionGoalLabels = <String, String>{
  'goal.calories': 'Calories',
  'goal.carbsPercent': 'Carbohydrates',
  'goal.proteinPercent': 'Protein',
  'goal.fatPercent': 'Fat',
  'goal.carbsGrams': 'Carbohydrates',
  'goal.proteinGrams': 'Protein',
  'goal.fatGrams': 'Fat',
  'goal.saturatedFat': 'Saturated fat',
  'goal.polyunsaturatedFat': 'Polyunsaturated fat',
  'goal.monounsaturatedFat': 'Monounsaturated fat',
  'goal.transFat': 'Trans fat',
  'goal.cholesterol': 'Cholesterol',
  'goal.sodium': 'Sodium',
  'goal.potassium': 'Potassium',
  'goal.fiber': 'Fiber',
  'goal.sugar': 'Sugar',
  'goal.vitaminAMcg': 'Vitamin A',
  'goal.vitaminCMg': 'Vitamin C',
  'goal.calciumMg': 'Calcium',
  'goal.ironMg': 'Iron',
  'goal.magnesium': 'Magnesium',
  'goal.phosphorus': 'Phosphorus',
};

/// One discoverable book for this page. Field-specific references and advice
/// stay inside it; no explanatory captions are repeated beside the targets.
class _NutritionGoalBook extends StatelessWidget {
  const _NutritionGoalBook();
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('nutrition-goals-source-book'),
    tooltip: context.strings.text('Health sources & methodology'),
    icon: const Icon(Icons.menu_book_outlined),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final snapshot = ref.watch(nutritionGoalCurrentSnapshotProvider);
          final repository = ref.watch(preferencesRepositoryProvider);
          final visit = ref.watch(nutritionGoalOwnerVisitProvider);
          bool isCurrent() =>
              context.mounted &&
              identical(visit, ref.read(nutritionGoalOwnerVisitProvider)) &&
              identical(repository, ref.read(preferencesRepositoryProvider));
          return AlertDialog(
            title: Text(context.strings.text('Health sources & methodology')),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: snapshot == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final entry in _nutritionGoalLabels.entries)
                            ExpansionTile(
                              key: ValueKey('goal-reference-${entry.key}'),
                              initiallyExpanded: entry.key == 'goal.calories',
                              title: Text(
                                '${_nutritionGoalText(context, entry.value)} · ${snapshot.goals[entry.key]!.unit}',
                              ),
                              childrenPadding: const EdgeInsets.all(12),
                              children: [
                                _GoalSourceDetails(
                                  goal: snapshot.goals[entry.key]!,
                                  label: entry.value,
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
            ),
            actions: [
              TextButton(
                key: const Key('restore-all-nutrition-goals'),
                onPressed: snapshot == null
                    ? null
                    : () async {
                        try {
                          await _restoreAllNutritionGoals(
                            context,
                            repository,
                            isCurrent,
                          );
                        } on Object {
                          if (context.mounted && isCurrent()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.strings.text(
                                    'Could not save changes.',
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'استعادة المقترحات والمراجع'
                      : 'Restore suggestions and references',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.strings.text('Close')),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _GoalSourceDetails extends StatelessWidget {
  const _GoalSourceDetails({required this.goal, required this.label});
  final NutritionGoalValue goal;
  final String label;
  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final source = goal.needsReview
        ? (ar ? 'تحقق من القيمة والوحدة' : 'Check the value and unit')
        : goal.isManual
        ? (goal.source == 'manual_override'
              ? (ar ? 'هدفك المخصص' : 'Your custom target')
              : (ar ? 'القيمة الحالية' : 'Current value'))
        : goal.status == NutritionGoalStatus.generalReference
        ? (ar ? 'مرجع عام للملصق' : 'General label reference')
        : goal.status == NutritionGoalStatus.suggested
        ? (ar ? 'المقترح من ملفك' : 'Suggested from your profile')
        : (ar ? 'غير محدد' : 'Unspecified');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(source),
        const SizedBox(height: 12),
        if (goal.legacyRaw != null)
          SelectableText(
            '${ar ? 'النسبة' : 'Percentage'}: ${goal.legacyRaw!.characters.take(160)}%',
          ),
        if (goal.suggestion != null)
          Text(
            '${ar ? 'المقترح / المرجع' : 'Suggestion / reference'}: ${goal.suggestion} ${goal.unit}',
          ),
        const SizedBox(height: 12),
        Text(
          NutrientDailyReferences.values.containsKey(goal.key)
              ? (ar
                    ? 'FDA Daily Value: مرجع للملصقات للبالغين والأطفال من عمر 4 سنوات، وليس احتياجًا شخصيًا أو حد سمّية. لا يتغير بتغيير السعرات.'
                    : 'FDA Daily Value: label reference for adults and children age 4+, not individual need or a toxicological limit. It does not scale with calories.')
              : goal.key.endsWith('Percent') ||
                    goal.key.endsWith('Grams') ||
                    goal.key == 'goal.calories'
              ? (ar
                    ? 'الماكروز: غرام البروتين والكربوهيدرات ×4، والدهون ×9 kcal. النسبة هنا من الطاقة، وليست %DV أو تقدم التسجيل. المقترح يعتمد على ملفك ونشاطك؛ تخصيصك لا يُمحى عند تحديثهما.'
                    : 'Macros: protein/carbohydrate grams ×4, fat grams ×9 kcal. Percent is energy share, not %DV or logged progress. Suggestions use profile/activity; updates do not erase overrides.')
              : (ar
                    ? 'لا توجد Daily Value لهذا الحقل في المرجع المستخدم. غياب المرجع لا يعني أن الكمية غير محدودة. التخصيص هدفك، وليس اقتراحًا طبيًا من BIL.'
                    : 'No Daily Value is assigned to this field in the reference used. This does not mean unlimited intake. A customization is your target, not BIL medical advice.'),
        ),
        if (goal.key == 'goal.vitaminAMcg')
          Text(
            ar
                ? 'وحدة فيتامين A هنا mcg RAE؛ لا تُحوّل من IU دون معرفة صيغة المصدر.'
                : 'Vitamin A uses mcg RAE. Conversion from IU requires the source form.',
          ),
        if (goal.key == 'goal.fiber') ...[
          Text(
            ar
                ? 'توصية WHO للبالغين: 25 غرامًا على الأقل يوميًا من الألياف الموجودة طبيعيًا في الطعام. قيمة FDA المرجعية للملصق هي 28 غرامًا؛ ليستا نسبة ماكروز أو احتياجًا شخصيًا لكل حالة.'
                : 'WHO recommends at least 25 g/day of naturally occurring fibre for adults. FDA label DV is 28 g. These are distinct references, not macro energy percentages or individualized needs.',
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(
                'https://www.who.int/news/item/17-07-2023-who-updates-guidelines-on-fats-and-carbohydrates',
              ),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('WHO · Dietary fibre'),
          ),
        ],
        if (goal.needsReview)
          Text(
            ar
                ? 'يمكنك تصحيح القيمة والوحدة أو استعادة المقترح.'
                : 'Correct the value/unit or restore the suggestion.',
          ),
        if (goal.legacyRaw != null)
          Text(
            ar
                ? 'النسبة القديمة لا تُحوّل إلى mg/mcg دون إثبات المرجع الذي حُسبت منه.'
                : 'Legacy percent cannot become mg/mcg without its evidenced denominator.',
          ),
        if (goal.warning != null)
          Text(switch (goal.warning) {
            'exceeds_total_target' || 'review_carbohydrate_definition' =>
              ar
                  ? 'هذه القيمة تتجاوز هدف إجمالي الكربوهيدرات أو الدهون المرتبط بها. راجع القيمة وتعريف المغذي؛ لا يُعاد توزيع أهدافك تلقائيًا.'
                  : 'This value exceeds its related carbohydrate or fat target. Check the amount and nutrient definition; targets are not automatically redistributed.',
            'above_label_reference' =>
              ar
                  ? 'هذه القيمة أعلى من المرجع المعروض. التخصيص لا يُعد اقتراحًا غذائيًا من BIL.'
                  : 'This value is above the displayed reference. A customization is not a BIL dietary recommendation.',
            'target_context_unavailable' =>
              ar
                  ? 'الهدف المرتبط غير متاح الآن.'
                  : 'Its related target is currently unavailable.',
            _ =>
              ar
                  ? 'تحقق من مقدار القيمة ووحدتها. هذا تنبيه لجودة الإدخال، وليس حدًا علاجيًا.'
                  : 'Check the magnitude and unit. This is an input-quality check, not a treatment limit.',
          }),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(
              goal.kind == NutritionGoalKind.energy ||
                      goal.kind == NutritionGoalKind.energyShare ||
                      goal.kind == NutritionGoalKind.allocation
                  ? 'https://www.ecfr.gov/current/title-21/section-101.9#p-101.9(c)(1)(i)(C)'
                  : NutrientDailyReferences.sourceUrl,
            ),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(
            '${goal.kind == NutritionGoalKind.energy || goal.kind == NutritionGoalKind.energyShare || goal.kind == NutritionGoalKind.allocation ? '4 / 4 / 9 · ' : 'FDA · '}${_nutritionGoalText(context, label)}',
          ),
        ),
      ],
    );
  }
}

Future<bool> _restoreGoalSuggestion(
  BuildContext context,
  PreferencesRepository repository,
  String key,
  bool Function() isCurrent,
) async {
  final group = NutritionGoalSnapshot.macroKeys.contains(key);
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(ar ? 'استعادة المقترح' : 'Restore suggestion'),
      content: Text(
        group
            ? (ar
                  ? 'ستعود السعرات وجميع الماكروز إلى اقتراح ملفك، وستُزال أقفالها.'
                  : 'Restore profile calorie and macro suggestions and remove their locks.')
            : (ar
                  ? 'سيعود هذا الهدف فقط إلى المقترح أو المرجع.'
                  : 'Restore the suggestion or reference for this target only.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.strings.text('Cancel')),
        ),
        FilledButton(
          key: const Key('confirm-goal-restore'),
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
  final removals = group
      ? [
          ...NutritionGoalSnapshot.macroKeys,
          'goal.macroEditor.v2',
          'goal.macroLastEdited',
          for (final item in ['carbs', 'protein', 'fat']) ...[
            'goal.lock.$item',
            'goal.lockMode.$item',
          ],
          for (final target in NutritionGoalSnapshot.macroKeys)
            'goal.origin.$target',
        ]
      : [key, 'goal.origin.$key', 'goal.confirmed.$key'];
  final committed = await repository.mutateIfUnchanged(
    isCurrent: isCurrent,
    expected: {
      for (final target in NutritionGoalSnapshot.storageKeys)
        target: stored[target],
    },
    set: {
      'goal.backup.v1.${DateTime.now().microsecondsSinceEpoch}': jsonEncode({
        'version': 1,
        'reason': 'explicit_restore',
        'values': stored,
      }),
      if (NutritionGoalSnapshot.legacyKeys.containsKey(key))
        'goal.legacyReviewed.$key': 'true',
    },
    remove: removals,
  );
  if (!committed) throw StateError('Goals changed during restore. Retry.');
  return isCurrent();
}
