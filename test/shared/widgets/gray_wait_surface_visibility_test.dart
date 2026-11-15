import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final light = BilFlagshipTheme.light(isArabic: false);
  final dark = BilFlagshipTheme.dark(isArabic: false);
  final surfaces = [
    (
      name: 'white',
      theme: light,
      background: Colors.white,
      requested: Colors.blue,
      expected: const Color(0xFF697178),
    ),
    (
      name: 'dark',
      theme: dark,
      background: const Color(0xFF121212),
      requested: Colors.blue,
      expected: const Color(0xFFBBC4CD),
    ),
    (
      name: 'filled-primary',
      theme: light,
      background: light.colorScheme.primary,
      requested: light.colorScheme.onPrimary,
      expected: const Color(0xFFE5E7EB),
    ),
  ];
  for (final surface in surfaces) {
    for (final reduced in [false, true]) {
      testWidgets('actual grey ticks visible on ${surface.name} reduced=$reduced', (
        tester,
      ) async {
        const capture = Key('real-wait-pixels');
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: surface.theme,
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: capture,
                      child: ColoredBox(
                        color: surface.background,
                        child: BilFeatureWelcomeStatus(
                          color: surface.requested,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 160));
          final segmented = tester.widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          );
          expect(segmented.color, surface.expected);
          expect(segmented.animating, !reduced);
          expect(tester.getSize(find.byKey(capture)), const Size.square(24));
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          Future<List<int>> pixels({bool save = false}) async {
            final result = await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                final directory =
                    Platform.environment['BIL_GRAY_WAIT_EVIDENCE_DIR'];
                if (save && directory != null && directory.isNotEmpty) {
                  final png = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final file = File(
                    '$directory/${surface.name}-${reduced ? 'static' : 'rotating'}.png',
                  );
                  await file.parent.create(recursive: true);
                  await file.writeAsBytes(png!.buffer.asUint8List());
                }
                return bytes!.buffer.asUint8List().toList();
              } finally {
                image.dispose();
              }
            });
            return result!;
          }

          final first = await pixels(save: true);
          await tester.pump(const Duration(milliseconds: 320));
          final second = await pixels();
          final backgroundLuminance = surface.background.computeLuminance();
          var maximumContrast = 1.0;
          var changed = 0;
          for (var offset = 0; offset < first.length; offset += 4) {
            final pixel = Color.fromARGB(
              first[offset + 3],
              first[offset],
              first[offset + 1],
              first[offset + 2],
            );
            final luminance = pixel.computeLuminance();
            final contrast =
                (math.max(backgroundLuminance, luminance) + .05) /
                (math.min(backgroundLuminance, luminance) + .05);
            maximumContrast = math.max(maximumContrast, contrast);
            if (first[offset] != second[offset] ||
                first[offset + 1] != second[offset + 1] ||
                first[offset + 2] != second[offset + 2] ||
                first[offset + 3] != second[offset + 3]) {
              changed++;
            }
          }
          // Measure the composited ticks, including Cupertino's native alpha.
          // This is visible-paint evidence, not a WCAG contrast certification.
          expect(maximumContrast, greaterThan(2));
          expect(changed, reduced ? 0 : greaterThan(0));
          expect(tester.takeException(), isNull);
          final directory = Platform.environment['BIL_GRAY_WAIT_EVIDENCE_DIR'];
          if (directory != null && directory.isNotEmpty) {
            final receipt = File(
              '$directory/${surface.name}-${reduced ? 'static' : 'rotating'}.json',
            );
            receipt.writeAsStringSync(
              jsonEncode({
                'surface': surface.name,
                'reducedMotion': reduced,
                'observedMaximumTickContrast': maximumContrast,
                'changedRgbaPixelCount': changed,
                'indicatorColorArgb': segmented.color!.toARGB32(),
                'backgroundColorArgb': surface.background.toARGB32(),
                'scope':
                    'actual production widget host RGBA; no native-device claim',
              }),
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });
    }
  }
}
