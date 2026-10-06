import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/shared/widgets/bil_reference_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual_closure/visual_evidence_font.dart';

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _mount(
  WidgetTester tester, {
  required double width,
  required Locale locale,
  required Brightness brightness,
  required double scale,
  GlobalKey? captureKey,
  ValueChanged<int>? onSelected,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: visualEvidenceTheme(
        ThemeData(brightness: brightness),
        fontFamily: locale.languageCode == 'ar'
            ? 'NotoArabicEvidence'
            : 'RobotoEvidence',
      ),
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: RepaintBoundary(
          key: captureKey,
          child: BilReferenceBottomBar(
            selected: 1,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name,
  Map<String, Object> geometry,
) async {
  final directory = Platform.environment['BIL_NAVIGATION_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    await Directory(directory).create(recursive: true);
    final bitmap = await boundary.toImage(pixelRatio: 2);
    try {
      final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      await File(
        '$directory/$name.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(geometry));
    } finally {
      bitmap.dispose();
    }
  });
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final width in [320.0, 390.0, 414.0]) {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          final name =
              'dock_${width.toInt()}_${locale.languageCode}_${brightness.name}_$scale';
          testWidgets(
            'reference geometry, baseline, theme and real hit regions $name',
            (tester) async {
              final semantics = tester.ensureSemantics();
              try {
                final captureKey = GlobalKey();
                final tapped = <int>[];
                await _mount(
                  tester,
                  width: width,
                  locale: locale,
                  brightness: brightness,
                  scale: scale,
                  captureKey: captureKey,
                  onSelected: tapped.add,
                );
                final navigation = tester.getRect(
                  find.byKey(const Key('bil-reference-navigation')),
                );
                final surface = tester.getRect(
                  find.byKey(const Key('bil-reference-nav-surface')),
                );
                final circle = tester.getRect(
                  find.byKey(const Key('bil-reference-nav-circle')),
                );
                // Measurements from AI_COACH_APPROVED.png, SHA256 07f25ba0…ce63d0:
                // inner dock width478px, surface79px, raised circle48px/rise6px.
                final factor = width / 478;
                expect(circle.width, closeTo(48 * factor, .15));
                expect(circle.height, closeTo(circle.width, .01));
                expect(surface.top - circle.top, closeTo(6 * factor, .15));
                expect(surface.height, greaterThanOrEqualTo(79 * factor - .1));
                if (scale == 1 && locale.languageCode == 'en') {
                  expect(surface.height, closeTo(79 * factor, .25));
                }

                final baseline = <double>[];
                final centres = <double>[];
                for (var index = 0; index < 5; index++) {
                  final action = find.byKey(Key('bil-reference-nav-$index'));
                  final bounds = tester.getRect(action);
                  expect(bounds.width, greaterThanOrEqualTo(48));
                  expect(bounds.height, greaterThanOrEqualTo(48));
                  expect(navigation.contains(bounds.center), isTrue);
                  final label = find.byKey(
                    Key('bil-reference-nav-label-$index'),
                  );
                  final paragraph = tester.renderObject<RenderParagraph>(label);
                  baseline.add(
                    tester.getTopLeft(label).dy +
                        paragraph.getDryBaseline(
                          paragraph.constraints,
                          TextBaseline.alphabetic,
                        )!,
                  );
                  centres.add(tester.getCenter(label).dx);
                  await tester.tap(action);
                  await tester.pump();
                }
                expect(tapped, [0, 1, 2, 3, 4]);
                await tester.pumpAndSettle();
                expect(
                  baseline.reduce((a, b) => a > b ? a : b) -
                      baseline.reduce((a, b) => a < b ? a : b),
                  lessThan(.1),
                );
                final ordered = centres.toList()..sort();
                expect(
                  centres,
                  locale.languageCode == 'ar'
                      ? ordered.reversed.toList()
                      : ordered,
                );
                // Measured optical anchors, not equal Expanded slots.
                const referenceCentres = [55.5, 134.0, 233.5, 339.0, 429.0];
                for (var index = 0; index < 5; index++) {
                  final ltr = scale > 1.3
                      ? (index + .5) / 5 * width
                      : referenceCentres[index] / 478 * width;
                  expect(
                    centres[index],
                    closeTo(
                      locale.languageCode == 'ar' ? width - ltr : ltr,
                      .1,
                    ),
                  );
                }
                final decoration =
                    tester
                            .widget<DecoratedBox>(
                              find.byKey(
                                const Key('bil-reference-nav-surface'),
                              ),
                            )
                            .decoration
                        as BoxDecoration;
                expect(
                  decoration.gradient!.colors.first,
                  brightness == Brightness.dark
                      ? const Color(0xFF121B28)
                      : Colors.white,
                );
                final selected = find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.button == true &&
                      widget.properties.selected == true,
                );
                expect(selected, findsOneWidget);
                expect(tester.takeException(), isNull);
                await _capture(tester, captureKey, name, {
                  'locale': locale.toLanguageTag(),
                  'brightness': brightness.name,
                  'viewport_width_dp': width,
                  'text_scale': scale,
                  'surface_height_dp': surface.height,
                  'circle_diameter_dp': circle.width,
                  'circle_rise_dp': surface.top - circle.top,
                  'label_baselines_dp': baseline
                      .map((value) => value - navigation.top)
                      .toList(),
                  'label_centres_dp': centres,
                  'render_kind': 'actual Flutter shared component',
                  'reference_parity_claimed': false,
                });
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'all five labels remain complete at 200% in ${locale.toLanguageTag()}',
      (tester) async {
        await _mount(
          tester,
          width: 320,
          locale: locale,
          brightness: Brightness.dark,
          scale: 2,
        );
        for (var index = 0; index < 5; index++) {
          final text = tester.widget<Text>(
            find.byKey(Key('bil-reference-nav-label-$index')),
          );
          expect(text.maxLines, isNull);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
          final label = tester.getRect(
            find.byKey(Key('bil-reference-nav-label-$index')),
          );
          final action = tester.getRect(
            find.byKey(Key('bil-reference-nav-$index')),
          );
          expect(label.left, greaterThanOrEqualTo(action.left));
          expect(label.right, lessThanOrEqualTo(action.right));
          expect(label.bottom, lessThanOrEqualTo(action.bottom));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
