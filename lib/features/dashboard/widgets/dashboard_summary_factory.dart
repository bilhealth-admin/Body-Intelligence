import 'package:flutter/material.dart';

import 'dashboard_daily_summary.dart';

typedef DashboardTranslate = String Function(String english, String arabic);

class DashboardSummaryFactory {
  const DashboardSummaryFactory._();

  static Widget build({
    required DashboardTranslate tr,
    required bool arabic,
    required int loggingStreak,
    required bool mealsEmpty,
    required int calories,
    required int protein,
    required int fats,
    required double? fiber,
    required int dailyRequirement,
    required String weight,
    required String weightUnit,
    required String bodyFat,
    required String bodyFatUnit,
    required String fatFreeMass,
  }) => DashboardDailySummarySection(
    title: tr('Daily Summary', 'ملخص اليوم'),
    subtitle: tr(
      'Your recorded nutrition and active daily references.',
      'تغذيتك المسجلة ومراجع يومك النشطة.',
    ),
    badge: loggingStreak >= 2
        ? DashboardStreakBadge(days: loggingStreak, arabic: arabic)
        : null,
    pages: [
      DashboardMetricGridPage(
        metrics: [
          DashboardMetricData(
            Icons.local_fire_department_outlined,
            tr('Calories', 'السعرات'),
            mealsEmpty ? '—' : calories.toString(),
            mealsEmpty ? '' : 'kcal',
            Colors.orange,
          ),
          DashboardMetricData(
            Icons.fitness_center_outlined,
            tr('Protein', 'البروتين'),
            mealsEmpty ? '—' : protein.toString(),
            mealsEmpty ? '' : 'g',
            Colors.green,
          ),
          DashboardMetricData(
            Icons.opacity_outlined,
            tr('Fat', 'الدهون'),
            mealsEmpty ? '—' : fats.toString(),
            mealsEmpty ? '' : 'g',
            Colors.purple,
          ),
          DashboardMetricData(
            Icons.grass_outlined,
            tr('Fiber', 'الألياف'),
            fiber == null ? '—' : fiber.round().toString(),
            fiber == null ? '' : 'g',
            Colors.lightGreen,
          ),
        ],
      ),
      DashboardMetricGridPage(
        metrics: [
          DashboardMetricData(
            Icons.bolt_outlined,
            tr('Daily Requirement', 'الاحتياج اليومي'),
            dailyRequirement.toString(),
            'kcal',
            Colors.deepOrangeAccent,
          ),
          DashboardMetricData(
            Icons.monitor_weight_outlined,
            tr('Weight', 'الوزن'),
            weight,
            weightUnit,
            Colors.blue,
          ),
          DashboardMetricData(
            Icons.donut_large_rounded,
            tr('Body fat', 'نسبة دهون الجسم'),
            bodyFat,
            bodyFatUnit,
            Colors.pinkAccent,
          ),
          DashboardMetricData(
            Icons.accessibility_new_rounded,
            tr('Expected fat-free mass', 'الكتلة الخالية من الدهون المتوقعة'),
            fatFreeMass,
            '',
            Colors.teal,
          ),
        ],
      ),
    ],
  );
}
