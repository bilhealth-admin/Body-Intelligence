import 'dart:convert';

import 'package:body_intelligence_log/features/cloud_platform/services/cloud_account_key_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const ownerId = 'owner-a';
  const ownerMismatch = 'owner-b';
  final validEncoded = base64.encode(List.generate(32, (index) => index + 7));

  test('local cached key is used and skips RPC call', () async {
    final calls = <String>[];
    final repository = CloudAccountKeyRepository(
      client: _FakeSupabaseClient(
        user: _user(ownerId),
        rpc: (fnName) {
          calls.add(fnName);
          return fail('RPC must not be called for cached key');
        },
      ),
      secureStore: _InMemorySecretStore(
        initialValues: {'bil.cloud.payload-key.v1.$ownerId': validEncoded},
      ),
      rpc: (fnName) {
        calls.add(fnName);
        return fail('Injected RPC must not be called for cached key');
      },
    );

    final key = await repository.resolveExisting(ownerId);
    expect(key, isNotNull);
    expect(key.length, 32);
    expect(calls, isEmpty);
  });

  test(
    'new device reads key from bil_get_existing_cloud_key and caches it',
    () async {
      final calls = <String>[];
      final store = _InMemorySecretStore();
      final repository = CloudAccountKeyRepository(
        client: _FakeSupabaseClient(user: _user(ownerId), rpc: (_) => null),
        secureStore: store,
        rpc: (fnName) {
          calls.add(fnName);
          if (fnName == 'bil_get_existing_cloud_key') {
            return validEncoded;
          }
          return fail('Unexpected RPC $fnName');
        },
      );

      final key = await repository.resolveExisting(ownerId);
      expect(key, isNotNull);
      expect(key.length, 32);
      expect(store.readSync('bil.cloud.payload-key.v1.$ownerId'), validEncoded);
      expect(store.writeCount, 1);
      expect(calls, ['bil_get_existing_cloud_key']);
    },
  );

  test(
    'missing cloud key resolves to null without creating or writing',
    () async {
      final calls = <String>[];
      final store = _InMemorySecretStore();
      final repository = CloudAccountKeyRepository(
        client: _FakeSupabaseClient(user: _user(ownerId), rpc: (_) => null),
        secureStore: store,
        rpc: (fnName) {
          calls.add(fnName);
          return null;
        },
      );

      expect(await repository.resolveExisting(ownerId), isNull);
      expect(store.writeCount, 0);
      expect(calls, ['bil_get_existing_cloud_key']);
    },
  );

  test('owner mismatch is rejected before reading cache', () async {
    final calls = <String>[];
    final repository = CloudAccountKeyRepository(
      client: _FakeSupabaseClient(user: _user(ownerMismatch), rpc: (_) => null),
      secureStore: _InMemorySecretStore(
        initialValues: {'bil.cloud.payload-key.v1.$ownerId': validEncoded},
      ),
      rpc: (fnName) {
        calls.add(fnName);
        return validEncoded;
      },
    );

    await expectLater(
      repository.resolveExisting(ownerId),
      throwsA(isA<StateError>()),
    );
    expect(calls, isEmpty);
  });

  test('corrupt local key is rejected and not cached', () async {
    final calls = <String>[];
    final store = _InMemorySecretStore(
      initialValues: {'bil.cloud.payload-key.v1.$ownerId': 'not-base64'},
    );
    final repository = CloudAccountKeyRepository(
      client: _FakeSupabaseClient(user: _user(ownerId), rpc: (_) => null),
      secureStore: store,
      rpc: (fnName) {
        calls.add(fnName);
        return validEncoded;
      },
    );

    await expectLater(
      repository.resolveExisting(ownerId),
      throwsA(isA<FormatException>()),
    );
    expect(store.writeCount, 0);
    expect(calls, isEmpty);
  });
}

final class _InMemorySecretStore implements CloudSecretStore {
  _InMemorySecretStore({Map<String, String>? initialValues})
    : _values = {...?initialValues};

  final Map<String, String> _values;
  int writeCount = 0;
  int readCount = 0;

  @override
  Future<String?> read(String key) async {
    readCount += 1;
    return _values[key];
  }

  String? readSync(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount += 1;
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

final class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient({required User user, required CloudKeyRpcLookup rpc})
    : _authClient = _FakeAuthClient(user),
      _rpc = rpc;

  final _FakeAuthClient _authClient;
  final CloudKeyRpcLookup _rpc;

  @override
  GoTrueClient get auth => _authClient;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    bool get = false,
  }) => _ImmediateRpcResult<T>(_rpc(fn)) as PostgrestFilterBuilder<T>;
}

final class _FakeAuthClient extends Fake implements GoTrueClient {
  _FakeAuthClient(this.currentUser);

  @override
  final User currentUser;
}

final class _ImmediateRpcResult<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _ImmediateRpcResult(this.value);

  final T value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future<T>.value(value).then(onValue, onError: onError);
  }
}

User _user(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: null,
  aud: 'authenticated',
  createdAt: DateTime.now().toIso8601String(),
);
