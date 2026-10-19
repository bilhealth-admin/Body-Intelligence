// Negative owner-boundary fixture, pending its first visible validation.
// Actual Coach widget + actual Supabase Auth SDK + synthetic HTTP receipts.
// Gateway injects consentRequired to exercise the actual consent UI. It does
// not prove the production model gateway, published cloud or a native phone.
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Reuse the existing SQLite/ProviderScope/real Coach test mount, rather
// than a separate imitation consent dialog or a synthetic button harness.
import 'coach_review_actions_regression_test.dart' as scene;

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
const _question = 'How can I support my health during a demanding workday?';
// ModelBackedLocalCoachApi sends normalized syntax; the UI preserves casing.
// This explicit independent expected value is not computed from the subject.
const _normalizedQuestion =
    'how can i support my health during a demanding workday?';
const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _tts = MethodChannel('bil/tts');
const _accept = Key('ai-coach-remote-consent-accept');
const _decline = Key('ai-coach-remote-consent-decline');

Map<String, Object?> _session(String owner) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-dialog-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-13T00:00:00Z',
    },
  };
}

String _httpOwner(http.Request request) {
  final token = request.headers['authorization']!.split(' ').last;
  final claims =
      jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1])),
            ),
          )
          as Map;
  return claims['sub'] as String;
}

class _ConsentDialogBoundary {
  Supabase? sdk;
  late final SupabaseClient client;
  http.Client? transport;
  AppDatabase? database;
  late final _ConsentScenarioGateway gateway;
  GoRouter? router;
  StreamSubscription<AuthState>? observer;
  final events = <({String? delivered, String? current})>[];
  final reads = <String>[];
  final writes = <({String owner, bool granted})>[];
  final aiRequests = <({String owner, String question})>[];
  final allowed = <String, bool>{_a: false, _b: false};
  final storage = <String, String>{};
  Completer<void>? readGate;
  Completer<void>? heldReadEntered;
  bool failNextConsentWrite = false;
  Object? unexpectedHttpFailure;
  bool _nativeResourcesDisposed = false;

