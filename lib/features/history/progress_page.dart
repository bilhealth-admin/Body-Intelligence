import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/localization/runtime_copy.dart';
import '../../data/database/app_database.dart';
import '../../core/units/measurement_units.dart';
import '../ads/presentation/safe_free_ad_anchor.dart';
import '../daily_log/providers/daily_log_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

part 'progress_page_components.dart';
part 'progress_page_copy.dart';

enum ProgressMetric { steps, weight, neck, waist, hips, chest, arm, thigh }

enum ProgressRange { week, month, twoMonths, threeMonths, sixMonths, year, all }

DateTime? progressRangeCutoff(ProgressRange range, DateTime now) {
  final days = switch (range) {
    ProgressRange.week => 7,
    ProgressRange.month => 30,
    ProgressRange.twoMonths => 60,
    ProgressRange.threeMonths => 90,
    ProgressRange.sixMonths => 180,
    ProgressRange.year => 365,
    ProgressRange.all => null,
  };
  if (days == null) return null;
  final dayStart = now.isUtc
      ? DateTime.utc(now.year, now.month, now.day)
      : DateTime(now.year, now.month, now.day);
  return dayStart.subtract(Duration(days: days - 1));
}

bool progressDateInRange(DateTime date, ProgressRange range, DateTime now) {
  final cutoff = progressRangeCutoff(range, now);
  return (cutoff == null || !date.isBefore(cutoff)) && !date.isAfter(now);
}

bool progressValidMeasurementCm(double? value) =>
    value != null && value.isFinite && value > 0;

final class ProgressSeriesStats {
  const ProgressSeriesStats({
    required this.average,
    required this.best,
    required this.total,
    required this.start,
    required this.current,
    required this.change,
  });
  final double average;
  final double best;
  final double total;
  final double start;
  final double current;
  final double change;

  /// [values] must be ordered oldest to newest.
  static ProgressSeriesStats? fromChronologicalValues(List<double> values) {
    if (values.isEmpty) return null;
    if (values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError.value(values, 'values');
    }
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return ProgressSeriesStats(
      average: total / values.length,
      best: values.reduce(math.max),
      total: total,
      start: values.first,
      current: values.last,
      change: values.last - values.first,
    );
  }
}

final progressDailyLogsProvider = StreamProvider<List<DailyLog>>(
  (ref) => ref.watch(dailyLogRepositoryProvider).watchAll(),
);

final progressClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  ProgressMetric metric = ProgressMetric.steps;
  ProgressRange range = ProgressRange.month;

  @override
  Widget build(BuildContext context) {
    final copy = _ProgressCopy.of(context);
    final logs = ref.watch(progressDailyLogsProvider);
    final weights = ref.watch(weightHistoryProvider);
    final measurements = ref.watch(bodyMeasurementHistoryProvider);
    final systemState = ref.watch(measurementSystemProvider);
    final shareData = _shareData(logs, weights, measurements, systemState);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        centerTitle: true,
        title: Text(copy.progress),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: IconButton.filledTonal(
              key: const Key('progress-share'),
              tooltip: copy.shareProgress,
              onPressed: shareData == null
                  ? null
                  : () => _shareProgress(copy, shareData),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ),
          if (metric == ProgressMetric.weight)
            IconButton(
              key: const Key('progress-manage-weight'),
              tooltip: copy.addEditWeight,
              onPressed: () => context.push('/weight-history'),
              icon: const Icon(Icons.edit_note_rounded),
            ),
          if (const {
            ProgressMetric.neck,
            ProgressMetric.waist,
            ProgressMetric.hips,
            ProgressMetric.chest,
            ProgressMetric.arm,
            ProgressMetric.thigh,
          }.contains(metric))
            IconButton(
              key: const Key('progress-edit-measurements'),
              tooltip: copy.editMeasurements,
              onPressed: () => context.push('/profile-settings'),
              icon: const Icon(Icons.straighten_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _ProgressSelector(
                  key: const Key('progress-metric-selector'),
                  icon: _metricIcon(metric),
                  eyebrow: copy.metric,
                  value: copy.metricLabel(metric),
                  onTap: _pickMetric,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProgressSelector(
                  key: const Key('progress-range-selector'),
                  icon: Icons.calendar_today_rounded,
                  eyebrow: copy.range,
                  value: copy.rangeLabel(range),
                  onTap: _pickRange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (metric == ProgressMetric.steps)
            logs.when(
              loading: _loading,
              error: (_, _) =>
                  _error(copy, () => ref.invalidate(progressDailyLogsProvider)),
              data: (rows) => _series(
                copy,
                _filter(
                  rows
                      .where((row) => row.steps != null && row.steps! >= 0)
                      .map((row) => _Point(row.date, row.steps!.toDouble()))
                      .toList(growable: false),
                ),
                copy.stepsUnit,
              ),
            )
          else if (systemState.isLoading)
            _loading()
          else if (systemState.hasError)
            _error(copy, () => ref.invalidate(measurementSystemProvider))
          else
            switch (metric) {
              ProgressMetric.steps => const SizedBox.shrink(),
              ProgressMetric.weight => weights.when(
                loading: _loading,
                error: (_, _) =>
                    _error(copy, () => ref.invalidate(weightHistoryProvider)),
                data: (rows) {
                  final points = _filter(
                    rows
                        .where((row) => row.weight.isFinite && row.weight >= 0)
                        .map(
                          (row) => _Point(
                            row.date,
                            UnitConverter.weightFromKg(
                              row.weight,
                              systemState.requireValue,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                  return _series(
                    copy,
                    points,
                    UnitConverter.weightUnit(systemState.requireValue),
                  );
                },
              ),
              ProgressMetric.neck ||
              ProgressMetric.waist ||
              ProgressMetric.hips ||
              ProgressMetric.chest ||
              ProgressMetric.arm ||
              ProgressMetric.thigh => measurements.when(
                loading: _loading,
                error: (_, _) => _error(
                  copy,
                  () => ref.invalidate(bodyMeasurementHistoryProvider),
                ),
                data: (rows) {
                  final points = _filter(
                    rows
                        .map(
                          (row) => _measurementPoint(
                            row,
                            metric,
                            systemState.requireValue,
                          ),
                        )
                        .whereType<_Point>()
                        .toList(growable: false),
                  );
                  return _series(
                    copy,
                    points,
                    systemState.requireValue == MeasurementSystem.imperial
                        ? 'in'
                        : 'cm',
                  );
                },
              ),
            },
          const SafeFreeAdAnchor(
            key: Key('progress-free-ad-slot'),
            surface: SafeFreeAdSurface.progress,
          ),
        ],
      ),
    );
  }

  ({List<_Point> points, String unit})? _shareData(
    AsyncValue<List<DailyLog>> logs,
    AsyncValue<List<WeightEntry>> weights,
    AsyncValue<List<BodyMeasurementEntry>> measurements,
    AsyncValue<MeasurementSystem> systemState,
  ) {
    List<_Point>? points;
    String? unit;
    if (metric == ProgressMetric.steps && logs.hasValue) {
      points = _filter(
        logs.requireValue
            .where((row) => row.steps != null && row.steps! >= 0)
            .map((row) => _Point(row.date, row.steps!.toDouble()))
            .toList(growable: false),
      );
      unit = _ProgressCopy.of(context).stepsUnit;
    } else if (metric == ProgressMetric.weight &&
        weights.hasValue &&
        systemState.hasValue) {
      points = _filter(
        weights.requireValue
            .where((row) => row.weight.isFinite && row.weight >= 0)
            .map(
              (row) => _Point(
                row.date,
                UnitConverter.weightFromKg(
                  row.weight,
                  systemState.requireValue,
                ),
              ),
            )
            .toList(growable: false),
      );
      unit = UnitConverter.weightUnit(systemState.requireValue);
    } else if (metric != ProgressMetric.steps &&
        metric != ProgressMetric.weight &&
        measurements.hasValue &&
        systemState.hasValue) {
      points = _filter(
        measurements.requireValue
            .map(
              (row) => _measurementPoint(row, metric, systemState.requireValue),
            )
            .whereType<_Point>()
            .toList(growable: false),
      );
      unit = systemState.requireValue == MeasurementSystem.imperial
          ? 'in'
          : 'cm';
    }
    if (points == null || points.isEmpty || unit == null) return null;
    points.sort((a, b) => a.date.compareTo(b.date));
    return (points: points, unit: unit);
  }

  Future<void> _shareProgress(
    _ProgressCopy copy,
    ({List<_Point> points, String unit}) data,
  ) async {
    final stats = ProgressSeriesStats.fromChronologicalValues(
      data.points.map((point) => point.value).toList(growable: false),
    )!;
    final text = copy.shareText(
      copy.metricLabel(metric),
      copy.rangeLabel(range),
      data.points.length,
      stats.start,
      stats.current,
      stats.change,
      data.unit,
      wholeNumbers: metric == ProgressMetric.steps,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: copy.shareProgress),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.shareUnavailable)));
    }
  }

  Future<void> _pickMetric() async {
    final copy = _ProgressCopy.of(context);
    final selected = await showModalBottomSheet<ProgressMetric>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(copy.selectMetric)),
            for (final value in ProgressMetric.values)
              ListTile(
                leading: Icon(_metricIcon(value)),
                title: Text(copy.metricLabel(value)),
                trailing: value == metric
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, value),
              ),
          ],
        ),
      ),
    );
    if (mounted && selected != null) setState(() => metric = selected);
  }

  Future<void> _pickRange() async {
    final copy = _ProgressCopy.of(context);
    final selected = await showModalBottomSheet<ProgressRange>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(copy.selectRange)),
            for (final value in ProgressRange.values)
              ListTile(
                title: Text(copy.rangeLabel(value)),
                trailing: value == range
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, value),
              ),
          ],
        ),
      ),
    );
    if (mounted && selected != null) setState(() => range = selected);
  }

  _Point? _measurementPoint(
    BodyMeasurementEntry row,
    ProgressMetric metric,
    MeasurementSystem system,
  ) {
    final centimeters = switch (metric) {
      ProgressMetric.neck => row.neckCm,
      ProgressMetric.waist => row.waistCm,
      ProgressMetric.hips => row.hipsCm,
      ProgressMetric.chest => row.chestCm,
      ProgressMetric.arm => row.armCm,
      ProgressMetric.thigh => row.thighCm,
      _ => null,
    };
    if (!progressValidMeasurementCm(centimeters)) {
      return null;
    }
    return _Point(row.date, UnitConverter.heightFromCm(centimeters!, system));
  }

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
            ? () => context.push(
                metric == ProgressMetric.weight
                    ? '/weight-history'
                    : '/profile-settings',
              )
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
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: .58),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _metricIcon(metric),
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<_Point> _filter(List<_Point> points) {
    final now = ref.read(progressClockProvider)();
    return points
        .where((point) => progressDateInRange(point.date, range, now))
        .toList();
  }

  Widget _loading() => const _ProgressLoadingState();
  Widget _error(_ProgressCopy copy, VoidCallback onRetry) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            copy.unavailable,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(copy.retry),
          ),
        ],
      ),
    ),
  );
}

IconData _metricIcon(ProgressMetric metric) => switch (metric) {
  ProgressMetric.steps => Icons.directions_walk_rounded,
  ProgressMetric.weight => Icons.monitor_weight_outlined,
  ProgressMetric.neck => Icons.accessibility_new_rounded,
  ProgressMetric.waist => Icons.straighten_rounded,
  ProgressMetric.hips => Icons.accessibility_rounded,
  ProgressMetric.chest => Icons.favorite_border_rounded,
  ProgressMetric.arm => Icons.fitness_center_rounded,
  ProgressMetric.thigh => Icons.directions_run_rounded,
};
