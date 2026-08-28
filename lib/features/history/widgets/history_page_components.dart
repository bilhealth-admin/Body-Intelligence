part of '../history_page.dart';

class WeightTrendChart extends StatefulWidget {
  const WeightTrendChart({
    super.key,
    required this.weights,
    required this.variability,
    required this.semanticsLabel,
  });

  final List<double> weights;
  final double? variability;
  final String semanticsLabel;

  @override
  State<WeightTrendChart> createState() => _WeightTrendChartState();
}

class _WeightTrendChartState extends State<WeightTrendChart> {
  bool showRaw = false;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label:
              '${widget.semanticsLabel}. ${_historyText(locale, 'smoothBand')}',
          image: true,
          child: SizedBox(
            key: const Key('weight-trend-canvas'),
            width: double.infinity,
            height: 150,
            child: CustomPaint(
              painter: _WeightTrendPainter(
                weights: widget.weights,
                variability: widget.variability,
                showRaw: showRaw,
                color: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).dividerColor,
              ),
            ),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(_historyText(locale, 'showRaw')),
          subtitle: Text(_historyText(locale, 'bandHelp')),
          value: showRaw,
          onChanged: (value) => setState(() => showRaw = value),
        ),
      ],
    );
  }
}

class _HistorySkeletonBlock extends StatelessWidget {
  const _HistorySkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: SizedBox(
        height: height,
        child: const DecoratedBox(
          decoration: BoxDecoration(color: Color(0x14000000)),
        ),
      ),
    );
  }
}

class _HistoryContextBanner extends StatelessWidget {
  const _HistoryContextBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: PremiumDesignTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PremiumDesignTokens.cardHeading(context)),
                const SizedBox(height: PremiumDesignTokens.spaceXs),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryExplainabilityChips extends StatelessWidget {
  const _HistoryExplainabilityChips({
    required this.confidenceLabel,
    required this.sampleCount,
    required this.spanDays,
    required this.system,
    required this.weeklyDirectionKg,
  });

  final String confidenceLabel;
  final int sampleCount;
  final int spanDays;
  final MeasurementSystem system;
  final double? weeklyDirectionKg;

  @override
  Widget build(BuildContext context) {
    final unit = UnitConverter.weightUnit(system);
    final directionLabel = weeklyDirectionKg == null
        ? context.strings.text('At least four entries needed')
        : '${weeklyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(weeklyDirectionKg!, system).toStringAsFixed(2)} $unit/${context.strings.text('week')}';
    return Wrap(
      spacing: PremiumDesignTokens.spaceXs,
      runSpacing: PremiumDesignTokens.spaceXs,
      children: [
        Chip(
          label: Text(
            '${context.strings.text('Confidence')}: $confidenceLabel',
          ),
        ),
        Chip(
          label: Text(
            '${context.strings.text('Evidence')}: $sampleCount ${context.strings.text('entries')} · $spanDays ${context.strings.text('days')}',
          ),
        ),
        Chip(
          label: Text('${context.strings.text('Direction')}: $directionLabel'),
        ),
      ],
    );
  }
}

class _HistoryGoalProjectionCard extends StatelessWidget {
  const _HistoryGoalProjectionCard({
    required this.analysis,
    required this.system,
    required this.locale,
  });

  final ProgressAnalysis analysis;
  final MeasurementSystem system;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final title = _historyText(locale, 'goalTitle');
    final noEstimateMessage = _historyText(locale, 'noGoal');
    final direction = analysis.weeklyDirectionKg;
    final unit = UnitConverter.weightUnit(system);

    final reasons = <String>[
      if (analysis.projectedGoalDate == null && analysis.sampleCount < 4)
        _historyText(locale, 'needFour'),
      if (analysis.projectedGoalDate == null &&
          analysis.confidence == ProgressConfidence.insufficient)
        _historyText(locale, 'withheld'),
      if (analysis.projectedGoalDate == null &&
          direction != null &&
          direction.abs() < 0.01)
        _historyText(locale, 'nearFlat'),
    ];

    String directionLine() {
      if (direction == null) {
        return _historyText(locale, 'weeklyUnavailable');
      }
      final formatted =
          '${direction >= 0 ? '+' : ''}${UnitConverter.weightFromKg(direction, system).toStringAsFixed(2)} $unit/${context.strings.text('week')}';
      return '${_historyText(locale, 'currentDirection')}: $formatted';
    }

    final projectionLine = analysis.projectedGoalDate == null
        ? noEstimateMessage
        : '${analysis.projectedGoalDate!.year}-${analysis.projectedGoalDate!.month.toString().padLeft(2, '0')}-${analysis.projectedGoalDate!.day.toString().padLeft(2, '0')}';

    return PremiumSurface(
      child: Padding(
        padding: PremiumDesignTokens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: PremiumDesignTokens.cardHeading(context)),
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            Text(
              analysis.projectedGoalDate == null
                  ? noEstimateMessage
                  : '$title: $projectionLine',
            ),
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            Text(directionLine()),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: PremiumDesignTokens.spaceXs),
              for (final reason in reasons) Text('• $reason'),
            ],
          ],
        ),
      ),
    );
  }
}
