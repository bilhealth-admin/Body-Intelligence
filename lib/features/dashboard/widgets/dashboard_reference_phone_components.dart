part of 'premium_dashboard_benchmark.dart';

class _OverviewCardsCarousel extends StatefulWidget {
  const _OverviewCardsCarousel({
    required this.cards,
    this.initialPage = 0,
    this.hasBurnPolicyNote = false,
  });

  final List<Widget> cards;
  final int initialPage;
  final bool hasBurnPolicyNote;

  @override
  State<_OverviewCardsCarousel> createState() => _OverviewCardsCarouselState();
}

class _OverviewCardsCarouselState extends State<_OverviewCardsCarousel> {
  late var _page = widget.cards.isEmpty
      ? 0
      : widget.initialPage.clamp(0, widget.cards.length - 1);
  late final PageController _controller = PageController(
    initialPage: _page,
    // Text-rich cards must never expose a clipped strip of the following
    // card. The dots below already communicate that more pages are available.
    viewportFraction: 1,
  );

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
              height:
                  (224 +
                          (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                                0.0,
                                1.5,
                              ) *
                              120)
                      .clamp(224.0, 330.0)
                      .toDouble() +
                  // Keep the existing burned-calorie explanation readable;
                  // its presence must not squeeze the values or progress bar.
                  (widget.hasBurnPolicyNote ? 24 : 0),
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

class _ReferenceTrendRail extends StatefulWidget {
  const _ReferenceTrendRail({
    required this.weightValues,
    required this.stepValues,
    required this.todaySteps,
    required this.stepSourceName,
    required this.weightUnit,
  });

  final List<double> weightValues;
  final List<double> stepValues;
  final double? todaySteps;
  final String? stepSourceName;
  final String weightUnit;

  @override
  State<_ReferenceTrendRail> createState() => _ReferenceTrendRailState();
}

class _ReferenceTrendRailState extends State<_ReferenceTrendRail> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => _referenceText(context, en, ar);
    return SizedBox(
      key: const Key('dashboard-reference-trend-rail'),
      height:
          130 +
          (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 2.0) * 90,
      child: PageView(
        // Refreshing the data must not reset the selected trend page.
        controller: _controller,
        padEnds: true,
        children: [
          _ReferenceTrendCard(
            key: const Key('dashboard-weight-trend-card'),
            title: tr('Weight', 'الوزن'),
            period: tr('Last 90 days', 'آخر 90 يومًا'),
            values: widget.weightValues,
            unit: widget.weightUnit,
            colors: const [AppColors.protein, AppColors.carbs, AppColors.fats],
            emptyLabel: tr(
              'Add weight to see your trend',
              'أضف وزنك لعرض الاتجاه',
            ),
            onTap: () => context.push('/weight-history'),
          ),
          _ReferenceTrendCard(
            key: const Key('dashboard-step-trend-card'),
            title: tr('Today steps', 'خطوات اليوم'),
            period: [
              tr('Last 30 days', 'آخر 30 يومًا'),
              ?widget.stepSourceName,
            ].join(' · '),
            values: widget.stepValues,
            explicitValue: widget.todaySteps,
            useExplicitValue: true,
            unit: tr('steps', 'خطوة'),
            colors: const [AppColors.protein, AppColors.carbs, AppColors.fats],
            emptyLabel: tr(
              'Connect or log steps to see your trend',
              'اربط مصدرًا أو سجل خطواتك لعرض الاتجاه',
            ),
            onTap: () => context.push('/connected-health'),
          ),
        ],
      ),
    );
  }
}

class _ReferenceTrendCard extends StatelessWidget {
  const _ReferenceTrendCard({
    super.key,
    required this.title,
    required this.period,
    required this.values,
    required this.unit,
    required this.colors,
    required this.emptyLabel,
    required this.onTap,
    this.explicitValue,
    this.useExplicitValue = false,
  });

