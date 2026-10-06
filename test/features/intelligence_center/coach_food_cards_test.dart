import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_action_receipt.dart';
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
  // Native connection creation, initialization and disposal belong to the
  // real runner lifecycle, outside the widget binding's fake clock.
  setUp(() async => fixture = await CoachFoodCardsFixture.create());
  tearDown(() async => fixture.close());

  testWidgets('review and Adjust do not commit or mutate the proposal', (
    tester,
  ) async {
    var confirmed = 0;
    var adjusted = 0;
    final original = fixture.review.items.map((item) => item.digest).toList();
    await mountFoodCard(
      tester,
      _review(
        fixture,
        onConfirm: () async {
          confirmed++;
        },
        onAdjust: () async {
          adjusted++;
        },
      ),
      evidenceFont: true,
    );
    expect(await _items(tester, fixture), isEmpty);
    await tester.tap(
      find.byKey(CoachFoodCardKeys.adjust('food-card-breakfast')),
    );
    await tester.pumpAndSettle();
    expect(adjusted, 1);
    expect(confirmed, 0);
    expect(await _items(tester, fixture), isEmpty);
    expect(fixture.review.items.map((item) => item.digest), original);
    expect(find.textContaining('Juhayna skim milk'), findsOneWidget);
    expect(find.textContaining('1 Tomato (~123 g)'), findsOneWidget);
  });

  testWidgets(
    'Yes commits four real Drift rows and never changes reviewed values',
    (tester) async {
      Future<CoachMealCommit>? pending;
      await mountFoodCard(
        tester,
        _review(
          fixture,
          onConfirm: () async {
            pending = fixture.commitReview();
            await pending!;
          },
        ),
        evidenceFont: true,
      );
      expect(await _items(tester, fixture), isEmpty);
      await tester.tap(
        find.byKey(CoachFoodCardKeys.confirm('food-card-breakfast')),
      );
      final result = await tester.runAsync(() => pending!);
      await tester.pumpAndSettle();
      expect(result!.after, hasLength(4));
      final rows = await _items(tester, fixture);
      expect(rows, hasLength(4));
      expect(rows.map((row) => row.quantity), [150, 200, 123, 200]);
      expect(rows.fold<double>(0, (sum, row) => sum + row.calories), 407);
      expect(rows.fold<double>(0, (sum, row) => sum + row.protein), 36);
      expect(result.after.map((row) => row.item.uuid).toSet(), hasLength(4));
      expect(result.after.every((row) => row.item.revision == 1), isTrue);
    },
  );

  testWidgets(
    'a pending confirmation coalesces double taps and blocks Adjust',
    (tester) async {
      final pending = Completer<void>();
      var confirmations = 0;
      var adjustments = 0;
      await mountFoodCard(
        tester,
        _review(
          fixture,
          onConfirm: () async {
            confirmations++;
            await pending.future;
          },
          onAdjust: () async {
            adjustments++;
          },
        ),
        evidenceFont: true,
      );
      final confirm = find.byKey(
        CoachFoodCardKeys.confirm('food-card-breakfast'),
      );
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.tap(
        find.byKey(CoachFoodCardKeys.adjust('food-card-breakfast')),
      );
      await tester.pump();
      expect(confirmations, 1);
      expect(adjustments, 0);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    },
  );

  testWidgets(
    'failed confirmation retains all input and retries the same operation',
    (tester) async {
      var attempts = 0;
      Future<CoachMealCommit>? pending;
      await mountFoodCard(
        tester,
        _review(
          fixture,
          onConfirm: () async {
            attempts++;
            if (attempts == 1) throw StateError('temporary offline fixture');
            pending = fixture.commitReview();
            await pending!;
          },
        ),
        evidenceFont: true,
      );
      final confirm = find.byKey(
        CoachFoodCardKeys.confirm('food-card-breakfast'),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        find.text('The action could not be completed. Your review is kept.'),
        findsOneWidget,
      );
      expect(find.textContaining('Juhayna skim milk'), findsOneWidget);
      await tester.tap(
        find.byKey(CoachFoodCardKeys.reviewFood('food-card-breakfast', 1)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('200 ml (200 g)'), findsOneWidget);
      expect(await _items(tester, fixture), isEmpty);
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      final commit = await tester.runAsync(() => pending!);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(commit!.operationId, 'food-card-breakfast');
      expect(await _items(tester, fixture), hasLength(4));
      expect(
        find.text('The action could not be completed. Your review is kept.'),
        findsNothing,
      );
    },
  );

  testWidgets('cancelled owner and A to B to A cannot revive the old review', (
    tester,
  ) async {
    late StateSetter rebuild;
    var confirmations = 0;
    await mountFoodCard(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _review(
            fixture,
            onConfirm: () async {
              confirmations++;
            },
          );
        },
      ),
      evidenceFont: true,
    );
    fixture.cancelOwner();
    rebuild(() {});
    await tester.pumpAndSettle();
    expect(find.textContaining('Juhayna skim milk'), findsNothing);
    fixture.ownerCurrent = true;
    rebuild(() {});
    await tester.pumpAndSettle();
    expect(
      find.byKey(CoachFoodCardKeys.confirm('food-card-breakfast')),
      findsNothing,
    );
    expect(
      find.text('Your account changed. Return to Coach to continue.'),
      findsOneWidget,
    );
    expect(confirmations, 0);
    expect(await _items(tester, fixture), isEmpty);
  });

  testWidgets(
    'owner cancellation during confirmation prevents late Drift write',
    (tester) async {
      late StateSetter rebuild;
      final release = Completer<void>();
      final scope = fixture.scope();
      await mountFoodCard(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _review(
              fixture,
              onConfirm: () async {
                await release.future;
                await fixture.repository.commitCoachMeal(
                  command: CoachMealCommand.foods(
                    operationId: 'food-card-breakfast',
                    date: CoachFoodCardsFixture.day,
                    mealType: 'breakfast',
                    review: fixture.review,
                  ),
                  scope: scope,
                );
              },
            );
          },
        ),
        evidenceFont: true,
      );
      await tester.tap(
        find.byKey(CoachFoodCardKeys.confirm('food-card-breakfast')),
      );
      fixture.cancelOwner();
      rebuild(() {});
      release.complete();
      await tester.pumpAndSettle();
      expect(await _items(tester, fixture), isEmpty);
      expect(find.textContaining('Juhayna skim milk'), findsNothing);
      expect(
        find.text('Your account changed. Return to Coach to continue.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late failure from a replaced proposal cannot taint the next review',
    (tester) async {
      late StateSetter rebuild;
      final old = Completer<void>();
      var operation = 'food-card-breakfast';
      await mountFoodCard(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _review(
              fixture,
              operationId: operation,
              onConfirm: () => old.future,
            );
          },
        ),
        evidenceFont: true,
      );
      await tester.tap(find.byKey(CoachFoodCardKeys.confirm(operation)));
      rebuild(() => operation = 'next-food-proposal');
      await tester.pump();
      old.completeError(StateError('old completion'));
      await tester.pumpAndSettle();
      expect(
        find.text('The action could not be completed. Your review is kept.'),
        findsNothing,
      );
      final next = find.byKey(CoachFoodCardKeys.confirm(operation));
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      expect(await _items(tester, fixture), isEmpty);
    },
  );

  testWidgets(
    'receipt renders actual committed totals and four saved identities',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitReview))!;
      await mountFoodCard(
        tester,
        _receipt(fixture, commit),
        evidenceFont: true,
      );
      expect(find.text('Breakfast logged'), findsOneWidget);
      expect(find.text('407'), findsOneWidget);
      expect(find.text('36 g'), findsOneWidget);
      expect(find.text('18 g'), findsOneWidget);
      expect(find.text('20 g'), findsOneWidget);
      for (final row in commit.after) {
        expect(
          find.byKey(CoachFoodCardKeys.receiptFood(row.item.uuid)),
          findsOneWidget,
        );
        expect(find.text(row.foodName), findsOneWidget);
      }
      expect(find.textContaining('USDA'), findsNothing);
      expect(find.textContaining('BIL Verified'), findsNothing);
      expect(find.textContaining('Estimated portion'), findsOneWidget);
      expect(await _items(tester, fixture), hasLength(4));
    },
  );

  testWidgets(
    'source, identity and quantity confidence remain three distinct facts',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitReview))!;
      await mountFoodCard(
        tester,
        _receipt(fixture, commit),
        evidenceFont: true,
      );
      await tester.tap(
        find.byKey(CoachFoodCardKeys.receiptFood(commit.after.first.item.uuid)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Source confidence: 91% · QA source evidence'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Identity confidence: 98% · QA matched identity'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Quantity confidence: 63% · QA quantity evidence'),
        findsOneWidget,
      );
      expect(find.textContaining('qa:isolated-drift:food-0'), findsOneWidget);
      expect(find.textContaining('3 items (150 g)'), findsOneWidget);
    },
  );

  testWidgets(
    'one missing nutrient makes its total unknown while known zero stays zero',
    (tester) async {
      final commit = (await tester.runAsync(
        () => fixture.commitReview(
          proposal: foodCardFixtureReview(unknownProtein: true),
        ),
      ))!;
      final semantics = tester.ensureSemantics();
      try {
        await mountFoodCard(
          tester,
          _receipt(fixture, commit),
          evidenceFont: true,
        );
        expect(find.text('407'), findsOneWidget);
        expect(find.text('Unknown'), findsOneWidget);
        expect(find.text('33 g'), findsNothing);
        expect(find.bySemanticsLabel('Protein: Unknown'), findsOneWidget);
        await tester.tap(
          find.byKey(CoachFoodCardKeys.menu(commit.operationId)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nutrition details'));
        await tester.pumpAndSettle();
        expect(find.text('Potassium: 0 mg'), findsOneWidget);
        expect(find.text('Sodium: 242 mg'), findsOneWidget);
        expect(find.text('Protein: Unknown'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Edit receives the selected committed UUID and revision', (
    tester,
  ) async {
    final commit = (await tester.runAsync(fixture.commitReview))!;
    CoachMealSnapshot? selected;
    await mountFoodCard(
      tester,
      _receipt(
        fixture,
        commit,
        onEdit: (item) async {
          selected = item;
        },
      ),
      evidenceFont: true,
    );
    final expected = commit.after[2];
    await tester.tap(
      find.byKey(CoachFoodCardKeys.receiptFood(expected.item.uuid)),
    );
    await tester.pumpAndSettle();
    final edit = find.byKey(CoachFoodCardKeys.edit(expected.item.uuid));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(selected, same(expected));
    expect(selected!.item.uuid, expected.item.uuid);
    expect(selected!.item.revision, expected.item.revision);
    expect(selected!.item.quantity, 123);
    expect(await _items(tester, fixture), hasLength(4));
  });

  testWidgets(
    '1905 calories is a numeric-only receipt without invented foods or macros',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitCalories))!;
      await mountFoodCard(
        tester,
        _receipt(fixture, commit),
        evidenceFont: true,
      );
      expect(find.text('Calorie entry saved'), findsOneWidget);
      expect(find.text('1905'), findsOneWidget);
      expect(find.text('Unknown'), findsNWidgets(3));
      expect(
        find.byKey(
          CoachFoodCardKeys.receiptFood(commit.after.single.item.uuid),
        ),
        findsNothing,
      );
      expect(find.textContaining('Juhayna'), findsNothing);
      expect(find.textContaining('1905 g'), findsNothing);
      expect(find.textContaining('0 g'), findsNothing);
      expect(
        find.byKey(CoachFoodCardKeys.edit(commit.after.single.item.uuid)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Undo commits compensation and replaces old success and Undo controls',
    (tester) async {
      var commit = (await tester.runAsync(fixture.commitReview))!;
      late StateSetter rebuild;
      Future<CoachMealCommit>? pending;
      await mountFoodCard(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _receipt(
              fixture,
              commit,
              onUndo: () async {
                pending = fixture.undo(commit);
                final undone = await pending!;
                rebuild(() => commit = undone);
              },
            );
          },
        ),
        evidenceFont: true,
      );
      await tester.tap(find.byKey(CoachFoodCardKeys.menu(commit.operationId)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoachFoodCardKeys.undo(commit.operationId)));
      await tester.runAsync(() => pending!);
      await tester.pumpAndSettle();
      expect(commit.state, CoachMealResultState.undone);
      expect(find.text('Entry undone'), findsOneWidget);
      expect(find.text('Breakfast logged'), findsNothing);
      expect(
        find.byKey(CoachFoodCardKeys.menu(commit.operationId)),
        findsNothing,
      );
      expect(find.text('407'), findsNothing);
      expect(
        (await _items(tester, fixture)).every((row) => row.deletedAt != null),
        isTrue,
      );
    },
  );

  testWidgets(
    'actual concurrent edit rejects Undo without a false success receipt',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitReview))!;
      await tester.runAsync(
        () => fixture.repository.updateMealItem(
          id: commit.after.first.item.id,
          quantity: 175,
        ),
      );
      Future<CoachMealCommit>? pending;
      await mountFoodCard(
        tester,
        _receipt(
          fixture,
          commit,
          onUndo: () async {
            pending = fixture.undo(commit);
            await pending!;
          },
        ),
        evidenceFont: true,
      );
      await tester.tap(find.byKey(CoachFoodCardKeys.menu(commit.operationId)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoachFoodCardKeys.undo(commit.operationId)));
      await tester.runAsync(() async {
        await expectLater(pending!, throwsA(isA<CoachMealConflict>()));
      });
      await tester.pumpAndSettle();
      expect(find.text('Breakfast logged'), findsNothing);
      expect(find.text('Entry undone'), findsNothing);
      expect(
        find.text(
          'This meal changed. Review the current entry before editing or undoing.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(CoachFoodCardKeys.menu(commit.operationId)),
        findsNothing,
      );
      final rows = await _items(tester, fixture);
      expect(rows.first.quantity, 175);
      expect(rows.every((row) => row.deletedAt == null), isTrue);
    },
  );

  testWidgets(
    'owner change while receipt menu is open cannot invoke old Undo',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitReview))!;
      var undos = 0;
      await mountFoodCard(
        tester,
        _receipt(
          fixture,
          commit,
          onUndo: () async {
            undos++;
          },
        ),
        evidenceFont: true,
      );
      await tester.tap(find.byKey(CoachFoodCardKeys.menu(commit.operationId)));
      await tester.pumpAndSettle();
      fixture.cancelOwner();
      await tester.tap(find.byKey(CoachFoodCardKeys.undo(commit.operationId)));
      await tester.pumpAndSettle();
      expect(undos, 0);
      expect(find.text('Breakfast logged'), findsNothing);
      expect(find.text('Juhayna skim milk'), findsNothing);
      expect(
        find.text('Your account changed. Return to Coach to continue.'),
        findsOneWidget,
      );
      expect(await _items(tester, fixture), hasLength(4));
    },
  );

  testWidgets(
    'wrong operation receipt is unavailable and never resolves food photos',
    (tester) async {
      final commit = (await tester.runAsync(fixture.commitReview))!;
      var images = 0;
      await mountFoodCard(
        tester,
        CoachFoodReceiptCard(
          commit: commit,
          receipt: foodCardReceipt(
            commit,
            operationId: 'a-different-operation',
          ),
          ownerIsCurrent: () => fixture.ownerCurrent,
          onEdit: (_) async {},
          onUndo: () async {},
          onViewDailyLog: () async {},
          thumbnailFor: (_) {
            images++;
            return null;
          },
        ),
        evidenceFont: true,
      );
      expect(
        find.text('This food receipt is unavailable. Review your Daily Log.'),
        findsOneWidget,
      );
      expect(find.text('Breakfast logged'), findsNothing);
      expect(find.text('407'), findsNothing);
      expect(
        find.byKey(CoachFoodCardKeys.menu(commit.operationId)),
        findsNothing,
      );
      expect(images, 0);
    },
  );
}

