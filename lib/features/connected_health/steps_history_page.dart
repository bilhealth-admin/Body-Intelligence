import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../app/localization/app_localizations.dart';
import 'connected_health_copy.dart';
import 'connected_health_model.dart';
import 'providers/connected_health_provider.dart';
import '../visual_2026/bil_calm_visual_scope.dart';

/// Daily step totals imported from the authorized connected-health source.
///
/// Missing days stay absent rather than being presented as measured zeroes.
class StepsHistoryPage extends ConsumerStatefulWidget {
  const StepsHistoryPage({super.key});

  @override
  ConsumerState<StepsHistoryPage> createState() => _StepsHistoryPageState();
}

class _StepsHistoryPageState extends ConsumerState<StepsHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(connectedHealthProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(connectedHealthProvider);
    final snapshot = health.value;
    final totals = connectedHealthDailyStepTotals(snapshot, DateTime.now());
    final days = totals.keys.toList(growable: false)
      ..sort((left, right) => right.compareTo(left));
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    )..maximumFractionDigits = 0;
    String t(String english, String arabic) =>
        connectedHealthText(context, english, arabic);

    return BilCalmVisualScope(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(t('Steps', 'الخطوات'))),
        body: RefreshIndicator(
          onRefresh: () => ref.read(connectedHealthProvider.notifier).refresh(),
          child: ListView(
            key: const Key('steps-history-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (days.isNotEmpty)
                Card(
                  key: const Key('steps-current-measured'),
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
                          '${number.format(totals[days.first])} ${t('steps', 'خطوة')}',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const Divider(height: 32),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.strings.text('Source')),
                          subtitle: Text(
                            connectedHealthDisplaySource(
                              snapshot!.stepHistory.firstWhere(
                                (signal) {
                                  final observed = signal.observedAt.toLocal();
                                  return signal.key == 'steps' &&
                                      DateTime(
                                            observed.year,
                                            observed.month,
                                            observed.day,
                                          ) ==
                                          days.first;
                                },
                                orElse: () => snapshot.signals.firstWhere(
                                  (signal) => signal.key == 'steps',
                                ),
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.strings.text('Measured')),
                          subtitle: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatFullDate(days.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (days.isNotEmpty) const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(context.strings.text('Last 30 days')),
                subtitle: snapshot?.platformSource?.trim().isNotEmpty == true
                    ? Text(snapshot!.platformSource!)
                    : null,
                trailing: health.isLoading || snapshot?.isBusy == true
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        key: const Key('steps-history-refresh'),
                        tooltip: t('Sync now', 'زامن الآن'),
                        onPressed: () => ref
                            .read(connectedHealthProvider.notifier)
                            .refresh(),
                        icon: const Icon(Icons.sync_rounded),
                      ),
              ),
              const SizedBox(height: 8),
              if (days.isEmpty)
                Card(
                  key: const Key('steps-history-empty'),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.directions_walk_outlined, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          context.strings.text('No steps logged'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t(
                            'Pull down or tap sync to read authorized daily records.',
                            'اسحب للأسفل أو اضغط مزامنة لقراءة السجلات اليومية المصرح بها.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var index = 0; index < days.length; index++) ...[
                        ListTile(
                          key: ValueKey('steps-history-${days[index]}'),
                          leading: const Icon(Icons.directions_walk_rounded),
                          title: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatFullDate(days[index]),
                          ),
                          trailing: Text(
                            '${number.format(totals[days[index]])} ${t('steps', 'خطوة')}',
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (index != days.length - 1)
                          const Divider(height: 1, indent: 56),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
