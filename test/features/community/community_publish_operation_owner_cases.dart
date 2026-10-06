part of 'community_publish_operation_test.dart';

void _registerPublishOwnerTests() {
  for (final roundTrip in [false, true]) {
    test(
      'owner switch roundTrip=$roundTrip fences prepared publish response',
      () async {
        final backend = _OperationBackend();
        final service = await _service(backend);
        final hold = _holdRpc(
          backend,
          'bil_begin_my_community_publish_operation_v1',
        );
        final outcome = expectLater(
          service.publish(_fields(), [_image()]),
          throwsA(isA<AuthException>()),
        );
        await hold.waitUntilEntered();
        await _changeOperationOwner(service.client, roundTrip: roundTrip);
        hold.release.complete();
        await outcome;
        expect(_rpcNames(backend), [
          'bil_begin_my_community_publish_operation_v1',
        ]);
        expect(backend.requests.map(_requestOwner), everyElement(_owner));
        expect(backend.uploads, 0);
        expect(backend.commits, 0);
        expect(backend.deletes, 0);
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(prefs.containsKey(_ownerJournal), isTrue);
      },
    );

    test(
      'owner switch roundTrip=$roundTrip fences upload before next image/commit',
      () async {
        final backend = _OperationBackend();
        final service = await _service(backend);
        final hold = _HeldOperationResponse(
          (request) =>
              request.method == 'POST' &&
              request.url.path.contains('/storage/'),
        );
        backend.beforeResponse = hold.call;
        final outcome = expectLater(
          service.publish(_fields(), [_image(), _image()]),
          throwsA(isA<AuthException>()),
        );
        await hold.waitUntilEntered();
        await _changeOperationOwner(service.client, roundTrip: roundTrip);
        hold.release.complete();
        await outcome;
        expect(backend.uploads, 1);
        expect(backend.objects, hasLength(1));
        expect(backend.commits, 0);
        expect(backend.deletes, 0);
        expect(backend.requests.map(_requestOwner), everyElement(_owner));
        expect(
          (await SharedPreferences.getInstance()).containsKey(_ownerJournal),
          isTrue,
        );
      },
    );
  }

  test(
    'late committed receipt retains owner journal without false UI acknowledgement',
    () async {
      final backend = _OperationBackend();
      final service = await _service(backend);
      final hold = _holdRpc(backend, 'bil_publish_community_post_operation_v1');
      final outcome = expectLater(
        service.publish(_fields(), [_image()]),
        throwsA(isA<AuthException>()),
      );
      await hold.waitUntilEntered();
      await _changeOperationOwner(service.client);
      hold.release.complete();
      await outcome;
      // The server already received the original owner's commit. Cancellation
      // suppresses the stale continuation, not that authorized in-flight write.
      expect(backend.rows, 1);
      expect(backend.commits, 1);
      expect(backend.deletes, 0);
      expect(
        (await SharedPreferences.getInstance()).containsKey(_ownerJournal),
        isTrue,
      );
      backend.beforeResponse = null;
      await service.client.auth.recoverSession(_cachedOwnerSession(_owner));
      final id = await service.publish(_fields(), [_image()]);
      expect(id, backend.operations.keys.single);
      expect(backend.rows, 1);
      expect(backend.commits, 1);
      expect(
        (await SharedPreferences.getInstance()).containsKey(_ownerJournal),
        isFalse,
      );
    },
  );

  test(
    'same-owner refreshed session continues one durable operation',
    () async {
      final backend = _OperationBackend();
      final service = await _service(backend);
      final hold = _holdRpc(
        backend,
        'bil_begin_my_community_publish_operation_v1',
      );
      final future = service.publish(_fields(), [_image()]);
      await hold.waitUntilEntered();
      await service.client.auth.recoverSession(
        _cachedOwnerSession(_owner, revision: 'refreshed'),
      );
      hold.release.complete();
      final id = await future;
      expect(id, backend.operations.keys.single);
      expect(backend.rows, 1);
      expect(backend.uploads, 1);
      expect(backend.commits, 1);
      expect(backend.requests.map(_requestOwner), everyElement(_owner));
      expect(
        (await SharedPreferences.getInstance()).containsKey(_ownerJournal),
        isFalse,
      );
    },
  );

  test(
    'editor lifetime predicate fences nested repository and service after begin',
    () async {
      final backend = _OperationBackend();
      _installDraftRpc(backend);
      final service = await _service(backend);
      final repository = CommunityRepository(service.client);
      var editorCurrent = true;
      final hold = _holdRpc(
        backend,
        'bil_begin_my_community_publish_operation_v1',
      );
      final outcome = expectLater(
        repository.runForCommunityOwner(
          // The feed can remain mounted while its child editor is invalidated.
          () => repository.runForCommunityOwner(
            () => repository.publishRichPost(
              'Original editor body',
              images: [_image()],
            ),
            ownerId: _owner,
            isCurrentOwner: () => editorCurrent,
          ),
          ownerId: _owner,
          isCurrentOwner: () => true,
        ),
        throwsA(isA<AuthException>()),
      );
      await hold.waitUntilEntered();
      editorCurrent = false;
      hold.release.complete();
      await outcome;
      expect(service.client.auth.currentUser?.id, _owner);
      expect(_rpcNames(backend), [
        'bil_assert_community_publish_ready',
        'bil_begin_my_community_publish_operation_v1',
      ]);
      expect(backend.uploads, 0);
      expect(backend.commits, 0);
      expect(backend.deletes, 0);
    },
  );

  test(
    'signed-out service cannot reserve an operation or upload bytes',
    () async {
      final backend = _OperationBackend();
      final service = await _service(backend);
      await service.client.auth.signOut(scope: SignOutScope.local);
      final before = backend.requests.length;
      await expectLater(
        service.publish(_fields(), [_image()]),
        throwsA(isA<AuthException>()),
      );
      expect(backend.requests, hasLength(before));
      expect(backend.operations, isEmpty);
      expect(backend.uploads, 0);
      expect(
        (await SharedPreferences.getInstance()).containsKey(_ownerJournal),
        isFalse,
      );
    },
  );

  test(
    'late abort receipt cannot clean owner media under another account',
    () async {
      final backend = _OperationBackend()..loseUploadResponse = true;
      final service = await _service(backend);
      await expectLater(
        service.publish(_fields(), [_image()]),
        throwsA(isA<http.ClientException>()),
      );
      expect(backend.objects, hasLength(1));
      final hold = _holdRpc(
        backend,
        'bil_abort_my_community_publish_operation_v1',
      );
      final outcome = expectLater(
        service.cancelPending(),
        throwsA(isA<AuthException>()),
      );
      await hold.waitUntilEntered();
      await _changeOperationOwner(service.client, roundTrip: true);
      hold.release.complete();
      await outcome;
      expect(backend.deletes, 0);
      expect(backend.objects, hasLength(1));
      expect(
        (await SharedPreferences.getInstance()).containsKey(_ownerJournal),
        isTrue,
      );
      backend.beforeResponse = null;
      expect(await service.cancelPending(), isTrue);
      expect(backend.deletes, 1);
      expect(backend.objects, isEmpty);
    },
  );
}
