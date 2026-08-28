import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom dashboard exposes and persists the five reference modes', () {
    final source =
        [
              'dashboard_preferences_page.dart',
              'dashboard_preferences_catalog.dart',
              'dashboard_preferences_actions.dart',
            ]
            .map(
              (name) => File(
                'lib/features/dashboard/presentation/$name',
              ).readAsStringSync(),
            )
            .join('\n');

    expect(source, contains("Key('dashboard-preset-\${preset.id}')"));
    for (final id in <String>['calorie', 'macros', 'heart', 'low_carb']) {
      expect(source, contains("id: '$id'"));
    }
    expect(source, contains("Key('dashboard-preset-custom')"));
    expect(source, contains('repository.setMany({'));
    expect(source, contains("'dashboard.preset': preset"));
    expect(source, contains("'dashboard.section.\$section'"));
    expect(source, contains('CommerceEntitlement.advancedIntelligence'));
    expect(source, contains("context.push('/plans')"));
  });
}
