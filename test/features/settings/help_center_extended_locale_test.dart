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
  test('Urdu medical disclaimer retains all three safety limitations', () {
    const source =
        'No. BIL supports wellness tracking and does not diagnose, prescribe, or replace a qualified clinician.';
    expect(
      RuntimeCopy.resolve(source, 'ur'),
      'نہیں۔ BIL صحت و تندرستی کی نگرانی میں مدد کرتا ہے۔ یہ بیماری کی تشخیص نہیں کرتا، علاج تجویز نہیں کرتا اور کسی مستند معالج کا متبادل نہیں ہے۔',
    );
  });

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

  testWidgets('help rows stay text-first while all destinations remain actionable',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const HelpCenterPage(),
        ),
      );
      await tester.pumpAndSettle();

      for (final item in const [
        (id: 'about', title: 'About BIL'),
        (id: 'faq', title: 'Frequently Asked Questions'),
        (id: 'contact-support', title: 'Contact Support'),
        (id: 'terms', title: 'Terms of Service'),
        (id: 'troubleshooting', title: 'Troubleshooting'),
        (id: 'delete-account', title: 'Delete Account'),
        (id: 'service-status', title: 'Service Status'),
      ]) {
        final label = find.text(item.title);
        expect(label, findsOneWidget, reason: '${platform.name}:${item.id}');
        final tileFinder = find.ancestor(
          of: label,
          matching: find.byType(ListTile),
        );
        expect(tileFinder, findsOneWidget);
        final tile = tester.widget<ListTile>(tileFinder);
        expect(tile.onTap, isNotNull, reason: item.id);
        expect(tile.leading, isNull, reason: 'No decorative leading icon');
        expect(tile.minTileHeight, greaterThanOrEqualTo(48));
        expect(tile.trailing, isA<Icon>());
        expect((tile.trailing! as Icon).size, 16);
        expect(
          find.byKey(Key('help-center-icon-${item.id}')),
          findsNothing,
        );
      }

      await tester.tap(find.text('About BIL'));
      await tester.pumpAndSettle();
      expect(find.text('Body Intelligence Log™'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: platform.name);
    }
  });

}
