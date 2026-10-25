// Exercises the real Coach page and entitlement gate with controlled local I/O.
import '../../support/coach_conversation_entry.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import '../../visual_closure/visual_evidence_font.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_presentation_view.dart';
import 'support/coach_message_presentation_fixture.dart';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_brief_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_anchored_history.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/system_speech_disclosure_test_support.dart';

part 'support/coach_page_accessibility_cases.dart';
part 'support/coach_page_presentation_cases.dart';
part 'support/coach_page_voice_cases.dart';
part 'support/coach_page_request_cases.dart';
part 'support/coach_page_scroll_cases.dart';

class _HeldGateway implements LocalModelGateway {
  final replies = <Completer<LocalModelResult>>[];
  Completer<LocalModelResult> get reply => replies.first;
  int calls = 0;
  final conversations = <List<CoachConversationTurn>>[];
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) {
    calls++;
    conversations.add(List.unmodifiable(conversation));
    final pending = Completer<LocalModelResult>();
    replies.add(pending);
    return pending.future;
  }

  void finish({
    int index = 0,
    String text = 'A completed local fixture response.',
  }) => replies[index].complete(
    LocalModelResult.answer(LocalModelAnswer(text: text, action: null)),
  );
}

class _HeldPreferences extends PreferencesRepository {
  _HeldPreferences(super.database);
  Completer<String?>? heldHistory;
  bool failTranscriptRead = false;
  @override
  Future<String?> get(String key) {
    if (key == 'intelligenceConversationV1' && failTranscriptRead) {
      return Future.error(StateError('controlled local read failure'));
    }
    if (key == 'intelligenceConversationHistoryV1' && heldHistory != null) {
      return heldHistory!.future;
    }
    return super.get(key);
  }
}