Widget _review(
  CoachFoodCardsFixture fixture, {
  String operationId = 'food-card-breakfast',
  Future<void> Function()? onConfirm,
  Future<void> Function()? onAdjust,
}) => CoachFoodReviewCard(
  review: fixture.review,
  operationId: operationId,
  mealType: 'breakfast',
  day: CoachFoodCardsFixture.day,
  ownerIsCurrent: () => fixture.ownerCurrent,
  onConfirm: onConfirm ?? () async {},
  onAdjust: onAdjust ?? () async {},
);

Widget _receipt(
  CoachFoodCardsFixture fixture,
  CoachMealCommit commit, {
  BilActionReceipt? receipt,
  Future<void> Function(CoachMealSnapshot)? onEdit,
  Future<void> Function()? onUndo,
}) => CoachFoodReceiptCard(
  commit: commit,
  receipt: receipt ?? foodCardReceipt(commit),
  ownerIsCurrent: () => fixture.ownerCurrent,
  onEdit: onEdit ?? (_) async {},
  onUndo: onUndo ?? () async {},
  onViewDailyLog: () async {},
);

Future<List<MealItem>> _items(
  WidgetTester tester,
  CoachFoodCardsFixture fixture,
) async => (await tester.runAsync(
  () => fixture.database.select(fixture.database.mealItems).get(),
))!;
