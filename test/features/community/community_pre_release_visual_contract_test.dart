import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
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
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => CommunityPolicyState.acceptanceRequired(
    CommunityContentPolicy.fromJson({
      'version': 'qa-community-policy-v1',
      'locale_code': 'en',
      'document_url': 'https://www.bilhealth.com/community-guidelines',
      'effective_at': '2026-09-08T00:00:00Z',
    }),
  );
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

  test('all long Community Safety copy is native in every supported locale', () {
    const safetyStateKeys = <String>{
      'The policy could not be opened. Try again before accepting.',
      'Publishing, comments, and messages stay locked until you review and accept this version.',
      'I have read and agree to this policy version.',
      'Checking Community policy…',
      'Publishing, comments, and messages stay locked until verification finishes.',
      'Community policy could not be verified',
      'Publishing, comments, and messages remain locked. Check your connection and retry.',
      'No active Community policy is available',
      'Publishing, comments, and messages are locked until BIL publishes a production policy. No acceptance has been recorded.',
    };
    const noticeKeys = <String>{
      'Posting and messages stay locked until verification finishes.',
      'Posting and messages remain locked. Check your connection and retry.',
      'Community publishing is unavailable',
      'No active production policy could be verified. No acceptance has been recorded.',
      'Review safety',
      'Review the active Community policy',
      'Posting and messages stay locked until you accept the active version.',
      'Posting and messages stay locked until you accept {version}.',
    };
    final exceptionKeys = <String>{
      for (final failure in CommunityPolicyAccessFailure.values)
        for (final action in CommunityPolicyProtectedAction.values)
          CommunityPolicyAccessException(
            failure: failure,
          ).englishMessage(action),
      for (final failure in CommunityMembershipAccessFailure.values)
        for (final action in CommunityPolicyProtectedAction.values)
          CommunityMembershipAccessException(
            failure: failure,
          ).englishMessage(action),
    };
    final expectedPolicyKeys = <String>{
      ...safetyStateKeys,
      ...exceptionKeys,
      ...noticeKeys,
    };
    final expectedExtendedLocales =
        AppLocalizations.supportedLocales
            .map(BilLocalePolicy.canonicalTag)
            .toSet()
          ..removeAll(const {'ar', 'en', 'fr', 'es', 'tr'});

    expect(exceptionKeys.length, 10);
    expect(
      communitySafetyEnglishKeys.toSet().length,
      communitySafetyEnglishKeys.length,
    );
    expect(communityPolicyEnglishKeys.toSet(), expectedPolicyKeys);
    expect(
      communityPolicyEnglishKeys.toSet().length,
      communityPolicyEnglishKeys.length,
    );
    expect(
      <String>{
        ...communitySafetyEnglishKeys,
        ...communityPolicyEnglishKeys,
      }.length,
      communitySafetyEnglishKeys.length + communityPolicyEnglishKeys.length,
    );
    expect(communitySafetyLocaleCopy.keys.toSet(), expectedExtendedLocales);
    expect(communityPolicyLocaleCopy.keys.toSet(), expectedExtendedLocales);

    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final english in <String>[
        ...communitySafetyEnglishKeys,
        ...communityPolicyEnglishKeys,
      ]) {
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
    for (final entry in communityPolicyLocaleCopy.entries) {
      expect(
        entry.value.length,
        communityPolicyEnglishKeys.length,
        reason: entry.key,
      );
      expect(entry.value.every((value) => value.trim().isNotEmpty), isTrue);
    }
  });

  test(
    'Community policy shared labels and version token close all locales',
    () {
      const sharedLabels = <String>[
        'Not now',
        'Retry',
        'Review policy',
        'Read policy',
        'Check again',
      ];
      const versionTemplate =
          'Posting and messages stay locked until you accept {version}.';
      const arabicVersionTemplate =
          'يبقى النشر والرسائل مقفلين حتى توافق على {version}.';

      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        for (final english in sharedLabels) {
          final value = communityTextForLanguage(tag, english, 'نص عربي أصلي');
          expect(value.trim(), isNotEmpty, reason: '$tag: $english');
          if (tag != 'en') {
            expect(value, isNot(english), reason: '$tag: $english');
          }
        }

        final template = communityTextForLanguage(
          tag,
          versionTemplate,
          arabicVersionTemplate,
        );
        expect(
          RegExp(r'\{version\}').allMatches(template).length,
          1,
          reason: tag,
        );
        final rendered = template.replaceAll(
          '{version}',
          'community-policy-v2',
        );
        expect(rendered, contains('community-policy-v2'), reason: tag);
        expect(rendered, isNot(contains('{version}')), reason: tag);
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
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final repository = _PreReleaseCommunityRepository();
      final localeTag = BilLocalePolicy.canonicalTag(locale);
      await tester.pumpWidget(
        _app(
          locale: locale,
          home: NewCommunityMessagePage(
            key: ValueKey(localeTag),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(const Key('community-message-recipient-search'));
      expect(field, findsOneWidget, reason: localeTag);
      final appBar = find.byType(AppBar);
      expect(
        tester.getTopLeft(field).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(appBar).dy),
        reason: localeTag,
      );
      expect(
        find.byKey(const Key('community-message-send')).hitTestable(),
        findsOneWidget,
        reason: localeTag,
      );

      expect(
        find.byKey(const Key('community-new-message-scroll')),
        findsOneWidget,
        reason: localeTag,
      );
      final outerScroll = find
          .descendant(
            of: find.byKey(const Key('community-new-message-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final subject = find.byKey(const Key('community-message-subject'));
      await tester.scrollUntilVisible(subject, 120, scrollable: outerScroll);
      await tester.ensureVisible(subject);
      await tester.pumpAndSettle();
      expect(subject.hitTestable(), findsOneWidget, reason: localeTag);

      final body = find.byKey(const Key('community-message-body'));
      await tester.scrollUntilVisible(body, 120, scrollable: outerScroll);
      await tester.ensureVisible(body);
      await tester.pumpAndSettle();
      expect(body.hitTestable(), findsOneWidget, reason: localeTag);
      final keyboardTop =
          tester.view.physicalSize.height / tester.view.devicePixelRatio -
          tester.view.viewInsets.bottom;
      expect(
        tester.getTopLeft(body).dy,
        lessThan(keyboardTop),
        reason: localeTag,
      );
      expect(tester.takeException(), isNull, reason: localeTag);
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