  Future<void> mount(WidgetTester tester) async {
    // The application SDK outlives this route. The widget binding must finish
    // its frame/microtask cleanup before native resources are disposed by the
    // test runner in its real asynchronous zone.
    addTearDown(_disposeNativeResources);
    SharedPreferences.setMockInitialValues({});
    // Importing the shared Coach scene does not run another file's main/setup.
    // Match the existing lifecycle fixture: text-only consent cases may stop
    // local speech during route disposal, but must never synthesize a reply.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_tts, (
      call,
    ) async {
      if (call.method != 'stop') {
        throw StateError('Unexpected native TTS method ${call.method}');
      }
      return null;
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_storage, (
      call,
    ) async {
      final args = Map<String, Object?>.from(
        call.arguments as Map? ?? const {},
      );
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return storage[key];
        case 'write':
          storage[key!] = args['value']! as String;
          return null;
        case 'delete':
          storage.remove(key);
          return null;
        case 'readAll':
          return storage;
        case 'containsKey':
          return storage.containsKey(key);
        default:
          throw StateError(
            'Unexpected synthetic secure-storage call ${call.method}',
          );
      }
    });
    transport = CommunityOwnerHttpClient(MockClient(_request));
    await tester.runAsync(() async {
      try {
        sdk = await Supabase.initialize(
          url: 'https://consent-dialog.invalid',
          publishableKey: 'synthetic-dialog-key',
          debug: false,
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),
          ),
          httpClient: transport!,
        );
      } finally {
        if (sdk == null) {
          // Preserve the original initialization error, but retain any SDK
          // resource created before asynchronous setup failed for teardown.
          try {
            sdk = Supabase.instance;
          } on AssertionError {
            // Supabase is still uninitialized after the expected setup failure.
          }
        }
      }
      client = sdk!.client;
      await client.auth.recoverSession(jsonEncode(_session(_a)));
    });
    observer = client.auth.onAuthStateChange.listen((state) {
      events.add((
        delivered: state.session?.user.id,
        current: client.auth.currentUser?.id,
      ));
    });
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: _a,
    );
    gateway = _ConsentScenarioGateway(this);
    if (tester.binding is LiveTestWidgetsFlutterBinding) {
      // Live binding has an independent logical test surface. Match the
      // unchanged shared Coach scene rather than its 800x600 default.
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(tester.binding.resetLayers);
    }
    router = await scene.mount(tester, database!, gateway: gateway);
    expect(unexpectedHttpFailure, isNull);
  }

  Future<http.Response> _request(http.Request request) async {
    try {
      Object? result;
      var status = 200;
      final owner = _httpOwner(request);
      switch (request.url.path) {
        case '/rest/v1/rpc/bil_get_remote_ai_consent':
          reads.add(owner);
          final receipt = allowed[owner] ?? false;
          if (readGate != null) {
            if (!heldReadEntered!.isCompleted) heldReadEntered!.complete();
            await readGate!.future;
          }
          result = {'granted': receipt, 'policy_version': '3'};
        case '/rest/v1/rpc/bil_record_consent':
          final body = jsonDecode(request.body) as Map;
          expect(body['p_purpose'], 'remote_ai');
          expect(body['p_policy_version'], '3');
          final granted = body['p_granted'] as bool;
          writes.add((owner: owner, granted: granted));
          if (failNextConsentWrite) {
            failNextConsentWrite = false;
            status = 503;
            result = {'message': 'Synthetic consent storage unavailable'};
          } else {
            allowed[owner] = granted;
            result = null;
          }
        case '/functions/v1/ai-coach-chat':
          final body = jsonDecode(request.body) as Map;
          expect(body['question'], _normalizedQuestion);
          expect(allowed[owner], isTrue);
          aiRequests.add((owner: owner, question: body['question'] as String));
          result = {'answer': 'Synthetic verified answer'};
        // These are read-only scene startup contracts, if the configured app
        // environment enables their normal widgets. Never fabricate a grant.
        case '/rest/v1/rpc/bil_get_ai_usage_status':
          expectSync(request.method, 'POST');
          expectSync(jsonDecode(request.body), isNull);
          result = {
            'credits': {'total_remaining': 0},
          };
        case '/rest/v1/rpc/bil_gold_balance_v1':
          result = {'balance': 0};
        case '/rest/v1/bil_coach_memories':
          expect(request.method, 'GET');
          result = <Object?>[];
        default:
          throw StateError(
            'Unexpected synthetic Coach HTTP ${request.method} ${request.url.path}',
          );
      }
      return http.Response(
        jsonEncode(result),
        status,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    } on Object catch (error) {
      unexpectedHttpFailure = error;
      rethrow;
    }
  }

  Future<void> crossOwner(WidgetTester tester, {required bool aba}) async {
    await tester.runAsync(() async {
      final toB = client.auth.recoverSession(jsonEncode(_session(_b)));
      final toA = aba
          ? client.auth.recoverSession(jsonEncode(_session(_a)))
          : null;
      await Future.wait([toB, ?toA]);
    });
    await tester.pumpAndSettle();
    expect(client.auth.currentUser?.id, aba ? _a : _b);
    expect(events.where((e) => e.delivered == _b), isNotEmpty);
    if (aba) {
      expect(events, contains((delivered: _b, current: _a)));
      expect(events.where((e) => e.delivered == _a), isNotEmpty);
    }
  }

  Future<void> close(WidgetTester tester) async {
    if (readGate != null && !readGate!.isCompleted) readGate!.complete();
    await scene.unmount(tester);
    await observer?.cancel();
    observer = null;
    // Coach dispose queues its last SQLite snapshot. Pump its fake-clock
    // continuations while bounded real yields allow native work to finish.
    // Do not close the SDK ahead of the binding's final frame cleanup.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
  }

  Future<void> _disposeNativeResources() async {
    if (_nativeResourcesDisposed) return;
    _nativeResourcesDisposed = true;
    if (readGate != null && !readGate!.isCompleted) readGate!.complete();
    await observer?.cancel();
    await database?.close();
    await sdk?.dispose();
    transport?.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_tts, null);
  }
}

// An explicit scenario boundary, not a substitute for production Gemini.
// Consent write/readback remains the unchanged production coordinator and SDK.
class _ConsentScenarioGateway extends scene.Gateway {
  _ConsentScenarioGateway(this.boundary);
  final _ConsentDialogBoundary boundary;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    questions.add(question);
    contexts.add(context);
    final receipt = await boundary.client.rpc('bil_get_remote_ai_consent');
    if (receipt is! Map ||
        receipt['granted'] != true ||
        receipt['policy_version'] != '3') {
      return const LocalModelResult(status: CoachServiceStatus.consentRequired);
    }
    final result = await boundary.client.functions.invoke(
      'ai-coach-chat',
      body: {'question': question},
    );
    return LocalModelResult.answer(
      LocalModelAnswer(
        text: (result.data as Map)['answer'] as String,
        action: null,
        processedOnDevice: false,
      ),
    );
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 60 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
    // Actual FunctionsClient uses YAJsonIsolate for body encode/decode. Fake
    // widget time alone does not deliver those native isolate messages.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  expect(ready(), isTrue, reason: 'The actual widget/SDK stage must complete.');
}

