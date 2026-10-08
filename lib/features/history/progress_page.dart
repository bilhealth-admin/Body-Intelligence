import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/localization/runtime_copy.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../data/database/app_database.dart';
import '../../data/database/date_keys.dart';
import '../../core/units/measurement_units.dart';
import '../ads/presentation/safe_free_ad_anchor.dart';
import '../daily_log/providers/daily_log_provider.dart';
import '../connected_health/connected_health_model.dart';
import '../connected_health/providers/connected_health_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../visual_2026/bil_calm_visual_scope.dart';

part 'progress_page_components.dart';
part 'progress_page_copy.dart';
part 'progress_page_domain.dart';
part 'progress_page_series.dart';

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
    final connectedHealth = ref.watch(connectedHealthProvider).value;
    final weights = ref.watch(weightHistoryProvider);
    final measurements = ref.watch(bodyMeasurementHistoryProvider);
    final systemState = ref.watch(measurementSystemProvider);
    final shareData = _shareData(
      logs,
      connectedHealth,
      weights,
      measurements,
      systemState,
    );

    return BilCalmVisualScope(
      builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          centerTitle: true,
          title: Text(copy.progress),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: IconButton(
                key: const Key('progress-share'),
                tooltip: copy.shareProgress,
                onPressed: shareData == null
                    ? null
                    : () => _shareProgress(copy, shareData),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
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
                onPressed: () => _editMeasurement(copy),
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
                    eyebrow: copy.metric,
                    value: copy.metricLabel(metric),
                    onTap: _pickMetric,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProgressSelector(
                    key: const Key('progress-range-selector'),
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
                error: (_, _) => _error(
                  copy,
                  () => ref.invalidate(progressDailyLogsProvider),
                ),
                data: (rows) => _series(
                  copy,
                  _filter(_progressStepPoints(rows, connectedHealth)),
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
                          .where(
                            (row) => row.weight.isFinite && row.weight >= 0,
                          )
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
      ),
    );
  }

  ({List<_Point> points, String unit})? _shareData(
    AsyncValue<List<DailyLog>> logs,
    ConnectedHealthSnapshot? connectedHealth,
    AsyncValue<List<WeightEntry>> weights,
    AsyncValue<List<BodyMeasurementEntry>> measurements,
    AsyncValue<MeasurementSystem> systemState,
  ) {
    List<_Point>? points;
    String? unit;
    if (metric == ProgressMetric.steps && logs.hasValue) {
      points = _filter(_progressStepPoints(logs.requireValue, connectedHealth));
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
                leading: BilSemanticIconBadge(
                  kind: _metricKind(value),
                  iconOverride: _metricIcon(value),
                  appleIconOverride: _metricAppleIcon(value),
                  size: 38,
                  iconSize: 21,
                  shape: BoxShape.rectangle,
                ),
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

  List<_Point> _filter(List<_Point> points) {
    final now = ref.read(progressClockProvider)();
    return points
        .where((point) => progressDateInRange(point.date, range, now))
        .toList();
  }

  double? _measurementValue(BodyMeasurementEntry? row) => switch (metric) {
    ProgressMetric.neck => row?.neckCm,
    ProgressMetric.waist => row?.waistCm,
    ProgressMetric.hips => row?.hipsCm,
    ProgressMetric.chest => row?.chestCm,
    ProgressMetric.arm => row?.armCm,
    ProgressMetric.thigh => row?.thighCm,
    _ => null,
  };

  Future<void> _editMeasurement(_ProgressCopy copy, {DateTime? date}) async {
    if (metric == ProgressMetric.steps || metric == ProgressMetric.weight) {
      return;
    }
    final system = ref.read(measurementSystemProvider).value;
    if (system == null) return;
    final repository = ref.read(bodyMeasurementRepositoryProvider);
    var selectedDate = DateUtils.dateOnly(
      date ?? ref.read(progressClockProvider)(),
    );
    final controller = TextEditingController();

    Future<void> loadDay() async {
      final existing = await repository.getForDay(selectedDate);
      final centimeters = _measurementValue(existing);
      controller.text = centimeters == null
          ? ''
          : UnitConverter.heightFromCm(centimeters, system).toStringAsFixed(1);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }

    await loadDay();
    if (!mounted) {
      controller.dispose();
      return;
    }
    var saving = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final unit = system == MeasurementSystem.imperial ? 'in' : 'cm';
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      copy.addMeasurement(copy.metricLabel(metric)),
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const Key('measurement-entry-date'),
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: sheetContext,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateUtils.dateOnly(
                                  ref.read(progressClockProvider)(),
                                ),
                              );
                              if (picked == null) return;
                              selectedDate = DateUtils.dateOnly(picked);
                              await loadDay();
                              setSheetState(() => error = null);
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        MaterialLocalizations.of(
                          sheetContext,
                        ).formatFullDate(selectedDate),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('measurement-entry-value'),
                      controller: controller,
                      autofocus: false,
                      enabled: !saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: copy.metricLabel(metric),
                        suffixText: unit,
                        errorText: error,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const Key('measurement-entry-save'),
                      onPressed: saving
                          ? null
                          : () async {
                              final displayValue = double.tryParse(
                                controller.text.trim().replaceAll(',', '.'),
                              );
                              final centimeters = displayValue == null
                                  ? null
                                  : UnitConverter.heightToCm(
                                      displayValue,
                                      system,
                                    );
                              if (centimeters == null ||
                                  !centimeters.isFinite ||
                                  centimeters < 20 ||
                                  centimeters > 300) {
                                setSheetState(
                                  () => error = copy.invalidMeasurement,
                                );
                                return;
                              }
                              setSheetState(() {
                                saving = true;
                                error = null;
                              });
                              try {
                                await switch (metric) {
                                  ProgressMetric.neck => repository.saveForDay(
                                    date: selectedDate,
                                    neckCm: centimeters,
                                    preserveExistingValues: true,
                                  ),
                                  ProgressMetric.waist => repository.saveForDay(
                                    date: selectedDate,
                                    waistCm: centimeters,
                                    preserveExistingValues: true,
                                  ),
                                  ProgressMetric.hips => repository.saveForDay(
                                    date: selectedDate,
                                    hipsCm: centimeters,
                                    preserveExistingValues: true,
                                  ),
                                  ProgressMetric.chest => repository.saveForDay(
                                    date: selectedDate,
                                    chestCm: centimeters,
                                    preserveExistingValues: true,
                                  ),
                                  ProgressMetric.arm => repository.saveForDay(
                                    date: selectedDate,
                                    armCm: centimeters,
                                    preserveExistingValues: true,
                                  ),
                                  ProgressMetric.thigh => repository.saveForDay(
                                    date: selectedDate,
                                    thighCm: centimeters,
                                    preserveExistingValues: true,
                                  ),
                                  _ => Future<void>.value(),
                                };
                                ref.invalidate(bodyMeasurementHistoryProvider);
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } on Object {
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    saving = false;
                                    error = copy.saveFailed;
                                  });
                                }
                              }
                            },
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(copy.saveMeasurement),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    // The modal future resolves when dismissal begins; its reverse transition
    // can still build the text field for a short time. Dispose only after the
    // route has fully left the overlay.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
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

IconData _metricAppleIcon(ProgressMetric metric) => switch (metric) {
  ProgressMetric.steps => Icons.directions_walk_rounded,
  ProgressMetric.weight => Icons.monitor_weight_outlined,
  ProgressMetric.neck => Icons.accessibility_new_rounded,
  ProgressMetric.waist => Icons.straighten_rounded,
  ProgressMetric.hips => Icons.accessibility_rounded,
  ProgressMetric.chest => CupertinoIcons.heart,
  ProgressMetric.arm => Icons.fitness_center_rounded,
  ProgressMetric.thigh => Icons.directions_run_rounded,
};

BilSemanticIconKind _metricKind(ProgressMetric metric) => switch (metric) {
  ProgressMetric.steps => BilSemanticIconKind.steps,
  ProgressMetric.weight => BilSemanticIconKind.weight,
  ProgressMetric.neck ||
  ProgressMetric.waist ||
  ProgressMetric.hips ||
  ProgressMetric.chest ||
  ProgressMetric.arm ||
  ProgressMetric.thigh => BilSemanticIconKind.measurements,
};
