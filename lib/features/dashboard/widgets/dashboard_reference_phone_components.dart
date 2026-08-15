part of 'premium_dashboard_benchmark.dart';

class _OverviewCardsCarousel extends StatefulWidget {
  const _OverviewCardsCarousel({required this.cards, this.initialPage = 0});

  final List<Widget> cards;
  final int initialPage;

  @override
  State<_OverviewCardsCarousel> createState() => _OverviewCardsCarouselState();
}

class _OverviewCardsCarouselState extends State<_OverviewCardsCarousel> {
  late var _page = widget.cards.isEmpty
      ? 0
      : widget.initialPage.clamp(0, widget.cards.length - 1);
  late final PageController _controller = PageController(initialPage: _page);

  @override
  void didUpdateWidget(covariant _OverviewCardsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage &&
        widget.cards.isNotEmpty) {
      _page = widget.initialPage.clamp(0, widget.cards.length - 1);
      if (_controller.hasClients) {
        _controller.animateToPage(
          _page,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.cards.isEmpty
      ? const SizedBox.shrink()
      : Column(
          children: [
            SizedBox(
              height: 250,
              child: PageView.builder(
                key: const Key('dashboard-calories-macros-horizontal'),
                physics: const PageScrollPhysics(),
                padEnds: false,
                controller: _controller,
                itemCount: widget.cards.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => widget.cards[index],
              ),
            ),
            if (widget.cards.length > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.cards.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _page ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
}

class _NutrientPlanRow {
  const _NutrientPlanRow({
    required this.label,
    required this.value,
    required this.goal,
    this.unit = 'g',
    this.minimumGoal = false,
  });

  final String label;
  final int? value;
  final int? goal;
  final String unit;
  final bool minimumGoal;
}

class _NutrientPlanCard extends StatelessWidget {
  const _NutrientPlanCard({
    required this.title,
    required this.accent,
    required this.rows,
    required this.onTap,
  });

  final String title;
  final Color accent;
  final List<_NutrientPlanRow> rows;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
    shadowColor: const Color(0x22000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF101923),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: accent),
              ],
            ),
            const Spacer(),
            for (final row in rows) ...[
              _NutrientPlanProgress(row: row, accent: accent),
              if (row != rows.last) const SizedBox(height: 12),
            ],
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}

class _NutrientPlanProgress extends StatelessWidget {
  const _NutrientPlanProgress({required this.row, required this.accent});

  final _NutrientPlanRow row;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final progress = row.goal == null || row.goal! <= 0 || row.value == null
        ? 0.0
        : (row.value! / row.goal!).clamp(0.0, 1.0);
    final state = NutrientProgressPolicy.evaluate(
      value: row.value?.toDouble(),
      goal: row.goal?.toDouble() ?? 0,
      minimumGoal: row.minimumGoal,
    );
    final progressColor = switch (state) {
      NutrientProgressState.unknown => Theme.of(context).colorScheme.outline,
      NutrientProgressState.below => const Color(0xFFEF9A23),
      NutrientProgressState.near => const Color(0xFFF2C94C),
      NutrientProgressState.reached => const Color(0xFF269E68),
      NutrientProgressState.exceeded => const Color(0xFFD64B4B),
    };
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: const TextStyle(
                  color: Color(0xFF101923),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              row.value == null
                  ? '—'
                  : row.goal == null
                  ? '${row.value} ${row.unit}'
                  : '${row.value} / ${row.goal} ${row.unit}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Color(0xFF101923),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            color: progressColor,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _ReferenceTrendRail extends StatelessWidget {
  const _ReferenceTrendRail({
    required this.weightValues,
    required this.stepValues,
    required this.weightUnit,
  });

  final List<double> weightValues;
  final List<double> stepValues;
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => _referenceText(context, en, ar);
    return SizedBox(
      key: const Key('dashboard-reference-trend-rail'),
      height: 224,
      child: PageView(
        controller: PageController(viewportFraction: .94),
        padEnds: false,
        children: [
          _ReferenceTrendCard(
            title: tr('Weight', 'الوزن'),
            period: tr('Last 90 days', 'آخر 90 يومًا'),
            values: weightValues,
            unit: weightUnit,
            accent: const Color(0xFF2F8F68),
            emptyLabel: tr(
              'Add weight to see your trend',
              'أضف وزنك لعرض الاتجاه',
            ),
            onTap: () => context.push('/weight-history'),
          ),
          _ReferenceTrendCard(
            title: tr('Steps', 'الخطوات'),
            period: tr('Last 30 days', 'آخر 30 يومًا'),
            values: stepValues,
            unit: tr('steps', 'خطوة'),
            accent: const Color(0xFFE83E6B),
            emptyLabel: tr(
              'Connect or log steps to see your trend',
              'اربط مصدرًا أو سجل خطواتك لعرض الاتجاه',
            ),
            onTap: () => context.push('/history'),
          ),
        ],
      ),
    );
  }
}

class _ReferenceTrendCard extends StatelessWidget {
  const _ReferenceTrendCard({
    required this.title,
    required this.period,
    required this.values,
    required this.unit,
    required this.accent,
    required this.emptyLabel,
    required this.onTap,
  });

  final String title;
  final String period;
  final List<double> values;
  final String unit;
  final Color accent;
  final String emptyLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: theme.brightness == Brightness.light ? 1 : 0,
        shadowColor: const Color(0x22000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            period,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: values.isEmpty
                      ? Center(
                          child: Text(
                            emptyLabel,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : CustomPaint(
                          painter: _ReferenceTrendPainter(
                            values: values,
                            color: accent,
                            gridColor: theme.colorScheme.outlineVariant,
                          ),
                        ),
                ),
                if (values.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${values.last.toStringAsFixed(unit == 'kg' || unit == 'lb' ? 1 : 0)} $unit',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceTrendPainter extends CustomPainter {
  const _ReferenceTrendPainter({
    required this.values,
    required this.color,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final spread = (maxValue - minValue).abs();
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final normalized = spread == 0 ? .5 : (values[index] - minValue) / spread;
      final y =
          size.height - (normalized * size.height * .8 + size.height * .1);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    if (values.length == 1) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReferenceTrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}

/// Image-led body-twin summary used by the compact reference dashboard.
class _BodyTwinImageCard extends StatelessWidget {
  const _BodyTwinImageCard({
    super.key,
    required this.title,
    required this.summary,
    required this.onTap,
  });

  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardHeight = (188 + (textScale - 1).clamp(0, 2) * 96).toDouble();
    return Material(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink.image(
        image: const AssetImage(
          'assets/images/brand/generated/bil_dashboard_body_twin_hero_v1.png',
        ),
        height: cardHeight,
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xE8031026), Color(0x52031026)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 210),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.accessibility_new_rounded,
                        color: Color(0xFF75E5FF),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFD9ECF7),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Daily calorie progress strip displayed below the calorie equation.
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
  const _ReferenceCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
    shadowColor: const Color(0x22000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _ReferenceEquationRow extends StatelessWidget {
  const _ReferenceEquationRow({
    required this.label,
    required this.value,
    required this.icon,
    this.honestEmpty = false,
  });
  final String label;
  final int value;
  final IconData icon;
  final bool honestEmpty;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          honestEmpty ? '—' : '$value',
          style: const TextStyle(fontWeight: FontWeight.w700),
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
  });
  final String label;
  final int value;
  final int goal;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final remaining = (goal - value).clamp(0, goal);
    return Semantics(
      label: '$label, $value of $goal grams',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 70,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$remaining',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF101923),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'g',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF101923),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF101923),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceStatusCard extends StatelessWidget {
  const _ReferenceStatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: _ReferenceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
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
