import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
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
          BilFlagshipTheme.light(isArabic: language == 'ar'),
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
            child: visualEvidenceTextSurface(child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await settleVisualAssetImages(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'bil_app_settings':
          '{"localeCode":"en","themeMode":"light","reduceMotion":true}',
    }),
  );

  for (final language in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('workspace actual Flutter $language text $scale', (
        tester,
      ) async {
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
          onRoute: routes.add,
          onPhoto: () => photos++,
          onVoice: () => voices++,
        );
        await _mount(tester, page, db, key, language: language, scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('612 / 1200'), findsOneWidget);
        await _capture(tester, key, 'coach_workspace_${language}_$scale');
        final photo = find.text(language == 'ar' ? 'سجّل وجبة' : 'Log a Meal');
        await tester.ensureVisible(photo);
        await tester.pumpAndSettle();
        expect(photo.hitTestable(), findsOneWidget);
        await tester.tap(photo);
        expect(photos, 1);
        final voice = find.text(language == 'ar' ? 'تسجيل صوتي' : 'Voice Log');
        await tester.ensureVisible(voice);
        await tester.pumpAndSettle();
        expect(voice.hitTestable(), findsOneWidget);
        await tester.tap(voice);
        expect(voices, 1);
        final scan = find.text(language == 'ar' ? 'مسح منتج' : 'Scan Product');
        await tester.ensureVisible(scan);
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
          'coach_workspace_timeline_${language}_$scale',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }

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
      expect(routes, ['/plans']);
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
      await preferences.set(
        'intelligenceConversationV1',
        jsonEncode(transcript.map((m) => m.toJson()).toList()),
      );
      final key = GlobalKey();
      await _mount(tester, const IntelligenceCenterPage(), db, key);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
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
      await tester.tap(find.byKey(const Key('coach-workspace-tab-chat')));
      await tester.pumpAndSettle();
      expect(find.text('Keep this unfinished draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

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
