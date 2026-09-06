import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const actionKinds = <BilSemanticIconKind>[
    BilSemanticIconKind.foodLog,
    BilSemanticIconKind.barcode,
    BilSemanticIconKind.voice,
    BilSemanticIconKind.mealPhoto,
    BilSemanticIconKind.exercise,
    BilSemanticIconKind.notes,
    BilSemanticIconKind.foodSearch,
  ];

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Brightness brightness,
    required Locale locale,
    Size size = const Size(390, 844),
    String? photoAsset,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: ThemeData.light().copyWith(platform: platform),
        darkTheme: ThemeData.dark().copyWith(platform: platform),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: BilQuickAddSheet(
            photoAsset: photoAsset,
            onFood: () {},
            onBarcode: () {},
            onVoice: () {},
            onPhoto: () {},
            onExercise: () {},
            onNotes: () {},
            onSearch: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('seven Quick Add actions keep distinct accessible colors '
          '${brightness.name} ${locale.languageCode}', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSheet(tester, brightness: brightness, locale: locale);
        final expected = actionKinds
            .map((kind) => BilSemanticIcons.spec(kind).accent(brightness))
            .toList(growable: false);
        final actual = <Color>[];
        for (var index = 0; index < 7; index++) {
          final primary = index < 4;
          final actionIndex = primary ? index : index - 4;
          final action = find.byKey(
            Key(
              'quick-add-${primary ? 'primary' : 'secondary'}-'
              '$actionIndex',
            ),
          );
          final icon = tester.widget<Icon>(
            find.byKey(
              Key(
                'quick-add-${primary ? 'primary' : 'secondary'}-icon-'
                '$actionIndex',
              ),
            ),
          );
          final representedAccent = primary
              ? (tester
                            .widget<Container>(
                              find.byKey(
                                Key('quick-add-primary-badge-$actionIndex'),
                              ),
                            )
                            .decoration!
                        as BoxDecoration)
                    .color!
              : icon.color!;
          actual.add(representedAccent);
          expect(representedAccent, expected[index]);
          if (primary) {
            final spec = BilSemanticIcons.spec(actionKinds[index]);
            expect(icon.color, spec.onAccent(brightness));
            expect(
              _contrastRatio(representedAccent, icon.color!),
              greaterThanOrEqualTo(3),
            );
          }
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          final node = tester.getSemantics(action);
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          expect(node.label.trim(), isNotEmpty);
        }
        expect(actual.toSet(), hasLength(7));

        final surface = Theme.of(
          tester.element(find.byKey(const Key('quick-add-half-sheet'))),
        ).colorScheme.surface;
        for (final color in actual) {
          expect(
            _contrastRatio(color, surface),
            greaterThanOrEqualTo(3),
            reason: '$color must retain graphical contrast on $surface',
          );
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  for (final width in const <double>[320, 390, 430, 800, 1024]) {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'Quick Add identity stays on the physical viewport centre with photo '
        '${width.toInt()} ${locale.languageCode}',
        (tester) async {
          await pumpSheet(
            tester,
            brightness: Brightness.light,
            locale: locale,
            size: Size(width, 844),
            photoAsset:
                'assets/images/onboarding_2026/'
                'bil_onboarding_meal_quick_add_photo_v1.webp',
          );

          final wordmark = find.byKey(const Key('quick-add-wordmark'));
          final photo = find.byKey(const Key('quick-add-photo-hero'));
          expect(wordmark, findsOneWidget);
          expect(photo, findsOneWidget);
          final wordmarkLockup = find
              .ancestor(
                of: find.descendant(
                  of: wordmark,
                  matching: find.text('BODY INTELLIGENCE LOG'),
                ),
                matching: find.byType(Row),
              )
              .first;
          final wordmarkRect = tester.getRect(wordmarkLockup);
          expect(
            (wordmarkRect.center.dx - width / 2).abs(),
            lessThanOrEqualTo(1),
          );
          expect(tester.getRect(photo).left, greaterThan(wordmarkRect.right));
          expect(
            find.ancestor(of: wordmark, matching: find.byType(Container)),
            findsNothing,
          );
          expect(
            find.ancestor(of: wordmark, matching: find.byType(DecoratedBox)),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('reference action glyphs and primary badges remain distinct', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      brightness: Brightness.light,
      locale: const Locale('en'),
    );
    final logFood = tester.widget<Icon>(
      find.byKey(const Key('quick-add-primary-icon-0')),
    );
    final barcode = tester.widget<Icon>(
      find.byKey(const Key('quick-add-primary-icon-1')),
    );
    final searchOrCreate = tester.widget<Icon>(
      find.byKey(const Key('quick-add-secondary-icon-2')),
    );
    expect(logFood.icon, Icons.search_rounded);
    expect(barcode.icon, CupertinoIcons.barcode_viewfinder);
    expect(searchOrCreate.icon, Icons.manage_search_rounded);

    final badgeColors = <Color>[];
    for (var index = 0; index < 4; index++) {
      final badge = tester.widget<Container>(
        find.byKey(Key('quick-add-primary-badge-$index')),
      );
      final decoration = badge.decoration! as BoxDecoration;
      badgeColors.add(decoration.color!);
      expect(decoration.shape, BoxShape.circle);
      expect(
        tester
            .widget<Icon>(find.byKey(Key('quick-add-primary-icon-$index')))
            .color,
        Colors.white,
      );
    }
    expect(badgeColors.toSet(), hasLength(4));
  });

  for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('Quick Add resolves native-appropriate glyphs on $platform', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        brightness: Brightness.light,
        locale: const Locale('en'),
        platform: platform,
      );
      for (var index = 0; index < actionKinds.length; index++) {
        final primary = index < 4;
        final actionIndex = primary ? index : index - 4;
        final icon = tester.widget<Icon>(
          find.byKey(
            Key(
              'quick-add-${primary ? 'primary' : 'secondary'}-icon-'
              '$actionIndex',
            ),
          ),
        );
        expect(
          icon.icon,
          BilSemanticIcons.spec(actionKinds[index]).iconFor(platform),
        );
      }
    });
  }
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + .05) / (darker + .05);
}
