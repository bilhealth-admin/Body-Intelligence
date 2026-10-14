// Draft only. Run through the visible owner-approved focused runner at SAFE.
// Uses the real pinned Supabase/Functions/Auth clients; only OS and remote I/O
// are synthetic. It is not a published-provider or native-phone intelligence test.
import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/app/security/bil_mobile_integrity_service.dart';
import 'package:body_intelligence_log/app/security/bil_play_integrity_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
Map<String, Object?> _session(String owner, {bool expired = false}) => {
  'access_token':
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': expired ? 1600000000 : 4102444800}))).replaceAll('=', '')}.fixture',
  'refresh_token': 'synthetic-$owner',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'app_metadata': {},
    'user_metadata': {},
    'aud': 'authenticated',
    'created_at': '2026-10-13T00:00:00Z',
  },
};
String _requestOwner(http.Request request) {
  final token = request.headers['authorization']!.split(' ').last;
  return (jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1])),
            ),
          )
          as Map)['sub']
      as String;
}

enum _Gap {
  iosSupport,
  iosAssertion,
  androidToken,
  functionEncoding,
  providerResponse,
  tokenRefresh,
}

enum _Move { sameOwner, otherOwner, roundTrip }

class _HeldJson extends YAJsonIsolate {
  _HeldJson(this.gap, this.entered, this.release);
  final _Gap gap;
  final Completer<void> entered, release;
  bool held = false;
  @override
  Future<String> encode(Object? value) async {
    if (gap == _Gap.functionEncoding &&
        !held &&
        value is Map &&
        value.containsKey('messages')) {
      held = true;
      entered.complete();
      await release.future;
    }
    return super.encode(value);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  for (final gap in _Gap.values) {
    for (final move in _Move.values) {
      test('real SDK Coach owner ${move.name} across ${gap.name}', () async {
        SharedPreferences.setMockInitialValues({});
        final entered = Completer<void>(), release = Completer<void>();
        final isolate = _HeldJson(gap, entered, release);
        await isolate.initialize();
        final requests = <({String path, String owner, Object? body})>[];
        var didHoldNative = false, refreshCount = 0;
        late SupabaseClient client;
        final httpClient = CommunityOwnerHttpClient(
          MockClient((request) async {
            final path = request.url.path;
            final body = request.body.isEmpty ? null : jsonDecode(request.body);
            if (path.startsWith('/auth/v1/')) {
              if (path != '/auth/v1/token') {
                throw StateError('Unexpected Auth fixture route');
              }
              refreshCount++;
              if (gap == _Gap.tokenRefresh && refreshCount == 1) {
                entered.complete();
                await release.future;
              }
              return http.Response(
                jsonEncode(_session(_a)),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            final owner = _requestOwner(request);
            requests.add((path: path, owner: owner, body: body));
            Object? response;
            if (path == '/rest/v1/rpc/bil_get_remote_ai_consent') {
              if (gap == _Gap.tokenRefresh && refreshCount == 0) {
                await client.auth.setInitialSession(
                  jsonEncode(_session(_a, expired: true)),
                );
              }
              response = {'granted': true, 'policy_version': '3'};
            } else if (path == '/functions/v1/app-attest') {
              final operation = (body as Map)['operation'];
              response = operation == 'challenge'
                  ? {
                      'challenge_id': 'synthetic-challenge',
                      'challenge': base64Url
                          .encode(List.filled(32, 7))
                          .replaceAll('=', ''),
                      'registration_required': false,
                    }
                  : {
                      'allowed': true,
                      'grant': {'id': 'fixture-native-grant'},
                    };
            } else if (path == '/functions/v1/play-integrity') {
              response = {
                'allowed': true,
                'trustworthy': true,
                'grant': {'id': 'fixture-native-grant'},
              };
            } else if (path == '/functions/v1/ai-coach') {
              if (gap == _Gap.providerResponse) {
                entered.complete();
                await release.future;
              }
              response = {
                'reply': 'Isolated local HTTP fixture answer',
                'response_id': 'fixture-response',
              };
            } else {
              throw StateError('Unexpected data route: $path');
            }
            return http.Response(
              jsonEncode(response),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        final platform = gap == _Gap.androidToken
            ? TargetPlatform.android
            : TargetPlatform.iOS;
        debugDefaultTargetPlatformOverride = platform;
        const ios = MethodChannel('bil/app_attest'),
            android = MethodChannel('bil/play_integrity');
        binding.defaultBinaryMessenger.setMockMethodCallHandler(ios, (
          call,
        ) async {
          if ((gap == _Gap.iosSupport && call.method == 'isSupported') ||
              (gap == _Gap.iosAssertion &&
                  call.method == 'generateAssertion')) {
            if (!didHoldNative) {
              didHoldNative = true;
              entered.complete();
              await release.future;
            }
          }
          return switch (call.method) {
            'isSupported' => true,
            'keyId' => 'synthetic-key-$_a',
            'generateAssertion' => base64Encode(List.filled(32, 9)),
            'discardKey' => null,
            _ => throw StateError('Unexpected native method: ${call.method}'),
          };
        });
        binding.defaultBinaryMessenger.setMockMethodCallHandler(android, (
          call,
        ) async {
          if (call.method == 'requestToken' &&
              gap == _Gap.androidToken &&
              !didHoldNative) {
            didHoldNative = true;
            entered.complete();
            await release.future;
          }
          return switch (call.method) {
            'prepare' => true,
            'requestToken' => 'synthetic-native-token',
            _ => throw StateError('Unexpected Android method'),
          };
        });
        Supabase? singleton;
        StreamSubscription<AuthState>? observer;
        try {
          singleton = await Supabase.initialize(
            url: 'https://bootstrap.invalid',
            publishableKey: 'synthetic-bootstrap',
            debug: false,
            accessToken: () async => 'synthetic-bootstrap',
            httpClient: MockClient(
              (request) async => http.Response('{}', 200, request: request),
            ),
          );
          await singleton.client.dispose();
          client = SupabaseClient(
            'https://coach-owner-sdk.invalid',
            'synthetic-publishable',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: httpClient,
            isolate: isolate,
          );
          singleton.client = client;
          await client.auth.recoverSession(jsonEncode(_session(_a)));
          final deliveredB = Completer<void>(), deliveredA = Completer<void>();
          observer = client.auth.onAuthStateChange.listen((event) {
            final id = event.session?.user.id;
            if (id == _b && !deliveredB.isCompleted) deliveredB.complete();
            if (id == _a && deliveredB.isCompleted && !deliveredA.isCompleted) {
              deliveredA.complete();
            }
          });
          final gateway = LlamaCppLocalGateway(
            mobileIntegrityService: BilMobileIntegrityService(
              playIntegrity: BilPlayIntegrityService.forTesting(
                cloudProjectNumber: 123456,
              ),
              integrityRequired: () => true,
            ),
          );
          final answer = gateway.answer(
            question: 'What is my weight?',
            locale: 'en',
            context: CoachContextSnapshot(
              generatedAt: DateTime.utc(2026, 10, 13),
              profile: {'currentWeightKg': 83.5},
              weights: [],
              nutritionDays: [],
              waterHistory: [],
              computedHealth: {},
            ),
          );
          await Future.any<void>([
            entered.future,
            answer.then((result) {
              if (!entered.isCompleted) {
                throw StateError(
                  'Gateway ended before ${gap.name}: '
                  'status=${result.status.name} '
                  'diagnostic=${result.diagnosticCode} '
                  'routes=${requests.map((item) => item.path).toList()}',
                );
              }
            }),
          ]).timeout(const Duration(seconds: 15));
          final deliveredBefore = requests.toList();
          if (move != _Move.sameOwner) {
            await client.auth.recoverSession(jsonEncode(_session(_b)));
            await deliveredB.future.timeout(const Duration(seconds: 5));
            if (move == _Move.roundTrip) {
              await client.auth.recoverSession(jsonEncode(_session(_a)));
              await deliveredA.future.timeout(const Duration(seconds: 5));
            }
          } else if (gap != _Gap.tokenRefresh) {
            await client.auth.recoverSession(jsonEncode(_session(_a)));
          }
          release.complete();
          final outcome = await answer.timeout(const Duration(seconds: 15));
          if (move == _Move.sameOwner) {
            expect(outcome.status, CoachServiceStatus.ready);
            final calls = requests
                .where((r) => r.path == '/functions/v1/ai-coach')
                .toList();
            expect(calls, hasLength(1));
            expect(calls.single.owner, _a);
            expect((calls.single.body as Map)['context'], isNotEmpty);
            for (final call in requests) {
              expect(call.owner, _a, reason: call.path);
            }
          } else {
            expect(
              outcome.status,
              isNot(CoachServiceStatus.ready),
              reason:
                  'A stale native/SDK task must not revive after owner change.',
            );
            final later = requests.skip(deliveredBefore.length).toList();
            expect(
              later,
              isEmpty,
              reason:
                  'No challenge/assertion/context request may cross transport after observed A/B or ABA.',
            );
            if (gap != _Gap.providerResponse) {
              expect(
                requests.where((r) => r.path == '/functions/v1/ai-coach'),
                isEmpty,
              );
            }
          }
        } finally {
          if (!release.isCompleted) release.complete();
          binding.defaultBinaryMessenger.setMockMethodCallHandler(ios, null);
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            android,
            null,
          );
          debugDefaultTargetPlatformOverride = null;
          await observer?.cancel();
          await singleton?.dispose();
          await isolate.dispose();
        }
      });
    }
  }
}
