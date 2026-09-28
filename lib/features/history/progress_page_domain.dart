part of 'progress_page.dart';

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
