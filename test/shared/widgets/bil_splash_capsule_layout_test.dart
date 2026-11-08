import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_splash_capsule_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _capture = Key('capsule-layout-capture');

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final rtl in [false, true]) {
    for (final dark in [false, true]) {
      for (final reduced in [false, true]) {
        testWidgets(
          'capsule compact, wide and intrinsic layout rtl=$rtl dark=$dark reduced=$reduced',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              tester.view.physicalSize = const Size(390, 844);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final label = rtl ? 'أجهّز ردك…' : 'Preparing your reply…';
              final theme = dark ? ThemeData.dark() : ThemeData.light();
              await tester.pumpWidget(
                MaterialApp(
                  theme: visualEvidenceTheme(
                    theme,
                    fontFamily: rtl ? 'NotoArabicEvidence' : 'RobotoEvidence',
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(disableAnimations: reduced),
                    child: Directionality(
                      textDirection: rtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: RepaintBoundary(
                        key: _capture,
                        child: Scaffold(
                          body: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    for (final size in [16.0, 18.0, 22.0, 24.0])
                                      SizedBox.square(
                                        dimension: size,
                                        child: BilFeatureWelcomeStatus(
                                          key: ValueKey('compact-$size'),
                                          label: label,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const SizedBox(
                                  width: 180,
                                  height: 24,
                                  child: BilFeatureWelcomeStatus(
                                    key: Key('wide'),
                                    label: 'Working on your question…',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                IntrinsicWidth(
                                  child: Row(
                                    children: [
                                      BilFeatureWelcomeStatus(
                                        key: const Key('natural'),
                                        label: label,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        label,
                                        key: const Key('waiting-copy'),
                                      ),
                                    ],
                                  ),
                                ),
                                const AlertDialog(
                                  title: Text('Please wait'),
                                  content: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      BilFeatureWelcomeStatus(
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Loading'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 80));
              for (final size in [16.0, 18.0, 22.0, 24.0]) {
                final status = find.byKey(ValueKey('compact-$size'));
                expect(tester.getSize(status), Size.square(size));
                final capsule = find.descendant(
                  of: status,
                  matching: find.byType(BilSplashCapsuleProgress),
                );
                expect(tester.getSize(capsule), Size(size, 7));
                final node = tester.getSemantics(status).getSemanticsData();
                expect(node.role, ui.SemanticsRole.loadingSpinner);
                expect(node.label, label);
                expect(node.value, isEmpty);
                final tint = tester
                    .widget<BilSplashCapsuleProgress>(capsule)
                    .color;
                final track = Color.alphaBlend(
                  tint.withAlpha(0x38),
                  theme.scaffoldBackgroundColor,
                );
                final fill = Color.alphaBlend(tint.withAlpha(0xA8), track);
                final a = fill.computeLuminance();
                final b = theme.scaffoldBackgroundColor.computeLuminance();
                final contrast =
                    (math.max(a, b) + .05) / (math.min(a, b) + .05);
                expect(contrast, greaterThanOrEqualTo(3));
              }
              final wide = find.descendant(
                of: find.byKey(const Key('wide')),
                matching: find.byType(BilSplashCapsuleProgress),
              );
              expect(tester.getSize(wide), const Size(112, 7));
              expect(
                tester.getSize(find.byKey(const Key('natural'))),
                const Size(24, 24),
              );
              final textRect = tester.getRect(
                find.byKey(const Key('waiting-copy')),
              );
              final statusRect = tester.getRect(
                find.byKey(const Key('natural')),
              );
              expect(
                rtl
                    ? statusRect.left - textRect.right
                    : textRect.left - statusRect.right,
                8,
              );
              final colored = tester
                  .widgetList<BilSplashCapsuleProgress>(
                    find.byType(BilSplashCapsuleProgress),
                  )
                  .where((indicator) => indicator.color == Colors.red);
              expect(colored, hasLength(1));
              expect(tester.takeException(), isNull);
              if (reduced) {
                await tester.pump(const Duration(seconds: 20));
                expect(tester.binding.hasScheduledFrame, isFalse);
              }
              await _captureIfRequested(
                tester,
                'capsule-${rtl ? 'ar' : 'en'}-${dark ? 'dark' : 'light'}-${reduced ? 'static' : 'animated'}',
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              expect(tester.binding.transientCallbackCount, 0);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}

Future<void> _captureIfRequested(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('BIL_DASHBOARD_CAPTURE_DIR');
  if (output.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('No rendered PNG');
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
}
