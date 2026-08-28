part of 'weekly_report_page.dart';

class _Food extends ConsumerStatefulWidget {
  const _Food({required this.report});
  final WeeklyReportSnapshot report;

  @override
  ConsumerState<_Food> createState() => _FoodState();
}

class _FoodState extends ConsumerState<_Food> {
  String? saved;
  bool loadingFeedback = true;
  bool savingFeedback = false;
  bool feedbackError = false;
  String? failedFeedbackChoice;

  String get _feedbackKey =>
      'weekly_report_feedback_${widget.report.days.isEmpty ? 'empty' : widget.report.days.last.dayKey}';

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    if (mounted) {
      setState(() {
        loadingFeedback = true;
        feedbackError = false;
        failedFeedbackChoice = null;
      });
    }
    try {
      final value = await ref
          .read(preferencesRepositoryProvider)
          .get(_feedbackKey);
      if (mounted) setState(() => saved = value);
    } catch (_) {
      if (mounted) setState(() => feedbackError = true);
    } finally {
      if (mounted) setState(() => loadingFeedback = false);
    }
  }

  Future<void> _saveFeedback(String value) async {
    if (savingFeedback || loadingFeedback) return;
    setState(() {
      savingFeedback = true;
      feedbackError = false;
      failedFeedbackChoice = null;
    });
    try {
      await ref.read(preferencesRepositoryProvider).set(_feedbackKey, value);
      if (mounted) setState(() => saved = value);
    } catch (_) {
      if (mounted) {
        setState(() {
          feedbackError = true;
          failedFeedbackChoice = value;
        });
      }
    } finally {
      if (mounted) setState(() => savingFeedback = false);
    }
  }

  int _count(List<String> words) => widget.report.foodCategoryCounts.entries
      .where((entry) => words.any(entry.key.contains))
      .fold(0, (sum, entry) => sum + entry.value);

  @override
  Widget build(BuildContext context) {
    final dietaryPreferences = ref.watch(dietaryPreferencesProvider).value;
    final rows = <_FoodSignal>[
      _FoodSignal(
        label: _t(context, 'vegetables'),
        count: _count(['vegetable', '\u062e\u0636\u0631']),
        eyebrow: _weeklySurfaceText(context, 'NUTRITION SUPERSTARS'),
        description: _weeklySurfaceText(
          context,
          'Plants packed with vitamins, minerals and antioxidants.',
        ),
        color: const Color(0xFF2E9B72),
        icon: Icons.eco_rounded,
      ),
      _FoodSignal(
        label: _t(context, 'fruit'),
        count: _count(['fruit', '\u0641\u0627\u0643\u0647']),
        eyebrow: _weeklySurfaceText(context, 'FULL OF FIBER'),
        description: _weeklySurfaceText(
          context,
          'Fresh fruits add fiber, color and natural sweetness.',
        ),
        color: const Color(0xFFE05D67),
        icon: Icons.spa_rounded,
      ),
      _FoodSignal(
        label: _t(context, 'proteins'),
        count: _count([
          'protein',
          'meat',
          'egg',
          'fish',
          'legume',
          '\u0628\u0631\u0648\u062a\u064a\u0646',
          '\u0644\u062d\u0648\u0645',
        ]),
        eyebrow: _weeklySurfaceText(context, 'NUTRITION POWERHOUSES'),
        description: _weeklySurfaceText(
          context,
          'Protein-rich foods help maintain and repair muscle.',
        ),
        color: const Color(0xFFF0A22E),
        icon: Icons.fitness_center_rounded,
      ),
      _FoodSignal(
        label: _t(context, 'snacks'),
        count: _count([
          'snack',
          'sweet',
          'dessert',
          '\u062d\u0644\u0648\u064a\u0627\u062a',
        ]),
        eyebrow: _weeklySurfaceText(context, 'ENJOY MINDFULLY'),
        description: _weeklySurfaceText(
          context,
          'Snacks count too\u2014logging them makes the weekly picture honest.',
        ),
        color: const Color(0xFF527BEA),
        icon: Icons.cookie_rounded,
      ),
      _FoodSignal(
        label: _t(context, 'alcohol'),
        count: _count(['alcohol', 'beer', 'wine', '\u0643\u062d\u0648\u0644']),
        eyebrow: _weeklySurfaceText(context, 'KNOW YOUR PATTERN'),
        description: _weeklySurfaceText(
          context,
          'Alcohol can affect sleep, hydration and recovery.',
        ),
        color: const Color(0xFF7A68B5),
        icon: Icons.water_drop_rounded,
      ),
    ];
    final evidencedRows = rows
        .where((row) => row.count > 0)
        .toList(growable: false);
    final maxSignal = evidencedRows.fold<int>(
      1,
      (maximum, row) => row.count > maximum ? row.count : maximum,
    );

    return Column(
      key: const Key('weekly-food-insights-hero'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF12A494), Color(0xFF08636B)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.radar_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(context, 'food'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t(context, 'food_intro'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (dietaryPreferences?.hasFoodSelectionConstraints == true) ...[
          Container(
            key: const Key('weekly-dietary-preferences-boundary'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _weeklySurfaceText(
                context,
                'Food suggestions use your saved dietary pattern, requirements, and allergen exclusions. Logged-food totals remain unchanged.',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (evidencedRows.isEmpty)
          _FoodSignalsEmptyState(message: _t(context, 'frequent_empty_action'))
        else ...[
          _FoodCompositionStrip(rows: evidencedRows),
          const SizedBox(height: 10),
          Text(
            _t(context, 'logged'),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            key: const Key('weekly-food-signal-grid'),
            builder: (context, constraints) {
              final singleColumn =
                  constraints.maxWidth < 520 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.3;
              final width = singleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final row in evidencedRows)
                    SizedBox(
                      width: width,
                      child: _FoodSignalCard(
                        key: Key('weekly-food-category-${rows.indexOf(row)}'),
                        signal: row,
                        strength: row.count / maxSignal,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _weeklySurfaceText(
              context,
              'Keep logging foods to unlock more personalized patterns and weekly insights.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _FoodFeedbackPanel(
          saved: saved,
          loading: loadingFeedback,
          saving: savingFeedback,
          hasError: feedbackError,
          onRetry: failedFeedbackChoice == null
              ? _loadFeedback
              : () => _saveFeedback(failedFeedbackChoice!),
          onSave: _saveFeedback,
        ),
      ],
    );
  }
}

@immutable
class _FoodSignal {
  const _FoodSignal({
    required this.label,
    required this.count,
    required this.eyebrow,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final String eyebrow;
  final String description;
  final Color color;
  final IconData icon;
}

class _FoodSignalsEmptyState extends StatelessWidget {
  const _FoodSignalsEmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('weekly-food-insights-empty'),
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          size: 38,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _FoodCompositionStrip extends StatelessWidget {
  const _FoodCompositionStrip({required this.rows});
  final List<_FoodSignal> rows;

  @override
  Widget build(BuildContext context) => Semantics(
    label: _t(context, 'logged'),
    child: Container(
      key: const Key('weekly-food-composition-strip'),
      height: 10,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(99)),
      child: Row(
        children: [
          for (final row in rows)
            Expanded(
              flex: row.count,
              child: ColoredBox(color: row.color),
            ),
        ],
      ),
    ),
  );
}

class _FoodSignalCard extends StatelessWidget {
  const _FoodSignalCard({
    super.key,
    required this.signal,
    required this.strength,
  });

  final _FoodSignal signal;
  final double strength;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          signal.color.withValues(alpha: .13),
          signal.color.withValues(alpha: .035),
        ],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: signal.color.withValues(alpha: .28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: signal.color,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(signal.icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: signal.color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${signal.count}',
                style: TextStyle(
                  color: signal.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          signal.eyebrow,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: signal.color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          signal.label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(signal.description),
        const SizedBox(height: 13),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: strength.clamp(0, 1),
            color: signal.color,
            backgroundColor: signal.color.withValues(alpha: .12),
          ),
        ),
      ],
    ),
  );
}

class _FoodFeedbackPanel extends StatelessWidget {
  const _FoodFeedbackPanel({
    required this.saved,
    required this.loading,
    required this.saving,
    required this.hasError,
    required this.onRetry,
    required this.onSave,
  });

  final String? saved;
  final bool loading;
  final bool saving;
  final bool hasError;
  final VoidCallback onRetry;
  final ValueChanged<String> onSave;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('weekly-food-feedback-panel'),
    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
    decoration: BoxDecoration(
      color: const Color(0xFF071F2D),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          saved == null ? _t(context, 'helpful') : _t(context, 'saved'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _weeklySurfaceText(
            context,
            'Your feedback helps us make these weekly patterns more useful.',
          ),
          style: const TextStyle(color: Color(0xBFFFFFFF)),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            _t(context, 'feedback_error'),
            style: const TextStyle(color: Color(0xFFFFC6C6)),
          ),
          TextButton(
            key: const Key('weekly-food-feedback-retry'),
            onPressed: saving ? null : onRetry,
            child: Text(context.strings.text('Retry')),
          ),
        ],
        Wrap(
          key: const Key('weekly-food-feedback-actions'),
          spacing: 6,
          children: [
            IconButton.filledTonal(
              key: const Key('weekly-food-feedback-up'),
              onPressed: loading || saving ? null : () => onSave('up'),
              tooltip: _t(context, 'helpful_action'),
              icon: Icon(
                saved == 'up'
                    ? Icons.thumb_up_rounded
                    : Icons.thumb_up_outlined,
              ),
            ),
            IconButton.filledTonal(
              key: const Key('weekly-food-feedback-down'),
              onPressed: loading || saving ? null : () => onSave('down'),
              tooltip: _t(context, 'not_helpful_action'),
              icon: Icon(
                saved == 'down'
                    ? Icons.thumb_down_rounded
                    : Icons.thumb_down_outlined,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
