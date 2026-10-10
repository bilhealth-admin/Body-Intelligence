import 'package:flutter/material.dart';
import '../../app/localization/sapphire_copy.dart';
import '../global_platform/core/global_platform_core.dart';
import 'connected_health_daily_history.dart';
import 'connected_health_model.dart';
import 'connected_health_copy.dart';

/// Compact pre-upgrade cached rows too; leave the latest/watch snapshot alone.
List<ConnectedHealthSignalView> compactConnectedHistoryViews(
  Iterable<ConnectedHealthSignalView> input,
  DateTime asOf,
) => projectConnectedDailyHistory(
  ConnectedDailyHistoryInput(
    asOf: asOf,
    samples: [
      for (final s in input)
        GlobalHealthSignal(
          key: s.key,
          canonicalValue: s.value,
          canonicalUnit: s.unit == 'bpm' ? 'count/min' : s.unit,
          provenance: GlobalProvenance(
            providerId: 'history.view',
            sourceId: s.source,
            recordId:
                '${s.key}:${s.source}:${s.observedAt.toUtc().toIso8601String()}',
            observedAt: s.observedAt,
            confidence: s.confidence,
          ),
          attributes: s.attributes,
        ),
    ],
  ),
).map(ConnectedHealthSignalView.fromSignal).toList(growable: false);

String connectedViewHistoryDay(ConnectedHealthSignalView signal) =>
    signal.attributes['historyLocalDay']?.toString() ??
    connectedHistoryDay(signal.observedAt);

/// Prefer the ordinary heart-rate mean. A resting-only day is labeled as such;
/// resting and ordinary measurements must never be blended into one average.
List<ConnectedHealthSignalView> closedHeartHistory(
  Iterable<ConnectedHealthSignalView> rows,
  DateTime now,
) {
  final byDay = <String, ConnectedHealthSignalView>{};
  for (final row in rows) {
    final day = connectedViewHistoryDay(row);
    if (!connectedHistoryDayComplete(day, now)) continue;
    if (row.key != 'heartRate' && row.key != 'restingHeartRate') continue;
    if (byDay[day]?.key != 'heartRate') byDay[day] = row;
  }
  return byDay.values.toList()..sort(
    (a, b) => connectedViewHistoryDay(b).compareTo(connectedViewHistoryDay(a)),
  );
}

class ConnectedDailyHistoryRow extends StatelessWidget {
  const ConnectedDailyHistoryRow({
    required this.signal,
    required this.asOf,
    super.key,
  });
  final ConnectedHealthSignalView signal;
  final DateTime asOf;
  @override
  Widget build(BuildContext context) {
    final energy = signal.key == 'activeEnergy';
    final day = connectedViewHistoryDay(signal);
    final date = connectedHistoryDate(day) ?? signal.observedAt.toLocal();
    final title = MaterialLocalizations.of(context).formatFullDate(date);
    final completed = connectedHistoryDayComplete(day, asOf);
    final label = energy
        ? (signal.attributes['historyAggregation'] == 'native_daily'
              ? 'dailyTotal'
              : 'recordedTotal')
        : signal.key == 'restingHeartRate'
        ? 'restingAverage'
        : 'dailyAverage';
    final above =
        signal.key == 'heartRate' &&
        ((signal.attributes['aboveThresholdCount'] as num?)?.toInt() ?? 0) > 0;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey('daily-history-${signal.key}-$day'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  energy
                      ? Icons.local_fire_department_outlined
                      : Icons.favorite_border,
                  color: scheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 5),
                    Text(
                      sapphireText(context, label),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      connectedHealthSignalValueText(context, signal),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connectedHealthDisplayName(context, signal),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!energy && signal.attributes['sampleCount'] is int)
                      Text(
                        '${sapphireText(context, 'samples')}: ${signal.attributes['sampleCount']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (energy && !completed)
                      Text(
                        sapphireText(context, 'inProgress'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (above) ...[
            const SizedBox(height: 12),
            ConnectedDailyHeartNotice(signal: signal),
          ],
        ],
      ),
    );
  }
}

/// One informational marker per day, not a medical/background alarm.
class ConnectedDailyHeartNotice extends StatelessWidget {
  const ConnectedDailyHeartNotice({required this.signal, super.key});
  final ConnectedHealthSignalView signal;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFFFD59A) : const Color(0xFF854A0E);
    final fill = dark ? const Color(0xFF382B1A) : const Color(0xFFFFF7E9);
    final first = DateTime.tryParse(
      signal.attributes['firstAboveThresholdAt']?.toString() ?? '',
    );
    final peakAt = DateTime.tryParse(
      signal.attributes['peakObservedAt']?.toString() ?? '',
    );
    final peak = signal.attributes['dailyMaximum'];
    String time(DateTime at, String offsetKey) {
      final offset = signal.attributes[offsetKey];
      final local = offset is int
          ? at.toUtc().add(Duration(minutes: offset))
          : at.toLocal();
      return TimeOfDay.fromDateTime(local).format(context);
    }

    String number(num value) => value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return Container(
      key: ValueKey('heart-day-notice-${connectedViewHistoryDay(signal)}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: ink, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sapphireText(context, 'above100'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: ink),
                ),
              ),
            ],
          ),
          if (first != null) ...[
            const SizedBox(height: 7),
            Text(
              '${sapphireText(context, 'first')}: ${time(first, 'firstAboveThresholdOffsetMinutes')}',
              style: TextStyle(color: ink),
            ),
          ],
          if (peak is num && peakAt != null)
            Text(
              '${sapphireText(context, 'peak')}: ${number(peak)} bpm · ${time(peakAt, 'peakOffsetMinutes')}',
              style: TextStyle(color: ink),
            ),
          const SizedBox(height: 8),
          Text(
            sapphireText(context, 'heartNotice'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}
