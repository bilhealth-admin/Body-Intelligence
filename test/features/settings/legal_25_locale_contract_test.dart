import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:body_intelligence_log/features/community/presentation/community_translation_copy.dart';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/settings/legal_document_page.dart';
import 'package:body_intelligence_log/features/settings/food_search_privacy_disclosure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'food-search processor disclosure covers every supported locale',
    (tester) async {
      String? english;
      for (final tag in RuntimeCopy.supported) {
        final parts = tag.split('-');
        final locale = Locale.fromSubtags(
          languageCode: parts.first,
          scriptCode: parts.length > 1 && parts[1].length == 4
              ? parts[1]
              : null,
          countryCode: parts.length > 1 && parts[1].length == 2
              ? parts[1]
              : null,
        );
        String? text;
        await tester.pumpWidget(
          Localizations(
            locale: locale,
            delegates: GlobalMaterialLocalizations.delegates,
            child: Builder(
              builder: (context) {
                text = foodSearchPrivacyDisclosure(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(text, contains('USDA'), reason: tag);
        expect(text, contains('Google Cloud Translation'), reason: tag);
        if (tag == 'en') english = text;
        if (tag != 'en' && english != null) {
          expect(text, isNot(english), reason: tag);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final language in ['en', 'ar']) {
    testWidgets(
      'privacy renders translation provider disclosure in $language',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const LegalDocumentPage(document: BilLegalDocument.privacy),
          ),
        );
        final context = tester.element(find.byType(LegalDocumentPage));
        final disclosure = cloudTranslationDisclosure(context);
        expect(
          disclosure,
          contains(
            language == 'ar'
                ? 'ترجمة Google السحابية'
                : 'Google Cloud Translation',
          ),
        );
        await tester.scrollUntilVisible(
          find.text(disclosure),
          600,
          maxScrolls: 60,
        );
        expect(find.text(disclosure), findsOneWidget);
        final foodDisclosure = foodSearchPrivacyDisclosure(context);
        await tester.scrollUntilVisible(find.text(foodDisclosure), 400);
        expect(find.text(foodDisclosure), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test('legal and trust copy has direct extended locale entries', () {
    final legal = File(
      'lib/features/settings/legal_document_page.dart',
    ).readAsStringSync();
    final trust = File(
      'lib/features/settings/trust_support_page.dart',
    ).readAsStringSync();
    final keys = <String>{};

    for (final marker in const [
      'const _privacySections =',
      'const _termsSections =',
      'const _healthDisclaimerSections =',
    ]) {
      final start = legal.indexOf(marker);
      final end = legal.indexOf('\n];', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      keys.addAll(
        RegExp(r"'((?:\\.|[^'])*)'", multiLine: true)
            .allMatches(legal.substring(start, end))
            .map((match) => match.group(1)!),
      );
    }
    final englishStart = legal.indexOf("  'en': _LegalPageCopy(");
    final englishEnd = legal.indexOf("\n  'ar':", englishStart);
    keys.addAll(
      RegExp(r"'((?:\\.|[^'])*)'", multiLine: true)
          .allMatches(legal.substring(englishStart, englishEnd))
          .map((match) => match.group(1)!),
    );
    keys.removeAll(const {'en', 'ar', 'fr', 'es', 'tr'});
    final trustStart = trust.indexOf('const _trustSecondary');
    final trustEnd = trust.indexOf('\n};', trustStart);
    keys.addAll(
      RegExp(r"^  '((?:\\.|[^'])*)':", multiLine: true)
          .allMatches(trust.substring(trustStart, trustEnd))
          .map((match) => match.group(1)!),
    );

    expect(RuntimeCopy.supported, hasLength(25));
    for (final key in keys) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = RuntimeCopy.resolve(key, locale)?.trim();
        expect(value, isNotNull, reason: 'missing $locale/$key');
        expect(value, isNotEmpty, reason: 'blank $locale/$key');
        if (!key.contains('@') && !key.contains('BIL Health')) {
          expect(value, isNot(key), reason: 'English fallback $locale/$key');
        }
      }
    }
  });

  test('all legal documents share one auditable policy revision', () {
    expect(bilLegalPolicyId, 'BIL-LEGAL');
    expect(bilLegalPolicyRevision, '2026-10-19');
    expect(bilLegalPublicationStatus, 'PUBLISHED');
    expect(BilLegalDocument.values, hasLength(3));
  });

  test('legal entity is rendered only from immutable metadata', () {
    final source = File(
      'lib/features/settings/legal_document_page.dart',
    ).readAsStringSync();
    expect(source, contains("copy.effective.split(' • ').take(2)"));
    expect(source, contains('\$bilLegalEntity'));
    expect(source, contains("'it': {"));
    expect(source, contains('controlli di segnalazione e blocco'));
  });

  test('authored legal locales preserve document structure and order', () {
    final source = File(
      'lib/features/settings/legal_document_page.dart',
    ).readAsStringSync();

    int tupleCount(String constantName) {
      final start = source.indexOf('const $constantName =');
      final end = source.indexOf('\n];', start);
      expect(start, greaterThanOrEqualTo(0), reason: constantName);
      expect(end, greaterThan(start), reason: constantName);
      return RegExp(
        r"\(\s*'\d+\.",
        multiLine: true,
      ).allMatches(source.substring(start, end)).length;
    }

    List<int> sectionOrdinals(String constantName) {
      final start = source.indexOf('const $constantName =');
      final end = source.indexOf('\n];', start);
      return RegExp(r"\(\s*'(\d+)\.", multiLine: true)
          .allMatches(source.substring(start, end))
          .map((match) => int.parse(match.group(1)!))
          .toList(growable: false);
    }

    for (final document in const [
      '_privacySections',
      '_termsSections',
      '_healthDisclaimerSections',
    ]) {
      final englishCount = tupleCount(document);
      expect(englishCount, greaterThan(0), reason: document);
      final expectedOrder = List<int>.generate(
        englishCount,
        (index) => index + 1,
      );
      expect(sectionOrdinals(document), expectedOrder, reason: document);
      for (final suffix in const ['Ar', 'Fr', 'Es', 'Tr']) {
        expect(
          tupleCount('$document$suffix'),
          englishCount,
          reason: '$document$suffix must match the English revision structure',
        );
        expect(
          sectionOrdinals('$document$suffix'),
          expectedOrder,
          reason: '$document$suffix section order',
        );
      }
    }
  });
}