  final String title;
  final String period;
  final List<double> values;
  final String unit;
  final List<Color> colors;
  final String emptyLabel;
  final VoidCallback onTap;
  final double? explicitValue;
  final bool useExplicitValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.zero,
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
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        period,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
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
                      : Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${(useExplicitValue ? explicitValue : values.last)?.toStringAsFixed(unit == 'kg' || unit == 'lb' ? 1 : 0) ?? '—'} $unit',
                                    textDirection: TextDirection.ltr,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 6,
                              child: SizedBox.expand(
                                child: CustomPaint(
                                  key: Key(
                                    useExplicitValue
                                        ? 'dashboard-step-bars'
                                        : 'dashboard-weight-bars',
                                  ),
                                  painter: _ReferenceTrendPainter(
                                    values: values,
                                    colors: colors,
                                    gridColor: theme.colorScheme.outlineVariant,
                                    zeroBased: useExplicitValue,
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
    );
  }
}

class _ReferenceTrendPainter extends CustomPainter {
  const _ReferenceTrendPainter({
    required this.values,
    required this.colors,
    required this.gridColor,
    this.zeroBased = false,
  });

  final List<double> values;
  final List<Color> colors;
  final Color gridColor;
  final bool zeroBased;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: .72)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final axis = Paint()
      ..color = gridColor
      ..strokeWidth = 1.25;
    final chartBottom = size.height - 2;
    canvas.drawLine(
      Offset(0, chartBottom),
      Offset(size.width, chartBottom),
      axis,
    );
    canvas.drawLine(const Offset(0, 0), Offset(0, chartBottom), axis);

    final populatedValues = values
        .where((value) => value.isFinite && value > 0)
        .toList(growable: false);
    if (populatedValues.isEmpty) return;
    final minValue = populatedValues.reduce((a, b) => a < b ? a : b);
    final maxValue = populatedValues.reduce((a, b) => a > b ? a : b);
    final spread = (maxValue - minValue).abs();
    if (!zeroBased) {
      // A single measurement is one point, never an invented trend. Draw a
      // line only between actual recorded weights; leave missing data gaps.
      final line = Paint()
        ..color = colors.first
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      Offset? previous;
      for (var i = 0; i < values.length; i++) {
        final value = values[i];
        if (!value.isFinite || value <= 0) {
          previous = null;
          continue;
        }
        final point = Offset(
          values.length == 1
              ? size.width / 2
              : 6 + (size.width - 12) * i / (values.length - 1),
          spread == 0
              ? size.height / 2
              : 6 + (size.height - 12) * (1 - (value - minValue) / spread),
        );
        if (previous != null) canvas.drawLine(previous, point, line);
        canvas.drawCircle(
          point,
          values.length == 1 ? 4 : 2.5,
          Paint()..color = colors.first,
        );
        previous = point;
      }
      return;
    }
    final slotWidth = size.width / values.length;
    final barWidth = (slotWidth * .62).clamp(3.0, 14.0);
    final stepFractions = zeroBased ? dashboardStepBarFractions(values) : null;
    for (var index = 0; index < values.length; index++) {
      // An absent day remains visually absent; the card reports the actual
      // latest-day value rather than an invented baseline.
      if (!values[index].isFinite || values[index] <= 0) continue;
      final normalized = spread == 0
          ? .52
          : (values[index] - minValue) / spread;
      final height =
          size.height *
          (zeroBased ? stepFractions![index] * .92 : .16 + normalized * .76);
      final left = index * slotWidth + (slotWidth - barWidth) / 2;
      final rect = Rect.fromLTWH(left, chartBottom - height, barWidth, height);
      final third = ((index * 3) ~/ values.length).clamp(0, 2);
      final color = colors[third];
      final rounded = RRect.fromRectAndRadius(
        rect,
        Radius.circular((barWidth / 2).clamp(2.0, 7.0)),
      );
      canvas.drawRRect(
        rounded,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(color, Colors.white, .42)!,
              color,
              Color.lerp(color, Colors.black, .20)!,
            ],
            stops: const [0, .42, 1],
          ).createShader(rect)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rounded,
        Paint()
          ..color = Colors.white.withValues(alpha: .32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReferenceTrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.zeroBased != zeroBased ||
      oldDelegate.colors != colors ||
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
    final cardHeight = (108 + (textScale - 1).clamp(0, 2) * 108).toDouble();
    return Material(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink.image(
        image: const AssetImage(
          'assets/images/brand/generated/bil_dashboard_body_twin_hero_v1.png',
        ),
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          // Longer summaries and accessibility text can grow beyond the
          // compact artwork height without cropping any existing content.
          constraints: BoxConstraints(minHeight: cardHeight),
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
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 210),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.accessibility_new_rounded,
                              color: Color(0xFF75E5FF),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFFD9ECF7),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
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
