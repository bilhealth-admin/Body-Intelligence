import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_learn_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  Widget app() =>
      const MaterialApp(locale: Locale('en'), home: WellnessLearnPage());

  testWidgets('search filters article content and clears to full catalog', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'privacy');
    await tester.pumpAndSettle();
    expect(
      find.text('Your health data stays under your control'),
      findsOneWidget,
    );
    expect(
      find.text('Consistency matters more than a perfect day'),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Educational highlights'), findsOneWidget);
  });

  testWidgets('search has honest empty state', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'no-such-bil-topic');
    await tester.pumpAndSettle();
    expect(find.text('No learning topics match this search.'), findsOneWidget);
  });

  testWidgets('production build hides unavailable community destination', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(find.text('Community discussions'), findsNothing);
  });

  testWidgets('topic controls wrap without clipped horizontal viewport', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(Wrap, skipOffstage: false), findsWidgets);
    expect(find.text('All', skipOffstage: false), findsOneWidget);
    expect(find.text('Privacy', skipOffstage: false), findsOneWidget);
  });

  test('Learn additions have direct copy in every extended locale', () {
    const legitimateIdenticalTranslations = <String, Set<String>>{
      'Privacy': {'it', 'nl'},
    };
    final keys = <String>{
      'Search learning topics',
      'Clear search',
      'No learning topics match this search.',
      'Explore general wellness education in BIL. Its internal basis and limits are shown in every article.',
      'BIL education is general information, not diagnosis or treatment. Its internal basis and limits are shown in every article.',
      'Sharing is unavailable right now.',
      'Share article',
      'Explore more',
      'Nutrition education',
      'Learn about portions and practical food skills',
      'Nutrients',
      'Understand macros, fiber and minerals',
      'Your progress history',
      'Review patterns without comparisons or judgment',
      'Recipe library',
      'Browse recipes with their available ingredients and nutrition details',
      'Wellness tools',
      'Explore goals, sleep, movement and recovery',
      'Community discussions',
      'Discuss food and wellness with clear safety rules',
    };
    final source = File(
      'lib/features/wellness/presentation/wellness_learn_page.dart',
    ).readAsStringSync();
    for (final expression in [
      RegExp(r"wellnessCopy\(\s*context,\s*'((?:\\.|[^'])*)'", multiLine: true),
      RegExp(r"_learnText\(\s*context,\s*'((?:\\.|[^'])*)'", multiLine: true),
    ]) {
      keys.addAll(
        expression.allMatches(source).map((match) => match.group(1)!),
      );
    }
    expect(RuntimeCopy.supported, hasLength(25));
    for (final key in keys) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        expect(
          ExtendedRuntimeCopy.values[key]?.containsKey(locale),
          isTrue,
          reason: 'missing direct $locale/$key',
        );
        expect(ExtendedRuntimeCopy.values[key]![locale]!.trim(), isNotEmpty);
        if (key.length > 3 &&
            !RegExp(r'^[A-Z0-9]+$').hasMatch(key) &&
            !(legitimateIdenticalTranslations[key]?.contains(locale) ??
                false)) {
          expect(
            ExtendedRuntimeCopy.values[key]![locale]!.trim(),
            isNot(key),
            reason: 'English fallback leaked for $locale/$key',
          );
        }
      }
    }
  });
}
