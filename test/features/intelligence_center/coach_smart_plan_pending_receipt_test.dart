import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_action_receipt.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/coach_conversation_entry.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
final _now = DateTime.utc(2026, 11, 17, 12);

class _ReceiptPreferences extends PreferencesRepository {
  _ReceiptPreferences(super.database);
  bool measuring = false;
  int pendingReads = 0;
  int planWrites = 0;
  bool _planKey(String key) => key.startsWith('bil.smart-plan.');

  @override
  Future<String?> get(String key) {
    if (measuring && key.startsWith('bil.smart-plan.draft.')) pendingReads++;
    return super.get(key);
  }

  @override
  Future<String> update(
    String key,
    String Function(String?) derive, {
    bool Function()? isCurrent,
  }) {
    if (measuring && _planKey(key)) planWrites++;
    return super.update(key, derive, isCurrent: isCurrent);
  }

  @override
  Future<bool> mutateIfUnchanged({
    required Map<String, String?> expected,
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
    bool Function()? isCurrent,
  }) {
    if (measuring && (set.keys.any(_planKey) || remove.any(_planKey))) {
      planWrites++;
    }
    return super.mutateIfUnchanged(
      expected: expected,
      set: set,
      remove: remove,
      isCurrent: isCurrent,
    );
  }
}

class _ReceiptGateway implements LocalModelGateway {
  _ReceiptGateway(this.tool, this.arguments);
  final String tool;
  final Map<String, Object?> arguments;
  int calls = 0;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    calls++;
    return LocalModelResult.answer(
      LocalModelAnswer(
        text: 'The prepared action is ready for your review.',
        action: {'name': tool, 'arguments': arguments},
        processedOnDevice: false,
      ),
    );
  }
}

Map<String, Object?> _session(String owner) => {
  'access_token':
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800}))).replaceAll('=', '')}.fixture',
  'refresh_token': 'synthetic-not-a-secret',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'app_metadata': {},
    'user_metadata': {},
    'aud': 'authenticated',
    'created_at': '2026-11-17T00:00:00Z',
  },
};

SubscriptionState _access({bool paid = true}) => SubscriptionState(
  plan: paid ? CommercePlan.premium : CommercePlan.free,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: false,
);

