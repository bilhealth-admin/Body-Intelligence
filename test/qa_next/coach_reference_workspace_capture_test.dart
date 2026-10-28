import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/shared/widgets/bil_reference_bottom_bar.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../visual_closure/visual_evidence_font.dart';
import '../support/coach_conversation_entry.dart';

final _clock = DateTime(2026, 10, 5, 9, 41);
final _snapshot = CoachContextSnapshot(
  generatedAt: _clock,
  profile: const {'displayName': 'Alex'},
  weights: [
    CoachWeightPoint(
      at: _clock.subtract(const Duration(minutes: 50)),
      kg: 91.2,
    ),
  ],
  nutritionDays: const [
    CoachNutritionDay(
      day: '2026-10-05',
      meals: [
        {'type': 'breakfast', 'items': []},
      ],
      calories: 612,
      protein: 48,
      carbs: 26,
      fat: 24,
      sodium: 460,
    ),
  ],
  waterHistory: [
    {
      'amountMl': 500,
      'at': _clock.subtract(const Duration(minutes: 10)).toIso8601String(),
    },
  ],
  activityHistory: const [
    {'day': '2026-10-05', 'steps': 1086},
  ],
  computedHealth: const {
    'dailyTargets': {
      'caloriesKcal': 1200,
      'proteinG': 150,
      'carbsG': 50,
      'fatG': 65,
    },
  },
);

