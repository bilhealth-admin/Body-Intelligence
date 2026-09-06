import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('goal rows do not show a premium or lock badge when locked', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('diary-premium-feature-chevron')),
      findsWidgets,
    );
    expect(find.byKey(const Key('diary-premium-feature-state')), findsNothing);
  });

  testWidgets('goal rows remain badge-free when entitlement is active', (
    tester,
  ) async {
    final active = SubscriptionState(
      plan: CommercePlan.pro,
      entitlements: const {CommerceEntitlement.advancedIntelligence},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: true,
      canRestorePurchases: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(active),
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('diary-premium-feature-chevron')),
      findsWidgets,
    );
    expect(find.byKey(const Key('diary-premium-feature-state')), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ReferenceDiarySettingsPage(),
  );
}
