import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile summary uses real nullable providers, never personal fixtures',
    () {
      final source = File(
        'lib/features/profile/profile_summary_page.dart',
      ).readAsStringSync();
      expect(source, contains('profileMemberSinceProvider'));
      expect(source, contains('profileFriendsCountProvider'));
      expect(source, contains('verifiedSubscriptionStateProvider'));
      expect(source, isNot(contains('ref.watch(subscriptionStateProvider)')));
      expect(source, contains('friends?.toString()'));
      expect(source, contains('progress?.toStringAsFixed(1)'));
      expect(source, contains('goal?.createdAt'));
      expect(source, contains('weightsState.isLoading'));
      expect(source, isNot(contains("_Metric(value: '0'")));
      expect(source, isNot(contains("_copy(context, 'Today')")));
      expect(source, isNot(contains('Kademcom')));
    },
  );

  test('profile summary product source has no replacement character', () {
    final source = File(
      'lib/features/profile/profile_summary_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('\uFFFD')));
    for (final marker in ['Ã', 'Â', 'â', 'Ø', 'Ù']) {
      expect(source, isNot(contains(marker)));
    }
  });

  test(
    'profile summary contracts cover auth, community and entitlement states',
    () {
      final source = File(
        'lib/features/profile/profile_summary_page.dart',
      ).readAsStringSync();
      expect(source, contains('currentUser?.createdAt'));
      expect(source, contains('if (memberSince != null || profile != null)'));
      expect(source, contains('loadFriendshipsWithProfiles'));
      expect(source, contains("row['status'] == 'accepted'"));
      expect(source, contains('value.plan == CommercePlan.free'));
      expect(source, contains('Retry subscription check'));
      expect(source, contains('Expanded('));
    },
  );

  test('profile surface remains registered for all 25 locales', () {
    expect(AppLocalizations.supportedLocales.length, 25);
    expect(
      AppLocalizations.supportedLocales
          .map((e) => e.toLanguageTag())
          .toSet()
          .length,
      25,
    );
    const keys = [
      'BIL member',
      'Member since',
      'Weight lost',
      'Weight gained',
      'Weight change',
      'Friends',
      'Go Premium',
      'Edit Profile',
      'kg',
      'Profile data could not be loaded.',
      'Retry',
    ];
    for (final locale in AppLocalizations.supportedLocales) {
      if (const {'ar', 'en', 'fr', 'es', 'tr'}.contains(locale.languageCode)) {
        continue;
      }
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final key in keys) {
        expect(
          RuntimeCopy.resolve(key, tag),
          isNotNull,
          reason: '$key must resolve for $tag',
        );
      }
    }
  });
}
