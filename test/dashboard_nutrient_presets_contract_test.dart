import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard nutrient presets use the evidence-backed reference nutrients',
    () {
      final phoneSource = File(
        'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
      ).readAsStringSync();
      final cardsStart = phoneSource.indexOf(
        'final overviewCards = <Widget>[];',
      );
      final cardsEnd = phoneSource.indexOf('return Column(', cardsStart);
      expect(cardsStart, greaterThanOrEqualTo(0));
      expect(cardsEnd, greaterThan(cardsStart));
      final cardAssembly = phoneSource.substring(cardsStart, cardsEnd);
      final componentSource = [
        'lib/features/dashboard/widgets/dashboard_reference_phone_components.dart',
        'lib/features/dashboard/widgets/dashboard_reference_goal_components.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(cardAssembly, contains("tr('Heart Healthy'"));
      expect(cardAssembly, contains("tr('Potassium'"));
      expect(cardAssembly, contains("tr('Sodium'"));
      expect(cardAssembly, contains("tr('Fiber'"));
      expect(cardAssembly, isNot(contains("tr('Carb Conscious'")));
      expect(cardAssembly, contains('/analytics/nutrition?tab=nutrients'));
      expect(cardAssembly, contains('_CircularNutrientCard('));
      expect(phoneSource, contains('_OverviewCardsCarousel('));
      expect(phoneSource, contains('cards: overviewCards'));
      expect(cardAssembly, contains('PremiumDashboardCardLock('));
      expect(cardAssembly, contains('locked: !premiumUnlocked'));
      expect(phoneSource, isNot(contains('_ReferenceStatusCard(')));
      expect(
        componentSource,
        contains('class _CircularNutrientCard extends StatelessWidget'),
      );
      expect(
        componentSource,
        contains('class _OverviewCardsCarousel extends StatefulWidget'),
      );
    },
  );

  test('saved diary nutrient dashboard choice is consumed by Today', () {
    final provider = File(
      'lib/features/dashboard/providers/dashboard_preferences_provider.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(provider, contains("watch('diary.nutrientDashboard')"));
    expect(grid, contains('dashboardNutrientDashboardProvider'));
    expect(grid, contains('nutrientDashboardPreset:'));
  });
}
