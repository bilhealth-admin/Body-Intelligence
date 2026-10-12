import 'dart:ui' as ui;

import 'package:body_intelligence_log/shared/widgets/bil_striped_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_closure/closure_surface_capture.dart';

void main() {
  for (final rtl in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'stripe fill preserves quarter value and direction rtl=$rtl dark=$dark',
        (tester) async {
          final boundary = GlobalKey();
          const data = Key('actual-data-progress');
          const track = Color(0xFFEEEEEE);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: boundary,
                      child: const SizedBox(
                        width: 280,
                        height: 12,
                        child: BilStripedProgress(
                          tone: BilProgressTone.calories,
                          child: LinearProgressIndicator(
                            key: data,
                            value: .25,
                            backgroundColor: track,
                            semanticsLabel: 'Recorded progress',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.widget<LinearProgressIndicator>(find.byKey(data)).value,
            .25,
          );
          expect(tester.getSize(find.byKey(data)), const Size(280, 12));
          final handle = tester.ensureSemantics();
          final semantics = tester
              .getSemantics(find.byKey(data))
              .getSemanticsData();
          // Flutter 3.44 exposes numeric progress with an explicit 0..100 range.
          expect(semantics.value, '25');
          expect(semantics.minValue, '0');
          expect(semantics.maxValue, '100');
          expect(semantics.role, ui.SemanticsRole.progressBar);
          handle.dispose();
          final render = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(boundary),
          );
          final bytes = (await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 1);
            try {
              return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
            } finally {
              image.dispose();
            }
          }))!;
          int rgb(int x) {
            final i = (6 * 280 + x) * 4;
            return bytes.getUint8(i) << 16 |
                bytes.getUint8(i + 1) << 8 |
                bytes.getUint8(i + 2);
          }

          final fill = <int>{};
          for (var x = 8; x < 60; x++) {
            fill.add(rgb(rtl ? 279 - x : x));
          }
          expect(
            fill.length,
            greaterThan(1),
            reason: 'Actual pixels contain stripes.',
          );
          expect(
            rgb(rtl ? 40 : 239),
            0xEEEEEE,
            reason: 'No stripe or fill appears beyond the true quarter.',
          );
          expect(
            tester.binding.transientCallbackCount,
            0,
            reason: 'Determinate decoration adds no continuing animation.',
          );
        },
      );
    }
  }

  testWidgets(
    'circular half retains its Material value, room and accessible label',
    (tester) async {
      const key = Key('half-fat');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 82,
                child: BilStripedProgress(
                  tone: BilProgressTone.fat,
                  child: CircularProgressIndicator(
                    key: key,
                    value: .5,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    semanticsLabel: 'Fat consumed toward meal goal',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<CircularProgressIndicator>(find.byKey(key)).value,
        .5,
      );
      expect(tester.getSize(find.byKey(key)), const Size(82, 82));
      final handle = tester.ensureSemantics();
      final data = tester.getSemantics(find.byKey(key)).getSemanticsData();
      expect(data.label, 'Fat consumed toward meal goal');
      expect(data.value, '50');
      expect(data.role, ui.SemanticsRole.progressBar);
      handle.dispose();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('loading retains the native indicator without a data texture', (
    tester,
  ) async {
    const loading = CircularProgressIndicator(key: Key('native-loading'));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BilStripedProgress(child: loading)),
      ),
    );
    final state = tester.element(find.byType(BilStripedProgress));
    expect((state as StatelessElement).widget, isA<BilStripedProgress>());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ClipRRect), findsNothing);
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(find.byKey(const Key('native-loading')))
          .getSemanticsData()
          .role,
      ui.SemanticsRole.loadingSpinner,
    );
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('nutrition tones and explicit safety colors remain distinct', () {
    expect(
      BilProgressPalette.resolve(const Color(0xFF0A8F88), Brightness.light),
      BilProgressPalette.color(BilProgressTone.carbs, Brightness.light),
    );
    expect(
      BilProgressPalette.resolve(const Color(0xFF6F1096), Brightness.light),
      BilProgressPalette.color(BilProgressTone.fat, Brightness.light),
    );
    expect(
      BilProgressPalette.resolve(const Color(0xFFC56A00), Brightness.light),
      BilProgressPalette.color(BilProgressTone.protein, Brightness.light),
    );
    for (final color in [Colors.red, Colors.orange, Colors.green]) {
      expect(BilProgressPalette.resolve(color, Brightness.light), color);
    }
  });

  testWidgets(
    'reference data tones paint from actual linear and circular widgets',
    (tester) async {
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: capture,
                child: SizedBox(
                  width: 360,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final tone in BilProgressTone.values) ...[
                            SizedBox(
                              height: 14,
                              child: BilStripedProgress(
                                tone: tone,
                                child: const LinearProgressIndicator(
                                  value: .75,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              for (final tone in [
                                BilProgressTone.carbs,
                                BilProgressTone.fat,
                                BilProgressTone.protein,
                              ])
                                SizedBox.square(
                                  dimension: 82,
                                  child: BilStripedProgress(
                                    tone: tone,
                                    child: const CircularProgressIndicator(
                                      value: .5,
                                      strokeWidth: 6,
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await captureClosureSurface(
        tester,
        find.byKey(capture),
        'reference-striped-counters',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
