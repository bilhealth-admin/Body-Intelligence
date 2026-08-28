import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'domain/goal_timeline_estimator.dart';
import 'profile_locale_copy.dart';

final class GoalTimelinePresentation {
  const GoalTimelinePresentation({
    required this.title,
    required this.value,
    required this.supporting,
  });

  final String title;
  final String value;
  final String supporting;

  static GoalTimelinePresentation forContext(
    BuildContext context,
    GoalTimelineEstimate estimate,
  ) {
    final strings = context.strings;
    final locale = Localizations.localeOf(context);
    final title = profileLocaleText(
      context,
      'Estimated time to goal',
      'الوقت التقديري للوصول إلى الهدف',
    );
    if (estimate.state == GoalTimelineState.alreadyAtGoal) {
      return GoalTimelinePresentation(
        title: title,
        value: profileLocaleText(
          context,
          'Already at goal',
          'أنت عند الهدف بالفعل',
        ),
        supporting: profileLocaleText(
          context,
          'Current weight is within the goal range. This is an estimate, not a guarantee.',
          'الوزن الحالي ضمن نطاق الهدف. هذا تقدير وليس ضمانًا.',
        ),
      );
    }
    if (estimate.state == GoalTimelineState.maintain) {
      return GoalTimelinePresentation(
        title: title,
        value: profileLocaleText(
          context,
          'Maintenance plan · no countdown',
          'خطة تثبيت · بلا عدّ تنازلي',
        ),
        supporting: profileLocaleText(
          context,
          'Maintenance has no completion date. This is an estimate, not a guarantee.',
          'التثبيت ليس له تاريخ اكتمال. هذا تقدير وليس ضمانًا.',
        ),
      );
    }

    final minimumWeeks = strings.number(estimate.minimumWeeks!);
    final maximumWeeks = strings.number(estimate.maximumWeeks!);
    final earliest = strings.date(estimate.earliestDate!);
    final latest = strings.date(estimate.latestDate!);
    final lowRate = strings.number(
      estimate.plannedWeeklyLowKg,
      decimalDigits: 2,
    );
    final highRate = strings.number(
      estimate.plannedWeeklyHighKg,
      decimalDigits: 2,
    );
    final adherence = strings.number(
      estimate.adherenceAssumption * 100,
      decimalDigits: 0,
    );
    final value = profileGoalTimelineRangeText(
      locale,
      minimumWeeks: minimumWeeks,
      maximumWeeks: maximumWeeks,
      earliestDate: earliest,
      latestDate: latest,
    );
    final direction = estimate.state == GoalTimelineState.losing
        ? profileLocaleText(context, 'loss', 'نزول')
        : profileLocaleText(context, 'gain', 'زيادة');
    final supporting = profileGoalTimelineSupportingText(
      locale,
      direction: direction,
      lowRate: lowRate,
      highRate: highRate,
      adherence: adherence,
    );
    return GoalTimelinePresentation(
      title: title,
      value: value,
      supporting: supporting,
    );
  }
}

class GoalTimelineCard extends StatelessWidget {
  const GoalTimelineCard({super.key, required this.estimate});

  final GoalTimelineEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final copy = GoalTimelinePresentation.forContext(context, estimate);
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const Key('estimated-time-to-goal-field'),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.calendar_month_outlined, color: colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.title,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    copy.value,
                    key: const Key('estimated-time-to-goal-value'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    copy.supporting,
                    key: const Key('estimated-time-to-goal-caveat'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
