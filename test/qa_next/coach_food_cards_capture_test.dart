import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_receipt_card.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../features/intelligence_center/support/coach_food_cards_fixture.dart';
import '../visual_closure/visual_evidence_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoachFoodCardsFixture fixture;
  setUpAll(loadVisualEvidenceFont);
  setUp(() async => fixture = await CoachFoodCardsFixture.create());
  tearDown(() async => fixture.close());

  for (final language in ['en', 'ar']) {
    for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
      testWidgets(
        'real Flutter review and committed receipt $language ${width.toInt()} scale$scale',
        (tester) async {
          final key = GlobalKey();
          await mountFoodCard(
            tester,
            _review(fixture),
            language: language,
            scale: scale,
            width: width,
            evidenceFont: true,
            captureKey: key,
          );
          final card = find.byKey(
            CoachFoodCardKeys.review('capture-food-review'),
          );
          expect(tester.getSize(card).width, closeTo(290, .01));
          expect(tester.getRect(card).right, lessThanOrEqualTo(width));
          expect(tester.takeException(), isNull);
          if (language == 'ar' && scale == 2) {
            _expectSingleVisualLine(
              tester,
              find.textContaining('Boiled eggs'),
              firstToken: '150',
              lastToken: 'غ',
            );
          }
          final rowsBefore = await tester.runAsync(
            () => fixture.database.select(fixture.database.mealItems).get(),
          );
          expect(rowsBefore, isEmpty);
          final suffix =
              '${language}_${width.toInt()}_${(scale * 100).toInt()}';
          await _capture(tester, key, 'review_$suffix');
          final confirm = find.byKey(
            CoachFoodCardKeys.confirm('capture-food-review'),
          );
          final font = language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence';
          _expectButtonFont(tester, confirm, font);
          _expectButtonFont(
            tester,
            find.byKey(CoachFoodCardKeys.adjust('capture-food-review')),
            font,
          );
          await tester.ensureVisible(confirm);
          await tester.pumpAndSettle();
          expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          if (scale == 2) await _capture(tester, key, 'review_actions_$suffix');

          final commit = (await tester.runAsync(fixture.commitReview))!;
          final receiptKey = GlobalKey();
          await mountFoodCard(
            tester,
            _receipt(fixture, commit),
            language: language,
            scale: scale,
            width: width,
            evidenceFont: true,
            captureKey: receiptKey,
          );
          final receiptCard = find.byKey(
            CoachFoodCardKeys.receipt(commit.operationId),
          );
          expect(tester.getSize(receiptCard).width, closeTo(width - 24, .01));
          expect(tester.getRect(receiptCard).right, lessThanOrEqualTo(width));
          expect(tester.takeException(), isNull);
          expect(
            find.text(NumberFormat('0.##', language).format(407)),
            findsOneWidget,
          );
          expect(commit.after, hasLength(4));
          if (language == 'ar' && scale == 2) {
            _expectSingleVisualLine(
              tester,
              find.text('الكربوهيدرات'),
              firstToken: 'الكربوهيدرات',
              lastToken: 'الكربوهيدرات',
            );
          }
          for (final row in commit.after) {
            expect(
              find.byKey(CoachFoodCardKeys.receiptFood(row.item.uuid)),
              findsOneWidget,
            );
          }
          await _capture(tester, receiptKey, 'receipt_$suffix');
          final log = find.byKey(
            CoachFoodCardKeys.dailyLog(commit.operationId),
          );
          await tester.ensureVisible(log);
          await tester.pumpAndSettle();
          expect(tester.widget<TextButton>(log).onPressed, isNotNull);
          _expectButtonFont(tester, log, font);
          if (scale == 2) {
            await _capture(tester, receiptKey, 'receipt_actions_$suffix');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'calorie-only and missing values stay explicit $language at 200 percent',
      (tester) async {
        final commit = (await tester.runAsync(fixture.commitCalories))!;
        final key = GlobalKey();
        await mountFoodCard(
          tester,
          _receipt(fixture, commit),
          language: language,
          scale: 2,
          width: 320,
          evidenceFont: true,
          captureKey: key,
        );
        expect(
          find.text(NumberFormat('0.##', language).format(1905)),
          findsOneWidget,
        );
        expect(
          find.text(language == 'ar' ? 'غير معروف' : 'Unknown'),
          findsNWidgets(3),
        );
        expect(
          find.byKey(
            CoachFoodCardKeys.receiptFood(commit.after.single.item.uuid),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await _capture(tester, key, 'calorie_only_${language}_320_200');
      },
    );

    testWidgets(
      'real changed readback has no logged success or Undo $language',
      (tester) async {
        final original = (await tester.runAsync(fixture.commitReview))!;
        await tester.runAsync(
          () => fixture.repository.updateMealItem(
            id: original.after.first.item.id,
            quantity: 175,
          ),
        );
        final changed = (await tester.runAsync(fixture.commitReview))!;
        expect(changed.state, CoachMealResultState.modified);
        final key = GlobalKey();
        await mountFoodCard(
          tester,
          _receipt(fixture, changed),
          language: language,
          scale: 2,
          width: 320,
          evidenceFont: true,
          captureKey: key,
        );
        expect(find.text('407'), findsNothing);
        expect(
          find.byKey(CoachFoodCardKeys.menu(changed.operationId)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await _capture(tester, key, 'receipt_conflict_${language}_320_200');
      },
    );

    testWidgets(
      'food evidence expansion retains independent confidence $language',
      (tester) async {
        final commit = (await tester.runAsync(fixture.commitReview))!;
        final key = GlobalKey();
        await mountFoodCard(
          tester,
          _receipt(fixture, commit),
          language: language,
          evidenceFont: true,
          captureKey: key,
        );
        await tester.tap(
          find.byKey(
            CoachFoodCardKeys.receiptFood(commit.after.first.item.uuid),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            NumberFormat.percentPattern(language).format(.91),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            NumberFormat.percentPattern(language).format(.98),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            NumberFormat.percentPattern(language).format(.63),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        _expectButtonFont(
          tester,
          find.byKey(CoachFoodCardKeys.edit(commit.after.first.item.uuid)),
          language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
        );
        await _capture(tester, key, 'receipt_evidence_$language');
      },
    );
  }
}

void _expectButtonFont(WidgetTester tester, Finder button, String family) {
  final text = find.descendant(of: button, matching: find.byType(Text)).first;
  final richText = find
      .descendant(of: text, matching: find.byType(RichText))
      .first;
  final paragraph = tester.renderObject<RenderParagraph>(richText);
  expect(paragraph.text.style?.fontFamily, family);
}

void _expectSingleVisualLine(
  WidgetTester tester,
  Finder text, {
  required String firstToken,
  required String lastToken,
}) {
  final richText = find
      .descendant(of: text, matching: find.byType(RichText))
      .first;
  final paragraph = tester.renderObject<RenderParagraph>(richText);
  final plain = paragraph.text.toPlainText();
  final start = plain.indexOf(firstToken);
  final end = plain.indexOf(lastToken, start) + lastToken.length;
  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );
  expect(boxes, isNotEmpty);
  expect(
    boxes.map((box) => box.top.toStringAsFixed(2)).toSet(),
    hasLength(1),
    reason: 'Keep the measured quantity or single Arabic word on one line.',
  );
}

Widget _review(CoachFoodCardsFixture fixture) => CoachFoodReviewCard(
  review: fixture.review,
  operationId: 'capture-food-review',
  mealType: 'breakfast',
  day: CoachFoodCardsFixture.day,
  ownerIsCurrent: () => fixture.ownerCurrent,
  onConfirm: () async {},
  onAdjust: () async {},
);

Widget _receipt(CoachFoodCardsFixture fixture, CoachMealCommit commit) =>
    CoachFoodReceiptCard(
      commit: commit,
      receipt: foodCardReceipt(commit),
      ownerIsCurrent: () => fixture.ownerCurrent,
      onEdit: (_) async {},
      onUndo: () async {},
      onViewDailyLog: () async {},
    );

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final path = Platform.environment['BIL_REFERENCE_CAPTURE_DIR'];
  if (path == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(path).create(recursive: true);
      await File('$path/$name.png').writeAsBytes(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
