import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/settings/help_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _helpSurface = <String>{
  'Email support@bilhealth.com from your mail app.',
  'Close',
  'About BIL',
  'Private body intelligence for nutrition, movement, recovery and progress. BIL keeps evidence and user control visible.',
  'Frequently Asked Questions',
  'Contact Support',
  'Terms of Service',
  'Troubleshooting',
  'Check connectivity and permissions, restart BIL, then try again. Your saved local data is not removed.',
  'Delete Account',
  'Service Status',
  'Core local logging is available. Connected integrations show their current state and permissions on Apps & Devices.',
  'Help',
  'How does BIL calculate my targets?',
  'BIL uses the profile and goals you saved and shows missing evidence instead of inventing values.',
  'Can I use BIL offline?',
  'Core logging and saved content work offline. Connected services clearly show when a connection is required.',
  'Is BIL medical advice?',
  'No. BIL supports wellness tracking and does not diagnose, prescribe, or replace a qualified clinician.',
};

void main() {
  test('help surface has direct copy for every extended locale', () {
    for (final source in _helpSurface) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = RuntimeCopy.resolve(source, locale);
        expect(value, isNotNull, reason: '$locale: $source');
        expect(value, isNotEmpty, reason: '$locale: $source');
        expect(value, isNot(source), reason: '$locale: $source');
      }
    }
  });

  testWidgets('help cold-renders both Chinese script locales', (tester) async {
    for (final locale in const <Locale>[
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HelpCenterPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
      expect(find.text('Help'), findsNothing);
      expect(find.text('About BIL'), findsNothing);
      expect(find.byType(HelpCenterPage), findsOneWidget);
    }
  });
}
