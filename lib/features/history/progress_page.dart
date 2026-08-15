import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/localization/runtime_copy.dart';
import '../../data/database/app_database.dart';
import '../../core/units/measurement_units.dart';
import '../daily_log/providers/daily_log_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

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
      appBar: AppBar(
        title: Text(copy.progress),
        actions: [
          IconButton(
            key: const Key('progress-share'),
            tooltip: copy.shareProgress,
            onPressed: shareData == null
                ? null
                : () => _shareProgress(copy, shareData),
            icon: const Icon(Icons.ios_share_rounded),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          ListTile(
            key: const Key('progress-metric-selector'),
            leading: Icon(_metricIcon(metric)),
            title: Text(copy.metric),
            subtitle: Text(copy.metricLabel(metric)),
            trailing: const Icon(Icons.expand_more_rounded),
            onTap: _pickMetric,
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const Key('progress-range-selector'),
            leading: const Icon(Icons.date_range_rounded),
            title: Text(copy.range),
            subtitle: Text(copy.rangeLabel(range)),
            trailing: const Icon(Icons.expand_more_rounded),
            onTap: _pickRange,
          ),
          const SizedBox(height: 18),
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.show_chart_rounded, size: 44),
              const SizedBox(height: 12),
              Text(copy.noRecords, textAlign: TextAlign.center),
              if (canAdd) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('progress-empty-add'),
                  onPressed: () => context.push(
                    metric == ProgressMetric.weight
                        ? '/weight-history'
                        : '/profile-settings',
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    metric == ProgressMetric.weight
                        ? copy.addEditWeight
                        : copy.editMeasurements,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    final latest = points.last;
    final stats = ProgressSeriesStats.fromChronologicalValues(
      points.map((point) => point.value).toList(growable: false),
    )!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryValue(
                label: metric == ProgressMetric.steps
                    ? copy.average
                    : copy.start,
                value:
                    (metric == ProgressMetric.steps
                            ? stats.average
                            : stats.start)
                        .toStringAsFixed(
                          metric == ProgressMetric.steps ? 0 : 1,
                        ),
                unit: unit,
              ),
            ),
            Expanded(
              child: _SummaryValue(
                label: metric == ProgressMetric.steps
                    ? copy.best
                    : copy.current,
                value:
                    (metric == ProgressMetric.steps
                            ? stats.best
                            : stats.current)
                        .toStringAsFixed(
                          metric == ProgressMetric.steps ? 0 : 1,
                        ),
                unit: unit,
              ),
            ),
            Expanded(
              child: _SummaryValue(
                label: metric == ProgressMetric.steps
                    ? copy.total
                    : copy.change,
                value: metric == ProgressMetric.steps
                    ? stats.total.toStringAsFixed(0)
                    : '${stats.change >= 0 ? '+' : ''}${stats.change.toStringAsFixed(1)}',
                unit: unit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.latest,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  '${latest.value.toStringAsFixed(metric == ProgressMetric.steps ? 0 : 1)} $unit',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(latest.date),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SizedBox(
            height: 240,
            child: Semantics(
              label: copy.chartSummary(
                copy.metricLabel(metric),
                copy.rangeLabel(range),
                points.length,
                points.map((point) => point.value).reduce(math.min),
                points.map((point) => point.value).reduce(math.max),
                latest.value,
                unit,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: CustomPaint(
                  key: const Key('progress-real-series-chart'),
                  painter: _ProgressPainter(points),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(copy.recordCount(points.length), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(copy.entries, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        ...points.reversed.map(
          (point) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              MaterialLocalizations.of(context).formatMediumDate(point.date),
            ),
            trailing: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${point.value.toStringAsFixed(metric == ProgressMetric.steps ? 0 : 1)} $unit',
              ),
            ),
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

  Widget _loading() => const Center(child: CircularProgressIndicator());
  Widget _error(_ProgressCopy copy, VoidCallback onRetry) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(copy.unavailable, textAlign: TextAlign.center),
          TextButton.icon(
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

class _Point {
  const _Point(this.date, this.value);
  final DateTime date;
  final double value;
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label, $value $unit',
    child: Column(
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(value, style: Theme.of(context).textTheme.titleLarge),
        ),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter(this.points);
  final List<_Point> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0878F9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final values = points.map((point) => point.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final spread = math.max(high - low, 1);
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);
      final y =
          size.height - ((points[index].value - low) / spread * size.height);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _ProgressCopy {
  const _ProgressCopy(this.v);
  final Map<String, String> v;
  String t(String key) => v[key]!;
  String get progress => t('progress');
  String get metric => t('metric');
  String get range => t('range');
  String get selectMetric => t('selectMetric');
  String get selectRange => t('selectRange');
  String get stepsUnit => t('stepsUnit');
  String get latest => t('latest');
  String get noRecords => t('noRecords');
  String get unavailable => t('unavailable');
  String get currentOnly => t('currentOnly');
  String get noCurrentMeasurement => t('noCurrentMeasurement');
  String get hipsUnavailable => t('hipsUnavailable');
  String get addEditWeight => t('addEditWeight');
  String get editMeasurements => t('editMeasurements');
  String get shareProgress => t('shareProgress');
  String get average => t('average');
  String get best => t('best');
  String get total => t('total');
  String get start => t('start');
  String get current => t('current');
  String get change => t('change');
  String get entries => t('entries');
  String get retry => t('retry');
  String get shareUnavailable => t('shareUnavailable');
  String get neck => t('neck');
  String get waist => t('waist');
  String metricLabel(ProgressMetric value) => t(value.name);
  String rangeLabel(ProgressRange value) => t(value.name);
  String recordCount(int count) => '${t('records')}: $count';
  String chartSummary(
    String metric,
    String range,
    int count,
    double minimum,
    double maximum,
    double latest,
    String unit,
  ) =>
      '$metric, $range. $count ${t('records')}. '
      '${t('minimum')}: ${minimum.toStringAsFixed(1)} $unit. '
      '${t('maximum')}: ${maximum.toStringAsFixed(1)} $unit. '
      '${t('latest')}: ${latest.toStringAsFixed(1)} $unit.';
  String shareText(
    String metric,
    String range,
    int count,
    double start,
    double current,
    double change,
    String unit, {
    bool wholeNumbers = false,
  }) {
    String format(double value) =>
        wholeNumbers ? value.round().toString() : value.toStringAsFixed(1);
    return '$metric · $range\n'
        '${t('records')}: $count\n'
        '${t('start')}: ${format(start)} $unit\n'
        '${t('current')}: ${format(current)} $unit\n'
        '${t('change')}: ${change >= 0 ? '+' : ''}${format(change)} $unit';
  }

  static _ProgressCopy of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return _ProgressCopy(progressCopyForLocale(locale.toLanguageTag()));
  }
}

Map<String, String> progressCopyForLocale(String localeTag) {
  final language = localeTag.replaceAll('_', '-').split('-').first;
  final authored = _progressCopy[language];
  if (authored != null) return authored;
  return {
    for (final entry in _progressCopy['en']!.entries)
      entry.key: RuntimeCopy.resolve(entry.value, localeTag) ?? entry.value,
  };
}

const _progressCopy = <String, Map<String, String>>{
  'en': {
    'progress': 'Progress',
    'metric': 'Metric',
    'range': 'Date range',
    'selectMetric': 'Select a measurement',
    'selectRange': 'Select a date range',
    'steps': 'Steps',
    'weight': 'Weight',
    'neck': 'Neck',
    'waist': 'Waist',
    'hips': 'Hips',
    'chest': 'Chest',
    'arm': 'Arm',
    'thigh': 'Thigh',
    'week': '1w',
    'month': '1m',
    'twoMonths': '2m',
    'threeMonths': '3m',
    'sixMonths': '6m',
    'year': '1y',
    'all': 'All',
    'stepsUnit': 'steps',
    'latest': 'Latest',
    'records': 'Recorded days',
    'noRecords': 'No real records are available for this metric and range.',
    'unavailable': 'Local progress data is temporarily unavailable.',
    'currentOnly':
        'This is the current profile measurement. Measurement history is not stored yet.',
    'noCurrentMeasurement':
        'No current measurement is saved. Add or edit it in your profile.',
    'hipsUnavailable':
        'Hip measurement is unavailable because the current profile schema does not store it.',
    'addEditWeight': 'Add or edit weight',
    'editMeasurements': 'Edit measurements',
    'shareProgress': 'Share progress',
    'average': 'Average',
    'best': 'Best',
    'total': 'Total',
    'start': 'Start',
    'current': 'Current',
    'change': 'Change',
    'entries': 'Entries',
    'retry': 'Retry',
    'minimum': 'Minimum',
    'maximum': 'Maximum',
    'shareUnavailable': 'Sharing is unavailable on this device.',
  },
  'ar': {
    'progress': 'التقدم',
    'metric': 'المقياس',
    'range': 'الفترة الزمنية',
    'selectMetric': 'اختر قياسًا',
    'selectRange': 'اختر فترة زمنية',
    'steps': 'الخطوات',
    'weight': 'الوزن',
    'neck': 'الرقبة',
    'waist': 'الخصر',
    'hips': 'الورك',
    'chest': 'الصدر',
    'arm': 'الذراع',
    'thigh': 'الفخذ',
    'week': 'أسبوع',
    'month': 'شهر',
    'twoMonths': 'شهران',
    'threeMonths': '3 أشهر',
    'sixMonths': '6 أشهر',
    'year': 'سنة',
    'all': 'الكل',
    'stepsUnit': 'خطوة',
    'latest': 'الأحدث',
    'records': 'أيام مسجلة',
    'noRecords': 'لا توجد سجلات حقيقية لهذا المقياس وهذه المدة.',
    'unavailable': 'بيانات التقدم المحلية غير متاحة مؤقتًا.',
    'currentOnly':
        'هذه قياسة الملف الشخصي الحالية. لا يُحفظ تاريخ القياسات بعد.',
    'noCurrentMeasurement':
        'لا توجد قياسة حالية محفوظة. أضفها أو عدّلها في ملفك.',
    'hipsUnavailable': 'قياس الورك غير متاح لأن مخطط الملف الحالي لا يخزنه.',
    'addEditWeight': 'إضافة أو تعديل الوزن',
    'editMeasurements': 'تعديل القياسات',
    'shareProgress': 'مشاركة التقدم',
    'average': 'المتوسط',
    'best': 'الأفضل',
    'total': 'الإجمالي',
    'start': 'البداية',
    'current': 'الحالي',
    'change': 'التغير',
    'entries': 'الإدخالات',
    'retry': 'إعادة المحاولة',
    'minimum': 'الأدنى',
    'maximum': 'الأعلى',
    'shareUnavailable': 'المشاركة غير متاحة على هذا الجهاز.',
  },
  'fr': {
    'progress': 'Progression',
    'metric': 'Mesure',
    'range': 'Période',
    'selectMetric': 'Choisir une mesure',
    'selectRange': 'Choisir une période',
    'steps': 'Pas',
    'weight': 'Poids',
    'neck': 'Cou',
    'waist': 'Tour de taille',
    'hips': 'Hanches',
    'chest': 'Poitrine',
    'arm': 'Bras',
    'thigh': 'Cuisse',
    'week': '1 sem.',
    'month': '1 mois',
    'twoMonths': '2 mois',
    'threeMonths': '3 mois',
    'sixMonths': '6 mois',
    'year': '1 an',
    'all': 'Tout',
    'stepsUnit': 'pas',
    'latest': 'Dernière valeur',
    'records': 'Jours enregistrés',
    'noRecords': 'Aucune donnée réelle pour cette mesure et cette période.',
    'unavailable': 'Les données locales sont temporairement indisponibles.',
    'currentOnly':
        'Il s’agit de la mesure actuelle du profil. L’historique n’est pas encore stocké.',
    'noCurrentMeasurement':
        'Aucune mesure actuelle enregistrée. Ajoutez-la dans votre profil.',
    'hipsUnavailable':
        'La mesure des hanches est indisponible car le schéma actuel ne la stocke pas.',
    'addEditWeight': 'Ajouter ou modifier le poids',
    'editMeasurements': 'Modifier les mesures',
    'shareProgress': 'Partager la progression',
    'average': 'Moyenne',
    'best': 'Meilleur',
    'total': 'Total',
    'start': 'Début',
    'current': 'Actuel',
    'change': 'Variation',
    'entries': 'Entrées',
    'retry': 'Réessayer',
    'minimum': 'Minimum',
    'maximum': 'Maximum',
    'shareUnavailable': 'Le partage est indisponible sur cet appareil.',
  },
  'es': {
    'progress': 'Progreso',
    'metric': 'Métrica',
    'range': 'Periodo',
    'selectMetric': 'Seleccionar medida',
    'selectRange': 'Seleccionar periodo',
    'steps': 'Pasos',
    'weight': 'Peso',
    'neck': 'Cuello',
    'waist': 'Cintura',
    'hips': 'Caderas',
    'chest': 'Pecho',
    'arm': 'Brazo',
    'thigh': 'Muslo',
    'week': '1 sem.',
    'month': '1 mes',
    'twoMonths': '2 meses',
    'threeMonths': '3 meses',
    'sixMonths': '6 meses',
    'year': '1 año',
    'all': 'Todo',
    'stepsUnit': 'pasos',
    'latest': 'Último',
    'records': 'Días registrados',
    'noRecords': 'No hay registros reales para esta métrica y periodo.',
    'unavailable': 'Los datos locales no están disponibles temporalmente.',
    'currentOnly':
        'Esta es la medida actual del perfil. Aún no se guarda historial.',
    'noCurrentMeasurement':
        'No hay una medida actual guardada. Añádela en tu perfil.',
    'hipsUnavailable':
        'La medida de caderas no está disponible porque el esquema actual no la almacena.',
    'addEditWeight': 'Añadir o editar peso',
    'editMeasurements': 'Editar medidas',
    'shareProgress': 'Compartir progreso',
    'average': 'Promedio',
    'best': 'Mejor',
    'total': 'Total',
    'start': 'Inicio',
    'current': 'Actual',
    'change': 'Cambio',
    'entries': 'Entradas',
    'retry': 'Reintentar',
    'minimum': 'Mínimo',
    'maximum': 'Máximo',
    'shareUnavailable': 'Compartir no está disponible en este dispositivo.',
  },
  'tr': {
    'progress': 'İlerleme',
    'metric': 'Ölçüm',
    'range': 'Tarih aralığı',
    'selectMetric': 'Ölçüm seç',
    'selectRange': 'Tarih aralığı seç',
    'steps': 'Adımlar',
    'weight': 'Kilo',
    'neck': 'Boyun',
    'waist': 'Bel',
    'hips': 'Kalça',
    'chest': 'Göğüs',
    'arm': 'Kol',
    'thigh': 'Uyluk',
    'week': '1 hf.',
    'month': '1 ay',
    'twoMonths': '2 ay',
    'threeMonths': '3 ay',
    'sixMonths': '6 ay',
    'year': '1 yıl',
    'all': 'Tümü',
    'stepsUnit': 'adım',
    'latest': 'En son',
    'records': 'Kayıtlı gün',
    'noRecords': 'Bu ölçüm ve aralık için gerçek kayıt yok.',
    'unavailable': 'Yerel ilerleme verileri geçici olarak kullanılamıyor.',
    'currentOnly':
        'Bu, mevcut profil ölçümüdür. Ölçüm geçmişi henüz saklanmıyor.',
    'noCurrentMeasurement': 'Kayıtlı güncel ölçüm yok. Profilinizden ekleyin.',
    'hipsUnavailable':
        'Kalça ölçümü mevcut profil şemasında saklanmadığı için kullanılamıyor.',
    'addEditWeight': 'Kilo ekle veya düzenle',
    'editMeasurements': 'Ölçümleri düzenle',
    'shareProgress': 'İlerlemeyi paylaş',
    'average': 'Ortalama',
    'best': 'En iyi',
    'total': 'Toplam',
    'start': 'Başlangıç',
    'current': 'Güncel',
    'change': 'Değişim',
    'entries': 'Kayıtlar',
    'retry': 'Yeniden dene',
    'minimum': 'En düşük',
    'maximum': 'En yüksek',
    'shareUnavailable': 'Paylaşım bu cihazda kullanılamıyor.',
  },
};
