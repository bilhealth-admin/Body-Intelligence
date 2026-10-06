import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_publish_operation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'community_publish_operation_persistence.dart';
part 'community_publish_operation_owner_fixture.dart';
part 'community_publish_operation_owner_cases.dart';
part 'community_draft_operation_owner_cases.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> _fields({String body = 'Authoritative post'}) => {
  'body': body,
  'topic_slugs': <String>[],
  'circle_slug': null,
  'location_label': null,
  'mentioned_user_ids': <String>[],
  'title': null,
  'hashtags': <String>[],
  'collaborator_user_ids': <String>[],
  'poll': null,
  'persistent_draft_id': null,
};

class _OperationBackend {
  final requests = <http.Request>[];
  Future<void> Function(http.Request request)? beforeResponse;
  FutureOr<http.Response?> Function(String rpc, Map<String, dynamic> params)?
  additionalRpc;
  final operations = <String, Map<String, dynamic>>{};
  final objects = <String, Uint8List>{};
  int rows = 0;
  int commits = 0;
  int uploads = 0;
  int deletes = 0;
  bool loseCommittedResponse = false;
  bool delayServerCommit = false;
  bool delayServerBegin = false;
  bool loseUploadResponse = false;
  bool loseDeleteResponse = false;
  bool wrongPayloadReceipt = false;
  bool wrongCommittedPost = false;
  bool wrongCommittedPayload = false;
  bool corruptStoredBytes = false;
  bool postUnavailable = false;
  bool unprovedUnavailable = false;
  String? delayedOperation;
  String? delayedBeginId;
  Object? delayedBeginPayload;

  Map<String, dynamic> receipt(String id) {
    final operation = operations[id]!;
    final committed = operation['status'] == 'committed';
    final unavailable = committed && postUnavailable;
    return {
      'operation_id': id,
      'owner_id': _owner,
      'post_id': committed
          ? (wrongCommittedPost ? '99999999-9999-4999-8999-999999999999' : id)
          : null,
      'committed': committed && !unavailable,
      'status': unavailable ? 'unavailable' : operation['status'],
      'payload': wrongPayloadReceipt || (committed && wrongCommittedPayload)
          ? _fields(body: 'Mismatched server post')
          : operation['payload'],
      if (unavailable) ...{
        'was_committed': !unprovedUnavailable,
        'post_available': false,
        'cleanup_allowed': false,
        'aborted': false,
        'media_paths': [],
      },
    };
  }

  void finishDelayedCommit() {
    final operation = operations[delayedOperation];
    if (operation?['status'] == 'prepared') {
      operation!['status'] = 'committed';
      rows++;
    }
  }

  void finishDelayedBegin() {
    operations.putIfAbsent(
      delayedBeginId!,
      () => {'status': 'prepared', 'payload': delayedBeginPayload},
    );
  }

