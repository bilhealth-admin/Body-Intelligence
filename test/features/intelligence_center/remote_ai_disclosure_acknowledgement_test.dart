import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway_io.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/remote_ai_consent_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _allow = {'granted': true, 'policy_version': '3'};
const _deny = {'granted': false, 'policy_version': '3'};
const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

class _Disk {
  final acknowledgements = <String, bool>{};
  final denials = <String, bool>{};
  String owner = _a;
  Object receipt = _allow;
  int reads = 0;
  int grants = 0;
  int revokes = 0;
  Completer<void>? ackEntered;
  Completer<void>? ackRelease;
  bool failAckRead = false;
  bool failAckWrite = false;

  RemoteAiConsentCoordinator create() => RemoteAiConsentCoordinator(
    owner: () => owner,
    read: () async {
      reads++;
      return receipt;
    },
    write: () async {
      grants++;
      receipt = _allow;
    },
    revoke: () async {
      revokes++;
      receipt = _deny;
    },
    readDenial: (owner) async => denials[owner] ?? false,
    writeDenial: (owner, value) async {
      denials[owner] = value;
    },
    readDisclosureAcknowledgement: (owner) async {
      if (failAckRead) throw StateError('owned acknowledgement read failure');
      return acknowledgements[owner] ?? false;
    },
    writeDisclosureAcknowledgement: (owner, value) async {
      if (value && ackRelease != null) {
        if (!ackEntered!.isCompleted) ackEntered!.complete();
        await ackRelease!.future;
      }
      if (failAckWrite) throw StateError('owned acknowledgement write failure');
      acknowledgements[owner] = value;
    },
  );
}

Map<String, Object?> _session(String owner) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-disclosure-$owner',
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
}

