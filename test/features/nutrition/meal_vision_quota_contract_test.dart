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

  test('legacy quota display can parse shared Coach and Boost balances', () {
    final usage = MealVisionUsage.fromAiUsageStatus(const {
      'plan': 'ai_coach',
      'week_start': '2026-08-10',
      'credits': {
        'unit': 'BIL AI Token',
        'billing_scope': 'shared',
        'weekly_limit': 5000,
        'weekly_used': 800,
        'weekly_reserved': 100,
        'weekly_remaining': 4100,
        'paid_granted': 5000,
        'paid_used': 300,
        'paid_reserved': 200,
        'paid_remaining': 4500,
      },
    });

    expect(usage.limit, 10000);
    expect(usage.used, 1100);
    expect(usage.reserved, 300);
    expect(usage.remaining, 8600);
    expect(usage.periodStart, DateTime(2026, 8, 10));
  });

  test('production meal Vision reservation uses paid Boost only', () {
    final sql = File(
      'supabase/migrations/'
      '20260821174122_require_paid_boost_for_meal_vision.sql',
    ).readAsStringSync();
    final client = File(
      'lib/features/commerce/providers/commerce_providers.dart',
    ).readAsStringSync();
    expect(sql, contains('bil_reserve_paid_ai_vision_usage'));
    expect(sql, contains("raise exception 'ai_boost_required'"));
    expect(sql, contains("'billing_source','paid_boost'"));
    expect(sql, contains('credit_weekly_debit, credit_paid_debit'));
    expect(sql, contains("0, v_credit_reserve, 'usd-1e-4-v1'"));
    expect(
      sql,
      isNot(contains("bil_reserve_ai_usage(p_owner_id,p_request_id,'vision'")),
    );
    expect(client, contains('final aiBoostVisionAccessProvider'));
    expect(client, contains('paidRemaining >= 100'));
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
