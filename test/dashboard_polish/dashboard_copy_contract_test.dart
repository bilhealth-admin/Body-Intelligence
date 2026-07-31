import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard copy uses the approved flagship section names', () {
    final personalAi = File(
      'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
    ).readAsStringSync();
    final insights = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final dailyPath = File(
      'lib/features/dashboard/widgets/daily_return_card.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final bodyProfile = File(
      'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
    ).readAsStringSync();

    expect(personalAi, contains("tr('Bio Intelligence', 'الذكاء الحيوي')"));
    expect(insights, contains('tr("Today\'s Insights", "رؤى اليوم")'));
    expect(dailyPath, contains("tr('Your Path Today', 'مسارك اليوم')"));
    expect(grid, contains("tr('Daily Summary', 'ملخص اليوم')"));
    expect(bodyProfile, contains("tr('Body Identity', 'هوية الجسم')"));
    expect(grid, contains("tr('Analytics Center', 'مركز التحليلات')"));
  });

  test(
    'retired dashboard section names are absent from active presentation',
    () {
      final files = <String>[
        'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
        'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
        'lib/features/dashboard/widgets/daily_return_card.dart',
        'lib/features/dashboard/widgets/dashboard_grid.dart',
        'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
      ];
      final source = files
          .map((path) => File(path).readAsStringSync())
          .join('\n');

      for (final retired in <String>[
        'الذكاء الصحي الشخصي',
        'أهم رؤى اليوم',
        'تابع يومك',
        'تقدم اليوم',
        'ملف الجسم والخطة',
        "tr('Analytics', 'التحليلات')",
      ]) {
        expect(
          source,
          isNot(contains(retired)),
          reason: 'Retired copy: $retired',
        );
      }
    },
  );
}
