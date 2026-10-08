import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import 'connected_health_copy.dart';
import 'connected_health_model.dart';
import 'connected_health_daily_history.dart';
import 'connected_health_daily_history_view.dart';
import '../../app/localization/sapphire_copy.dart';
import '../../shared/widgets/bil_clinical_note.dart';
import 'providers/connected_health_provider.dart';

/// Truthful detail surface for a measured connected-health signal.
/// Missing evidence stays missing and routes to the source connection flow.
class ConnectedHealthSignalDetailPage extends ConsumerWidget {
  const ConnectedHealthSignalDetailPage({
    super.key,
    required this.keys,
    required this.title,
    required this.unitFallback,
    this.historyKeys,
    this.clock,
  });

  final List<String> keys;
  final String title;
  final String unitFallback;
  final List<String>? historyKeys;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(connectedHealthProvider);
    final snapshot = health.value;
    final acceptedHistoryKeys = historyKeys ?? keys;
    ConnectedHealthSignalView? signal;
    for (final candidate
        in snapshot?.signals ?? const <ConnectedHealthSignalView>[]) {
      if (!keys.contains(candidate.key)) continue;
      if (signal == null || candidate.observedAt.isAfter(signal.observedAt)) {
        signal = candidate;
      }
    }
    final asOf = (clock ?? DateTime.now)();
    final heart = acceptedHistoryKeys.contains('heartRate');
    final compact = compactConnectedHistoryViews([
      for (final candidate
          in snapshot?.signalHistory ?? const <ConnectedHealthSignalView>[])
        if (acceptedHistoryKeys.contains(candidate.key) &&
            candidate.value.isFinite &&
            candidate.confidence > 0)
          candidate,
    ], asOf);
    final history = heart ? closedHeartHistory(compact, asOf) : compact;
    final todayNotices = compact
        .where(
          (s) =>
              heart &&
              s.key == 'heartRate' &&
              !connectedHistoryDayComplete(connectedViewHistoryDay(s), asOf) &&
              ((s.attributes['aboveThresholdCount'] as num?)?.toInt() ?? 0) > 0,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text(title))),
      body: health.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (signal == null || snapshot?.deviceVerified != true)
                  _MissingSignalCard(
                    onConnect: () => context.push('/connected-health'),
                  )
                else
                  _MeasuredSignalCard(
                    signal: signal,
                    unitFallback: unitFallback,
                    lastSyncAt: snapshot?.lastSyncAt,
                  ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SignalHistoryCard(signals: history, asOf: asOf),
                ],
                if (heart) ...[
                  const SizedBox(height: 12),
                  Text(
                    sapphireText(context, 'closedDays'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  for (final notice in todayNotices) ...[
                    const SizedBox(height: 12),
                    Text(
                      sapphireText(context, 'inProgress'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ConnectedDailyHeartNotice(signal: notice),
                  ],
                ],
                const SizedBox(height: 16),
                BilClinicalNote(
                  text: context.strings.text(
                    'Connected-health values are wellness records, not a diagnosis. Seek medical care for concerning symptoms.',
                  ),
                ),
              ],
            ),
    );
  }
}

class _MissingSignalCard extends StatelessWidget {
  const _MissingSignalCard({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('connected-signal-not-connected'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.watch_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            context.strings.text('Not connected'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.strings.text(
              'Connect a supported health source to show a real measured value.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.link_rounded),
            label: Text(context.strings.text('Connect')),
          ),
        ],
      ),
    ),
  );
}

class _MeasuredSignalCard extends StatelessWidget {
  const _MeasuredSignalCard({
    required this.signal,
    required this.unitFallback,
    required this.lastSyncAt,
  });

  final ConnectedHealthSignalView signal;
  final String unitFallback;
  final DateTime? lastSyncAt;

  @override
  Widget build(BuildContext context) {
    final unit = signal.unit.trim().isEmpty ? unitFallback : signal.unit;
    final value = signal.value == signal.value.roundToDouble()
        ? signal.value.round().toString()
        : signal.value.toStringAsFixed(1);
    return Card(
      key: const Key('connected-signal-measured'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFF0BA878),
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              '$value $unit',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.strings.text('Source')),
              subtitle: Text(context.strings.text(connectedHealthDisplaySource(signal))),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.strings.text('Measured')),
              subtitle: Text(
                MaterialLocalizations.of(
                  context,
                ).formatFullDate(signal.observedAt.toLocal()),
              ),
            ),
            if (lastSyncAt != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.strings.text('Last sync')),
                subtitle: Text(
                  TimeOfDay.fromDateTime(lastSyncAt!.toLocal()).format(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignalHistoryCard extends StatelessWidget {
  const _SignalHistoryCard({required this.signals, required this.asOf});

  final List<ConnectedHealthSignalView> signals;
  final DateTime asOf;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('connected-signal-history'),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.text('History'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < signals.length; index++) ...[
            if (signals[index].attributes['historyProjection'] == 'daily_v1')
              ConnectedDailyHistoryRow(signal: signals[index], asOf: asOf)
            else
              _SignalHistoryRow(signal: signals[index]),
            if (index != signals.length - 1)
              const Divider(height: 1, indent: 44),
          ],
        ],
      ),
    ),
  );
}

class _SignalHistoryRow extends StatelessWidget {
  const _SignalHistoryRow({required this.signal});

  final ConnectedHealthSignalView signal;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final date = material.formatFullDate(signal.observedAt.toLocal());
    final includeTime =
        signal.key == 'heartRate' || signal.key == 'restingHeartRate';
    final when = includeTime
        ? '$date • ${TimeOfDay.fromDateTime(signal.observedAt.toLocal()).format(context)}'
        : date;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_rounded),
      title: Text(when),
      subtitle: Text(connectedHealthDisplaySource(signal)),
      trailing: Text(
        connectedHealthSignalValueText(context, signal),
        textDirection: TextDirection.ltr,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