Future<void> _openConsent(
  WidgetTester tester,
  _ConsentDialogBoundary boundary,
) async {
  final questionField = find.byKey(const Key('ai-coach-question-field'));
  await _pumpUntil(tester, () {
    return questionField.evaluate().isNotEmpty &&
        tester.widget<TextField>(questionField).enabled == true;
  });
  await tester.enterText(questionField, _question);
  await tester.pump();
  final send = find.byKey(const Key('ai-coach-send-button'));
  expect(send.hitTestable(), findsOneWidget);
  await tester.tap(send);
  await tester.pump();
  await _pumpUntil(tester, () => find.byKey(_accept).evaluate().isNotEmpty);
  await tester.pumpAndSettle();
  // The production sheet is intentionally scroll-safe. On the live test view,
  // its disclosures can place the actions below the initial viewport; exercise
  // the same scroll the user needs before asserting pointer reachability.
  await tester.ensureVisible(find.byKey(_decline));
  expect(find.byKey(_accept).hitTestable(), findsOneWidget);
  expect(find.byKey(_decline).hitTestable(), findsOneWidget);
  expect(boundary.gateway.questions, hasLength(1));
  expect(boundary.writes, isEmpty);
  expect(boundary.aiRequests, isEmpty);
  expect(boundary.unexpectedHttpFailure, isNull);
  expect(tester.takeException(), isNull);
}

// Standalone synthetic SDK + SQLite widget fixture. Only this test file uses
// a real clock; all other test files keep their own default binding/isolate.
// Keep the same finite limit for every case despite Live's default no-timeout.
class _ConsentSdkLiveBinding extends LiveTestWidgetsFlutterBinding {
  @override
  Timeout get defaultTestTimeout => const Timeout(Duration(seconds: 60));
}

