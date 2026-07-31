import 'package:flutter/material.dart';

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
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Semantics(
      label: arabic ? 'النطاق الزمني للتحليلات' : 'Analytics time range',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<AnalyticsRange>(
          segments: [
            ButtonSegment(
              value: AnalyticsRange.sevenDays,
              label: Text(arabic ? '٧ أيام' : '7 days'),
            ),
            ButtonSegment(
              value: AnalyticsRange.thirtyDays,
              label: Text(arabic ? '٣٠ يومًا' : '30 days'),
            ),
            ButtonSegment(
              value: AnalyticsRange.ninetyDays,
              label: Text(arabic ? '٩٠ يومًا' : '90 days'),
            ),
            ButtonSegment(
              value: AnalyticsRange.allTime,
              label: Text(arabic ? 'الكل' : 'All'),
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
