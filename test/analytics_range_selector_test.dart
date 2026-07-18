import 'package:body_intelligence_log/features/analytics/widgets/analytics_range_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('analytics range selector changes the selected evidence window', (
    tester,
  ) async {
    var selected = AnalyticsRange.thirtyDays;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => AnalyticsRangeSelector(
            value: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );

    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    await tester.tap(find.text('90 days'));
    await tester.pump();
    expect(selected, AnalyticsRange.ninetyDays);
  });
}
