import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_health_evidence.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/core/health_evidence/health_evidence_catalog.dart';
import 'package:body_intelligence_log/features/settings/health_information_sources_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

final _targetSources = HealthEvidenceCatalog.resolve([
  ...HealthEvidenceCatalog.forTopic('nutrition-targets'),
  HealthEvidenceIds.cdcWeightLoss,
  HealthEvidenceIds.weightEnergyApproximation,
]);

String _displayCopy(HealthEvidenceSource source, Locale locale, bool note) {
  final arabic = locale.languageCode == 'ar';
  final directArabic = note
      ? source.arabicMethodologyNote
      : source.arabicShortDescription;
  if (arabic && directArabic != null) return directArabic;
  return HealthEvidenceRuntimeCopy.resolve(
    note ? source.methodologyNote : source.shortDescription,
    BilLocalePolicy.canonicalTag(locale),
  )!;
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final output = Platform.environment['BIL_UI_BATCH_CAPTURE_DIR'];
  if (output == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _assertSourceCopy(
  WidgetTester tester,
  Locale locale, {
  required double width,
  GlobalKey? capture,
  String? capturePrefix,
}) async {
  final vertical = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  for (final source in _targetSources) {
    final card = find.byKey(ValueKey('health-source-${source.id}'));
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: vertical,
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
    for (final note in [false, true]) {
      final expected = _displayCopy(source, locale, note);
      final text = find.descendant(of: card, matching: find.text(expected));
      expect(text, findsOneWidget, reason: '${source.id} note=$note');
      await tester.ensureVisible(text);
      await tester.pumpAndSettle();
      expect(text.hitTestable(), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.textDirection, BilLocalePolicy.directionFor(locale));
      expect(paragraph.didExceedMaxLines, isFalse);
      final rect = tester.getRect(text);
      expect(rect.width, greaterThan(0));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(width));
      if (locale.languageCode != 'en') {
        expect(
          expected,
          isNot(note ? source.methodologyNote : source.shortDescription),
        );
      }
    }
    if (capture != null && capturePrefix != null) {
      await _capture(tester, capture, '${capturePrefix}_${source.id}');
    }
  }
}

Future<GlobalKey> _mount(
  WidgetTester tester,
  Locale locale, {
  double width = 390,
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final key = GlobalKey();
  final family = locale.languageCode == 'ar'
      ? 'NotoArabicEvidence'
      : 'RobotoEvidence';
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: visualEvidenceTheme(
        dark
            ? BilFlagshipTheme.dark(isArabic: locale.languageCode == 'ar')
            : BilFlagshipTheme.light(isArabic: locale.languageCode == 'ar'),
        fontFamily: family,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: key,
          child: visualEvidenceTextSurface(child, fontFamily: family),
        ),
      ),
      home: const HealthInformationSourcesPage(
        initialTopic: 'nutrition-targets',
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

({List<String> messages, VoidCallback restore}) _watchTargetWarnings() {
  final previous = debugPrint;
  final messages = <String>[];
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message?.startsWith('Missing reviewed runtime translation:') == true) {
      messages.add(message!);
      return;
    }
    previous(message, wrapWidth: wrapWidth);
  };
  return (messages: messages, restore: () => debugPrint = previous);
}

void _expectNoTargetWarnings(List<String> messages) {
  final protectedCopy = {
    ...HealthEvidenceRuntimeCopy.sources,
    for (final source in _targetSources) ...[
      if (source.arabicShortDescription != null) source.arabicShortDescription!,
      if (source.arabicMethodologyNote != null) source.arabicMethodologyNote!,
    ],
  };
  // Other catalog topics remain separate scope. These assertions cover every
  // requested nutrition/weight-planning fields and the existing Arabic FDA
  // literals, rather than treating an English publication title as a warning.
  expect(
    messages.where((message) => protectedCopy.any(message.contains)),
    isEmpty,
  );
}

void main() {
  setUpAll(loadVisualEvidenceFont);

  test(
    'nutrition-target descriptions and limitations have exact 25-tag coverage',
    () {
      final expectedSources = {
        for (final source in _targetSources) ...[
          source.shortDescription,
          source.methodologyNote,
        ],
      };
      expect(_targetSources, hasLength(7));
      expect(expectedSources, hasLength(14));
      expect(HealthEvidenceRuntimeCopy.sources.toSet(), expectedSources);
      expect(HealthEvidenceRuntimeCopy.balanced, isTrue);
      expect(
        HealthEvidenceRuntimeCopy.rows.keys.toSet(),
        AppLocalizations.supportedLocales
            .map(BilLocalePolicy.canonicalTag)
            .toSet(),
      );
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        for (final english in expectedSources) {
          final resolved = HealthEvidenceRuntimeCopy.resolve(english, tag);
          expect(resolved, isNotNull, reason: '$tag:$english');
          expect(RuntimeCopy.resolve(english, tag), resolved);
          expect(AppLocalizations(locale).text(english), resolved);
          expect(resolved!.trim(), isNotEmpty);
          expect(resolved, tag == 'en' ? english : isNot(english));
        }
      }
      final fda = HealthEvidenceCatalog.byId(HealthEvidenceIds.fdaDailyValues)!;
      expect(
        HealthEvidenceRuntimeCopy.resolve(fda.shortDescription, 'ar'),
        fda.arabicShortDescription,
      );
      expect(
        HealthEvidenceRuntimeCopy.resolve(fda.methodologyNote, 'ar'),
        fda.arabicMethodologyNote,
      );
      expect(
        HealthEvidenceRuntimeCopy.resolve(
          HealthEvidenceRuntimeCopy.sources[5],
          'pt-BR',
        ),
        isNot(
          HealthEvidenceRuntimeCopy.resolve(
            HealthEvidenceRuntimeCopy.sources[5],
            'pt-PT',
          ),
        ),
      );
      expect(
        HealthEvidenceRuntimeCopy.resolve(
          HealthEvidenceRuntimeCopy.sources[5],
          'zh-Hans',
        ),
        isNot(
          HealthEvidenceRuntimeCopy.resolve(
            HealthEvidenceRuntimeCopy.sources[5],
            'zh-Hant',
          ),
        ),
      );
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets(
      'real nutrition source page renders all fourteen fields for $tag',
      (tester) async {
        final messages = _watchTargetWarnings();
        try {
          final key = await _mount(tester, locale);
          await _assertSourceCopy(
            tester,
            locale,
            width: 390,
            capture: tag == 'ar' || tag == 'en' ? key : null,
            capturePrefix: 'health_sources_${tag}_390_1_light',
          );
          _expectNoTargetWarnings(messages.messages);
          expect(tester.takeException(), isNull);
        } finally {
          // Flutter checks binding invariants before addTearDown callbacks run.
          // Restore the global printer within this callback, even on failure.
          messages.restore();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );
  }

  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'nutrition source copy is readable at 320px 2x $language dark=$dark',
        (tester) async {
          final locale = Locale(language);
          final messages = _watchTargetWarnings();
          try {
            final key = await _mount(
              tester,
              locale,
              width: 320,
              scale: 2,
              dark: dark,
            );
            await _assertSourceCopy(
              tester,
              locale,
              width: 320,
              capture: key,
              capturePrefix:
                  'health_sources_${language}_320_2_${dark ? 'dark' : 'light'}',
            );
            _expectNoTargetWarnings(messages.messages);
            expect(tester.takeException(), isNull);
          } finally {
            messages.restore();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        },
      );
    }
  }
}