final class _Projector implements CoachCloudContextProjector {
  int calls = 0;
  @override
  CoachCloudContextProjection project({
    required String question,
    required CoachContextSnapshot context,
    required List<CoachConversationTurn> conversation,
  }) {
    calls++;
    return const CoachCloudContextProjection(
      context: {'fixture': 'selected'},
      disclosure: {
        'categories': <String>[],
        'included_context_fields': <String>[],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy valid3 without disclosure acknowledgement stays blocked on restart',
    () async {
      final disk = _Disk();
      expect(await disk.create().isGranted(), isFalse);
      expect(await disk.create().isGranted(forceServerRead: true), isFalse);
      expect(disk.reads, 2);
      expect(disk.grants, 0);
      expect(disk.acknowledgements, isEmpty);
    },
  );

  test('missing acknowledgement callbacks never default to consent', () async {
    final coordinator = RemoteAiConsentCoordinator(
      owner: () => _a,
      read: () async => _allow,
      write: () async {},
    );
    expect(await coordinator.isGranted(), isFalse);
    await expectLater(coordinator.grantAndVerify(), throwsStateError);
    expect(await coordinator.isGranted(), isFalse);
  });

  test(
    'explicit Allow persists acknowledgement and current3 before restart access',
    () async {
      final disk = _Disk();
      final consent = disk.create();
      expect(await consent.isGranted(), isFalse);
      expect(await consent.grantAndVerify(), isTrue);
      expect(disk.acknowledgements, {_a: true});
      expect(disk.denials, {_a: false});
      expect(disk.grants, 1);
      expect(disk.reads, 2);
      expect(await disk.create().isGranted(), isTrue);
      expect(disk.reads, 3);
      expect(disk.grants, 1);
    },
  );

  test('owner acknowledgement cannot replace current server consent', () async {
    final disk = _Disk()..acknowledgements[_a] = true;
    disk.receipt = _deny;
    expect(await disk.create().isGranted(), isFalse);
    disk.receipt = {'granted': true, 'policy_version': '2'};
    expect(await disk.create().isGranted(), isFalse);
  });

  test(
    'acknowledgement read failure blocks legacy positive after metadata read',
    () async {
      final disk = _Disk()..failAckRead = true;
      await expectLater(disk.create().isGranted(), throwsStateError);
      expect(disk.reads, 1);
      expect(disk.grants, 0);
    },
  );

  test(
    'acknowledgement write failure retains durable denial through restart',
    () async {
      final disk = _Disk()..failAckWrite = true;
      final consent = disk.create();
      await expectLater(consent.grantAndVerify(), throwsStateError);
      expect(disk.receipt, _allow);
      expect(disk.denials[_a], isTrue);
      expect(disk.acknowledgements, isEmpty);
      disk.failAckWrite = false;
      expect(await disk.create().isGranted(), isFalse);
      expect(disk.reads, 1);
    },
  );

  test(
    'acknowledgement is not published while its storage write is held',
    () async {
      final disk = _Disk()
        ..ackEntered = Completer<void>()
        ..ackRelease = Completer<void>();
      final consent = disk.create();
      final allowing = consent.grantAndVerify();
      await disk.ackEntered!.future;
      expect(await consent.isGranted(), isFalse);
      expect(disk.denials[_a], isTrue);
      expect(disk.acknowledgements, isEmpty);
      disk.ackRelease!.complete();
      expect(await allowing, isTrue);
      expect(await consent.isGranted(), isTrue);
    },
  );

  test(
    'owner A B A retires delayed acknowledgement and leaves durable denial',
    () async {
      final disk = _Disk()
        ..ackEntered = Completer<void>()
        ..ackRelease = Completer<void>();
      final consent = disk.create();
      final allowing = consent.grantAndVerify();
      await disk.ackEntered!.future;
      disk.owner = _b;
      expect(await consent.isGranted(), isFalse);
      disk.owner = _a;
      expect(await consent.isGranted(), isFalse);
      disk.ackRelease!.complete();
      expect(await allowing, isFalse);
      expect(disk.denials[_a], isTrue);
      expect(disk.acknowledgements[_b], isNull);
      expect(await disk.create().isGranted(), isFalse);
    },
  );

  test(
    'new withdrawal wins over held Allow acknowledgement and survives restart',
    () async {
      final disk = _Disk()
        ..ackEntered = Completer<void>()
        ..ackRelease = Completer<void>();
      final consent = disk.create();
      final allowing = consent.grantAndVerify();
      await disk.ackEntered!.future;
      final withdrawing = consent.revokeAndVerify();
      expect(await consent.isGranted(), isFalse);
      disk.ackRelease!.complete();
      expect(await allowing, isFalse);
      expect(await withdrawing, isTrue);
      expect(disk.acknowledgements[_a], isFalse);
      expect(disk.denials[_a], isTrue);
      expect(await disk.create().isGranted(), isFalse);
    },
  );

  test(
    'withdrawal clears acknowledgement while durable denial overrides failed clear',
    () async {
      final disk = _Disk()..acknowledgements[_a] = true;
      final consent = disk.create();
      expect(await consent.isGranted(), isTrue);
      disk.failAckWrite = true;
      await expectLater(consent.revokeAndVerify(), throwsStateError);
      expect(disk.revokes, 1);
      expect(disk.receipt, _deny);
      expect(disk.denials[_a], isTrue);
      expect(await disk.create().isGranted(), isFalse);
      disk.failAckWrite = false;
      expect(await consent.revokeAndVerify(), isTrue);
      expect(disk.acknowledgements[_a], isFalse);
    },
  );

  test(
    'actual shared factory and production gateway gate legacy3 before projection or Edge',
    () async {
      SharedPreferences.setMockInitialValues({});
      final projector = _Projector();
      final requests = <String>[];
      var edgeCalls = 0;
      var grants = 0;
      Supabase? sdk;
      final transport = CommunityOwnerHttpClient(
        MockClient((request) async {
          requests.add(request.url.path);
          Object? response;
          switch (request.url.path) {
            case '/rest/v1/rpc/bil_get_remote_ai_consent':
              response = _allow;
            case '/rest/v1/rpc/bil_record_consent':
              final body = jsonDecode(request.body) as Map;
              expect(body, {
                'p_purpose': 'remote_ai',
                'p_policy_version': '3',
                'p_granted': true,
              });
              grants++;
              response = null;
            case '/functions/v1/ai-coach':
              edgeCalls++;
              response = {'reply': 'Synthetic acknowledged response'};
            default:
              throw StateError('Unexpected owned synthetic HTTP path');
          }
          return http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      Future<void> start() async {
        sdk = await Supabase.initialize(
          url: 'https://disclosure-owned.invalid',
          publishableKey: 'synthetic-disclosure-key',
          debug: false,
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),
          ),
          httpClient: transport,
        );
        await sdk!.client.auth.recoverSession(jsonEncode(_session(_a)));
      }

      Future<LocalModelResult> answer() =>
          LlamaCppLocalGateway(cloudContextProjector: projector).answer(
            question: 'Give a general health tip',
            locale: 'en',
            context: CoachContextSnapshot.empty(
              generatedAt: DateTime.utc(2026, 11, 21),
            ),
          );
      try {
        await start();
        final old = await answer();
        expect(old.status, CoachServiceStatus.consentRequired);
        expect(projector.calls, 0);
        expect(edgeCalls, 0);
        expect(requests, ['/rest/v1/rpc/bil_get_remote_ai_consent']);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('bil.remoteAi.disclosure.googleRecipient.v1.$_a'),
          isNull,
        );
        // A status read or page load must not synthesize acknowledgement.
        expect(
          await sharedRemoteAiConsentCoordinator().isGranted(
            forceServerRead: true,
          ),
          isFalse,
        );
        expect(
          prefs.getBool('bil.remoteAi.disclosure.googleRecipient.v1.$_a'),
          isNull,
        );
        expect(
          await sharedRemoteAiConsentCoordinator().grantAndVerify(),
          isTrue,
        );
        expect(
          prefs.getBool('bil.remoteAi.disclosure.googleRecipient.v1.$_a'),
          isTrue,
        );
        expect(grants, 1);
        expect((await answer()).status, CoachServiceStatus.ready);
        expect(projector.calls, 1);
        expect(edgeCalls, 1);
        // New actual client forces the factory to retire its prior coordinator.
        await sdk!.dispose();
        sdk = null;
        await start();
        expect((await answer()).status, CoachServiceStatus.ready);
        expect(grants, 1);
        expect(edgeCalls, 2);
        await sdk!.client.auth.recoverSession(jsonEncode(_session(_b)));
        await Future<void>.delayed(Duration.zero);
        expect((await answer()).status, CoachServiceStatus.consentRequired);
        expect(edgeCalls, 2);
        expect(
          prefs.getBool('bil.remoteAi.disclosure.googleRecipient.v1.$_b'),
          isNull,
        );
      } finally {
        await sdk?.dispose();
        transport.close();
      }
    },
  );
}
