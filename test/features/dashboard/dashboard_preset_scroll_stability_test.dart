import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final failSave in [false, true]) {
      testWidgets('$locale: Low Carb stays in place during and after '
          '${failSave ? 'failed' : 'successful'} save', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _DeferredPresetRepository(database, failSave);
        await repository.set('dashboard.preset', 'calorie');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesRepositoryProvider.overrideWithValue(repository),
              verifiedSubscriptionStateProvider.overrideWithValue(
                AsyncData(
                  SubscriptionState(
                    plan: CommercePlan.premium,
                    entitlements: const {
                      CommerceEntitlement.advancedIntelligence,
                    },
                    authority: EntitlementAuthority.verifiedServer,
                    isPurchasable: true,
                    canRestorePurchases: true,
                  ),
                ),
              ),
              for (final section in DashboardSectionIds.all)
                dashboardSectionVisibleProvider(
                  section,
                ).overrideWith((_) => Stream.value(true)),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const DashboardPreferencesPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final carousel = find.byKey(const Key('dashboard-preset-carousel'));
        final scroll = find.descendant(
          of: carousel,
          matching: find.byType(Scrollable),
        );
        final lowCarb = find.byKey(const Key('dashboard-preset-low_carb'));
        await tester.scrollUntilVisible(lowCarb, 280, scrollable: scroll);
        await tester.pumpAndSettle();
        final position = tester.state<ScrollableState>(scroll).position;
        final beforeOffset = position.pixels;
        final beforeRect = tester.getRect(lowCarb);
        expect(beforeOffset, greaterThan(500));
        await tester.tap(lowCarb);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(carousel, findsOneWidget);
        expect(tester.state<ScrollableState>(scroll).position, same(position));
        expect(position.pixels, closeTo(beforeOffset, .1));
        expect(tester.getRect(lowCarb), beforeRect);
        expect(repository.presetSubscriptions, 1);

        repository.release.complete();
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(beforeOffset, .1));
        expect(tester.getRect(lowCarb), beforeRect);
        expect(repository.presetSubscriptions, 1);
        expect(
          await repository.get('dashboard.preset'),
          failSave ? 'calorie' : 'low_carb',
        );
        expect(
          find.descendant(
            of: lowCarb,
            matching: find.byIcon(Icons.check_rounded),
          ),
          failSave ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}

class _DeferredPresetRepository extends PreferencesRepository {
  _DeferredPresetRepository(super.database, this.failSave);
  final bool failSave;
  final release = Completer<void>();
  int presetSubscriptions = 0;

  @override
  Stream<String?> watch(String key) {
    if (key == 'dashboard.preset') presetSubscriptions++;
    return super.watch(key);
  }

  @override
  Future<void> setMany(Map<String, String> values) async {
    await release.future;
    if (failSave) throw StateError('save failed');
    await super.setMany(values);
  }
}
