part of 'community_publish_operation_test.dart';

void _registerDraftOwnerTests() {
  test(
    'lost draft metadata reply preserves saved media and retry cleans only verified stale paths',
    () async {
      final backend = _OperationBackend();
      _installDraftRpc(backend);
      final originalRpc = backend.additionalRpc!;
      var loseReply = true;
      var authoritativePaths = <String>[];
      backend.additionalRpc = (rpc, params) async {
        if (rpc != 'bil_set_my_community_post_draft_media_v1') {
          return await originalRpc(rpc, params);
        }
        final stale = authoritativePaths;
        authoritativePaths = [
          for (final raw in params['p_items'] as List)
            (raw as Map)['object_path'] as String,
        ];
        if (loseReply) {
          loseReply = false;
          throw http.ClientException(
            'synthetic committed draft metadata reply lost',
          );
        }
        return http.Response(jsonEncode(stale), 200);
      };
      final service = await _service(backend);
      final repository = CommunityRepository(service.client);
      const input = CommunityDraftSaveInput(
        draftId: _draftId,
        body: 'Private persisted body',
      );
      await expectLater(
        repository.saveMyCommunityDraft(input: input, images: [_image()]),
        throwsA(isA<http.ClientException>()),
      );
      expect(authoritativePaths, hasLength(1));
      expect(backend.objects.keys, authoritativePaths);
      expect(backend.deletes, 0);
      final firstPath = authoritativePaths.single;
      expect(
        await repository.saveMyCommunityDraft(input: input, images: [_image()]),
        _draftId,
      );
      expect(authoritativePaths, hasLength(1));
      expect(authoritativePaths.single, isNot(firstPath));
      expect(backend.objects.keys, authoritativePaths);
      expect(backend.deletes, 1);
      final cleanup = backend.requests.singleWhere(
        (request) => request.method == 'DELETE',
      );
      expect((jsonDecode(cleanup.body) as Map)['prefixes'], [firstPath]);
      expect(backend.rows, 0);
    },
  );

  test(
    'failure before draft metadata starts can clean only completed private uploads',
    () async {
      final backend = _OperationBackend();
      _installDraftRpc(backend);
      var uploads = 0;
      backend.beforeResponse = (request) async {
        if (request.method == 'POST' &&
            request.url.path.contains('/storage/') &&
            ++uploads == 2) {
          throw http.ClientException(
            'synthetic second upload never reached storage',
          );
        }
      };
      final service = await _service(backend);
      final repository = CommunityRepository(service.client);
      await expectLater(
        repository.saveMyCommunityDraft(
          input: const CommunityDraftSaveInput(
            draftId: _draftId,
            body: 'Retained local draft',
          ),
          images: [_image(), _image()],
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(backend.uploads, 1);
      expect(backend.deletes, 1);
      expect(backend.objects, isEmpty);
      expect(_rpcNames(backend), [
        'bil_assert_community_publish_ready',
        'bil_upsert_my_community_post_draft_v1',
      ]);
      expect(backend.requests.map(_requestOwner), everyElement(_owner));
    },
  );

  for (final roundTrip in [false, true]) {
    for (final draft in [false, true]) {
      test(
        'repository ${draft ? "draft save" : "publish"} fences readiness roundTrip=$roundTrip',
        () async {
          final backend = _OperationBackend();
          _installDraftRpc(backend);
          final service = await _service(backend);
          final repository = CommunityRepository(service.client);
          final hold = _holdRpc(backend, 'bil_assert_community_publish_ready');
          final Future<Object?> future = draft
              ? repository.saveMyCommunityDraft(
                  input: const CommunityDraftSaveInput(
                    draftId: _draftId,
                    body: 'Original draft',
                  ),
                  images: [_image()],
                )
              : repository.publishRichPost('Original post', images: [_image()]);
          final outcome = expectLater(future, throwsA(isA<AuthException>()));
          await hold.waitUntilEntered();
          await _changeOperationOwner(service.client, roundTrip: roundTrip);
          hold.release.complete();
          await outcome;
          expect(_rpcNames(backend), ['bil_assert_community_publish_ready']);
          expect(backend.requests.map(_requestOwner), everyElement(_owner));
          expect(backend.uploads, 0);
          expect(backend.commits, 0);
          expect(backend.deletes, 0);
        },
      );
    }
  }

  test('late draft upsert stops before media upload and replacement', () async {
    final backend = _OperationBackend();
    _installDraftRpc(backend);
    final service = await _service(backend);
    final repository = CommunityRepository(service.client);
    final hold = _holdRpc(backend, 'bil_upsert_my_community_post_draft_v1');
    final outcome = expectLater(
      repository.saveMyCommunityDraft(
        input: const CommunityDraftSaveInput(
          draftId: _draftId,
          body: 'Private body',
        ),
        images: [_image()],
      ),
      throwsA(isA<AuthException>()),
    );
    await hold.waitUntilEntered();
    await _changeOperationOwner(service.client, roundTrip: true);
    hold.release.complete();
    await outcome;
    expect(_rpcNames(backend), [
      'bil_assert_community_publish_ready',
      'bil_upsert_my_community_post_draft_v1',
    ]);
    expect(backend.uploads, 0);
    expect(backend.deletes, 0);
  });

  test(
    'late draft upload stops before second image/metadata and cleanup',
    () async {
      final backend = _OperationBackend();
      _installDraftRpc(backend);
      final service = await _service(backend);
      final repository = CommunityRepository(service.client);
      final hold = _HeldOperationResponse(
        (request) =>
            request.method == 'POST' && request.url.path.contains('/storage/'),
      );
      backend.beforeResponse = hold.call;
      final outcome = expectLater(
        repository.saveMyCommunityDraft(
          input: const CommunityDraftSaveInput(
            draftId: _draftId,
            body: 'Private body',
          ),
          images: [_image(), _image()],
        ),
        throwsA(isA<AuthException>()),
      );
      await hold.waitUntilEntered();
      await _changeOperationOwner(service.client);
      hold.release.complete();
      await outcome;
      expect(backend.uploads, 1);
      expect(backend.deletes, 0);
      expect(backend.objects.keys.single, startsWith('$_owner/$_draftId/'));
      expect(_rpcNames(backend), [
        'bil_assert_community_publish_ready',
        'bil_upsert_my_community_post_draft_v1',
      ]);
      expect(backend.requests.map(_requestOwner), everyElement(_owner));
    },
  );

  for (final preview in [false, true]) {
    test(
      'late draft ${preview ? "preview" : "open"} does not download private media',
      () async {
        final backend = _OperationBackend();
        _installDraftRpc(backend);
        final service = await _service(backend);
        final repository = CommunityRepository(service.client);
        final hold = _holdRpc(backend, 'bil_get_my_community_post_draft_v1');
        final future = preview
            ? repository.loadMyCommunityDraftPreview(_draftId)
            : repository.loadMyCommunityDraft(_draftId);
        final outcome = expectLater(future, throwsA(isA<AuthException>()));
        await hold.waitUntilEntered();
        await _changeOperationOwner(service.client, roundTrip: true);
        hold.release.complete();
        await outcome;
        expect(_rpcNames(backend), ['bil_get_my_community_post_draft_v1']);
        expect(backend.requests, hasLength(1));
      },
    );
  }

  for (final consume in [false, true]) {
    test(
      'late draft ${consume ? "consumption" : "delete"} never cleans storage after owner change',
      () async {
        final backend = _OperationBackend();
        _installDraftRpc(backend);
        final service = await _service(backend);
        final repository = CommunityRepository(service.client);
        final rpc = consume
            ? 'bil_consume_my_community_post_draft_v1'
            : 'bil_delete_my_community_post_draft_v1';
        final hold = _holdRpc(backend, rpc);
        final outcome = expectLater(
          consume
              ? repository.consumeMyCommunityDraftAfterPublish(
                  draftId: _draftId,
                  postId: _postId,
                )
              : repository.deleteMyCommunityDraft(_draftId),
          throwsA(isA<AuthException>()),
        );
        await hold.waitUntilEntered();
        await _changeOperationOwner(service.client, roundTrip: true);
        hold.release.complete();
        await outcome;
        expect(_rpcNames(backend), [rpc]);
        expect(backend.deletes, 0);
      },
    );
  }

  test(
    'same-owner draft refresh preserves full body and private image path',
    () async {
      final backend = _OperationBackend();
      _installDraftRpc(backend);
      final service = await _service(backend);
      final repository = CommunityRepository(service.client);
      final hold = _holdRpc(backend, 'bil_assert_community_publish_ready');
      final future = repository.saveMyCommunityDraft(
        input: const CommunityDraftSaveInput(
          draftId: _draftId,
          body: 'Original unchanged body',
        ),
        images: [_image()],
      );
      await hold.waitUntilEntered();
      await service.client.auth.recoverSession(
        _cachedOwnerSession(_owner, revision: 'refreshed'),
      );
      hold.release.complete();
      expect(await future, _draftId);
      expect(backend.uploads, 1);
      expect(backend.objects.keys.single, startsWith('$_owner/$_draftId/'));
      final upsert = backend.requests.singleWhere(
        (request) =>
            request.url.path.endsWith('/bil_upsert_my_community_post_draft_v1'),
      );
      expect(
        (jsonDecode(upsert.body) as Map)['p_body'],
        'Original unchanged body',
      );
      expect(_rpcNames(backend), [
        'bil_assert_community_publish_ready',
        'bil_upsert_my_community_post_draft_v1',
        'bil_set_my_community_post_draft_media_v1',
      ]);
      expect(backend.requests.map(_requestOwner), everyElement(_owner));
    },
  );
}