  Future<http.Response> request(http.Request request) async {
    requests.add(request);
    await beforeResponse?.call(request);
    final path = request.url.path;
    if (path == '/auth/v1/logout') return http.Response('{}', 200);
    if (path.contains('/rest/v1/rpc/')) {
      final json = Map<String, dynamic>.from(
        jsonDecode(request.body) as Map? ?? const {},
      );
      final rpc = path.split('/').last;
      final additional = await additionalRpc?.call(rpc, json);
      if (additional != null) return additional;
      final id = json['p_operation_id'] as String;
      if (rpc == 'bil_begin_my_community_publish_operation_v1') {
        if (delayServerBegin) {
          delayedBeginId = id;
          delayedBeginPayload = json['p_payload'];
          throw http.ClientException('synthetic delayed begin response lost');
        }
        operations.putIfAbsent(
          id,
          () => {'status': 'prepared', 'payload': json['p_payload']},
        );
        return http.Response(jsonEncode(receipt(id)), 200);
      }
      if (rpc == 'bil_publish_community_post_operation_v1') {
        commits++;
        if (delayServerCommit) {
          delayedOperation = id;
          throw http.ClientException('synthetic commit response lost');
        }
        if (operations[id]!['status'] != 'aborted' &&
            operations[id]!['status'] != 'committed') {
          operations[id]!['status'] = 'committed';
          rows++;
        }
        if (loseCommittedResponse) {
          loseCommittedResponse = false;
          throw http.ClientException('synthetic committed response lost');
        }
        return http.Response(jsonEncode(receipt(id)), 200);
      }
      if (rpc == 'bil_abort_my_community_publish_operation_v1') {
        operations.putIfAbsent(
          id,
          () => {'status': 'aborted', 'payload': null},
        );
        if (operations[id]!['status'] == 'committed') {
          return http.Response(
            jsonEncode({...receipt(id), 'aborted': false}),
            200,
          );
        }
        operations[id]!['status'] = 'aborted';
        final payload = operations[id]!['payload'] as Map?;
        return http.Response(
          jsonEncode({
            ...receipt(id),
            'aborted': true,
            'media_paths': ((payload?['media'] as List?) ?? [])
                .map((item) => item['object_path'])
                .toList(),
          }),
          200,
        );
      }
      throw StateError('Unexpected RPC $rpc');
    }
    const objectPrefix = '/storage/v1/object/community-post-images/';
    const downloadPrefix = '/storage/v1/object/community-post-images/';
    if (request.method == 'POST' && path.startsWith(objectPrefix)) {
      final object = path.substring(objectPrefix.length);
      uploads++;
      if (objects.containsKey(object)) {
        return http.Response(
          jsonEncode({
            'statusCode': '409',
            'error': 'Duplicate',
            'message': 'The resource already exists',
          }),
          409,
        );
      }
      objects[object] = corruptStoredBytes
          ? Uint8List.fromList([0])
          : Uint8List.fromList(request.bodyBytes);
      if (loseUploadResponse) {
        loseUploadResponse = false;
        throw http.ClientException('synthetic upload response lost');
      }
      return http.Response(
        jsonEncode({
          'Key': 'community-post-images/$object',
          'Id': '99999999-9999-4999-8999-999999999999',
        }),
        200,
      );
    }
    if (request.method == 'GET' && path.startsWith(downloadPrefix)) {
      return http.Response.bytes(
        objects[path.substring(downloadPrefix.length)]!,
        200,
      );
    }
    if (request.method == 'DELETE' &&
        path == '/storage/v1/object/community-post-images') {
      deletes++;
      final json = jsonDecode(request.body) as Map;
      for (final path in json['prefixes'] as List) {
        objects.remove(path);
      }
      if (loseDeleteResponse) {
        loseDeleteResponse = false;
        throw http.ClientException('synthetic cleanup response lost');
      }
      return http.Response('[]', 200);
    }
    throw StateError('Unexpected transport ${request.method} $path');
  }
}

class _OperationClient extends http.BaseClient {
  _OperationClient(this.backend);
  final _OperationBackend backend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final transport = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    if (request is http.MultipartRequest) {
      // Model the installed Storage SDK's actual multipart upload, not the
      // surrounding multipart headers/boundary as if they were image bytes.
      transport.bodyBytes = await request.files.single.finalize().toBytes();
    } else {
      transport.bodyBytes = await request.finalize().toBytes();
    }
    final response = await backend.request(transport);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      request: request,
      headers: request.url.path.contains('/rest/v1/rpc/')
          ? {'content-type': 'application/json'}
          : response.headers,
    );
  }
}