SubscriptionState _subscription(bool premium) => SubscriptionState(
  plan: premium ? CommercePlan.premiumAiCoach : CommercePlan.free,
  entitlements: premium ? {CommerceEntitlement.advancedIntelligence} : {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: true,
  canRestorePurchases: true,
);

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['BIL_REFERENCE_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _mount(
  WidgetTester tester,
  Widget child,
  AppDatabase db,
  GlobalKey key, {
  String language = 'en',
  bool premium = true,
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: '/intelligence-center',
    routes: [
      GoRoute(path: '/intelligence-center', builder: (_, _) => child),
      for (final route in [
        '/dashboard',
        '/daily-log',
        '/community',
        '/settings',
        '/plans',
        '/analytics',
        '/analytics/nutrition',
        '/history',
        '/plan',
        '/weight-history',
        '/daily-log/water',
        '/connected-health/steps',
      ])
        GoRoute(
          path: route,
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: Text('Route: $route')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          AsyncData(_subscription(premium)),
        ),
        // This synthetic account declares both verified subscription and
        // authoritative quota access. A paid plan alone is not a quota proof.
        aiCoachCreditAccessProvider.overrideWith((ref) async => premium),
        coachContextSnapshotProvider.overrideWith((ref) async => _snapshot),
        intelligenceConversationClockProvider.overrideWithValue(() => _clock),
        intelligenceHealthContextProvider.overrideWith(
          (ref) async => const IntelligenceHealthContext(
            primaryMessage: '',
            explanation: [],
            confidence: 1,
            evidence: [],
            missingData: [],
          ),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: visualEvidenceTheme(
          dark
              ? BilFlagshipTheme.dark(isArabic: language == 'ar')
              : BilFlagshipTheme.light(isArabic: language == 'ar'),
          fontFamily: language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: key,
            child: visualEvidenceTextSurface(
              child,
              fontFamily: language == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await settleVisualAssetImages(tester);
  await tester.pumpAndSettle();
}

Future<void> _revealWorkspaceAction(WidgetTester tester, Finder action) async {
  if (action.evaluate().isEmpty) {
    final vertical = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up),
    );
    await tester.scrollUntilVisible(
      action,
      150,
      scrollable: vertical.first,
      maxScrolls: 40,
    );
  } else {
    await tester.ensureVisible(action);
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'bil_app_settings':
          '{"localeCode":"en","themeMode":"light","reduceMotion":true}',
    }),
  );

  for (final dark in [false, true]) {
    for (final language in ['en', 'ar']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'workspace actual Flutter $language text $scale ${dark ? 'dark' : 'light'}',
          (tester) async {
            final db = AppDatabase.forTesting(NativeDatabase.memory());
            addTearDown(db.close);
            final key = GlobalKey();
            var photos = 0;
            var voices = 0;
            final routes = <String>[];
            final page = CoachReferenceWorkspace(
              snapshot: _snapshot,
              now: _clock,
              onChat: () {},
              onQuickAdd: () {},
              onRoute: routes.add,
              onPhoto: () => photos++,
              onVoice: () => voices++,
            );
            await _mount(
              tester,
              page,
              db,
              key,
              language: language,
              scale: scale,
              dark: dark,
            );
            expect(tester.takeException(), isNull);
            final coachTab = find.byKey(const Key('coach-workspace-tab-coach'));
            expect(
              find.descendant(
                of: coachTab,
                matching: find.byIcon(Icons.smart_toy_outlined),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: coachTab,
                matching: find.text(language == 'ar' ? 'المدرب' : 'Coach'),
              ),
              findsOneWidget,
            );
            expect(find.text('612 / 1200'), findsOneWidget);
            expect(find.text('Premium AI Coach'), findsOneWidget);
            expect(find.text('Pro'), findsNothing);
            final valueText = tester.widget<Text>(find.text('612 / 1200'));
            expect(valueText.textDirection, TextDirection.ltr);
            // Phone values retain readable type rather than wrapping one card
            // into a taller row or shrinking all four values to fit.
            expect(valueText.style!.fontSize, greaterThanOrEqualTo(14));
            expect(
              tester.getRect(find.text('612 / 1200')).top,
              tester.getRect(find.text('48 / 150 g')).top,
            );
            expect(
              tester.getRect(find.text('26 / 50 g')).top,
              greaterThan(tester.getRect(find.text('612 / 1200')).bottom),
            );
            final valueContext = tester.element(find.text('612 / 1200'));
            final scheme = Theme.of(valueContext).colorScheme;
            final greeting = find.byKey(const Key('coach-workspace-greeting'));
            expect(
              tester.widget<Text>(greeting).style!.color,
              scheme.onSurface,
            );
            expect(tester.getRect(greeting).top, greaterThanOrEqualTo(0));
            expect(
              tester.getRect(greeting).bottom,
              lessThanOrEqualTo(
                tester
                    .getRect(
                      find.byKey(const Key('coach-workspace-plan-label')),
                    )
                    .top,
              ),
            );
            expect(valueText.style!.color, scheme.onSurface);
            for (final label in [
              language == 'ar' ? 'السعرات' : 'Calories',
              language == 'ar' ? 'البروتين' : 'Protein',
              language == 'ar' ? 'الكربوهيدرات' : 'Carbs',
              language == 'ar' ? 'الدهون' : 'Fat',
            ]) {
              final ink = tester.widget<Text>(find.text(label)).style!.color!;
              final back = dark
                  ? const Color(0xFF30485C)
                  : const Color(0xFFEBF3FA);
              final a = ink.computeLuminance(), b = back.computeLuminance();
              final contrast = a > b
                  ? (a + .05) / (b + .05)
                  : (b + .05) / (a + .05);
              expect(
                contrast,
                greaterThanOrEqualTo(4.5),
                reason: '$label readable across the panel gradient',
              );
            }
            await _capture(
              tester,
              key,
              'coach_workspace_${language}_${scale}_${dark ? 'dark' : 'light'}',
            );
            final photo = find.text(
              language == 'ar' ? 'سجّل وجبة' : 'Log a Meal',
            );
            await _revealWorkspaceAction(tester, photo);
            await tester.pumpAndSettle();
            expect(photo.hitTestable(), findsOneWidget);
            await tester.tap(photo);
            expect(photos, 1);
            final voice = find.text(
              language == 'ar' ? 'تسجيل صوتي' : 'Voice Log',
            );
            await _revealWorkspaceAction(tester, voice);
            await tester.pumpAndSettle();
            expect(voice.hitTestable(), findsOneWidget);
            await tester.tap(voice);
            expect(voices, 1);
            final scan = find.text(
              language == 'ar' ? 'مسح منتج' : 'Scan Product',
            );
            await _revealWorkspaceAction(tester, scan);
            await tester.pumpAndSettle();
            expect(scan.hitTestable(), findsOneWidget);
            await tester.tap(scan);
            expect(routes.last, '/daily-log?foodLog=1&action=barcode');
            await tester.drag(find.byType(ListView), const Offset(0, -1000));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await _capture(
              tester,
              key,
              'coach_workspace_timeline_${language}_${scale}_${dark ? 'dark' : 'light'}',
            );
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          },
        );
      }
    }
  }

  testWidgets(
    'workspace preserves a known zero target separately from missing intake',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final snapshot = CoachContextSnapshot(
        generatedAt: _clock,
        profile: const {},
        weights: const [],
        waterHistory: const [],
        nutritionDays: const [
          CoachNutritionDay(
            day: '2026-10-05',
            meals: [],
            calories: 0,
            protein: 0,
            carbs: 497,
            fat: 0,
            sodium: 0,
            knownTotals: {'proteinG'},
          ),
        ],
        computedHealth: const {
          'dailyTargets': {
            'caloriesKcal': 1200,
            'proteinG': 0,
            'carbsG': 50,
            'fatG': 65,
          },
        },
      );
      await _mount(
        tester,
        CoachReferenceWorkspace(
          snapshot: snapshot,
          now: _clock,
          onChat: () {},
          onQuickAdd: () {},
          onRoute: (_) {},
          onPhoto: () {},
          onVoice: () {},
        ),
        db,
        GlobalKey(),
      );
      expect(find.text('0 / 0 g'), findsOneWidget);
      expect(find.text('— / 50 g'), findsOneWidget);
      expect(find.text('497 / 50 g'), findsNothing);
      expect(
        tester.widget<Text>(find.text('0 / 0 g')).textDirection,
        TextDirection.ltr,
      );
      for (final bar in tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      )) {
        expect(bar.value, 0);
        expect(bar.value!.isFinite, isTrue);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'locked nutrition preserves labels but hides values and targets',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final key = GlobalKey();
      final routes = <String>[];
      await _mount(
        tester,
        CoachReferenceWorkspace(
          snapshot: _snapshot,
          now: _clock,
          onChat: () {},
          onQuickAdd: () {},
          onRoute: routes.add,
          onPhoto: () {},
          onVoice: () {},
        ),
        db,
        key,
        premium: false,
      );
      expect(find.text('Calories'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('612 / 1200'), findsNothing);
      expect(find.text('48 / 150 g'), findsNothing);
      await tester.tap(find.text('Calories'));
      expect(routes, ['/analytics/nutrition']);
      expect(
        routes,
        isNot(contains('/plans')),
        reason: 'the visible feature label is not an automatic purchase trap',
      );
      await _capture(tester, key, 'coach_workspace_locked');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'real conversation restores SQLite transcript and preserves draft on overview return',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final preferences = PreferencesRepository(db);
      final transcript = [
        IntelligenceMessage(
          id: 'fixture-user-1',
          role: IntelligenceMessageRole.user,
          kind: IntelligenceMessageKind.coach,
          text: 'سجل فطوري: ٣ بيضات مسلوقة، كوب حليب خالي الدسم، طماطم وخيار.',
          createdAt: _clock.subtract(const Duration(minutes: 29)),
        ),
        IntelligenceMessage(
          id: 'fixture-answer-1',
          role: IntelligenceMessageRole.bil,
          kind: IntelligenceMessageKind.coach,
          text:
              'I understand your breakfast:\n\n• 3 boiled eggs (150 g)\n• Skim milk (200 ml)\n• Tomato — portion to confirm\n• Cucumber — portion to confirm\n\nThis is a saved conversation example. Nothing is added to your food log until a real action is confirmed.',
          createdAt: _clock.subtract(const Duration(minutes: 28)),
        ),
      ];
      await tester.runAsync(
        () => preferences.set(
          'intelligenceConversationV1',
          jsonEncode(transcript.map((m) => m.toJson()).toList()),
        ),
      );
      final key = GlobalKey();
      await _mount(tester, const IntelligenceCenterPage(), db, key);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await openCoachConversationFromOverview(tester);
      expect(find.byKey(const Key('ai-coach-question-field')), findsOneWidget);
      expect(find.byKey(const Key('bil-reference-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'coach_conversation_persisted');
      await tester.enterText(
        find.byKey(const Key('ai-coach-question-field')),
        'Keep this unfinished draft',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Coach controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachReferenceWorkspace), findsOneWidget);
      await tester.tap(find.byKey(const Key('coach-workspace-tab-coach')));
      await tester.pumpAndSettle();
      expect(find.text('Keep this unfinished draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('bil-reference-nav-2')));
      await tester.pumpAndSettle();
      expect(find.byType(BilQuickAddSheet), findsOneWidget);
      expect(
        jsonDecode(
          (await tester.runAsync(
            () async => (await preferences.get('intelligenceConversationV1'))!,
          ))!,
        ),
        transcript.map((message) => message.toJson()).toList(),
      );
      await settleVisualAssetImages(tester);
      await tester.pumpAndSettle();
      await _capture(tester, key, 'coach_quick_add_draft_preserved');
      Navigator.of(tester.element(find.byType(BilQuickAddSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Keep this unfinished draft'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bil-reference-nav-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-add-primary-0')));
      await tester.pumpAndSettle();
      final destination = tester.element(find.text('Route: /daily-log'));
      expect(GoRouterState.of(destination).uri.path, '/daily-log');
      expect(GoRouterState.of(destination).uri.queryParameters, {
        'foodLog': '1',
        'from': '/intelligence-center',
      });
      expect(find.byType(BilQuickAddSheet), findsNothing);
      Navigator.of(destination).pop();
      await tester.pumpAndSettle();
      expect(find.text('Keep this unfinished draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  for (final language in ['en', 'ar']) {
    testWidgets(
      'Coach robot is the single conversation entry and Back preserves state in $language',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final preferences = PreferencesRepository(db);
        final savedMessage = IntelligenceMessage(
          id: 'single-coach-entry-$language',
          role: IntelligenceMessageRole.user,
          kind: IntelligenceMessageKind.coach,
          text: 'Saved conversation entry fixture',
          createdAt: _clock.subtract(const Duration(minutes: 20)),
        );
        final savedJson = jsonEncode([savedMessage.toJson()]);
        await tester.runAsync(
          () => preferences.set('intelligenceConversationV1', savedJson),
        );
        await _mount(
          tester,
          const IntelligenceCenterPage(),
          db,
          GlobalKey(),
          language: language,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        final coach = find.byKey(const Key('coach-workspace-tab-coach'));
        expect(coach, findsOneWidget);
        expect(
          find.descendant(
            of: coach,
            matching: find.text(language == 'ar' ? 'المدرب' : 'Coach'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: coach,
            matching: find.byIcon(Icons.smart_toy_outlined),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('coach-workspace-open-chat')),
          findsNothing,
        );
        expect(find.text('Open Coach conversation'), findsNothing);
        expect(find.text('افتح محادثة المدرب'), findsNothing);
        await tester.tap(coach);
        await tester.pumpAndSettle();
        final composer = find.byKey(const Key('ai-coach-question-field'));
        expect(composer, findsOneWidget);
        expect(find.byType(CoachReferenceWorkspace), findsNothing);
        const draft = 'Keep this unsent conversation draft';
        await tester.enterText(composer, draft);
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(language == 'ar' ? 'رجوع' : 'Back'));
        await tester.pumpAndSettle();
        expect(find.byType(CoachReferenceWorkspace), findsOneWidget);
        expect(find.text('Route: /dashboard'), findsNothing);
        await tester.tap(coach);
        await tester.pumpAndSettle();
        expect(find.text(draft), findsOneWidget);
        expect(
          find.byKey(const Key('bil-reference-navigation')),
          findsOneWidget,
        );
        expect(
          await tester.runAsync(
            () => preferences.get('intelligenceConversationV1'),
          ),
          savedJson,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  }

  testWidgets('shared dock keeps five accessible destinations', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BilReferenceBottomBar(
            selected: 3,
            onSelected: selected.add,
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(Key('bil-reference-nav-$i')));
    }
    expect(selected, [0, 1, 2, 3, 4]);
    expect(tester.takeException(), isNull);
  });
}
