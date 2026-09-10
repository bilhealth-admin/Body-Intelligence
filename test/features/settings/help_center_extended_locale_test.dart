import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:body_intelligence_log/features/settings/help_center_page.dart';
import 'package:flutter/cupertino.dart';
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

  testWidgets('help rows render functional semantic mappings per platform', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final expected =
        <
          ({
            String id,
            String title,
            BilSemanticIconKind kind,
            IconData? androidOverride,
            IconData? appleOverride,
          })
        >[
          (
            id: 'about',
            title: 'About BIL',
            kind: BilSemanticIconKind.support,
            androidOverride: Icons.info_outline_rounded,
            appleOverride: CupertinoIcons.info_circle,
          ),
          (
            id: 'faq',
            title: 'Frequently Asked Questions',
            kind: BilSemanticIconKind.support,
            androidOverride: Icons.quiz_outlined,
            appleOverride: CupertinoIcons.question_circle,
          ),
          (
            id: 'contact-support',
            title: 'Contact Support',
            kind: BilSemanticIconKind.support,
            androidOverride: null,
            appleOverride: null,
          ),
          (
            id: 'terms',
            title: 'Terms of Service',
            kind: BilSemanticIconKind.legal,
            androidOverride: null,
            appleOverride: null,
          ),
          (
            id: 'troubleshooting',
            title: 'Troubleshooting',
            kind: BilSemanticIconKind.preferences,
            androidOverride: Icons.build_outlined,
            appleOverride: CupertinoIcons.wrench,
          ),
          (
            id: 'delete-account',
            title: 'Delete Account',
            kind: BilSemanticIconKind.accountDeletion,
            androidOverride: null,
            appleOverride: null,
          ),
          (
            id: 'service-status',
            title: 'Service Status',
            kind: BilSemanticIconKind.health,
            androidOverride: Icons.monitor_heart_outlined,
            appleOverride: CupertinoIcons.waveform_path_ecg,
          ),
        ];

    for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const HelpCenterPage(),
        ),
      );
      await tester.pumpAndSettle();

      for (final item in expected) {
        expect(find.text(item.title), findsOneWidget);
        final badgeFinder = find.byKey(Key('help-center-icon-${item.id}'));
        expect(badgeFinder, findsOneWidget);

        final badge = tester.widget<BilSemanticIconBadge>(badgeFinder);
        expect(badge.kind, item.kind);
        final spec = BilSemanticIcons.spec(item.kind);
        final expectedIcon = switch (platform) {
          TargetPlatform.iOS => item.appleOverride ?? spec.appleIcon,
          _ => item.androidOverride ?? spec.icon,
        };
        final icon = tester.widget<Icon>(
          find.descendant(of: badgeFinder, matching: find.byType(Icon)),
        );
        expect(icon.icon, expectedIcon, reason: '${platform.name}:${item.id}');
        expect(
          icon.color,
          spec.onAccent(Brightness.light),
          reason: '${platform.name}:${item.id}:accent',
        );

        final container = tester.widget<Container>(
          find.descendant(of: badgeFinder, matching: find.byType(Container)),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(
          (decoration.gradient! as LinearGradient).colors,
          [
            Color.lerp(spec.accent(Brightness.light), Colors.white, .18)!,
            spec.accent(Brightness.light),
          ],
          reason: '${platform.name}:${item.id}:container',
        );
      }
      expect(tester.takeException(), isNull, reason: platform.name);
    }
  });
}
