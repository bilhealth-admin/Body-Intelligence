import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('verified Premium never receives a second Premium upsell', (
    tester,
  ) async {
    final premium = SubscriptionState(
      plan: CommercePlan.premium,
      entitlements: PaidPlanCatalog.composedEntitlementsFor(
        CommercePlan.premium,
      ),
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: true,
      canRestorePurchases: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(premium),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ReferenceSettingsHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore Premium'), findsNothing);
    expect(find.text('Go Premium'), findsNothing);
    expect(find.text('Start 7-day free trial'), findsNothing);
  });

  testWidgets(
    'free Settings uses the same Premium identity and action as More',
    (tester) async {
      final free = SubscriptionState(
        plan: CommercePlan.free,
        entitlements: const {},
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: true,
        canRestorePurchases: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(free),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: ReferenceSettingsHomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('BIL Premium'), 400);
      expect(find.text('BIL Premium'), findsOneWidget);
      expect(find.text('Start 7-day free trial'), findsOneWidget);
      expect(find.text('Explore Premium'), findsNothing);
      expect(find.text('Go Premium'), findsNothing);
    },
  );

  test('safety and legal copy describe the current published product', () {
    final safety = File(
      'lib/features/community/presentation/community_safety_page.dart',
    ).readAsStringSync();
    final legal = File(
      'lib/features/settings/legal_document_page.dart',
    ).readAsStringSync();

    expect(safety, isNot(contains('Community is unavailable in this build')));
    expect(legal, contains("bilLegalPublicationStatus = 'PUBLISHED'"));
    expect(legal, contains('Last updated: 22 August 2026'));
    expect(legal, isNot(contains('Effective date pending')));
    expect(legal, isNot(contains('Embedded draft')));
  });

  test('shared account identity is cloud authoritative and offline safe', () {
    final provider = File(
      'lib/features/profile/providers/user_profile_provider.dart',
    ).readAsStringSync();
    final avatar = File(
      'lib/shared/widgets/bil_account_avatar.dart',
    ).readAsStringSync();
    final photoService = File(
      'lib/features/profile/services/profile_photo_service.dart',
    ).readAsStringSync();

    expect(provider, contains("from('bil_public_profiles')"));
    expect(
      provider,
      contains("await preferences.set('displayName', remoteName)"),
    );
    expect(
      provider,
      contains("await preferences.set('profilePhotoPublicUrl', url)"),
    );
    expect(avatar, contains('foregroundImage: foreground'));
    expect(avatar, contains('final background = _backgroundImage'));
    expect(avatar, contains('backgroundImage: background'));
    expect(avatar, contains('onForegroundImageError:'));
    expect(photoService, contains(".select('avatar_url')"));
    expect(photoService, contains('if (updated == null'));
  });
}