Future<GoRouter> _mount(
  WidgetTester tester, {
  required AppDatabase database,
  required _HeldGateway gateway,
  bool gate = false,
  Future<Object?> Function()? usageLoader,
  PreferencesRepository? preferences,
  bool arabic = false,
  bool dark = false,
  bool highContrast = false,
  int historyCount = 0,
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.iOS,
  double textScale = 1,
  bool evidenceFonts = false,
  Stream<String?>? owners,
  CoachNativeOwnerWitness? messageOwnerWitness,
  Future<CoachContextSnapshot> Function()? contextLoader,
  Future<CoachContextSnapshot> Function()? briefLoader,
  bool waitForBrief = false,
}) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  const tts = MethodChannel('bil/tts');
  if (messenger.checkMockMessageHandler(tts.name, null)) {
    messenger.setMockMethodCallHandler(tts, (call) async {
      if (call.method != 'stop') throw MissingPluginException(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(tts, null));
  }
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  if (historyCount > 0) {
    await PreferencesRepository(database).set(
      'intelligenceConversationV1',
      jsonEncode(
        List.generate(
          historyCount,
          (i) => IntelligenceMessage(
            id: 'fixture-$i',
            role: i.isEven
                ? IntelligenceMessageRole.user
                : IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: arabic
                ? 'رسالة اختبار $i، هذا نص طويل لقراءة المحادثة والتحرك بين الرسائل.'
                : 'Fixture message $i. This is enough text to read and scroll through the actual conversation.',
            createdAt: DateTime(2026, 9, 9, 9, i),
          ).toJson(),
        ),
      ),
    );
  }
  final router = GoRouter(
    initialLocation: '/intelligence-center',
    routes: [
      GoRoute(
        path: '/intelligence-center',
        builder: (_, _) => gate
            ? const PremiumRouteGlassGate(
                feature: PremiumGateFeature.aiCoach,
                child: IntelligenceCenterPage(),
              )
            : const IntelligenceCenterPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Audit dashboard')),
      ),
    ],
  );
  addTearDown(router.dispose);
  // Close subscribers before NativeDatabase.close even when an assertion fails.
  // The previous fixture waited for database shutdown with a live page mounted.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  final fixtureTheme =
      (dark
              ? BilFlagshipTheme.dark(
                  isArabic: arabic,
                  highContrast: highContrast,
                )
              : BilFlagshipTheme.light(
                  isArabic: arabic,
                  highContrast: highContrast,
                ))
          .copyWith(platform: platform);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (messageOwnerWitness != null)
          coachNativeOwnerWitnessProvider.overrideWithValue(
            messageOwnerWitness,
          ),
        intelligenceCoachMealVisionConsentProvider.overrideWithValue(
          (_) async => true,
        ),
        if (preferences != null)
          preferencesRepositoryProvider.overrideWithValue(preferences),
        intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
        intelligenceConversationClockProvider.overrideWithValue(
          () => DateTime(2026, 9, 9, 10),
        ),
        coachContextSnapshotProvider.overrideWith(
          (ref) async => contextLoader == null
              ? CoachContextSnapshot.empty()
              : await contextLoader(),
        ),
        if (briefLoader != null)
          coachHealthBriefProvider.overrideWith((ref) => briefLoader()),
        intelligenceHealthContextProvider.overrideWith(
          (ref) async => const IntelligenceHealthContext(
            primaryMessage: '',
            explanation: [],
            confidence: 1,
            evidence: [],
            missingData: [],
          ),
        ),
        verifiedSubscriptionStateProvider.overrideWith(
          (ref) async => SubscriptionState(
            plan: CommercePlan.premiumAiCoach,
            entitlements: {},
            authority: EntitlementAuthority.verifiedServer,
            currentPeriodEndsAt: DateTime(2030),
            isPurchasable: false,
            canRestorePurchases: false,
          ),
        ),
        storefrontTargetPlanProvider.overrideWith(
          (ref) async => CommercePlan.premiumAiCoach,
        ),
        verifiedEntitlementOwnerProvider.overrideWith(
          (ref) => owners ?? Stream.value('audit-owner'),
        ),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(
          usageLoader ??
              () async => <String, Object?>{
                'credits': <String, Object?>{'total_remaining': 1000},
              },
        ),
      ],
      child: MaterialApp.router(
        locale: Locale(arabic ? 'ar' : 'en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: evidenceFonts
            ? visualEvidenceTheme(
                fixtureTheme,
                fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
              )
            : fixtureTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            highContrast: highContrast,
          ),
          child: RepaintBoundary(
            key: const ValueKey('coach-screen-capture-root'),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await openCoachConversationFromOverview(tester);
  await tester.pumpAndSettle();
  if (waitForBrief) await _settleBoundedBrief(tester);
  return router;
}

Future<void> _settleBoundedBrief(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(IntelligenceCenterPage)),
  );
  // pumpAndSettle drains frames, not SQLite's native I/O. Observe the real
  // bounded provider rather than replacing its data with a fake brief.
  final timer = Stopwatch()..start();
  while (container.read(coachHealthBriefProvider).isLoading &&
      timer.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    // Riverpod schedules dependency refreshes with the next Flutter frame.
    await tester.pump();
  }
  final state = container.read(coachHealthBriefProvider);
  expect(state.isLoading, isFalse, reason: 'Real bounded brief stayed pending');
  expect(state.hasError, isFalse, reason: '${state.error}');
  expect(tester.takeException(), isNull);
  await tester.pumpAndSettle();
}

