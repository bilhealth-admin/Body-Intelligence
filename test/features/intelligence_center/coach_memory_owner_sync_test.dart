import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'coach_memory_owner_sync_cases.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _memoryId = '33333333-3333-4333-8333-333333333333';
const _savedMemory = <String, Object?>{
  'id': _memoryId,
  'text': 'Prefer evening workouts',
  'kind': 'preference',
  'status': 'confirmed',
  'confidence': 1.0,
  'savedAt': '2026-10-06T10:00:00.000Z',
  'updatedAt': '2026-10-06T10:00:00.000Z',
  'source': 'explicit_user_confirmation',
};

Map<String, dynamic> _memorySession(String owner, {bool expired = false}) {
  final expiry = expired ? 1600000000 : 4102444800;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': expiry})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-memory-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-06T00:00:00Z',
    },
  };
}

String _memoryRequestOwner(http.Request request) {
  final token = request.headers['authorization']!.split(' ').last;
  final payload =
      jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1])),
            ),
          )
          as Map<String, dynamic>;
  return payload['sub'] as String;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _memoryOwnerSyncCases();
}

class _MemorySyncStore {
  _MemorySyncStore() {
    client = SupabaseClient(
      'https://memory-owner.invalid',
      'synthetic-memory-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(_handleRequest)),
    );
    repository = CoachMemoryRepository(preferences: preferences, cloud: client);
  }

  final database = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: _ownerA,
  );
  late final preferences = PreferencesRepository(database);
  late final SupabaseClient client;
  late final CoachMemoryRepository repository;
  final consentEntered = Completer<void>();
  final refreshEntered = Completer<void>();
  final readEntered = Completer<void>();
  final deliveredB = Completer<void>();
  final returnedA = Completer<void>();
  final events = <({String? eventOwner, String? currentOwner})>[];
  final writes = <http.Request>[];
  final reads = <http.Request>[];
  StreamSubscription<AuthState>? observer;
  Completer<void>? consentBlock;
  Completer<void>? refreshBlock;
  Completer<void>? readBlock;
  bool expireAfterConsent = false;
  bool failDataWrite = false;
  bool currentOperation = true;
  int refreshCount = 0;
  List<Map<String, Object?>> remoteRows = const [];

  Future<void> initialize() async {
    await client.auth.recoverSession(jsonEncode(_memorySession(_ownerA)));
    observer = client.auth.onAuthStateChange.listen((state) {
      final owner = state.session?.user.id;
      events.add((
        eventOwner: owner,
        currentOwner: client.auth.currentUser?.id,
      ));
      if (owner == _ownerB && !deliveredB.isCompleted) {
        deliveredB.complete();
      } else if (owner == _ownerA &&
          deliveredB.isCompleted &&
          !returnedA.isCompleted) {
        returnedA.complete();
      }
    });
    await setLocal([_savedMemory]);
  }

  Future<void> setLocal(List<Map<String, Object?>> values) =>
      preferences.set(CoachMemoryRepository.storageKey, jsonEncode(values));

  Future<void> sync({Map<String, Object?>? expected = _savedMemory}) =>
      repository.syncCommittedChange(
        id: _memoryId,
        expectedLocal: expected,
        isCurrentOwner: () => currentOperation,
      );

  Future<void> roundTrip() async {
    final second = client.auth.recoverSession(
      jsonEncode(_memorySession(_ownerB)),
    );
    final first = client.auth.recoverSession(
      jsonEncode(_memorySession(_ownerA)),
    );
    await Future.wait([second, first]);
    await returnedA.future.timeout(const Duration(seconds: 10));
    expect(events, contains((eventOwner: _ownerB, currentOwner: _ownerA)));
  }

  Future<http.Response> _handleRequest(http.Request request) async {
    final path = request.url.path;
    Object? body;
    var status = 200;
    if (path == '/rest/v1/rpc/bil_get_remote_ai_consent') {
      expect(_memoryRequestOwner(request), _ownerA);
      if (!consentEntered.isCompleted) consentEntered.complete();
      await consentBlock?.future;
      if (expireAfterConsent) {
        await client.auth.setInitialSession(
          jsonEncode(_memorySession(_ownerA, expired: true)),
        );
      }
      body = {'granted': true, 'policy_version': '3'};
    } else if (path == '/auth/v1/token') {
      refreshCount++;
      expect(request.url.queryParameters['grant_type'], 'refresh_token');
      expect(
        jsonDecode(request.body)['refresh_token'],
        'synthetic-memory-refresh-$_ownerA',
      );
      if (!refreshEntered.isCompleted) refreshEntered.complete();
      await refreshBlock?.future;
      body = _memorySession(_ownerA);
    } else if (path == '/rest/v1/bil_coach_memories') {
      if (request.method == 'GET') {
        reads.add(request);
        if (!readEntered.isCompleted) readEntered.complete();
        await readBlock?.future;
        body = remoteRows;
      } else {
        writes.add(request);
        if (failDataWrite) {
          status = 503;
          body = {'message': 'Synthetic optional memory sync failure'};
        }
      }
    } else {
      throw StateError(
        'Unexpected synthetic memory request: ${request.method} $path',
      );
    }
    return http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<void> dispose() async {
    for (final pending in [consentBlock, refreshBlock, readBlock]) {
      if (pending != null && !pending.isCompleted) pending.complete();
    }
    await observer?.cancel();
    await client.dispose();
    await database.close();
  }
}
