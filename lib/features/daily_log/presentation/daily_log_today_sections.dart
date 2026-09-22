import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../core/units/measurement_units.dart';
import '../../connected_health/connected_health_copy.dart';
import '../../connected_health/connected_health_model.dart';
import '../../connected_health/providers/connected_health_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../providers/daily_log_provider.dart';

class DailyLogTodayBackground extends StatelessWidget {
  const DailyLogTodayBackground({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canvas = theme.brightness == Brightness.light
        ? const Color(0xFFEBECF1)
        : scheme.surfaceContainerLow;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, .44, 1],
          colors: [
            Color.alphaBlend(
              scheme.primary.withValues(alpha: .10),
              scheme.surface,
            ),
            canvas,
            canvas,
          ],
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class DailyLogTodayCard extends StatelessWidget {
  const DailyLogTodayCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    clipBehavior: Clip.antiAlias,
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(18),
    child: child,
  );
}

String dailyLogHabitsTitle(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final key = locale.languageCode == 'zh'
      ? 'zh-${locale.scriptCode}'
      : locale.languageCode;
  return const {
        'ar': 'عادات صحية',
        'en': 'Healthy habits',
        'fr': 'Habitudes saines',
        'es': 'Hábitos saludables',
        'tr': 'Sağlıklı alışkanlıklar',
        'de': 'Gesunde Gewohnheiten',
        'it': 'Abitudini sane',
        'pt': 'Hábitos saudáveis',
        'ur': 'صحت مند عادات',
        'fa': 'عادت‌های سالم',
        'hi': 'स्वस्थ आदतें',
        'id': 'Kebiasaan sehat',
        'ms': 'Tabiat sihat',
        'ja': '健康的な習慣',
        'ko': '건강한 습관',
        'zh-Hans': '健康习惯',
        'zh-Hant': '健康習慣',
        'ru': 'Здоровые привычки',
        'bn': 'স্বাস্থ্যকর অভ্যাস',
        'vi': 'Thói quen lành mạnh',
        'th': 'นิสัยที่ดีต่อสุขภาพ',
        'pl': 'Zdrowe nawyki',
        'nl': 'Gezonde gewoonten',
        'uk': 'Здорові звички',
      }[key] ??
      'Healthy habits';
}

/// Date selection only: circles never invent logged/completed-day evidence.
class DailyLogWeekStrip extends StatelessWidget {
  const DailyLogWeekStrip({
    super.key,
    required this.date,
    required this.onSelected,
    this.firstDate,
    this.lastDate,
  });
  final DateTime date;
  final ValueChanged<DateTime>? onSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final first = material.firstDayOfWeekIndex;
    final offset = (date.weekday % 7 - first + 7) % 7;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const Key('daily-log-week-strip'),
      children: List.generate(7, (index) {
        final day = DateTime(date.year, date.month, date.day - offset + index);
        final selected = DateUtils.isSameDay(day, date);
        final enabled =
            onSelected != null &&
            (firstDate == null ||
                !day.isBefore(DateUtils.dateOnly(firstDate!))) &&
            (lastDate == null || !day.isAfter(DateUtils.dateOnly(lastDate!)));
        return Expanded(
          child: Semantics(
            selected: selected,
            enabled: enabled,
            button: true,
            label: material.formatFullDate(day),
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('daily-log-week-${day.toIso8601String()}'),
              onTap: enabled ? () => onSelected!(day) : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 22),
                child: Column(
                  children: [
                    Text(
                      material.narrowWeekdays[(first + index) % 7],
                      style: TextStyle(
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? scheme.primaryContainer
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant.withValues(alpha: .55),
                          width: selected ? 2 : 1.5,
                        ),
                      ),
                      child: selected
                          ? Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Reads the same canonical projections as BIL's existing pages. Opening Today
/// does not start native synchronization, request permissions or synthesize zero.
class DailyLogStepsShortcut extends ConsumerWidget {
  const DailyLogStepsShortcut({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(connectedHealthProvider).value;
    final steps = connectedHealthDailyStepTotals(
      snapshot,
      date,
    )[DateUtils.dateOnly(date)];
    return ListTile(
      key: const Key('daily-log-steps-shortcut'),
      minTileHeight: 80,
      title: Text(
        connectedHealthDataTypeText(context, 'steps'),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        steps == null
            ? '—'
            : MaterialLocalizations.of(context).formatDecimal(steps.round()),
        key: const Key('daily-log-steps-value'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/connected-health/steps'),
    );
  }
}

class DailyLogWeightShortcut extends ConsumerWidget {
  const DailyLogWeightShortcut({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(weightHistoryProvider);
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    // An older diary must never display a later measurement as its own.
    final end = DateTime(date.year, date.month, date.day + 1);
    final rows = history.value?.where((row) => row.date.isBefore(end)).toList()
      ?..sort((a, b) => b.date.compareTo(a.date));
    final weight = rows?.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            context.strings.text('Weight'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        DailyLogTodayCard(
          key: const Key('daily-log-weight-shortcut'),
          child: ListTile(
            minTileHeight: 80,
            title: Text(
              weight == null
                  ? '—'
                  : '${UnitConverter.weightFromKg(weight.weight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
              key: const Key('daily-log-weight-value'),
            ),
            subtitle: weight == null
                ? null
                : Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(weight.date.toLocal()),
                  ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/weight-history'),
          ),
        ),
      ],
    );
  }
}

class DailyLogNotesShortcut extends ConsumerWidget {
  const DailyLogNotesShortcut({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(selectedDailyLogProvider);
    final notes = log.isLoading ? null : log.value?.notes;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          DailyLogTodayCard(
            key: const Key('daily-log-notes-shortcut'),
            child: ListTile(
              minTileHeight: 64,
              title: Text(
                notes?.isNotEmpty == true ? notes! : '—',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => context.push('/daily-log/body-context'),
            ),
          ),
        ],
      ),
    );
  }
}
