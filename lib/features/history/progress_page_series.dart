part of 'progress_page.dart';

extension _ProgressPageSeries on _ProgressPageState {
  Widget _series(_ProgressCopy copy, List<_Point> points, String unit) {
    if (points.isEmpty) {
      final canAdd = metric != ProgressMetric.steps;
      return _ProgressEmptyState(
        message: copy.noRecords,
        actionLabel: canAdd
            ? metric == ProgressMetric.weight
                  ? copy.addEditWeight
                  : copy.editMeasurements
            : null,
        onAction: canAdd
            ? () => metric == ProgressMetric.weight
                  ? context.push('/weight-history')
                  : _editMeasurement(copy)
            : null,
      );
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    final latest = points.last;
    final stats = ProgressSeriesStats.fromChronologicalValues(
      points.map((point) => point.value).toList(growable: false),
    )!;
    final decimals = metric == ProgressMetric.steps ? 0 : 1;
    final currentValue = stats.current.toStringAsFixed(decimals);
    final changeValue = metric == ProgressMetric.steps
        ? stats.total.toStringAsFixed(0)
        : '${stats.change >= 0 ? '+' : ''}${stats.change.toStringAsFixed(1)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressChartCard(
          title: copy.metricLabel(metric),
          latestLabel: copy.latest,
          latestValue: currentValue,
          unit: unit,
          dateLabel: MaterialLocalizations.of(
            context,
          ).formatMediumDate(latest.date),
          semanticsLabel: copy.chartSummary(
            copy.metricLabel(metric),
            copy.rangeLabel(range),
            points.length,
            points.map((point) => point.value).reduce(math.min),
            points.map((point) => point.value).reduce(math.max),
            latest.value,
            unit,
          ),
          points: points,
          summaries: [
            _ProgressSummaryData(
              metric == ProgressMetric.steps ? copy.average : copy.start,
              (metric == ProgressMetric.steps ? stats.average : stats.start)
                  .toStringAsFixed(decimals),
            ),
            _ProgressSummaryData(
              metric == ProgressMetric.steps ? copy.best : copy.current,
              (metric == ProgressMetric.steps ? stats.best : stats.current)
                  .toStringAsFixed(decimals),
            ),
            _ProgressSummaryData(
              metric == ProgressMetric.steps ? copy.total : copy.change,
              changeValue,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.entries,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      copy.recordCount(points.length),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              for (var index = points.length - 1; index >= 0; index--) ...[
                if (index != points.length - 1) const Divider(height: 1),
                ListTile(
                  minTileHeight: 58,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  leading: BilSemanticIconBadge(
                    kind: _metricKind(metric),
                    iconOverride: _metricIcon(metric),
                    appleIconOverride: _metricAppleIcon(metric),
                    size: 34,
                    iconSize: 18,
                  ),
                  title: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(points[index].date),
                  ),
                  trailing: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${points[index].value.toStringAsFixed(decimals)} $unit',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  onTap: metric == ProgressMetric.steps
                      ? null
                      : metric == ProgressMetric.weight
                      ? () => context.push('/weight-history')
                      : () => _editMeasurement(copy, date: points[index].date),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
