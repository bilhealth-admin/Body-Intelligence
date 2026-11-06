import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_overview_paid_label_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:body_intelligence_log/shared/widgets/bil_navigation_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

enum _Access { free, premium, premiumAiCoach, boost }

final _now = DateTime(2026, 11, 6, 9, 41);

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

Iterable<Rect> _paintedTextRects(WidgetTester tester, Finder finder) sync* {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  final origin = paragraph.localToGlobal(Offset.zero);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  expect(boxes, isNotEmpty, reason: 'The real font must render visible text.');
  for (final box in boxes) {
    yield box.toRect().shift(origin);
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);

  for (final width in [320.0, 390.0]) {
    for (final language in ['ar', 'en']) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          for (final access in _Access.values) {
            final name =
                'overview_${width.toInt()}_${language}_${scale}_${dark ? 'dark' : 'light'}_${access.name}';
            testWidgets('$name keeps crystal clear of every header line', (
              tester,
            ) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(width, 844);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(tester.view.resetPhysicalSize);
              final capture = GlobalKey();
              var exits = 0;
              var chats = 0;
              final plan = switch (access) {
                _Access.premium => CommercePlan.premium,
                _Access.premiumAiCoach => CommercePlan.premiumAiCoach,
                _ => null,
              };
              final useExit = access != _Access.free;
              final family = language == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence';
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    coachOverviewPaidLabelProvider.overrideWithValue(plan),
                    coachOverviewCreditAccessProvider.overrideWithValue(
                      access != _Access.free,
                    ),
                  ],
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    locale: Locale(language),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      ...GlobalMaterialLocalizations.delegates,
                    ],
                    theme: visualEvidenceTheme(
                      dark
                          ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                          : BilFlagshipTheme.light(isArabic: language == 'ar'),
                      fontFamily: family,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: RepaintBoundary(
                        key: capture,
                        child: visualEvidenceTextSurface(
                          child,
                          fontFamily: family,
                        ),
                      ),
                    ),
                    home: CoachReferenceWorkspace(
                      snapshot: CoachContextSnapshot(
                        generatedAt: _now,
                        profile: {
                          'displayName': language == 'ar'
                              ? 'عبد الرحمن Alexander الطويل'
                              : 'Alexandra عبد الرحمن Longname',
                        },
                        weights: const [],
                        nutritionDays: const [],
                        waterHistory: const [],
                        computedHealth: const {},
                      ),
                      now: _now,
                      onChat: () => chats++,
                      onExit: useExit ? () => exits++ : null,
                      onRoute: (_) {},
                      onQuickAdd: () {},
                      onPhoto: () {},
                      onVoice: () {},
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await settleVisualAssetImages(tester);
              await tester.pumpAndSettle();

              final back = find.byKey(
                const Key('coach-workspace-back-to-chat'),
              );
              final bubble = find.descendant(
                of: back,
                matching: find.byKey(const Key('bil-crystal-arrow-bubble')),
              );
              final bubbleRect = tester.getRect(bubble);
              final hitRect = tester.getRect(back);
              expect(hitRect.width, greaterThanOrEqualTo(48));
              expect(hitRect.height, greaterThanOrEqualTo(48));
              expect(hitRect.contains(bubbleRect.topLeft), isTrue);
              expect(
                hitRect.contains(
                  bubbleRect.bottomRight - const Offset(.01, .01),
                ),
                isTrue,
              );
              expect(
                find.descendant(
                  of: back,
                  matching: find.byType(BilNavigationFeedback),
                ),
                findsOneWidget,
              );
              expect(
                find.descendant(
                  of: back,
                  matching: find.byType(BilCrystalArrow),
                ),
                findsOneWidget,
              );
              final greeting = find.byKey(
                const Key('coach-workspace-greeting'),
              );
              expect(
                bubbleRect.top,
                closeTo(tester.getRect(greeting).top, .01),
              );
              final detail = find.byKey(
                const Key('coach-workspace-greeting-detail'),
              );
              final label = find.byKey(const Key('coach-workspace-plan-label'));
              expect(
                label,
                access == _Access.free ? findsNothing : findsOneWidget,
              );
              for (final text in [
                greeting,
                detail,
                if (access != _Access.free) label,
              ]) {
                for (final textRect in _paintedTextRects(tester, text)) {
                  final clearance = language == 'ar'
                      ? bubbleRect.left - textRect.right
                      : textRect.left - bubbleRect.right;
                  expect(
                    clearance,
                    greaterThanOrEqualTo(12 - .01),
                    reason:
                        'Every wrapped line clears the crystal and its shadow.',
                  );
                  expect(bubbleRect.inflate(10).overlaps(textRect), isFalse);
                  expect(textRect.left, greaterThanOrEqualTo(0));
                  expect(textRect.right, lessThanOrEqualTo(width));
                }
                final widget = tester.widget<Text>(text);
                expect(
                  widget.maxLines,
                  isNull,
                  reason: 'Do not truncate accessible header copy.',
                );
              }
              expect(back.hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
              await _capture(tester, capture, name);
              await tester.tapAt(hitRect.center);
              await tester.pumpAndSettle();
              expect(exits, useExit ? 1 : 0);
              expect(chats, useExit ? 0 : 1);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            });
          }
        }
      }
    }
  }
}