Future<CommunityPublishOperationService> _service(
  _OperationBackend backend,
) async {
  final transport = CommunityOwnerHttpClient(_OperationClient(backend));
  addTearDown(transport.close);
  final client = SupabaseClient(
    'https://operation-fixture.invalid',
    'synthetic-key',
    httpClient: transport,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(client.dispose);
  await client.auth.recoverSession(_cachedOwnerSession(_owner));
  return CommunityPublishOperationService(client, _owner);
}

CommunityPostImageDraft _image() {
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 2, height: 2)),
  );
  return validateCommunityPostImage(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  _registerPublishPersistenceTests();
  _registerPublishOwnerTests();
  _registerDraftOwnerTests();

  test(
    'lost committed response retries durable identity with one actual row',
    () async {
      final backend = _OperationBackend()..loseCommittedResponse = true;
      final service = await _service(backend);
      await expectLater(
        service.publish(_fields(), []),
        throwsA(isA<http.ClientException>()),
      );
      expect(backend.rows, 1);
      expect(backend.deletes, 0);
      final firstId = backend.operations.keys.single;
      // Simulate a new service after relaunch, retaining the actual local journal.
      final result = await (await _service(backend)).publish(_fields(), []);
      expect(result, firstId);
      expect(backend.rows, 1);
      expect(backend.commits, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.contains('publish.operation')),
        isEmpty,
      );
    },
  );

  test('receipt mismatch is never treated as success or cleaned up', () async {
    final backend = _OperationBackend()..wrongPayloadReceipt = true;
    await expectLater(
      (await _service(backend)).publish(_fields(), []),
      throwsFormatException,
    );
    expect(backend.rows, 0);
    expect(backend.commits, 0);
    expect(backend.deletes, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => key.contains('publish.operation')),
      hasLength(1),
    );
  });

  for (final mismatch in ['post', 'payload']) {
    test(
      'committed $mismatch mismatch never unlocks success or deletes media',
      () async {
        final backend = _OperationBackend()
          ..wrongCommittedPost = mismatch == 'post'
          ..wrongCommittedPayload = mismatch == 'payload';
        final service = await _service(backend);
        await expectLater(
          service.publish(_fields(), [_image()]),
          throwsFormatException,
        );
        expect(backend.rows, 1);
        expect(backend.objects, hasLength(1));
        expect(backend.deletes, 0);
        backend.wrongCommittedPost = false;
        backend.wrongCommittedPayload = false;
        await service.publish(_fields(), [_image()]);
        expect(backend.rows, 1);
        expect(backend.commits, 1);
      },
    );
  }

  test(
    'changed payload requires explicit authoritative cancellation',
    () async {
      final backend = _OperationBackend()..delayServerCommit = true;
      final service = await _service(backend);
      await expectLater(
        service.publish(_fields(), []),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(
        service.publish(_fields(body: 'Edited post'), []),
        throwsA(isA<CommunityPublishOperationConflict>()),
      );
      expect(backend.operations, hasLength(1));
      expect(await service.cancelPending(), isTrue);
      backend.finishDelayedCommit();
      expect(
        backend.rows,
        0,
        reason: 'Authoritative abort defeated the delayed commit',
      );
      backend.delayServerCommit = false;
      await service.publish(_fields(body: 'Edited post'), []);
      expect(backend.rows, 1);
      expect(backend.operations, hasLength(2));
    },
  );

  test('commit winning cancellation never deletes post media', () async {
    final backend = _OperationBackend()..loseCommittedResponse = true;
    final service = await _service(backend);
    await expectLater(
      service.publish(_fields(), [_image()]),
      throwsA(isA<http.ClientException>()),
    );
    expect(backend.rows, 1);
    expect(backend.objects, hasLength(1));
    expect(await service.cancelPending(), isFalse);
    expect(backend.objects, hasLength(1));
    expect(backend.deletes, 0);
  });

  test(
    'lost upload response retries same immutable path and verifies bytes',
    () async {
      final backend = _OperationBackend()..loseUploadResponse = true;
      final service = await _service(backend);
      final image = _image();
      await expectLater(
        service.publish(_fields(), [image]),
        throwsA(isA<http.ClientException>()),
      );
      final paths = backend.objects.keys.toList();
      expect(backend.rows, 0);
      expect(backend.deletes, 0);
      await service.publish(_fields(), [image]);
      expect(backend.objects.keys.toList(), paths);
      expect(backend.rows, 1);
      expect(backend.uploads, 2);
    },
  );

  test(
    'duplicate path with differing bytes fails closed before commit',
    () async {
      final backend = _OperationBackend()
        ..corruptStoredBytes = true
        ..loseUploadResponse = true;
      final service = await _service(backend);
      final image = _image();
      await expectLater(
        service.publish(_fields(), [image]),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(service.publish(_fields(), [image]), throwsStateError);
      expect(backend.commits, 0);
      expect(backend.rows, 0);
      expect(backend.deletes, 0);
    },
  );

  test(
    'abort winning delayed commit authorizes only its exact media cleanup',
    () async {
      final backend = _OperationBackend()..delayServerCommit = true;
      final service = await _service(backend);
      await expectLater(
        service.publish(_fields(), [_image()]),
        throwsA(isA<http.ClientException>()),
      );
      expect(backend.objects, hasLength(1));
      expect(await service.cancelPending(), isTrue);
      expect(backend.deletes, 1);
      expect(backend.objects, isEmpty);
      backend.finishDelayedCommit();
      expect(backend.rows, 0);
    },
  );

  test(
    'abort tombstone defeats delayed begin without unproved cleanup',
    () async {
      final backend = _OperationBackend()..delayServerBegin = true;
      final service = await _service(backend);
      await expectLater(
        service.publish(_fields(), [_image()]),
        throwsA(isA<http.ClientException>()),
      );
      expect(backend.operations, isEmpty);
      expect(backend.uploads, 0);
      expect(await service.cancelPending(), isTrue);
      expect(backend.deletes, 0);
      backend.finishDelayedBegin();
      expect(backend.operations.values.single['status'], 'aborted');
      expect(backend.operations.values.single['payload'], isNull);
      expect(backend.rows, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.contains('publish.operation')),
        isEmpty,
      );
    },
  );

  test('mismatched abort payload never authorizes image deletion', () async {
    final backend = _OperationBackend()..delayServerCommit = true;
    final service = await _service(backend);
    await expectLater(
      service.publish(_fields(), [_image()]),
      throwsA(isA<http.ClientException>()),
    );
    backend.wrongPayloadReceipt = true;
    await expectLater(service.cancelPending(), throwsFormatException);
    expect(backend.deletes, 0);
    expect(backend.objects, hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => key.contains('publish.operation')),
      hasLength(1),
    );
    backend.wrongPayloadReceipt = false;
    expect(await service.cancelPending(), isTrue);
    expect(backend.deletes, 1);
  });

  test(
    'lost authorized cleanup response retains journal for safe retry',
    () async {
      final backend = _OperationBackend()
        ..delayServerCommit = true
        ..loseDeleteResponse = true;
      final service = await _service(backend);
      await expectLater(
        service.publish(_fields(), [_image()]),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(
        service.cancelPending(),
        throwsA(isA<http.ClientException>()),
      );
      expect(backend.operations.values.single['status'], 'aborted');
      expect(backend.objects, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.contains('publish.operation')),
        hasLength(1),
      );
      expect(await service.cancelPending(), isTrue);
      expect(backend.deletes, 2);
      expect(
        prefs.getKeys().where((key) => key.contains('publish.operation')),
        isEmpty,
      );
      backend.finishDelayedCommit();
      expect(backend.rows, 0);
    },
  );
  test(
    'only explicit cancellation can abandon verified unavailable post',
    () async {
      final backend = _OperationBackend()..loseCommittedResponse = true;
      final service = await _service(backend);
      final image = _image();
      await expectLater(
        service.publish(_fields(), [image]),
        throwsA(isA<http.ClientException>()),
      );
      final oldId = backend.operations.keys.single;
      backend.postUnavailable = true;
      await expectLater(
        service.publish(_fields(), [image]),
        throwsFormatException,
      );
      expect(backend.rows, 1);
      expect(backend.deletes, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.contains('publish.operation')),
        hasLength(1),
      );
      await expectLater(
        service.cancelPending(),
        throwsA(isA<CommunityPublishOperationUnavailable>()),
      );
      expect(backend.deletes, 0);
      expect(backend.objects, hasLength(1));
      expect(
        prefs.getKeys().where((key) => key.contains('publish.operation')),
        isEmpty,
      );
      backend.postUnavailable = false;
      final newId = await service.publish(
        _fields(body: 'New intended post'),
        [],
      );
      expect(newId, isNot(oldId));
      expect(backend.rows, 2);
    },
  );

  for (final mismatchPayload in [false, true]) {
    test(
      'unproved unavailable receipt preserves pending identity $mismatchPayload',
      () async {
        final backend = _OperationBackend()..loseCommittedResponse = true;
        final service = await _service(backend);
        await expectLater(
          service.publish(_fields(), [_image()]),
          throwsA(isA<http.ClientException>()),
        );
        backend
          ..postUnavailable = true
          ..unprovedUnavailable = !mismatchPayload
          ..wrongCommittedPayload = mismatchPayload;
        await expectLater(service.cancelPending(), throwsFormatException);
        expect(backend.deletes, 0);
        expect(backend.objects, hasLength(1));
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where((key) => key.contains('publish.operation')),
          hasLength(1),
        );
      },
    );
  }
}