Future<void> _send(
  WidgetTester tester,
  _HeldGateway gateway, {
  String question = 'hi',
}) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    question,
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  for (var i = 0; i < 100 && gateway.calls == 0; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(gateway.calls, 1);
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  registerCoachPresentationPageCases();
  registerCoachRevealViewportCases();
  registerCoachAccessibilityCases();
  registerCoachVoiceCases();
  registerCoachRequestCases();
  registerCoachScrollCases();
  testWidgets('Coach welcome brief stays anchored during a data refresh', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final refresh = Completer<CoachContextSnapshot>();
    var loads = 0;
    Future<CoachContextSnapshot> loadBrief() {
      loads++;
      return loads == 1
          ? Future.value(CoachContextSnapshot.empty())
          : refresh.future;
    }

    try {
      await _mount(
        tester,
        database: database,
        gateway: _HeldGateway(),
        briefLoader: loadBrief,
        waitForBrief: true,
      );
      const rowKey = ValueKey('coach-session-brief');
      final row = find.byKey(rowKey);
      final title = find.text('Let’s make the first decision');
      expect(row, findsOneWidget);
      expect(title, findsOneWidget);
      final initialRow = tester.getRect(row);
      final initialTitle = tester.getRect(title);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(IntelligenceCenterPage)),
      );

      container.invalidate(coachHealthBriefProvider);
      await tester.pump();

      expect(container.read(coachHealthBriefProvider).isRefreshing, isTrue);
      expect(row, findsOneWidget);
      expect(title, findsOneWidget);
      expect(tester.getRect(row), initialRow);
      expect(tester.getRect(title), initialTitle);

      refresh.complete(
        CoachContextSnapshot(
          generatedAt: DateTime(2026, 9, 9, 10),
          profile: const {'profileSaved': true},
          weights: const [],
          nutritionDays: const [],
          waterHistory: const [],
          computedHealth: const {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(rowKey), findsOneWidget);
      expect(find.text('I’m ready for today'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      if (!refresh.isCompleted) {
        refresh.complete(CoachContextSnapshot.empty());
      }
      await _unmount(tester);
      await tester.runAsync(database.close);
    }
  });
  testWidgets(
    'successful reply must preserve coach state and unsent draft through valid credit refresh',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _HeldGateway();
      var holdUsage = false;
      final refreshedUsage = Completer<Object?>();
      await _mount(
        tester,
        database: database,
        gateway: gateway,
        gate: true,
        usageLoader: () async => holdUsage
            ? await refreshedUsage.future
            : <String, Object?>{
                'credits': <String, Object?>{'total_remaining': 1000},
              },
      );
      final originalState = tester.state(find.byType(IntelligenceCenterPage));
      await _send(tester, gateway);
      await tester.enterText(
        find.byKey(const Key('ai-coach-question-field')),
        'My next unsent message',
      );
      holdUsage = true;
      gateway.finish();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final disappeared = find
          .byType(IntelligenceCenterPage)
          .evaluate()
          .isEmpty;
      final loading = find
          .byKey(const ValueKey('premium-route-access-checking'))
          .evaluate()
          .isNotEmpty;
      refreshedUsage.complete(<String, Object?>{
        'credits': <String, Object?>{'total_remaining': 999},
      });
      await tester.pumpAndSettle();
      final newState = tester.state(find.byType(IntelligenceCenterPage));
      final draft = tester
          .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
          .controller!
          .text;
      final list = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView).first,
      );
      final newest = tester
          .widget<CoachMessageText>(find.byType(CoachMessageText).first)
          .text;
      debugPrint(
        'AUDIT_REFRESH disappeared=$disappeared loading=$loading stateRecreated=${!identical(originalState, newState)} draft="$draft" offset=${list.controller!.offset} newest="$newest"',
      );
      await _unmount(tester);
      expect(
        disappeared,
        isFalse,
        reason:
            'A successful response and positive balance must not unmount the chat.',
      );
      expect(identical(originalState, newState), isTrue);
      expect(draft, 'My next unsent message');
    },
  );

  for (final arabic in [false, true]) {
    testWidgets('iOS-themed transcript scroll and keyboard Arabic=$arabic', (
      tester,
    ) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _mount(
        tester,
        database: database,
        gateway: _HeldGateway(),
        arabic: arabic,
        historyCount: 35,
      );
      final listFinder = find.byType(CustomScrollView).first;
      final scroll = tester.widget<CustomScrollView>(listFinder).controller!;
      expect(scroll.offset, closeTo(0, .5));
      final textFinder = find.byType(SelectableText).hitTestable().first;
      await tester.drag(textFinder, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(
        scroll.offset,
        greaterThan(72),
        reason: 'Dragging message text must reach older messages.',
      );
      await tester.tap(find.byKey(const ValueKey('chat-jump-to-latest')));
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(0, .5));
      await tester.tap(find.byKey(const Key('ai-coach-question-field')));
      final composer = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('ai-coach-question-field')),
          matching: find.byType(EditableText),
        ),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 310);
      await tester.pumpAndSettle();
      expect(composer.focusNode.hasFocus, isTrue);
      expect(
        tester
            .getBottomRight(find.byKey(const Key('ai-coach-question-field')))
            .dy,
        lessThanOrEqualTo(534),
      );
      final historyViewport = tester.getRect(find.byType(CoachAnchoredHistory));
      await tester.dragFrom(
        Offset(historyViewport.left + 2, historyViewport.center.dy),
        const Offset(0, 170),
      );
      await tester.pumpAndSettle();
      expect(
        composer.focusNode.hasFocus,
        isFalse,
        reason:
            'Dragging the message history should dismiss the keyboard itself.',
      );
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }

  testWidgets('incoming reply must keep the message being read in the same place', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final gateway = _HeldGateway();
    await _mount(
      tester,
      database: database,
      gateway: gateway,
      historyCount: 35,
    );
    await _send(tester, gateway);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 470),
    );
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView).first)
        .controller!;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (!scroll.position.isScrollingNotifier.value) break;
    }
    expect(scroll.position.isScrollingNotifier.value, isFalse);
    final offsetBefore = scroll.offset;
    expect(
      offsetBefore,
      greaterThan(72),
      reason:
          'The user must actually be reading older messages before the new response.',
    );
    final viewport = tester.getRect(find.byType(ChatHistoryViewport));
    final anchor =
        find.byType(CoachMessageText).evaluate().firstWhere((element) {
              final widget = element.widget as CoachMessageText;
              final rect = tester.getRect(find.byKey(widget.key!));
              return widget.text.contains('Fixture message') &&
                  rect.top > viewport.top + 100 &&
                  rect.bottom < viewport.bottom - 100;
            }).widget
            as CoachMessageText;
    final anchorFinder = find.byKey(anchor.key!);
    final before = tester.getTopLeft(anchorFinder).dy;
    gateway.finish();
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(anchorFinder).dy;
    debugPrint(
      'AUDIT_SCROLL anchor=${anchor.key} before=$before after=$after drift=${after - before} offsetBefore=$offsetBefore offsetAfter=${scroll.offset}',
    );
    await _unmount(tester);
    expect(
      after,
      closeTo(before, .5),
      reason:
          'Keeping only the numeric offset does not keep the same message visible after prepending to a reversed list.',
    );
  });

  testWidgets(
    'leaving coach while history loads must not use a disposed WidgetRef',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final preferences = _HeldPreferences(database);
      final router = await _mount(
        tester,
        database: database,
        gateway: _HeldGateway(),
        preferences: preferences,
      );
      preferences.heldHistory = Completer<String?>();
      await tester.tap(
        find.byKey(const Key('ai-coach-conversation-history-button')),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      preferences.heldHistory!.complete(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets('rapidly opening history creates only one sheet', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = _HeldPreferences(database);
    await _mount(
      tester,
      database: database,
      gateway: _HeldGateway(),
      preferences: preferences,
    );
    preferences.heldHistory = Completer<String?>();
    final history = find.byKey(
      const Key('ai-coach-conversation-history-button'),
    );
    await tester.tap(history);
    await tester.tap(history);
    preferences.heldHistory!.complete(null);
    await tester.pumpAndSettle();
    final sheets = find
        .byType(BottomSheet, skipOffstage: false)
        .evaluate()
        .length;
    debugPrint('AUDIT_HISTORY overlappingSheets=$sheets');
    await _unmount(tester);
    expect(
      sheets,
      1,
      reason: 'One history action must not stack duplicate sheets.',
    );
  });
}

void registerCoachRevealViewportCases() {
  for (final arabic in [false, true]) {
    testWidgets(
      'full long reply arrives softly at stable geometry AR=$arabic light 320 2x',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = _HeldGateway();
        try {
          await tester.runAsync(loadVisualEvidenceFont);
          await _mount(
            tester,
            database: database,
            gateway: gateway,
            gate: true,
            arabic: arabic,
            size: const Size(320, 844),
            textScale: 2,
            evidenceFonts: true,
          );
          await _send(tester, gateway);
          final reply = List.generate(
            26,
            (i) => arabic
                ? 'فقرة تركيبية $i: هذه قراءة محلية واضحة لا تحفظ طعامًا ولا تغير الحساب.'
                : 'Synthetic paragraph $i: this readable answer performs no write or account change.',
          ).join('\n');
          gateway.finish(text: reply);
          final row = find.byWidgetPredicate(
            (widget) => widget is CoachMessageText && widget.text == reply,
          );
          for (var frame = 0; frame < 20 && row.evaluate().isEmpty; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            row,
            findsOneWidget,
            reason: 'Actual page must append the answer.',
          );
          final replyStyle = tester.widget<CoachMessageText>(row).style;
          final starterStyle = Theme.of(
            tester.element(row),
          ).textTheme.bodyMedium;
          expect(
            replyStyle?.fontSize,
            (starterStyle?.fontSize ?? 14) + 1,
            reason:
                'Coach replies use the slightly enlarged conversation body size.',
          );
          expect(
            replyStyle?.fontFamily,
            starterStyle?.fontFamily,
            reason: 'Coach replies use the same typeface as starter guidance.',
          );
          expect(
            replyStyle?.fontWeight,
            starterStyle?.fontWeight,
            reason: 'Coach replies retain the shared body font weight.',
          );
          final messageTextKey =
              tester.widget<CoachMessageText>(row).key! as ValueKey<String>;
          final messageId = messageTextKey.value.replaceFirst(
            'coach-message-text-',
            '',
          );
          final replyCard = find.byKey(
            ValueKey('ai-coach-reply-card-$messageId'),
          );
          expect(replyCard, findsOneWidget);
          expect(
            tester.getSize(replyCard).width,
            greaterThan(290),
            reason:
                'The incoming Coach reply card should fill the wider chat column.',
          );
          final selectable = find.descendant(
            of: row,
            matching: find.byType(SelectableText),
          );
          expect(
            tester.widget<SelectableText>(selectable).data,
            reply,
            reason:
                'The complete validated answer is present before the soft entrance.',
          );
          final arrival = find.byKey(
            ValueKey('coach-reply-arrival-fade-$messageId'),
          );
          expect(arrival, findsOneWidget);
          final editableFinder = find.descendant(
            of: row,
            matching: find.byType(EditableText),
          );
          final viewport = find.byType(ChatHistoryViewport);
          final scroll = tester
              .widget<ChatHistoryViewport>(viewport)
              .controller;
          final samples = <Map<String, Object?>>[];
          for (var frame = 0; frame < 12; frame++) {
            final visibleText = tester.widget<SelectableText>(selectable).data!;
            final editable = tester
                .state<EditableTextState>(editableFinder)
                .renderEditable;
            final selectionLength = visibleText.characters
                .take(8)
                .join()
                .length;
            final glyphBoxes = editable.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: selectionLength),
            );
            final viewportRect = tester.getRect(viewport);
            var visibleGlyphArea = 0.0;
            for (final box in glyphBoxes) {
              final local = box.toRect();
              final global = local.shift(editable.localToGlobal(Offset.zero));
              final overlap = global.intersect(viewportRect);
              if (overlap.width > 0 && overlap.height > 0) {
                visibleGlyphArea += overlap.width * overlap.height;
              }
            }
            samples.add({
              'virtualFrame': frame,
              'visibleGraphemes': visibleText.characters.length,
              'visibleGlyphArea': visibleGlyphArea,
              'scrollPixels': scroll.offset,
              'replyOpacity': tester
                  .widget<FadeTransition>(arrival)
                  .opacity
                  .value,
              'messageHeight': tester.getSize(row).height,
            });
            await tester.pump(const Duration(milliseconds: 16));
          }
          // Emit source/case metrics before asserting so a genuine failure is
          // preserved. Virtual frame geometry is not a real device latency P95.
          debugPrint(
            'BIL_REPLY_ARRIVAL_WIDGET_GEOMETRY ${jsonEncode({'scope': 'actual_page_widget_virtual_frames_not_device_P95', 'font': arabic ? 'NotoArabicEvidence' : 'RobotoEvidence', 'arabic': arabic, 'theme': 'light', 'width': 320, 'textScale': 2, 'samples': samples})}',
          );
          expect(
            samples
                .skip(1)
                .any((sample) => (sample['visibleGlyphArea'] as num) > 0),
            isTrue,
            reason:
                'The complete reply must settle inside the actual chat viewport.',
          );
          expect(samples.map((x) => x['messageHeight']).toSet(), hasLength(1));
          expect(tester.takeException(), isNull);
        } finally {
          for (final pending in gateway.replies) {
            if (!pending.isCompleted) {
              pending.complete(
                LocalModelResult.answer(
                  LocalModelAnswer(
                    text: 'Synthetic fixture cancelled.',
                    action: null,
                  ),
                ),
              );
            }
          }
          try {
            await _unmount(tester); // TTS mock handler is still registered.
          } finally {
            await tester.runAsync(database.close);
          }
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }

  testWidgets(
    'wide tablet history expands while header and composer stay put',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = _HeldGateway();
      try {
        await _mount(
          tester,
          database: database,
          gateway: gateway,
          gate: true,
          size: const Size(1024, 900),
        );
        await _send(tester, gateway);
        gateway.finish(text: 'Wide tablet reply for the layout contract.');
        await tester.pump(const Duration(milliseconds: 340));

        final row = find.byWidgetPredicate(
          (widget) =>
              widget is CoachMessageText &&
              widget.text == 'Wide tablet reply for the layout contract.',
        );
        expect(row, findsOneWidget);
        final messageTextKey =
            tester.widget<CoachMessageText>(row).key! as ValueKey<String>;
        final messageId = messageTextKey.value.replaceFirst(
          'coach-message-text-',
          '',
        );
        expect(
          tester
              .getSize(find.byKey(ValueKey('ai-coach-reply-card-$messageId')))
              .width,
          greaterThan(880),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('ai-coach-hero'))).width,
          closeTo(760, .1),
        );
        expect(
          tester
              .getSize(find.byKey(const Key('ai-coach-composer-surface')))
              .width,
          closeTo(760, .1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        for (final pending in gateway.replies) {
          if (!pending.isCompleted) {
            pending.complete(
              LocalModelResult.answer(
                LocalModelAnswer(
                  text: 'Synthetic fixture cancelled.',
                  action: null,
                ),
              ),
            );
          }
        }
        try {
          await _unmount(tester);
        } finally {
          await tester.runAsync(database.close);
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'capture actual Coach reply preview from Flutter',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = _HeldGateway();
      try {
        await _mount(
          tester,
          database: database,
          gateway: gateway,
          gate: true,
          arabic: true,
          evidenceFonts: true,
          size: const Size(390, 844),
        );
        Future<void> savePreview(String filename) async {
          if (Platform.environment['BIL_CAPTURE_COACH_RELEASE'] == '0') return;
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('coach-screen-capture-root')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            try {
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              const outputDirectory = 'build/coach-reply-preview';
              final directory = Directory(outputDirectory);
              await directory.create(recursive: true);
              final file = File('${directory.path}/$filename');
              await file.writeAsBytes(png!.buffer.asUint8List());
              debugPrint('BIL_COACH_REPLY_PREVIEW ${file.absolute.path}');
            } finally {
              image.dispose();
            }
          });
        }

        final firstDayEvidenceIcon = tester.widget<Icon>(
          find.byKey(const Key('ai-coach-day-one-guidance-evidence')),
        );
        expect(firstDayEvidenceIcon.icon, Icons.verified_rounded);
        expect(firstDayEvidenceIcon.color, const Color(0xFF56C878));
        await savePreview('coach-first-open-ar.png');
        await _send(tester, gateway, question: 'كيف أراجع وجبتي؟');
        const previewReply =
            'سأراجع وجبتك المسجلة وأعرض السعرات والماكروز بوضوح. هذه معاينة اختبارية ولا تضيف طعامًا إلى سجلك.';
        gateway.finish(text: previewReply);
        final previewReplyFinder = find.byWidgetPredicate(
          (widget) => widget is CoachMessageText && widget.text == previewReply,
        );
        for (
          var frame = 0;
          frame < 60 && previewReplyFinder.evaluate().isEmpty;
          frame++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(previewReplyFinder, findsOneWidget);
        final helpfulButton = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.key.toString().contains('ai-coach-feedback-helpful-'),
        );
        final notHelpfulButton = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.key.toString().contains('ai-coach-feedback-not-helpful-'),
        );
        final helpfulIcon =
            tester.widget<IconButton>(helpfulButton).icon as AnimatedScale;
        final notHelpfulIcon =
            tester.widget<IconButton>(notHelpfulButton).icon as AnimatedScale;
        expect((helpfulIcon.child as Text).data, '👍');
        expect((notHelpfulIcon.child as Text).data, '👎');
        final helpfulStyle = (helpfulIcon.child as Text).style!;
        expect(helpfulStyle.fontFamily, 'Apple Color Emoji');
        expect(
          helpfulStyle.fontFamilyFallback,
          containsAll(<String>[
            'Segoe UI Emoji',
            'Apple Color Emoji',
            'Noto Color Emoji',
          ]),
        );
        await tester.pump(const Duration(milliseconds: 360));
        expect(tester.takeException(), isNull);
        await savePreview('coach-reply-ar.png');
      } finally {
        for (final pending in gateway.replies) {
          if (!pending.isCompleted) {
            pending.complete(
              LocalModelResult.answer(
                LocalModelAnswer(
                  text: 'Synthetic fixture cancelled.',
                  action: null,
                ),
              ),
            );
          }
        }
        try {
          await _unmount(tester);
        } finally {
          await tester.runAsync(database.close);
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'old history remains anchored during actual new reply reveal and keyboard closing',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = _HeldGateway();
      try {
        await tester.runAsync(loadVisualEvidenceFont);
        await _mount(
          tester,
          database: database,
          gateway: gateway,
          gate: true,
          historyCount: 35,
          arabic: true,
          evidenceFonts: true,
        );
        await _send(tester, gateway);
        final viewport = find.byType(ChatHistoryViewport);
        final scroll = tester.widget<ChatHistoryViewport>(viewport).controller;
        final gesture = await tester.startGesture(tester.getCenter(viewport));
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(0, 7));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 160));
        final oldOffset = scroll.offset;
        gateway.finish(
          text: List.filled(
            20,
            'إجابة تركيبية جديدة ينبغي ألا تقطع قراءة الرسائل السابقة.',
          ).join('\n'),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 32));
          expect(scroll.offset, closeTo(oldOffset, .5));
        }
        for (final inset in [240.0, 160.0, 0.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pump(const Duration(milliseconds: 32));
        }
        expect(scroll.offset, closeTo(oldOffset, .5));
        expect(tester.takeException(), isNull);
      } finally {
        for (final pending in gateway.replies) {
          if (!pending.isCompleted) {
            pending.complete(
              LocalModelResult.answer(
                LocalModelAnswer(
                  text: 'Synthetic fixture cancelled.',
                  action: null,
                ),
              ),
            );
          }
        }
        try {
          await _unmount(tester); // Runs before _mount teardown callbacks.
        } finally {
          await tester.runAsync(database.close);
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
