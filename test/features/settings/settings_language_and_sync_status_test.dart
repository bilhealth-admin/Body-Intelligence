import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_cloud_sync.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/settings/cloud_sync_status_presentation.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _settingsSources = <String>{
  'More',
  'BIL member',
  'View profile',
  'Current',
  'Remaining',
  'Goal',
  'kg',
  'Checking subscription',
  'Retry subscription check',
  'BIL Premium',
  'Premium',
  'Account & profile',
  'My Profile',
  'Profile',
  'App Appearance',
  'Language',
  'Location & local time',
  'Diary & goals',
  'Diary Settings',
  'Goals',
  'Progress',
  'Weekly Report',
  'Challenges',
  'Nutrition',
  'My Meals, Recipes & Foods',
  'Health preferences',
  'AI Coach',
  'AI Coach settings',
  'Intermittent Fasting',
  'Sleep',
  'Recipe Discovery',
  'Workout Routines',
  'Apps & Devices',
  'Steps',
  'Learn',
  'Community',
  'Friends',
  'Messages',
  'Privacy & notifications',
  'Sharing & Privacy',
  'Settings',
  'Exercise calories',
  'My Exercises',
  'Weekly Nutrition Settings',
  'Push Notifications',
  'Logout',
  'Explore Premium',
  'Go Premium',
  'Premium adds advanced insights and customization. Your results still depend on your own data and actions.',
  'Reminders',
  'Review initial setup',
  'Reopen onboarding without deleting your profile or records.',
  'Privacy',
  'Advertising privacy',
  'Help',
  'Sync',
  'Delete account',
};

const _privacySources = <String>{
  ...CloudSyncConsentCopy.sources,
  'Diary sharing',
  'Private',
  'Profile visibility',
  'Allow people to find me',
  'Show my activity to friends',
  'Terms of service',
  'Privacy policy',
  'Trust & support',
  'Manage personalization preferences',
  'Email settings',
  'Facebook settings',
  'Google settings',
  'Change password',
  'Contact support',
  'Export my data',
  'Encrypted cloud sync',
  'Sync profile, weight and water across your devices. Nutrition stays local until supported.',
  'Sign in to manage cloud sync.',
  'Premium is required to turn on cloud sync.',
  'Cloud sync is temporarily unavailable.',
  'Checking cloud sync…',
  'Turn on encrypted cloud sync?',
  'BIL encrypts profile, weight and water before cloud storage. You can turn sync off at any time.',
  'Cancel',
  'Turn on',
  'Cloud sync preference updated.',
  'Could not update cloud sync. Try again.',
  'Sync now',
  'Run a one-time encrypted sync now.',
  'Encrypted cloud sync completed.',
  'Cloud sync could not run. Check Premium, consent, and internet.',
  'Could not sign out. Check your connection and retry.',
  'Sign in to manage community privacy.',
};

const _syncStatusSources = <String>{
  'Latest synchronization',
  'Waiting for first sync',
  'Synchronizing',
  'Unavailable',
};

void main() {
  test('settings and privacy copy is complete for all 25 locales', () {
    expect(AppLocalizations.supportedLocales, hasLength(25));
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final source in _settingsSources) {
        expect(
          ReferenceSettingsCopy.resolve(source, tag),
          isNotNull,
          reason: '$tag must localize Settings "$source"',
        );
      }
      if (!const {'ar', 'en', 'fr', 'es', 'tr'}.contains(locale.languageCode)) {
        for (final source in {..._privacySources, ..._syncStatusSources}) {
          expect(
            RuntimeCopy.resolve(source, tag),
            isNotNull,
            reason: '$tag must localize privacy/sync "$source"',
          );
        }
        for (final source in const {
          'Premium is required to turn on cloud sync.',
          'Cloud sync could not run. Check Premium, consent, and internet.',
        }) {
          expect(
            RuntimeCopy.resolve(source, tag),
            contains('Premium'),
            reason: '$tag must preserve the Premium product name',
          );
        }
      }
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('$tag sync states fit at 160% and keep timestamp LTR', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final status in <CloudManualSyncStatus>[
        const CloudManualSyncStatus(phase: CloudManualSyncPhase.never),
        const CloudManualSyncStatus(phase: CloudManualSyncPhase.syncing),
        const CloudManualSyncStatus(phase: CloudManualSyncPhase.unavailable),
        CloudManualSyncStatus(
          phase: CloudManualSyncPhase.idle,
          lastSuccessfulSyncAt: DateTime.utc(2026, 8, 21, 9, 30),
        ),
      ]) {
        await tester.pumpWidget(_statusApp(locale, status));
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '$tag / ${status.phase}',
        );
        if (status.lastSuccessfulSyncAt != null) {
          final timestamp = find.byKey(
            const Key('cloud-last-successful-sync-value'),
          );
          expect(timestamp, findsOneWidget);
          expect(
            Directionality.of(tester.element(timestamp)),
            TextDirection.ltr,
          );
        }
      }
    });
  }
}

Widget _statusApp(Locale locale, CloudManualSyncStatus status) {
  return MaterialApp(
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
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: SizedBox(width: 320, child: CloudSyncStatusLine(status: status)),
    ),
  );
}
