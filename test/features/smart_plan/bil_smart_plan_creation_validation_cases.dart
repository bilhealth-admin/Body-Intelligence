part of 'bil_smart_plan_creation_retry_test.dart';

void _registerPlanChoiceValidationTests({
  required Future<void> Function(
    WidgetTester, {
    Locale locale,
    double width,
    double textScale,
  })
  mount,
  required AppDatabase Function() database,
  required _FaultPreferences Function() preferences,
  required ProviderContainer Function() container,
  required BilSmartPlanRepository Function() repository,
}) {
  testWidgets(
    'empty creation keeps Prepare enabled and lists missing choices without writing',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
      await tester.pumpAndSettle();
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      expect(tester.widget<FilledButton>(prepare).onPressed, isNotNull);
      expect(
        tester
            .widget<DropdownButtonFormField<BilPlanHorizon>>(
              find.byType(DropdownButtonFormField<BilPlanHorizon>),
            )
            .initialValue,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<BilPlanEnvironment>>(
              find.byType(DropdownButtonFormField<BilPlanEnvironment>),
            )
            .initialValue,
        isNull,
      );
      for (final field in ['minutes', 'sessions']) {
        expect(
          tester
              .widget<DropdownButtonFormField<int>>(_numberField(field))
              .initialValue,
          isNull,
        );
      }
      expect(
        tester
            .widget<DropdownButtonFormField<BilPlanFocus>>(
              find.byType(DropdownButtonFormField<BilPlanFocus>),
            )
            .initialValue,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<MealPlanDiet>>(
              find.byType(DropdownButtonFormField<MealPlanDiet>),
            )
            .initialValue,
        isNull,
      );
      for (final field in ['symptoms', 'medical']) {
        final control = find.descendant(
          of: find.byKey(ValueKey('bil-smart-plan-field-$field')),
          matching: find.byType(DropdownButtonFormField<bool>),
        );
        expect(
          tester.widget<DropdownButtonFormField<bool>>(control).initialValue,
          isNull,
        );
      }
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bil-smart-plan-required-choices')),
        findsOneWidget,
      );
      for (final field in [
        'horizon',
        'focus',
        'environment',
        'experience',
        'minutes',
        'sessions',
        'diet',
        'confirmation',
        'symptoms',
        'medical',
      ]) {
        expect(
          find.byKey(ValueKey('bil-smart-plan-missing-$field')),
          findsOneWidget,
        );
      }
      expect(preferences().planCommits, 0);
      expect(await tester.runAsync(() => repository().readFor(_owner)), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'validation row scrolls and focuses the actual missing duration field',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
      await tester.pumpAndSettle();
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      final missing = find.byKey(
        const ValueKey('bil-smart-plan-missing-horizon'),
      );
      await tester.ensureVisible(missing);
      await tester.tap(missing);
      await tester.pumpAndSettle();
      final field = find.byType(DropdownButtonFormField<BilPlanHorizon>);
      expect(field.hitTestable(), findsOneWidget);
      final control = find.descendant(
        of: field,
        matching: find.byType(DropdownButton<BilPlanHorizon>),
      );
      expect(
        tester
            .widget<DropdownButton<BilPlanHorizon>>(control)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(preferences().planCommits, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'nutrition-only requires no training setup or optional cloud permission',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
      await tester.pumpAndSettle();
      await _select<BilPlanHorizon>(tester, 'One week');
      await _select<BilPlanFocus>(tester, 'Nutrition only');
      expect(
        find.byType(DropdownButtonFormField<BilPlanEnvironment>),
        findsNothing,
      );
      await _select<MealPlanDiet>(tester, 'Balanced recipes');
      await _selectField<bool>(tester, 'symptoms', 'No');
      await _selectField<bool>(tester, 'medical', 'No');
      final adult = find.widgetWithText(CheckboxListTile, _adult);
      await tester.ensureVisible(adult);
      await tester.tap(adult);
      await tester.pump();
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await _until(
        tester,
        () => find
            .byKey(const ValueKey('bil-smart-plan-tabs'))
            .evaluate()
            .isNotEmpty,
      );
      final saved = await tester.runAsync(() => repository().readFor(_owner));
      expect(saved?.focus, BilPlanFocus.nutrition);
      expect(saved?.setup, isNull);
      expect(saved!.days.every((day) => day.workout == null), isTrue);
      expect(preferences().planCommits, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Home equipment is unanswered until an explicit item or No equipment choice',
    (tester) async {
      await mount(tester);
      await _openAndFill(tester);
      final mat = find.widgetWithText(CheckboxListTile, 'Exercise mat');
      await tester.ensureVisible(mat);
      await tester.tap(mat);
      await tester.pump();
      final none = find.widgetWithText(CheckboxListTile, 'No equipment');
      expect(tester.widget<CheckboxListTile>(none).value, isFalse);
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bil-smart-plan-missing-equipment')),
        findsOneWidget,
      );
      expect(preferences().planCommits, 0);
      await tester.tap(
        find.byKey(const ValueKey('bil-smart-plan-validation-cancel')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(none);
      await tester.tap(none);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(none).value, isTrue);
      expect(tester.widget<CheckboxListTile>(mat).value, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'medical Yes remains explicit and blocks preparation without being changed to No',
    (tester) async {
      await mount(tester);
      await _openAndFill(tester, exactReported: true);
      await _selectField<bool>(tester, 'medical', 'Yes');
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      expect(tester.widget<FilledButton>(prepare).onPressed, isNotNull);
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bil-smart-plan-medical-review')),
        findsOneWidget,
      );
      expect(preferences().planCommits, 0);
      await tester.tap(
        find.byKey(const ValueKey('bil-smart-plan-validation-cancel')),
      );
      await tester.pumpAndSettle();
      final medical = find.descendant(
        of: find.byKey(const ValueKey('bil-smart-plan-field-medical')),
        matching: find.byType(DropdownButtonFormField<bool>),
      );
      expect(
        tester.widget<DropdownButtonFormField<bool>>(medical).initialValue,
        isTrue,
      );
      expect(await tester.runAsync(() => repository().readFor(_owner)), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Arabic large-text missing-choice card stays RTL and scrollable without overflow',
    (tester) async {
      await mount(tester, locale: const Locale('ar'), width: 320, textScale: 2);
      await tester.ensureVisible(
        find.byKey(const ValueKey('bil-smart-plan-create')),
      );
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
      await tester.pumpAndSettle();
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      final dialog = find.byKey(
        const ValueKey('bil-smart-plan-required-choices'),
      );
      expect(dialog, findsOneWidget);
      expect(Directionality.of(tester.element(dialog)), TextDirection.rtl);
      expect(find.text('أكمل الاختيارات المطلوبة'), findsOneWidget);
      final target = find.byKey(
        const ValueKey('bil-smart-plan-missing-medical'),
      );
      await tester.ensureVisible(target);
      expect(target.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(preferences().planCommits, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'owner change closes validation and retired row callbacks cannot focus or submit for the next visit',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('bil-smart-plan-create')));
      await tester.pumpAndSettle();
      final prepare = find.byKey(const ValueKey('bil-smart-plan-review-draft'));
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      final oldTap = tester
          .widget<ListTile>(
            find.byKey(const ValueKey('bil-smart-plan-missing-horizon')),
          )
          .onTap!;
      final c = container();
      c.updateOverrides([
        databaseProvider.overrideWithValue(database()),
        preferencesRepositoryProvider.overrideWithValue(preferences()),
        verifiedEntitlementOwnerIdProvider.overrideWithValue(
          'synthetic-owner-B',
        ),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          const AsyncLoading(),
        ),
        bilSmartPlanClockProvider.overrideWithValue(() => _now),
      ]);
      await tester.pumpAndSettle();
      oldTap();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bil-smart-plan-required-choices')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('bil-smart-plan-review-draft')),
        findsNothing,
      );
      expect(preferences().planCommits, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
