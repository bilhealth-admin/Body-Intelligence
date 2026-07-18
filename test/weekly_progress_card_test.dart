import 'package:body_intelligence_log/features/dashboard/widgets/weekly_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('weekly progress shows real start today goal and difference', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeeklyProgressCard(
            start: 80,
            today: 79.4,
            goal: 72,
            unit: 'kg',
          ),
        ),
      ),
    );

    expect(find.text('Weekly progress'), findsOneWidget);
    expect(find.text('Week start'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Difference'), findsOneWidget);
    expect(find.text('-0.6 kg'), findsOneWidget);
  });
}
