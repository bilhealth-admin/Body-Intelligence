part of 'weekly_report_page.dart';

class _WeeklyPulseHero extends StatelessWidget {
  const _WeeklyPulseHero({
    required this.report,
    required this.weekRange,
    required this.onChooseWeek,
  });

  final WeeklyReportSnapshot report;
  final String weekRange;
  final VoidCallback onChooseWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackedCopy = _t(
      context,
      'tracked_days',
    ).replaceAll('{days}', '${report.trackedDays}');
    return Semantics(
      key: const Key('weekly-pulse-hero'),
      container: true,
      label: '$weekRange. $trackedCopy',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [Color(0xFF071F2D), Color(0xFF0B4C53)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26071F2D),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x3DFFFFFF)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_graph_rounded,
                        size: 17,
                        color: Color(0xFF75E4D5),
                      ),
                      SizedBox(width: 7),
                      Text(
                        'BIL',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _t(context, 'glance'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    weekRange,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('weekly-report-calendar'),
                  tooltip: _weeklySurfaceText(context, 'Choose report week'),
                  onPressed: onChooseWeek,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x26FFFFFF),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              key: const Key('weekly-pulse-days'),
              children: [
                for (final day in report.days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 5),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            height: day.hasAnyRecord ? 10 : 5,
                            decoration: BoxDecoration(
                              color: day.hasAnyRecord
                                  ? const Color(0xFF75E4D5)
                                  : const Color(0x4DFFFFFF),
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: day.hasAnyRecord
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x6675E4D5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _weeklyDayLabel(context, day.dayKey),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${report.trackedDays} / 7',
                key: const Key('weekly-pulse-tracked-copy'),
                style: const TextStyle(
                  color: Color(0xFFE4FFFB),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyEvidenceDeck extends StatelessWidget {
  const _WeeklyEvidenceDeck({required this.report});
  final WeeklyReportSnapshot report;

  @override
  Widget build(BuildContext context) {
    String value(double? number, String unit, {int decimals = 1}) =>
        number == null ? '—' : '${number.toStringAsFixed(decimals)} $unit';
    final activityLabel = _weeklySurfaceText(context, 'Active energy');
    final activityValue = report.totalVerifiedActiveEnergyKcal != null
        ? value(report.totalVerifiedActiveEnergyKcal, 'kcal', decimals: 0)
        : report.totalEstimatedBurnedCaloriesKcal == null
        ? '—'
        : '≈ ${report.totalEstimatedBurnedCaloriesKcal!.toStringAsFixed(0)} kcal';
    final entries = <(String, String, IconData, Color)>[
      (
        context.strings.text('Water'),
        report.totalWaterMl <= 0
            ? '—'
            : '${(report.totalWaterMl / 1000).toStringAsFixed(1)} L',
        Icons.water_drop_rounded,
        const Color(0xFF287FC0),
      ),
      (
        context.strings.text('Weight'),
        value(report.latestWeightKg, 'kg'),
        Icons.monitor_weight_rounded,
        const Color(0xFF7A68B5),
      ),
      (
        _weeklySurfaceText(context, 'Sleep'),
        value(report.averageSleepHours, 'h'),
        Icons.bedtime_rounded,
        const Color(0xFF5367B8),
      ),
      (
        _weeklySurfaceText(context, 'Fasting'),
        '${report.fastingSessions}',
        Icons.timelapse_rounded,
        const Color(0xFFB67825),
      ),
      (
        _weeklySurfaceText(context, 'Body context'),
        '${report.bodyContextDays} ${_t(context, 'days')}',
        Icons.psychology_alt_rounded,
        const Color(0xFF8C5678),
      ),
      (
        activityLabel,
        activityValue,
        report.totalVerifiedActiveEnergyKcal == null
            ? Icons.local_fire_department_outlined
            : Icons.verified_rounded,
        const Color(0xFFD55D2E),
      ),
    ];
    return LayoutBuilder(
      key: const Key('weekly-evidence-deck'),
      builder: (context, constraints) {
        final singleColumn =
            constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        final tileWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < entries.length; index++)
              SizedBox(
                width: tileWidth,
                child: _WeeklyEvidenceTile(
                  key: Key('weekly-evidence-$index'),
                  label: entries[index].$1,
                  value: entries[index].$2,
                  icon: entries[index].$3,
                  color: entries[index].$4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WeeklyEvidenceTile extends StatelessWidget {
  const _WeeklyEvidenceTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [...children],
          ),
        ),
      ],
    ),
  );
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(flex: 3, child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ResponsiveAction extends StatelessWidget {
  const _ResponsiveAction({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.filled = false,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton.tonal(onPressed: onPressed, child: content)
          : TextButton(onPressed: onPressed, child: content),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.days});
  final List<WeeklyReportDay> days;
  @override
  Widget build(BuildContext context) {
    final maxLogged = days.fold<double>(
      0,
      (maximum, day) => day.calories > maximum ? day.calories : maximum,
    );
    final maxGoal = days.fold<double>(
      0,
      (maximum, day) =>
          (day.calorieGoal ?? 0) > maximum ? day.calorieGoal! : maximum,
    );
    final rawMaximum = maxLogged > maxGoal ? maxLogged : maxGoal;
    final chartMaximum = rawMaximum <= 0
        ? 1000.0
        : ((rawMaximum / 500).ceil() * 500).toDouble();
    final axisValues = <double>[
      chartMaximum,
      chartMaximum * 2 / 3,
      chartMaximum / 3,
      0,
    ];
    return Semantics(
      label: maxLogged == 0
          ? _weeklySurfaceText(context, 'No foods logged')
          : _weeklySurfaceText(context, 'Weekly calories chart'),
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            Column(
              children: [
                for (final axis in axisValues)
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            axis.round().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 40,
              right: 0,
              top: 10,
              bottom: 22,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final day in days)
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: (day.calories / chartMaximum).clamp(
                                0.0,
                                1.0,
                              ),
                              child: Container(
                                width: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF006D77),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const Key('weekly-calorie-goal-line'),
                        painter: _WeeklyGoalLinePainter(
                          goals: [for (final day in days) day.calorieGoal],
                          maximum: chartMaximum,
                          color: const Color(0xFF8AA5AB),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 40,
              right: 0,
              bottom: 0,
              child: Row(
                children: [
                  for (var index = 0; index < days.length; index++)
                    Expanded(
                      child: Text(
                        _weeklyDayLabel(context, days[index].dayKey),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            if (maxLogged == 0)
              Center(
                child: Text(
                  _weeklySurfaceText(context, 'No foods logged'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyGoalLinePainter extends CustomPainter {
  const _WeeklyGoalLinePainter({
    required this.goals,
    required this.maximum,
    required this.color,
  });

  final List<double?> goals;
  final double maximum;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (maximum <= 0 || goals.isEmpty || goals.every((goal) => goal == null)) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final path = Path();
    var drawing = false;
    for (var index = 0; index < goals.length; index++) {
      final goal = goals[index];
      if (goal == null) {
        drawing = false;
        continue;
      }
      final x = size.width * (index + .5) / goals.length;
      final y = size.height * (1 - (goal / maximum).clamp(0.0, 1.0));
      if (drawing) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        drawing = true;
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WeeklyGoalLinePainter oldDelegate) =>
      maximum != oldDelegate.maximum ||
      color != oldDelegate.color ||
      !_sameGoals(oldDelegate.goals, goals);

  static bool _sameGoals(List<double?> a, List<double?> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});
  final List<(String, Color)> items;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 6,
    children: [
      for (final item in items)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.$2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  item.$1,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _MacroDistribution extends StatefulWidget {
  const _MacroDistribution({required this.report});
  final WeeklyReportSnapshot report;
  @override
  State<_MacroDistribution> createState() => _MacroDistributionState();
}

class _MacroDistributionState extends State<_MacroDistribution> {
  bool showTooltip = false;
  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final total = report.totalProteinG + report.totalCarbsG + report.totalFatG;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: _t(context, 'macros'),
          child: GestureDetector(
            key: const Key('weekly-macro-chart'),
            onTap: () => setState(() => showTooltip = !showTooltip),
            child: Semantics(
              label: _t(context, 'macros'),
              child: SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        for (final axis in const [
                          '100%',
                          '75%',
                          '50%',
                          '25%',
                          '0%',
                        ])
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    axis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      left: 42,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        children: [
                          for (final key in const ['protein', 'carbs', 'fat'])
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_t(context, key)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (total <= 0)
                      Center(
                        child: Text(
                          _t(context, 'no_macro_data'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      )
                    else
                      Positioned(
                        left: 48,
                        right: 8,
                        top: 10,
                        bottom: 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final value in [
                              report.totalProteinG,
                              report.totalCarbsG,
                              report.totalFatG,
                            ])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.bottomCenter,
                                    heightFactor: value / total,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF006D77),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showTooltip)
          Card(
            key: const Key('weekly-macro-tooltip'),
            color: const Color(0xFF263238),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.35,
                  fontFamily: 'RobotoEvidence',
                  decoration: TextDecoration.none,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(context, 'macros'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${_t(context, 'protein')}: ${report.totalProteinG.toStringAsFixed(1)} g',
                    ),
                    Text(
                      '${report.totalCarbsG.toStringAsFixed(1)} ${_t(context, 'grams_carbs')}',
                    ),
                    Text(
                      '${report.totalFatG.toStringAsFixed(1)} ${_t(context, 'grams_fat')}',
                    ),
                    Text(_t(context, 'no_macro_data')),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        _ChartLegend(
          items: [(_t(context, 'legend_logged'), const Color(0xFF006D77))],
        ),
      ],
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});
  final List<WeeklyReportDay> days;
  @override
  Widget build(BuildContext context) {
    final maximum = days
        .where((day) => day.steps != null)
        .fold<int>(0, (value, day) => day.steps! > value ? day.steps! : value);
    return Semantics(
      label: _weeklySurfaceText(context, 'Seven day exercise and steps chart'),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            Column(
              children: [
                for (final axis in const ['10k', '7.5k', '5k', '2.5k', '0'])
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            axis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
              ],
            ),
            if (maximum == 0)
              Center(
                child: Text(
                  _weeklySurfaceText(context, 'No steps logged'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              )
            else
              Positioned(
                left: 42,
                right: 0,
                top: 8,
                bottom: 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FractionallySizedBox(
                            heightFactor: (day.steps ?? 0) / maximum,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF90CAF9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Positioned(
              left: 42,
              right: 0,
              bottom: 0,
              child: Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: Text(
                        _weeklyDayLabel(context, day.dayKey),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _weeklyDayLabel(BuildContext context, String dayKey) {
  final date = DateTime.tryParse(dayKey);
  if (date == null) return '·';
  return MaterialLocalizations.of(context).narrowWeekdays[date.weekday % 7];
}

class _Message extends StatelessWidget {
  const _Message(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(value, textAlign: TextAlign.center),
    ),
  );
}
