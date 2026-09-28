part of 'progress_page.dart';

/// Combines local/manual daily steps with verified native daily totals.
/// Native evidence wins for the same calendar day because it is the source
/// shown by the dedicated Apple Health / Health Connect history screen.
List<_Point> _progressStepPoints(
  List<DailyLog> logs,
  ConnectedHealthSnapshot? connectedHealth,
) => progressMergedStepValues(logs, connectedHealth).entries
    .map((entry) => _Point(entry.key, entry.value))
    .toList(growable: false);

Map<DateTime, double> progressMergedStepValues(
  List<DailyLog> logs,
  ConnectedHealthSnapshot? connectedHealth,
) {
  final byDay = <String, MapEntry<DateTime, double>>{
    for (final row in logs)
      if (row.steps != null && row.steps! >= 0)
        row.dayKey: MapEntry(
          DateUtils.dateOnly(row.date),
          row.steps!.toDouble(),
        ),
  };
  if (connectedHealth?.deviceVerified == true) {
    for (final signal in connectedHealth!.stepHistory) {
      if (signal.key != 'steps' || !signal.value.isFinite || signal.value < 0) {
        continue;
      }
      final day = DateUtils.dateOnly(signal.observedAt.toLocal());
      byDay[dayKeyFor(day)] = MapEntry(day, signal.value);
    }
  }
  return Map<DateTime, double>.fromEntries(byDay.values);
}

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
