import 'dart:async';

import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_text_policy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_food_submission_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(
  Future<void> Function(CommunityFoodDraft) submit, {
  Locale locale = const Locale('en'),
  TargetPlatform platform = TargetPlatform.android,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(platform: platform),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          key: const Key('open-food'),
          onPressed: () => showModalBottomSheet<bool>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            builder: (_) => CommunityFoodSubmissionSheet(onSubmit: submit),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

Future<void> openSheet(
  WidgetTester tester,
  Future<void> Function(CommunityFoodDraft) submit, {
  Locale locale = const Locale('en'),
  TargetPlatform platform = TargetPlatform.android,
}) async {
  await tester.pumpWidget(host(submit, locale: locale, platform: platform));
  await tester.tap(find.byKey(const Key('open-food')));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, {String protein = '10'}) async {
  for (final entry in {
    'name': 'Test food',
    'serving': '100',
    'calories': '165',
    'protein': protein,
    'carbohydrate': '20',
    'fat': '5',
  }.entries) {
    final finder = find.byKey(Key('community-food-input-${entry.key}'));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, entry.value);
    await tester.pump();
  }
  await tester.ensureVisible(find.byKey(const Key('community-food-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invalid input stays in the sheet and never queues snackbars', (
    tester,
  ) async {
    var calls = 0;
    await openSheet(tester, (_) async {
      calls++;
    });
    final button = find.byKey(const Key('community-food-submit'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('This value is required.'), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);
    final cancel = find.byKey(const Key('community-food-cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(CommunityFoodSubmissionSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one request while pending and closes only after success', (
    tester,
  ) async {
    final barrier = Completer<void>();
    final submitted = <CommunityFoodDraft>[];
    await openSheet(tester, (draft) {
      submitted.add(draft);
      return barrier.future;
    });
    await fill(tester);
    final callback = tester
        .widget<FilledButton>(find.byKey(const Key('community-food-submit')))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(submitted, hasLength(1));
    expect(submitted.single.calories, 165);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('community-food-cancel')))
          .onPressed,
      isNull,
    );
    expect(find.byType(CommunityFoodSubmissionSheet), findsOneWidget);
    barrier.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CommunityFoodSubmissionSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'server error is inline, keeps input, and allows an explicit retry',
    (tester) async {
      var calls = 0;
      await openSheet(tester, (_) async {
        calls++;
        if (calls == 1) throw StateError('private server detail');
      });
      await fill(tester);
      await tester.tap(find.byKey(const Key('community-food-submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-food-submit-error')),
        findsOneWidget,
      );
      expect(find.textContaining('private server detail'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('community-food-input-name')),
            )
            .controller!
            .text,
        'Test food',
      );
      await tester.ensureVisible(
        find.byKey(const Key('community-food-submit')),
      );
      await tester.tap(find.byKey(const Key('community-food-submit')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(CommunityFoodSubmissionSheet), findsNothing);
    },
  );

  testWidgets('policy rejection remains localized inside the modal', (
    tester,
  ) async {
    const rejection = CommunityTextPolicyException(
      surface: CommunityTextSurface.foodName,
      kind: CommunityTextViolationKind.email,
    );
    await openSheet(tester, (_) async {
      throw rejection;
    }, locale: const Locale('ar'));
    await fill(tester);
    await tester.tap(find.byKey(const Key('community-food-submit')));
    await tester.pumpAndSettle();
    expect(find.text(rejection.localizedMessage('ar')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(CommunityFoodSubmissionSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('impossible macro values never reach the repository', (
    tester,
  ) async {
    var calls = 0;
    await openSheet(tester, (_) async {
      calls++;
    });
    await fill(tester, protein: '255');
    await tester.tap(find.byKey(const Key('community-food-submit')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(
      find.text('Nutrient grams cannot exceed the serving weight.'),
      findsWidgets,
    );
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('Arabic decimal keyboard submission on $platform', (
      tester,
    ) async {
      CommunityFoodDraft? result;
      await openSheet(
        tester,
        (draft) async {
          result = draft;
        },
        locale: const Locale('ar'),
        platform: platform,
      );
      await fill(tester);
      final serving = find.byKey(const Key('community-food-input-serving'));
      await tester.ensureVisible(serving);
      await tester.enterText(serving, '١٠٠٫٥');
      await tester.ensureVisible(
        find.byKey(const Key('community-food-submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-food-submit')));
      await tester.pumpAndSettle();
      expect(result!.servingGrams, 100.5);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'late request completion after unmount does not touch the route',
    (tester) async {
      final barrier = Completer<void>();
      await openSheet(tester, (_) => barrier.future);
      await fill(tester);
      await tester.tap(find.byKey(const Key('community-food-submit')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      barrier.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
