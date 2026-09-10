// Exercises the real Coach page and entitlement gate with controlled local I/O.
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
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
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

part 'support/coach_page_accessibility_cases.dart';
part 'support/coach_page_voice_cases.dart';
part 'support/coach_page_request_cases.dart';

class _HeldGateway implements LocalModelGateway {
  final replies = <Completer<LocalModelResult>>[];
  Completer<LocalModelResult> get reply => replies.first;
  int calls = 0;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) {
    calls++;
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
  int historyCount = 0,
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.iOS,
  double textScale = 1,
  Stream<String?>? owners,
}) async {
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (preferences != null)
          preferencesRepositoryProvider.overrideWithValue(preferences),
        intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
        intelligenceConversationClockProvider.overrideWithValue(
          () => DateTime(2026, 9, 9, 10),
        ),
        coachContextSnapshotProvider.overrideWith(
          (ref) async => CoachContextSnapshot.empty(),
        ),
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
        theme: BilFlagshipTheme.light(
          isArabic: arabic,
        ).copyWith(platform: platform),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.dragDetails != null) {
                  FocusManager.instance.primaryFocus?.unfocus();
                }
                return false;
              },
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _send(WidgetTester tester, _HeldGateway gateway) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    'hi',
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
  registerCoachAccessibilityCases();
  registerCoachVoiceCases();
  registerCoachRequestCases();
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
      tester.view.viewInsets = const FakeViewPadding(bottom: 310);
      await tester.pumpAndSettle();
      expect(
        tester
            .getBottomRight(find.byKey(const Key('ai-coach-question-field')))
            .dy,
        lessThanOrEqualTo(534),
      );
      await tester.drag(
        find.byType(SelectableText).hitTestable().first,
        const Offset(0, 170),
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