Future<void> _until(WidgetTester tester, bool Function() done) async {
  final watch = Stopwatch()..start();
  while (!done() && watch.elapsed < const Duration(seconds: 12)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(
    done(),
    isTrue,
    reason: 'Real caller must complete the observed stage.',
  );
}

Future<String?> _readWithFrames(
  WidgetTester tester,
  PreferencesRepository preferences,
  String key,
) async {
  String? value;
  Object? failure;
  StackTrace? failureStack;
  var completed = false;
  await tester.runAsync(() async {
    unawaited(
      preferences
          .get(key)
          .then<void>(
            (result) {
              value = result;
              completed = true;
            },
            onError: (Object error, StackTrace stack) {
              failure = error;
              failureStack = stack;
              completed = true;
            },
          ),
    );
  });
  // The page persists its tool receipt after returning. Keep frames moving
  // while the real executor drains, rather than blocking its write queue
  // inside runAsync. Read once; preserve the exact original-value assertion.
  await _until(tester, () => completed);
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('bil/tts'),
          (call) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('bil/tts'), null);
  });
  setUpAll(() async {
    const catalog = BilSmartPlanCatalog();
    await catalog.gymSessions(sessionMinutes: 75);
    await catalog.sourcedRecipes(dietary: const DietaryPreferences());
  });

  for (final mode in [
    'valid-pending',
    'valid-current',
    'wrong-id',
    'wrong-revision',
    'wrong-owner-pending',
    'wrong-tool-receipt',
    'other-tool',
    'unverified-catalog',
    'access-retired',
    'owner-A-B-A',
  ]) {
    testWidgets('real Coach caller pending receipt $mode', (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      Supabase? sdk;
      AppDatabase? database;
      ProviderContainer? container;
      GoRouter? router;
      try {
        await tester.runAsync(() async {
          sdk = await Supabase.initialize(
            url: 'https://smart-plan-receipt.invalid',
            publishableKey: 'synthetic-publishable-key',
            debug: false,
            authOptions: const FlutterAuthClientOptions(
              autoRefreshToken: false,
              detectSessionInUri: false,
              localStorage: EmptyLocalStorage(),
            ),
            httpClient: MockClient((request) async {
              expect(request.url.host, 'smart-plan-receipt.invalid');
              return http.Response(
                '{}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          );

          await sdk!.client.auth.recoverSession(jsonEncode(_session(_owner)));
        });
        expect(sdk!.client.auth.currentUser!.id, _owner);
        database = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: _owner,
        );
        final preferences = _ReceiptPreferences(database);
        final plain = PreferencesRepository(database);
        final plans = BilSmartPlanRepository(
          preferences: preferences,
          currentOwnerId: () => _owner,
        );
        late BilSmartPlan approved;
        late BilSmartPlan draft;
        await tester.runAsync(() async {
          const catalog = BilSmartPlanCatalog();

          final workouts = await catalog.gymSessions(sessionMinutes: 75);

          final recipes = await catalog.sourcedRecipes(
            dietary: const DietaryPreferences(),
          );

          BilSmartPlan make(String id) => const BilSmartPlanEngine().generate(
            BilPlanCreationRequest(
              ownerId: _owner,
              planId: id,
              startOn: _now,
              horizon: BilPlanHorizon.month,
              focus: BilPlanFocus.combined,
              workoutsPerWeek: 3,
              confirmedPreferences: true,
              adultConfirmed: true,
              ageYears: 30,
              workoutCatalog: workouts,
              recipeCatalog: recipes,
              setup: BilPlanSetup(
                environment: BilPlanEnvironment.gym,
                experience: BilPlanExperience.beginner,
                sessionMinutes: 75,
                equipment: {'gym'},
              ),
            ),
            _now,
          );
          draft = make('synthetic-pending-draft');
          await catalog.validate(draft, const DietaryPreferences());
          if (mode == 'valid-current') {
            approved = draft;
            await plans.save(approved, expectedRevision: 0);
          } else {
            final base = make('synthetic-approved-plan');
            await plans.save(base, expectedRevision: 0);
            approved = base.withStatus(BilPlanStatus.active, _now);
            await plans.save(approved, expectedRevision: 1);
            await plans.stageDraft(draft, approved: approved);
          }
          if (mode == 'wrong-owner-pending' || mode == 'unverified-catalog') {
            final malformed =
                jsonDecode(draft.encode()) as Map<String, dynamic>;
            if (mode == 'wrong-owner-pending') {
              malformed['ownerId'] = _other;
            } else {
              final days = malformed['days'] as List;
              final day = days.cast<Map>().firstWhere(
                (row) => row['workout'] != null,
              );
              (day['workout'] as Map)['templateId'] =
                  'synthetic-unreleased-session';
            }
            // Controlled malformed-storage fixture; production repository is
            // then the actual fail-closed reader. No Auth/cloud row is written.
            await plain.set(
              plans.draftKey(_owner),
              jsonEncode({
                'base': approved.encode(),
                'draft': jsonEncode(malformed),
              }),
            );
          }
        });
        final approvedBefore = await tester.runAsync(
          () => plain.get(plans.storageKey(_owner)),
        );

        final pendingBefore = await tester.runAsync(
          () => plain.get(plans.draftKey(_owner)),
        );

        final tool = mode == 'other-tool'
            ? 'request_smart_plan_revision'
            : 'create_smart_plan_draft';
        final gateway = _ReceiptGateway(
          tool,
          tool == 'create_smart_plan_draft'
              ? {'horizon': 'month', 'focus': 'combined'}
              : {'planId': approved.id, 'revision': approved.revision},
        );
        var currentAccess = _access();
        List<Override> overrides() => [
          databaseProvider.overrideWithValue(database!),
          preferencesRepositoryProvider.overrideWithValue(preferences),
          verifiedEntitlementOwnerIdProvider.overrideWithValue(_owner),
          verifiedSubscriptionAccessProvider.overrideWithValue(
            AsyncData(currentAccess),
          ),
          intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
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
        ];
        container = ProviderContainer(overrides: overrides());
        router = GoRouter(
          initialLocation: '/coach',
          routes: [
            GoRoute(
              path: '/coach',
              builder: (_, _) => const IntelligenceCenterPage(),
            ),
            GoRoute(
              path: '/smart-plan',
              builder: (context, _) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey('return-committed-receipt'),
                    onPressed: () => context.pop(
                      BilActionReceipt(
                        actionId: draft.id,
                        committed: true,
                        completedAt: _now,
                        entityType: 'smart_plan',
                        entityId: mode == 'wrong-id'
                            ? 'wrong-synthetic-id'
                            : draft.id,
                        toolId: mode == 'wrong-tool-receipt'
                            ? 'request_smart_plan_revision'
                            : tool,
                        after: {
                          'revision': mode == 'wrong-revision'
                              ? draft.revision + 1
                              : draft.revision,
                        },
                      ),
                    ),
                    child: const Text('Return committed fixture receipt'),
                  ),
                ),
              ),
            ),
          ],
        );
        preferences.measuring = true;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
            ),
          ),
        );

        await openCoachConversationFromOverview(tester);

        await tester.enterText(
          find.byKey(const Key('ai-coach-question-field')),
          mode == 'other-tool'
              ? 'Revise my plan'
              : 'أريد إنشاء خطة تمارين وتغذية لمدة شهر',
        );

        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pump();
        await _until(tester, () {
          final send = find.byKey(const Key('ai-coach-send-button'));
          return send.evaluate().isNotEmpty &&
              tester.widget<IconButton>(send).onPressed != null;
        });

        await tester.runAsync(
          () => tester.tap(find.byKey(const Key('ai-coach-send-button'))),
        );

        // Enter the actual deterministic Smart Plan route from a real user
        // request. This receipt test does not depend on model/catalog fallback.
        final back = find.byKey(const ValueKey('return-committed-receipt'));
        await _until(tester, () => back.evaluate().isNotEmpty);
        if (mode == 'access-retired') {
          currentAccess = _access(paid: false);
          container.updateOverrides(overrides());
          await tester.pump();
        }
        if (mode == 'owner-A-B-A') {
          final dynamic pendingCaller = tester.state(
            find.byType(IntelligenceCenterPage, skipOffstage: false),
          );
          final capturedEpoch = pendingCaller.conversationPersistenceEpoch;
          expect(pendingCaller.coachMessageVisitCancelled, isFalse);
          await tester.runAsync(
            () => sdk!.client.auth.recoverSession(jsonEncode(_session(_other))),
          );
          await tester.pump();
          expect(sdk!.client.auth.currentUser!.id, _other);
          expect(
            pendingCaller.coachMessageVisitCancelled,
            isTrue,
            reason: 'The existing production raw-auth observer must deliver B.',
          );
          await tester.runAsync(
            () => sdk!.client.auth.recoverSession(jsonEncode(_session(_owner))),
          );
          await tester.pump();
          expect(sdk!.client.auth.currentUser!.id, _owner);
          expect(
            pendingCaller.coachMessageVisitCancelled,
            isTrue,
            reason: 'Returning to A must not revive the retired page visit.',
          );
          expect(
            pendingCaller.conversationPersistenceEpoch,
            capturedEpoch,
            reason:
                'Current-owner/epoch equality alone misses this actual ABA.',
          );
        }

        await tester.runAsync(() => tester.tap(back));

        await tester.pump();

        await _until(
          tester,
          () => find.byType(IntelligenceCenterPage).evaluate().isNotEmpty,
        );
        final dynamic state = tester.state(find.byType(IntelligenceCenterPage));
        await _until(tester, () => (state.executingActionKeys as Set).isEmpty);
        final messages = state.messages as List;
        final receipts = messages
            .where(
              (dynamic message) =>
                  message.text == 'Plan change saved and verified.' &&
                  (message.evidence as List).contains(
                    'BIL verified tool result',
                  ),
            )
            .toList();
        final accepted = mode == 'valid-pending' || mode == 'valid-current';
        expect(receipts.length, accepted ? 1 : 0);
        if (accepted) {
          final evidence = (receipts.single as dynamic).evidence as List;
          final receipt = evidence
              .whereType<String>()
              .where((row) => row.startsWith('{'))
              .map((row) => jsonDecode(row) as Map)
              .single;
          expect(receipt['entity_id'], draft.id);
          expect((receipt['after'] as Map)['revision'], draft.revision);
          expect(receipt['committed'], isTrue);
        }
        final shouldReadPending = ![
          'valid-current',
          'wrong-tool-receipt',
          'other-tool',
          'access-retired',
          'owner-A-B-A',
        ].contains(mode);
        expect(preferences.pendingReads, shouldReadPending ? 1 : 0);
        expect(preferences.planWrites, 0);
        expect(
          await _readWithFrames(tester, plain, plans.storageKey(_owner)),
          approvedBefore,
        );
        expect(
          await _readWithFrames(tester, plain, plans.draftKey(_owner)),
          pendingBefore,
        );
        expect(gateway.calls, 0);
        expect(tester.takeException(), isNull);
      } catch (error) {
        rethrow;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(Duration.zero);
        router?.dispose();
        container?.dispose();
        var closed = database == null;
        Object? closeError;
        await tester.runAsync(() async {
          database?.close().then(
            (_) => closed = true,
            onError: (Object error) {
              closeError = error;
              closed = true;
            },
          );
        });
        // Owner-bound writes started by the real page can still finish after
        // unmount. Advance widget microtasks while awaiting executor shutdown.
        await _until(tester, () => closed);
        expect(closeError, isNull);
        await tester.runAsync(() async {
          await sdk?.dispose();
        });
      }
    });
  }
}
