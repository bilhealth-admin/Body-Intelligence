import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_tokens.dart';
import 'package:body_intelligence_log/shared/widgets/bil_mobile_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (first > second ? first + .05 : second + .05) /
      (first > second ? second + .05 : first + .05);
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'mobile intro has readable actual ink $language dark=$dark scale=$scale',
          (tester) async {
            final width = scale == 2 ? 320.0 : 390.0;
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 844);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final capture = GlobalKey();
            final arabic = language == 'ar';
            final family = arabic ? 'NotoArabicEvidence' : 'RobotoEvidence';
            final eyebrow = arabic ? 'الأهداف' : 'Goals';
            final title = arabic
                ? 'أهداف السعرات والماكروز'
                : 'Calorie & macro goals';
            final description = arabic
                ? 'راجع التوصية، ثم عدّل فقط ما يناسب خطتك.'
                : 'Review the recommendation, then adjust only what fits your plan.';
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: visualEvidenceTheme(
                  dark
                      ? BilFlagshipTheme.dark(isArabic: arabic)
                      : BilFlagshipTheme.light(isArabic: arabic),
                  fontFamily: family,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(key: capture, child: child),
                ),
                home: Scaffold(
                  body: ListView(
                    children: [
                      BilMobilePageIntro(
                        eyebrow: eyebrow,
                        title: title,
                        description: description,
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final intro = find.byType(BilMobilePageIntro);
            final background = tester
                .widget<Container>(
                  find
                      .descendant(of: intro, matching: find.byType(Container))
                      .first,
                )
                .color!;
            expect(
              background,
              dark
                  ? BilFlagshipTokens.surfaceDark
                  : BilFlagshipTokens.surfaceLight,
            );
            for (final copy in [eyebrow, title, description]) {
              final finder = find.descendant(
                of: intro,
                matching: find.text(copy),
              );
              final paragraph = tester.renderObject<RenderParagraph>(finder);
              final actualInk = paragraph.text.style!.color!;
              expect(
                _contrast(actualInk, background),
                greaterThanOrEqualTo(4.5),
                reason: copy,
              );
              expect(paragraph.didExceedMaxLines, isFalse);
              final rect = tester.getRect(finder);
              expect(rect.left, greaterThanOrEqualTo(20));
              expect(rect.right, lessThanOrEqualTo(width - 20));
              expect(rect.bottom, lessThanOrEqualTo(844));
              expect(finder.hitTestable(), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            final output = Platform.environment['BIL_UI_BATCH_CAPTURE_DIR'];
            if (output != null) {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 2);
                try {
                  final png = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory(output).create(recursive: true);
                  await File(
                    '$output/shared_intro_${language}_${scale}_${dark ? 'dark' : 'light'}.png',
                  ).writeAsBytes(png!.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }
          },
        );
      }
    }
  }
}
