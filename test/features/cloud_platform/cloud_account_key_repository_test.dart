import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/cloud_platform/services/cloud_account_key_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const ownerId = 'owner-a';
  const ownerMismatch = 'owner-b';
  final validEncoded = base64.encode(List.generate(32, (index) => index + 7));

  test('local cached key is used and skips RPC call', () async {
    final calls = <String>[];
    final repository = CloudAccountKeyRepository(
      client: _FakeSupabaseClient(user: _user(ownerId)),
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
    expect(key!.length, 32);
    expect(calls, isEmpty);
  });

  test(
    'new device reads key from bil_get_existing_cloud_key and caches it',
    () async {
      final calls = <String>[];
      final store = _InMemorySecretStore();
      final repository = CloudAccountKeyRepository(
        client: _FakeSupabaseClient(user: _user(ownerId)),
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
      expect(key!.length, 32);
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
        client: _FakeSupabaseClient(user: _user(ownerId)),
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
      client: _FakeSupabaseClient(user: _user(ownerMismatch)),
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
      client: _FakeSupabaseClient(user: _user(ownerId)),
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

  test('account switch during secure-store read fails closed', () async {
    var activeOwner = ownerId;
    final readGate = Completer<String?>();
    final store = _DelayedReadSecretStore(readGate.future);
    final calls = <String>[];
    final repository = CloudAccountKeyRepository(
      client: _FakeSupabaseClient(user: _user(ownerId)),
      activeOwner: () => activeOwner,
      secureStore: store,
      rpc: (fnName) {
        calls.add(fnName);
        return validEncoded;
      },
    );

    final pending = repository.resolveExisting(ownerId);
    activeOwner = ownerMismatch;
    readGate.complete(validEncoded);

    await expectLater(pending, throwsA(isA<StateError>()));
    expect(calls, isEmpty);
    expect(store.writeCount, 0);
  });

  test('account switch during cloud RPC cannot cache returned key', () async {
    var activeOwner = ownerId;
    final rpcGate = Completer<dynamic>();
    final store = _InMemorySecretStore();
    final repository = CloudAccountKeyRepository(
      client: _FakeSupabaseClient(user: _user(ownerId)),
      activeOwner: () => activeOwner,
      secureStore: store,
      rpc: (_) => rpcGate.future,
    );

    final pending = repository.resolveExisting(ownerId);
    await Future<void>.delayed(Duration.zero);
    activeOwner = ownerMismatch;
    rpcGate.complete(validEncoded);

    await expectLater(pending, throwsA(isA<StateError>()));
    expect(store.writeCount, 0);
  });

  test('account switch during secure write removes the stale key', () async {
    var activeOwner = ownerId;
    final writeGate = Completer<void>();
    final store = _DelayedWriteSecretStore(writeGate.future);
    final repository = CloudAccountKeyRepository(
      client: _FakeSupabaseClient(user: _user(ownerId)),
      activeOwner: () => activeOwner,
      secureStore: store,
      rpc: (_) => validEncoded,
    );

    final pending = repository.resolveExisting(ownerId);
    await Future<void>.delayed(Duration.zero);
    activeOwner = ownerMismatch;
    writeGate.complete();

    await expectLater(pending, throwsA(isA<StateError>()));
    expect(store.value, isNull);
    expect(store.deleteCount, 1);
  });

  test('same owner with a replaced auth session fails closed', () async {
    var sessionGeneration = 1;
    final rpcGate = Completer<dynamic>();
    final store = _InMemorySecretStore();
    final repository = CloudAccountKeyRepository(
      client: _FakeSupabaseClient(user: _user(ownerId)),
      activeOwner: () => ownerId,
      activeSession: () => sessionGeneration,
      secureStore: store,
      rpc: (_) => rpcGate.future,
    );

    final pending = repository.resolve(ownerId);
    await Future<void>.delayed(Duration.zero);
    sessionGeneration = 2;
    rpcGate.complete(validEncoded);

    await expectLater(pending, throwsA(isA<StateError>()));
    expect(store.writeCount, 0);
  });
}

final class _DelayedWriteSecretStore implements CloudSecretStore {
  _DelayedWriteSecretStore(this.writeGate);

  final Future<void> writeGate;
  String? value;
  int deleteCount = 0;

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {
    await writeGate;
    this.value = value;
  }

  @override
  Future<void> delete(String key) async {
    deleteCount += 1;
    value = null;
  }
}

final class _DelayedReadSecretStore implements CloudSecretStore {
  _DelayedReadSecretStore(this.readResult);

  final Future<String?> readResult;
  int writeCount = 0;

  @override
  Future<String?> read(String key) => readResult;

  @override
  Future<void> write(String key, String value) async {
    writeCount += 1;
  }

  @override
  Future<void> delete(String key) async {}
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
  _FakeSupabaseClient({required User user})
    : _authClient = _FakeAuthClient(user);

  final _FakeAuthClient _authClient;

  @override
  GoTrueClient get auth => _authClient;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get = false,
  }) => throw UnsupportedError('RPC is injected directly in these tests.');
}

final class _FakeAuthClient extends Fake implements GoTrueClient {
  _FakeAuthClient(this.currentUser);

  @override
  final User currentUser;

  @override
  Session? get currentSession => null;
}

User _user(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: null,
  aud: 'authenticated',
  createdAt: DateTime.now().toIso8601String(),
);
