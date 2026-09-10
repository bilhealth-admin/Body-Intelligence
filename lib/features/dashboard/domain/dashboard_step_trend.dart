import '../../connected_health/connected_health_model.dart';

/// One calendar-aligned evidence projection for both the bars and Today label.
/// Empty is unknown, whereas a real zero remains a valid observed value.
class DashboardStepTrend {
  const DashboardStepTrend({
    required this.values,
    required this.today,
    required this.source,
  });
  final List<double> values;
  final double? today;
  final String? source;

  factory DashboardStepTrend.fromEvidence({
    required DateTime now,
    required ConnectedHealthSnapshot? connected,
    required Iterable<({DateTime day, double? steps})> localReadings,
  }) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final first = DateTime(local.year, local.month, local.day - 29);
    final native = connected?.deviceVerified == true
        ? connectedHealthDailyStepTotals(connected, now)
        : const <DateTime, double>{};
    final manual = <DateTime, double>{};
    for (final row in localReadings) {
      final value = row.steps;
      final date = row.day.toLocal();
      final day = DateTime(date.year, date.month, date.day);
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          day.isBefore(first) ||
          day.isAfter(today)) {
        continue;
      }
      manual.putIfAbsent(day, () => value);
    }
    final totals = native.isNotEmpty ? native : manual;
    return DashboardStepTrend(
      values: totals.isEmpty
          ? const []
          : List.unmodifiable(
              List.generate(
                30,
                (index) =>
                    totals[DateTime(
                      today.year,
                      today.month,
                      today.day - 29 + index,
                    )] ??
                    0.0,
              ),
            ),
      today: totals[today],
      source: totals.isEmpty
          ? null
          : native.isNotEmpty
          ? connected!.platformSource
          : 'BIL',
    );
  }
}

/// Steps use a true zero baseline. A small count is never inflated to a
/// decorative minimum height, and invalid or absent counts never draw a bar.
List<double> dashboardStepBarFractions(List<double> values) {
  final finite = values.where((value) => value.isFinite && value > 0);
  final maximum = finite.fold<double>(0, (a, b) => a > b ? a : b);
  return [
    for (final value in values)
      maximum == 0 || !value.isFinite || value <= 0 ? 0 : value / maximum,
  ];
}
