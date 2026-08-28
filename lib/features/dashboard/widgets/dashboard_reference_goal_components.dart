part of 'premium_dashboard_benchmark.dart';

// Retained for the tablet/reference fallback composition.
// ignore: unused_element
class _DailyGoalStrip extends StatelessWidget {
  const _DailyGoalStrip({
    required this.arabic,
    required this.consumed,
    required this.goal,
    required this.onTap,
  });

  final bool arabic;
  final int consumed;
  final int goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);
    final remaining = (goal - consumed).clamp(0, goal);
    return Material(
      color: const Color(0xFFE6F7D6),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.flag_circle_rounded,
                size: 21,
                color: Color(0xFF4D8F15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    color: const Color(0xFF78C82F),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$remaining ${_referenceText(context, 'left', 'متبقية')}',
                style: const TextStyle(
                  color: Color(0xFF356B0F),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Retained for the tablet/reference fallback composition.
// ignore: unused_element
class _MissingDailyGoalCard extends StatelessWidget {
  const _MissingDailyGoalCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 21,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _referenceText(
                  context,
                  'Set your calorie goal to track daily progress',
                  'حدد هدف السعرات لتتبع تقدمك اليومي',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

/// Shared visual container for the reference-dashboard cards.
class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: const EdgeInsets.all(16), child: child);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
      shadowColor: const Color(0x22000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Phone-first calorie summary matching the familiar food-diary hierarchy:
/// consumed/goal and remaining are readable before a single linear bar.
class _ReferenceCaloriesCard extends StatelessWidget {
  const _ReferenceCaloriesCard({
    required this.consumed,
    required this.goal,
    required this.baseGoal,
    required this.burned,
    required this.net,
    required this.remainingOverride,
    required this.burnedApplied,
    required this.onEdit,
  });

  final int consumed;
  final int goal;
  final int baseGoal;
  final int burned;
  final int net;
  final int? remainingOverride;
  final bool burnedApplied;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal > 0;
    final remaining = hasGoal ? remainingOverride ?? goal - consumed : null;
    final progress = hasGoal ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final scheme = Theme.of(context).colorScheme;
    final localizedConsumed = _referenceText(context, 'consumed', 'المستهلك');
    final consumedLabel = Localizations.localeOf(context).languageCode == 'en'
        ? 'Consumed'
        : localizedConsumed;
    final remainingLabel = hasGoal
        ? _referenceText(context, 'left', 'متبقي')
        : _referenceText(context, 'Edit goal', 'تعديل الهدف');

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.25,
      child: Semantics(
        container: true,
        label:
            '${_referenceText(context, 'Calories', 'السعرات الحرارية')}: '
            '$consumed $consumedLabel, '
            '${hasGoal ? goal : _referenceText(context, 'Goal or nutrition evidence is unavailable', 'بيانات الهدف أو التغذية غير متاحة')}, '
            '${remaining ?? 0} $remainingLabel',
        child: _ReferenceCard(
          child: Column(
            key: const Key('dashboard-reference-calories-card'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _referenceText(context, 'Calories', 'السعرات الحرارية'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.25,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('dashboard-reference-calories-edit'),
                    tooltip: _referenceText(
                      context,
                      'Edit goal',
                      'تعديل الهدف',
                    ),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.tune_rounded, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _ReferenceCalorieValue(
                      valueKey: const Key(
                        'dashboard-reference-calorie-consumed-value',
                      ),
                      value: '$consumed',
                      trailing: hasGoal ? '/ $goal' : '/ —',
                      label: consumedLabel,
                      alignment: CrossAxisAlignment.start,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReferenceCalorieValue(
                      valueKey: const Key(
                        'dashboard-reference-calorie-remaining-value',
                      ),
                      value: remaining?.toString() ?? '—',
                      trailing: '',
                      label: remainingLabel,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('dashboard-calorie-equation'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _CalorieEquationValue(
                      label: _referenceText(context, 'Base', 'الأساس'),
                      value: baseGoal,
                    ),
                    _CalorieEquationValue(
                      label: _referenceText(context, 'Consumed', 'المستهلك'),
                      value: consumed,
                    ),
                    _CalorieEquationValue(
                      label: _referenceText(context, 'Burned', 'المحروق'),
                      value: burned,
                      verified: burned > 0,
                    ),
                    _CalorieEquationValue(
                      label: _referenceText(context, 'Net', 'الصافي'),
                      value: net,
                    ),
                  ],
                ),
              ),
              if (burned > 0 && !burnedApplied) ...[
                const SizedBox(height: 6),
                Text(
                  _referenceText(
                    context,
                    'Verified burned calories are shown but do not increase your allowance.',
                    'تظهر السعرات المحروقة الموثقة لكنها لا تزيد ميزانيتك.',
                  ),
                  key: const Key('dashboard-burn-policy-note'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  key: const Key('dashboard-reference-calories-progress'),
                  minHeight: 8,
                  value: progress,
                  color: const Color(0xFF1475E8),
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalorieEquationValue extends StatelessWidget {
  const _CalorieEquationValue({
    required this.label,
    required this.value,
    this.verified = false,
  });

  final String label;
  final int value;
  final bool verified;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          maxLines: 1,
          textDirection: TextDirection.ltr,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (verified) ...[
              const Icon(
                Icons.verified_rounded,
                size: 11,
                color: Color(0xFF0BA878),
              ),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ReferenceCalorieValue extends StatelessWidget {
  const _ReferenceCalorieValue({
    required this.valueKey,
    required this.value,
    required this.trailing,
    required this.label,
    required this.alignment,
  });

  final Key valueKey;
  final String value;
  final String trailing;
  final String label;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignment,
    mainAxisSize: MainAxisSize.min,
    children: [
      Align(
        alignment: alignment == CrossAxisAlignment.end
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Text.rich(
          key: valueKey,
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (trailing.isNotEmpty)
                TextSpan(
                  text: ' $trailing',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _ReferenceMacrosCard extends StatelessWidget {
  const _ReferenceMacrosCard({required this.macros, required this.onEdit});

  final List<_MacroProgress> macros;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.25,
    child: _ReferenceCard(
      child: Column(
        key: const Key('dashboard-reference-macros-card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _referenceText(context, 'Macros', 'المغذيات الكبرى'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.25,
                  ),
                ),
              ),
              IconButton(
                key: const Key('dashboard-reference-macros-edit'),
                tooltip: _referenceText(context, 'Edit goal', 'تعديل الهدف'),
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < macros.length; index++) ...[
                if (index > 0) const SizedBox(width: 14),
                Expanded(child: _ReferenceMacroColumn(macro: macros[index])),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

class _ReferenceMacroColumn extends StatelessWidget {
  const _ReferenceMacroColumn({required this.macro});

  final _MacroProgress macro;

  @override
  Widget build(BuildContext context) {
    final hasGoal = macro.goal != null && macro.goal! > 0;
    final value = macro.value;
    final progress = !hasGoal || value == null
        ? 0.0
        : (value / macro.goal!).clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${macro.label}: ${value ?? 0} ${macro.unit} / ${hasGoal ? macro.goal : '—'} ${macro.unit}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            macro.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text.rich(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              TextSpan(
                children: [
                  TextSpan(
                    text: '${value ?? 0} ${macro.unit}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${hasGoal ? macro.goal : '—'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              color: macro.color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularNutrientCard extends StatelessWidget {
  const _CircularNutrientCard({
    super.key,
    required this.title,
    required this.rings,
    this.onTap,
  });

  final String title;
  final List<Widget> rings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _ReferenceCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final ring in rings) Expanded(child: ring)],
        ),
      ],
    ),
  );
}

class _MacroProgress extends StatelessWidget {
  const _MacroProgress({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    this.unit = 'g',
  });
  final String label;
  final int? value;
  final int? goal;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final validGoal = goal != null && goal! > 0;
    final progress = !validGoal || value == null
        ? 0.0
        : (value! / goal!).clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final remaining = !validGoal || value == null
        ? value
        : (goal! - value!).clamp(0, goal!);
    final semanticValue = value == null
        ? 'unavailable'
        : validGoal
        ? '$value of $goal $unit'
        : '$value $unit';
    return Semantics(
      label: '$label, $semanticValue',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 56,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          remaining?.toString() ?? '—',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF101923),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          value == null ? '' : unit,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: const Color(0xFF101923)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF101923),
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogShortcut extends StatelessWidget {
  const _LogShortcut({
    required this.icon,
    required this.label,
    required this.recorded,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool recorded;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Icon(
            recorded
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            size: 17,
            color: recorded
                ? const Color(0xFF38A169)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}
