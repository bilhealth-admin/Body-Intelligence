part of 'dashboard_unknown_nutrition_flow_test.dart';

Future<void> _mountEvidenceDashboard(
  WidgetTester tester,
  _NutritionFixture fixture,
  String language,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        dashboardClockProvider.overrideWithValue(() => _today),
        for (final section in DashboardSectionIds.all)
          dashboardSectionVisibleProvider(section).overrideWith(
            (_) => Stream.value(
              section == DashboardSectionIds.calories ||
                  section == DashboardSectionIds.macros,
            ),
          ),
        // Isolated presentation entitlement only; no repository or policy is
        // changed. Both primary cards remain visible for evidence assertions.
        verifiedSubscriptionAccessProvider.overrideWithValue(
          AsyncData(
            SubscriptionState(
              plan: CommercePlan.premium,
              entitlements: const {},
              authority: EntitlementAuthority.verifiedServer,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: DashboardGrid(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(PremiumDashboardBenchmark), findsOneWidget);
  expect(tester.takeException(), isNull);
}

PremiumDashboardBenchmark _renderedEvidence(WidgetTester tester) => tester
    .widget<PremiumDashboardBenchmark>(find.byType(PremiumDashboardBenchmark));

String _cardValue(WidgetTester tester, String key) {
  final value = tester.widget<Text>(find.byKey(Key(key)));
  return value.textSpan?.toPlainText() ?? value.data ?? '';
}

Future<void> _showEvidenceMacros(WidgetTester tester) async {
  final pageView = tester.widget<PageView>(
    find.byKey(const Key('dashboard-calories-macros-horizontal')),
  );
  pageView.controller!.jumpToPage(1);
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('dashboard-reference-macros-card')),
    findsOneWidget,
  );
}

List<String> _macroSemantics(WidgetTester tester) => tester
    .widgetList<Semantics>(
      find.descendant(
        of: find.byKey(const Key('dashboard-reference-macros-card')),
        matching: find.byType(Semantics),
      ),
    )
    .map((widget) => widget.properties.label ?? '')
    .where((label) => label.isNotEmpty)
    .toList();

void _dashboardUnknownNutritionWidgetCases(
  _NutritionFixture Function() current,
) {
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language real Dashboard shows unknown macros after1905 commit',
      (tester) async {
        final fixture = current();
        await fixture.quick(operation: 'widget-calories', calories: 1905);
        final rows = await fixture.database
            .select(fixture.database.mealItems)
            .get();
        try {
          await _mountEvidenceDashboard(tester, fixture, language);
          final rendered = _renderedEvidence(tester);
          expect(rendered.caloriesConsumed, 1905);
          expect(rendered.proteinConsumed, isNull);
          expect(rendered.carbohydratesConsumed, isNull);
          expect(rendered.fatConsumed, isNull);
          expect(
            _cardValue(tester, 'dashboard-reference-calorie-consumed-value'),
            startsWith('1,905  cal / '),
          );
          await _showEvidenceMacros(tester);
          final card = find.byKey(const Key('dashboard-reference-macros-card'));
          expect(
            find.descendant(
              of: card,
              matching: find.text('—', findRichText: true),
            ),
            findsNWidgets(3),
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text('0 g', findRichText: true),
            ),
            findsNothing,
          );
          final labels = _macroSemantics(tester);
          expect(labels, hasLength(3));
          expect(labels.every((label) => !label.contains(': 0 ')), isTrue);
          expect(
            labels.every(
              (label) => label.contains(
                language == 'ar' ? 'غير متاحة' : 'unavailable',
              ),
            ),
            isTrue,
          );
          expect(
            await fixture.database.select(fixture.database.mealItems).get(),
            rows,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets('$language actual calorie net and remaining stay unknown', (
      tester,
    ) async {
      final fixture = current();
      await fixture.quick(operation: 'widget-protein', protein: 20);
      try {
        await _mountEvidenceDashboard(tester, fixture, language);
        final rendered = _renderedEvidence(tester);
        expect(rendered.caloriesConsumed, isNull);
        expect(rendered.netCalories, isNull);
        expect(rendered.remainingCalories, isNull);
        expect(rendered.caloriesGoal, greaterThan(0));
        expect(
          _cardValue(tester, 'dashboard-reference-calorie-consumed-value'),
          startsWith('—  cal / '),
        );
        expect(
          _cardValue(tester, 'dashboard-reference-calorie-remaining-value'),
          '—',
        );
        final equation = find.byKey(const Key('dashboard-calorie-equation'));
        expect(
          find.descendant(of: equation, matching: find.text('—')),
          findsNWidgets(2),
        );
        await _showEvidenceMacros(tester);
        expect(find.text('20 g', findRichText: true), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('dashboard-reference-macros-card')),
            matching: find.text('—', findRichText: true),
          ),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets(
    'real Dashboard preserves explicit core zero and empty ledger zero',
    (tester) async {
      final fixture = current();
      try {
        await _mountEvidenceDashboard(tester, fixture, 'en');
        expect(_renderedEvidence(tester).caloriesConsumed, 0);
        expect(_renderedEvidence(tester).proteinConsumed, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await fixture.quick(
          operation: 'widget-zero',
          calories: 100,
          protein: 0,
          carbohydrates: 25,
          fat: 0,
        );
        await _mountEvidenceDashboard(tester, fixture, 'en');
        final rendered = _renderedEvidence(tester);
        expect(rendered.caloriesConsumed, 100);
        expect(rendered.proteinConsumed, 0);
        expect(rendered.fatConsumed, 0);
        await _showEvidenceMacros(tester);
        expect(find.text('0 g', findRichText: true), findsNWidgets(2));
        expect(find.text('25 g', findRichText: true), findsOneWidget);
        expect(
          _macroSemantics(tester).join(' '),
          isNot(contains('unavailable')),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
}
