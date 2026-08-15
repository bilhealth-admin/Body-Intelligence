import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/presentation/meal_image_guide_page.dart';
import 'package:body_intelligence_log/features/nutrition/providers/meal_vision_usage_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_usage_contract.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'usage contract exposes truthful used reserved and remaining values',
    () {
      final usage = MealVisionUsage.fromJson(const {
        'limit': 100,
        'used': 23,
        'reserved': 1,
        'remaining': 76,
        'period_start': '2026-08-01',
      });
      expect(usage.limit, 100);
      expect(usage.exhausted, isFalse);
      expect(
        () => MealVisionUsage.fromJson(const {
          'limit': 100,
          'used': 23,
          'reserved': 1,
          'remaining': 77,
        }),
        throwsFormatException,
      );
    },
  );

  test('combines Coach weekly allowance and paid Boost balance', () {
    final usage = MealVisionUsage.fromAiUsageStatus(const {
      'plan': 'ai_coach',
      'week_start': '2026-08-10',
      'capabilities': {
        'vision': {
          'weekly_limit': 25,
          'weekly_used': 4,
          'weekly_reserved': 1,
          'weekly_remaining': 20,
          'paid_granted': 50,
          'paid_used': 3,
          'paid_reserved': 2,
          'paid_remaining': 45,
        },
      },
    });

    expect(usage.limit, 75);
    expect(usage.used, 7);
    expect(usage.reserved, 3);
    expect(usage.remaining, 65);
    expect(usage.periodStart, DateTime(2026, 8, 10));
  });

  test(
    'migration is atomic, idempotent, metered, RLS protected and fail closed',
    () {
      final sql = File(
        'supabase/migrations/202608100003_bil_meal_vision_quota.sql',
      ).readAsStringSync();
      expect(sql, contains("values ('free', 0), ('pro', 100), ('plus', 100)"));
      // Legacy migration coverage only. Runtime allowance now comes from
      // bil_get_ai_usage_status (standalone Coach weekly + paid Boost).
      expect(sql, contains('for update'));
      expect(sql, contains('vision_quota_not_configured'));
      expect(sql, contains('vision_quota_exhausted'));
      expect(sql, contains('idempotency_payload_mismatch'));
      expect(sql, contains('duplicate_image'));
      expect(sql, contains("state in ('reserved','succeeded','refunded')"));
      expect(sql, contains('provider text'));
      expect(sql, contains('latency_ms integer'));
      expect(sql, contains('input_tokens integer'));
      expect(sql, contains('output_tokens integer'));
      expect(sql, contains('cost_usd numeric'));
      expect(sql, contains('enable row level security'));
      expect(sql, contains('owner_id = (select auth.uid())'));
    },
  );

  for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
    testWidgets('meal guide exposes truthful quota in $locale', (tester) async {
      const usage = MealVisionUsage(
        limit: 75,
        used: 7,
        reserved: 0,
        remaining: 68,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealVisionUsageProvider.overrideWith(
              (ref) async => const MealVisionUsageSnapshot.available(usage),
            ),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
              Locale('fr'),
              Locale('es'),
              Locale('tr'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MealImageGuidePage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('meal-vision-usage')), findsOneWidget);
      expect(find.textContaining(locale == 'ar' ? '٦٨' : '68'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('meal-image-guide-next')),
            )
            .onPressed,
        isNotNull,
      );
    });
  }

  test('meal guide authored copy resolves across all 25 locales', () {
    const english = <String>[
      'Meal Scan',
      'Choose a meal photo',
      'Suggestions are not nutrition facts. You stay in control and nothing is logged until you confirm it.',
      'Scan your entire meal',
      'Select visible foods',
      'Add anything we missed',
      'Review and log your meal',
      'Nothing is saved until you confirm',
      'Analysis allowance is unavailable right now.',
      'Sign in to check your analysis allowance.',
      'Weekly allowance and AI Boost balance are exhausted.',
    ];
    for (final locale in AppLocalizations.supportedLocales) {
      if (const {'ar', 'en', 'fr', 'es', 'tr'}.contains(locale.languageCode)) {
        continue;
      }
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final key in english) {
        expect(RuntimeCopy.resolve(key, tag), isNotNull, reason: '$key $tag');
      }
    }
  });
}
