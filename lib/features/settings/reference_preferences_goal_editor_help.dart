part of 'reference_preferences_pages.dart';

/// The page stays free of captions. Guidance appears only in the opened editor
/// and its book, as requested by the owner.
class _GoalEditorBook extends StatelessWidget {
  const _GoalEditorBook({
    required this.goal,
    required this.label,
    required this.isCurrent,
  });
  final NutritionGoalValue goal;
  final String label;
  final bool Function() isCurrent;
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('nutrition-goal-editor-book'),
    tooltip: context.strings.text('Health sources & methodology'),
    icon: const Icon(Icons.menu_book_outlined),
    onPressed: () {
      if (!isCurrent()) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Consumer(
          builder: (context, ref, _) {
            ref.watch(nutritionGoalOwnerVisitProvider);
            return AlertDialog(
              title: Text(_nutritionGoalText(context, label)),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: isCurrent()
                      ? _GoalSourceDetails(goal: goal, label: label)
                      : const SizedBox.shrink(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.strings.text('Close')),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _GoalEditorNotice extends StatelessWidget {
  const _GoalEditorNotice();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      Localizations.localeOf(context).languageCode == 'ar'
          ? 'هذه القيمة تحتاج مراجعة. تحقق من الرقم والوحدة قبل الحفظ.'
          : 'This value needs review. Check the number and unit before saving.',
      key: const Key('nutrition-goal-editor-notice'),
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}
