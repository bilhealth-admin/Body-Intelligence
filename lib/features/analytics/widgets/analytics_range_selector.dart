import 'package:flutter/material.dart';

import '../analytics_locale_copy.dart';

enum AnalyticsRange { sevenDays, thirtyDays, ninetyDays, allTime }

extension AnalyticsRangeDays on AnalyticsRange {
  int? get days => switch (this) {
    AnalyticsRange.sevenDays => 7,
    AnalyticsRange.thirtyDays => 30,
    AnalyticsRange.ninetyDays => 90,
    AnalyticsRange.allTime => null,
  };
}

class AnalyticsRangeSelector extends StatelessWidget {
  const AnalyticsRangeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AnalyticsRange value;
  final ValueChanged<AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: analyticsText(
        context,
        'Analytics time range',
        'النطاق الزمني للتحليلات',
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<AnalyticsRange>(
          segments: [
            ButtonSegment(
              value: AnalyticsRange.sevenDays,
              label: Text(analyticsText(context, '7 days', '٧ أيام')),
            ),
            ButtonSegment(
              value: AnalyticsRange.thirtyDays,
              label: Text(analyticsText(context, '30 days', '٣٠ يومًا')),
            ),
            ButtonSegment(
              value: AnalyticsRange.ninetyDays,
              label: Text(analyticsText(context, '90 days', '٩٠ يومًا')),
            ),
            ButtonSegment(
              value: AnalyticsRange.allTime,
              label: Text(analyticsText(context, 'All', 'الكل')),
            ),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ),
    );
  }
}
