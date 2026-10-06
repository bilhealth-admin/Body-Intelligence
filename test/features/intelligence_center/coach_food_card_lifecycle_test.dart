import 'dart:async';

import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_receipt_card.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';
import 'support/coach_food_cards_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoachFoodCardsFixture fixture;
  setUpAll(loadVisualEvidenceFont);
  setUp(() async => fixture = await CoachFoodCardsFixture.create());
  tearDown(() async => fixture.close());

  testWidgets(
    'lost readback keeps the review and retries the same committed operation',
    (tester) async {
      var attempts = 0;
      Future<void>? pending;
      CoachMealCommit? result;
      await mountFoodCard(
        tester,
        CoachFoodReviewCard(
          review: fixture.review,
          operationId: 'food-card-breakfast',
          mealType: 'breakfast',
          day: CoachFoodCardsFixture.day,
          ownerIsCurrent: () => fixture.ownerCurrent,
          onConfirm: () {
            pending = () async {
              attempts++;
              result = await fixture.commitReview();
              if (attempts == 1) {
                throw const CoachMealConflict(
                  CoachMealConflictReason.readbackUnavailable,
                  committed: true,
                );
              }
            }();
            return pending!;
          },
          onAdjust: () async {},
        ),
        evidenceFont: true,
      );
      final confirm = find.byKey(
        CoachFoodCardKeys.confirm('food-card-breakfast'),
      );
      await tester.tap(confirm);
      await tester.runAsync(
        () async => expectLater(pending!, throwsA(isA<CoachMealConflict>())),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('The action could not be completed. Your review is kept.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'This meal changed. Review the current entry before editing or undoing.',
        ),
        findsNothing,
      );
      expect(find.textContaining('Juhayna skim milk'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      expect(
        await tester.runAsync(
          () => fixture.database.select(fixture.database.mealItems).get(),
        ),
        hasLength(4),
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.runAsync(() => pending!);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(result!.replayed, isTrue);
      expect(result!.operationId, 'food-card-breakfast');
      expect(
        await tester.runAsync(
          () => fixture.database.select(fixture.database.mealItems).get(),
        ),
        hasLength(4),
      );
    },
  );

  testWidgets(
    'an open receipt menu cannot undo a replacement repository readback',
    (tester) async {
      final original = (await tester.runAsync(fixture.commitReview))!;
      var current = original;
      late StateSetter rebuild;
      final requested = <CoachMealCommit>[];
      Future<CoachMealCommit>? pending;
      await mountFoodCard(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            final captured = current;
            return CoachFoodReceiptCard(
              commit: captured,
              receipt: foodCardReceipt(captured),
              ownerIsCurrent: () => fixture.ownerCurrent,
              onEdit: (_) async {},
              onUndo: () async {
                requested.add(captured);
                pending = fixture.undo(captured);
                await pending!;
              },
              onViewDailyLog: () async {},
            );
          },
        ),
        evidenceFont: true,
      );
      final menu = find.byKey(CoachFoodCardKeys.menu(original.operationId));
      final undo = find.byKey(CoachFoodCardKeys.undo(original.operationId));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(undo, findsOneWidget);
      final replay = (await tester.runAsync(fixture.commitReview))!;
      expect(replay.replayed, isTrue);
      expect(identical(original, replay), isFalse);
      rebuild(() => current = replay);
      await tester.pump();
      // The operation id intentionally stays the same. This is a fresh,
      // authoritative journal readback while the old popup is still open.
      expect(undo, findsOneWidget);
      await tester.tap(undo);
      if (pending != null) {
        await tester.runAsync(() => pending!);
      }
      await tester.pumpAndSettle();
      expect(
        requested,
        isEmpty,
        reason:
            'A choice opened for the old readback cannot target the new one.',
      );
      expect(
        await tester.runAsync(
          () => fixture.database.select(fixture.database.mealItems).get(),
        ),
        hasLength(4),
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(undo);
      final undone = (await tester.runAsync(() => pending!))!;
      await tester.pumpAndSettle();
      expect(requested, [same(replay)]);
      expect(undone.state, CoachMealResultState.undone);
      final stored = (await tester.runAsync(
        () => fixture.database.select(fixture.database.mealItems).get(),
      ))!;
      // Undo keeps sync tombstones, while removing every active diary row.
      expect(stored, hasLength(4));
      expect(stored.map((row) => row.deletedAt), everyElement(isNotNull));
      expect(stored.where((row) => row.deletedAt == null), isEmpty);
    },
  );

  testWidgets(
    'ordinary parent rebuild cannot revive Undo after a real stale-item conflict',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitReview))!;
      await tester.runAsync(
        () => fixture.repository.updateMealItem(
          id: commit.after.first.item.id,
          quantity: 175,
        ),
      );
      late StateSetter rebuild;
      Future<CoachMealCommit>? pending;
      await mountFoodCard(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return CoachFoodReceiptCard(
              commit: commit,
              // Recreating a serialization wrapper is not a fresh repository read.
              receipt: foodCardReceipt(commit),
              ownerIsCurrent: () => fixture.ownerCurrent,
              onEdit: (_) async {},
              onUndo: () async {
                pending = fixture.undo(commit);
                await pending!;
              },
              onViewDailyLog: () async {},
            );
          },
        ),
        evidenceFont: true,
      );
      await tester.tap(find.byKey(CoachFoodCardKeys.menu(commit.operationId)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoachFoodCardKeys.undo(commit.operationId)));
      await tester.runAsync(
        () async => expectLater(pending!, throwsA(isA<CoachMealConflict>())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Breakfast logged'), findsNothing);
      rebuild(() {});
      await tester.pumpAndSettle();
      expect(find.text('Breakfast logged'), findsNothing);
      expect(
        find.byKey(CoachFoodCardKeys.menu(commit.operationId)),
        findsNothing,
      );
      expect(
        find.text(
          'This meal changed. Review the current entry before editing or undoing.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'status and serialization rebuilds cannot unlock an in-flight Undo',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitReview))!;
      late StateSetter rebuild;
      var status = CoachFoodReceiptStatus.ready;
      var undos = 0;
      final release = Completer<void>();
      await mountFoodCard(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return CoachFoodReceiptCard(
              commit: commit,
              receipt: foodCardReceipt(commit),
              status: status,
              ownerIsCurrent: () => fixture.ownerCurrent,
              onEdit: (_) async {},
              onUndo: () async {
                undos++;
                await release.future;
              },
              onViewDailyLog: () async {},
            );
          },
        ),
        evidenceFont: true,
      );
      await tester.tap(find.byKey(CoachFoodCardKeys.menu(commit.operationId)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoachFoodCardKeys.undo(commit.operationId)));
      await tester.pump();
      try {
        rebuild(() => status = CoachFoodReceiptStatus.conflict);
        await tester.pump();
        rebuild(() => status = CoachFoodReceiptStatus.ready);
        await tester.pump();
        final menu = tester.widget<PopupMenuButton<dynamic>>(
          find.byKey(CoachFoodCardKeys.menu(commit.operationId)),
        );
        expect(menu.enabled, isFalse);
        expect(find.text('Working…'), findsOneWidget);
        expect(undos, 1);
      } finally {
        release.complete();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'unavailable optional image resolver cannot discard a committed receipt',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitReview))!;
      await mountFoodCard(
        tester,
        CoachFoodReceiptCard(
          commit: commit,
          receipt: foodCardReceipt(commit),
          ownerIsCurrent: () => fixture.ownerCurrent,
          onEdit: (_) async {},
          onUndo: () async {},
          onViewDailyLog: () async {},
          thumbnailFor: (_) =>
              throw StateError('optional image cache unavailable'),
        ),
        evidenceFont: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Breakfast logged'), findsOneWidget);
      expect(find.text('407'), findsOneWidget);
      expect(
        find.byKey(CoachFoodCardKeys.dailyLog(commit.operationId)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'closed review retains its food evidence but has no active write controls',
    (tester) async {
      var confirmations = 0;
      var adjustments = 0;
      await mountFoodCard(
        tester,
        CoachFoodReviewCard(
          review: fixture.review,
          operationId: 'closed-proposal',
          mealType: 'breakfast',
          day: CoachFoodCardsFixture.day,
          ownerIsCurrent: () => fixture.ownerCurrent,
          status: CoachFoodReviewStatus.closed,
          onConfirm: () async {
            confirmations++;
          },
          onAdjust: () async {
            adjustments++;
          },
        ),
        evidenceFont: true,
      );
      expect(find.textContaining('Juhayna skim milk'), findsOneWidget);
      final confirm = find.byKey(CoachFoodCardKeys.confirm('closed-proposal'));
      final adjust = find.byKey(CoachFoodCardKeys.adjust('closed-proposal'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(adjust).onPressed, isNull);
      expect(find.text('This review is closed.'), findsOneWidget);
      expect(confirmations, 0);
      expect(adjustments, 0);
    },
  );
}