void main() {
  _ConsentSdkLiveBinding().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  final previousHitTestWarningIsFatal =
      WidgetController.hitTestWarningShouldBeFatal;
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal =
        previousHitTestWarningIsFatal;
  });
  for (final aba in [false, true]) {
    testWidgets(
      'actual Coach old Allow ${aba ? 'A B A' : 'A B'} cannot record consent or dispatch',
      (tester) async {
        final boundary = _ConsentDialogBoundary();
        try {
          await boundary.mount(tester);
          await _openConsent(tester, boundary);
          await boundary.crossOwner(tester, aba: aba);
          // This is the actual still-visible consent action, not a callback
          // imitation or direct call to grantAndVerify on the new account.
          final allow = find.byKey(_accept);
          // A safe implementation may already retire the old sheet on account
          // change. Otherwise the old visible Allow must have no side effect.
          if (allow.evaluate().isNotEmpty) {
            expect(allow.hitTestable(), findsOneWidget);
            await tester.tap(allow);
            await tester.pumpAndSettle();
          }
          expect(find.byKey(_accept), findsNothing);
          expect(boundary.writes, isEmpty);
          expect(boundary.aiRequests, isEmpty);
          expect(boundary.gateway.questions, hasLength(1));
          expect(boundary.unexpectedHttpFailure, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          await boundary.close(tester);
          TestAsyncUtils.verifyAllScopesClosed();
          await tester.pump();
          TestAsyncUtils.verifyAllScopesClosed();
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }

  testWidgets(
    'actual Coach fresh reviewed Allow records one owner receipt then one request',
    (tester) async {
      final boundary = _ConsentDialogBoundary();
      try {
        await boundary.mount(tester);
        await _openConsent(tester, boundary);
        await tester.tap(find.byKey(_accept));
        await _pumpUntil(tester, () => boundary.aiRequests.length == 1);
        await tester.pumpAndSettle();
        expect(boundary.writes, [(owner: _a, granted: true)]);
        expect(boundary.aiRequests, [
          (owner: _a, question: _normalizedQuestion),
        ]);
        expect(boundary.gateway.questions, [
          _normalizedQuestion,
          _normalizedQuestion,
        ]);
        expect(find.text('Synthetic verified answer'), findsOneWidget);
        expect(boundary.unexpectedHttpFailure, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await boundary.close(tester);
      }
    },
  );

  for (final back in [false, true]) {
    testWidgets(
      'actual Coach ${back ? 'native back' : 'Do not Allow'} sends nothing and permits a fresh review',
      (tester) async {
        final boundary = _ConsentDialogBoundary();
        try {
          await boundary.mount(tester);
          await _openConsent(tester, boundary);
          if (back) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byKey(_decline));
          }
          await tester.pumpAndSettle();
          expect(find.byKey(_accept), findsNothing);
          expect(boundary.writes, isEmpty);
          expect(boundary.aiRequests, isEmpty);
          expect(boundary.gateway.questions, [_normalizedQuestion]);
          final field = find.byKey(const Key('ai-coach-question-field'));
          expect(tester.widget<TextField>(field).enabled, isNot(false));
          await tester.enterText(field, _question);
          await tester.pump();
          await tester.tap(find.byKey(const Key('ai-coach-send-button')));
          await _pumpUntil(
            tester,
            () => find.byKey(_accept).evaluate().isNotEmpty,
          );
          // A newly built sheet must finish its entrance before pointer input.
          await tester.pumpAndSettle();
          expect(boundary.gateway.questions, [
            _normalizedQuestion,
            _normalizedQuestion,
          ]);
          expect(boundary.writes, isEmpty);
          expect(boundary.aiRequests, isEmpty);
          final freshDecline = find.byKey(_decline);
          await tester.ensureVisible(freshDecline);
          expect(freshDecline.hitTestable(), findsOneWidget);
          await tester.tap(freshDecline);
          await tester.pumpAndSettle();
          expect(boundary.unexpectedHttpFailure, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          await boundary.close(tester);
        }
      },
    );
  }

  testWidgets(
    'actual Coach route disposal retires its pending consent sheet without a request',
    (tester) async {
      final boundary = _ConsentDialogBoundary();
      try {
        await boundary.mount(tester);
        await _openConsent(tester, boundary);
        boundary.router!.go('/dashboard');
        await tester.pumpAndSettle();
        expect(find.byType(IntelligenceCenterPage), findsNothing);
        // If the root Navigator retained its pageless sheet, exercise that
        // actual stale action after the Coach owning it has been disposed.
        if (find.byKey(_accept).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(_accept));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(_accept), findsNothing);
        expect(boundary.writes, isEmpty);
        expect(boundary.aiRequests, isEmpty);
        expect(boundary.unexpectedHttpFailure, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await boundary.close(tester);
      }
    },
  );

  testWidgets(
    'actual Coach failed consent write retries through a fresh reviewed Allow',
    (tester) async {
      final boundary = _ConsentDialogBoundary()..failNextConsentWrite = true;
      try {
        await boundary.mount(tester);
        await _openConsent(tester, boundary);
        await tester.tap(find.byKey(_accept));
        await _pumpUntil(
          tester,
          () => find.byKey(const Key('ai-coach-retry')).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(boundary.writes, [(owner: _a, granted: true)]);
        expect(boundary.allowed[_a], isFalse);
        expect(boundary.aiRequests, isEmpty);
        expect(find.text(_question), findsOneWidget);
        final retry = find.byKey(const Key('ai-coach-retry'));
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await _pumpUntil(
          tester,
          () => find.byKey(_accept).evaluate().isNotEmpty,
        );
        // Built during the route transition is not yet physically tappable.
        // Match _openConsent: finish the entrance before the actual pointer.
        await tester.pumpAndSettle();
        expect(boundary.writes, [(owner: _a, granted: true)]);
        expect(boundary.aiRequests, isEmpty);
        final freshAllow = find.byKey(_accept);
        await tester.ensureVisible(find.byKey(_decline));
        expect(freshAllow.hitTestable(), findsOneWidget);
        await tester.tap(freshAllow);
        await _pumpUntil(tester, () => boundary.aiRequests.length == 1);
        await tester.pumpAndSettle();
        expect(boundary.writes, [
          (owner: _a, granted: true),
          (owner: _a, granted: true),
        ]);
        expect(boundary.aiRequests, [
          (owner: _a, question: _normalizedQuestion),
        ]);
        expect(boundary.unexpectedHttpFailure, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await boundary.close(tester);
      }
    },
  );

  testWidgets(
    'actual Coach grant readback A B A cannot resume the retired question',
    (tester) async {
      final boundary = _ConsentDialogBoundary();
      try {
        await boundary.mount(tester);
        await _openConsent(tester, boundary);
        boundary.readGate = Completer<void>();
        boundary.heldReadEntered = Completer<void>();
        await tester.tap(find.byKey(_accept));
        await _pumpUntil(tester, () => boundary.heldReadEntered!.isCompleted);
        expect(boundary.writes, [(owner: _a, granted: true)]);
        await boundary.crossOwner(tester, aba: true);
        boundary.readGate!.complete();
        await tester.pumpAndSettle();
        expect(boundary.aiRequests, isEmpty);
        expect(boundary.gateway.questions, [_normalizedQuestion]);
        expect(boundary.writes, [(owner: _a, granted: true)]);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('bil.remoteAi.denied.v3.$_a'), isTrue);
        expect(boundary.unexpectedHttpFailure, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await boundary.close(tester);
      }
    },
  );
}
