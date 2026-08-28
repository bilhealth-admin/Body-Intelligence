import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_safety_locale_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_safety_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_taxonomy_locale_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_taxonomy_sheet.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _PreReleaseCommunityRepository extends CommunityRepository {
  _PreReleaseCommunityRepository()
    : super(
        SupabaseClient(
          'https://pre-release.invalid',
          'pre-release-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final Completer<List<Map<String, dynamic>>> connections = Completer();

  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async => [
    {
      'user_id': '22222222-2222-4222-8222-222222222222',
      'display_name': 'BIL QA Partner',
      'avatar_url': null,
      'locale_code': 'en',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() =>
      connections.future;

  @override
  Future<Map<String, dynamic>?> loadActiveContentPolicy({
    required String localeCode,
  }) async => {
    'version': 'qa-community-policy-v1',
    'document_url': 'https://bilhealth.com/community-policy',
  };

  @override
  Future<bool> hasAcceptedContentPolicy(String version) async => false;
}

final _verifiedPremium = SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.premium),
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: true,
  canRestorePurchases: true,
);

Widget _app({required Locale locale, required Widget home}) => ProviderScope(
  overrides: [
    verifiedSubscriptionStateProvider.overrideWithValue(
      AsyncData(_verifiedPremium),
    ),
  ],
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.6)),
      child: child!,
    ),
    home: home,
  ),
);

void main() {
  test(
    'community copy preserves every canonical locale and script variant',
    () {
      const english = 'Community profile';
      const arabic = 'ملف المجتمع';
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        final value = communityTextForLanguage(tag, english, arabic);
        expect(value.trim(), isNotEmpty, reason: tag);
        if (tag != 'en') expect(value, isNot(english), reason: tag);
      }
    },
  );

  test(
    'all long Community Safety copy is native in every supported locale',
    () {
      expect(communitySafetyLocaleCopy.length, 20);
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        for (final english in communitySafetyEnglishKeys) {
          final value = communityTextForLanguage(tag, english, 'نص أمان عربي');
          expect(value.trim(), isNotEmpty, reason: '$tag: $english');
          if (tag != 'en') {
            expect(value, isNot(english), reason: '$tag: $english');
          }
        }
      }
      for (final entry in communitySafetyLocaleCopy.entries) {
        expect(
          entry.value.length,
          communitySafetyEnglishKeys.length,
          reason: entry.key,
        );
        expect(entry.value.every((value) => value.trim().isNotEmpty), isTrue);
      }
    },
  );

  test('compact Community taxonomy closes all remaining twenty locales', () {
    expect(communityTaxonomyLocaleCopy.length, 20);
    for (final entry in communityTaxonomyLocaleCopy.entries) {
      expect(
        entry.value.keys.toSet(),
        communityTaxonomyCompactKeys,
        reason: entry.key,
      );
      expect(
        entry.value.values.every((value) => value.trim().isNotEmpty),
        isTrue,
        reason: entry.key,
      );
    }
  });

  testWidgets('Community taxonomy survives 25 locales at 160 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        _app(
          locale: locale,
          home: Scaffold(body: CommunityTaxonomySheet(onSelectTag: (_) {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(CommunityTaxonomySheet),
        findsOneWidget,
        reason: locale.toLanguageTag(),
      );
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
    }
  });

  testWidgets('full Community Safety copy survives RTL and 160 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        _app(
          locale: locale,
          home: CommunitySafetyPage(
            repository: _PreReleaseCommunityRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(CommunitySafetyPage),
        findsOneWidget,
        reason: locale.toLanguageTag(),
      );
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
    }
  });

  testWidgets('new-message recipient stays below the app bar in all locales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in AppLocalizations.supportedLocales) {
      final repository = _PreReleaseCommunityRepository();
      await tester.pumpWidget(
        _app(
          locale: locale,
          home: NewCommunityMessagePage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(const Key('community-message-recipient-search'));
      expect(field, findsOneWidget, reason: locale.toLanguageTag());
      final appBar = find.byType(AppBar);
      expect(
        tester.getTopLeft(field).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(appBar).dy),
        reason: locale.toLanguageTag(),
      );
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
    }
  });

  testWidgets('friends loading state is labelled instead of a bare spinner', (
    tester,
  ) async {
    final repository = _PreReleaseCommunityRepository();
    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        home: CommunityConnectionsPage(repository: repository),
      ),
    );
    await tester.pump();

    expect(find.text('Loading...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
