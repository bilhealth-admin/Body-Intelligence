import 'dart:typed_data';

import 'package:body_intelligence_log/features/community/data/community_post_cloud_store.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _RecordingPostStore implements CommunityPostStoreContract {
  _RecordingPostStore({this.imageFailure});

  final Object? imageFailure;
  int textCalls = 0;
  int imageCalls = 0;

  @override
  Future<void> publishText(String body) async {
    textCalls += 1;
  }

  @override
  Future<void> publishWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async {
    imageCalls += 1;
    final error = imageFailure;
    if (error != null) throw error;
  }

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => const [];

  @override
  Future<List<CommunityPost>> loadModerationQueue({int limit = 100}) async =>
      const [];

  @override
  Future<void> delete(String postId) async {}
}

final class _PreflightRepository extends CommunityRepository {
  _PreflightRepository({
    required CommunityPostStoreContract postStore,
    this.failure,
    this.guardFailures = const [],
  }) : super(
         SupabaseClient(
           'https://community-preflight.invalid',
           'community-preflight-test-key',
           authOptions: const AuthClientOptions(autoRefreshToken: false),
         ),
         postStore: postStore,
       );

  final Object? failure;
  final List<Object?> guardFailures;
  int guardCalls = 0;

  @override
  Future<void> assertCommunityPublishReady() async {
    guardCalls += 1;
    final error = guardCalls <= guardFailures.length
        ? guardFailures[guardCalls - 1]
        : failure;
    if (error != null) throw error;
  }
}

final _image = CommunityPostImageDraft(
  bytes: Uint8List(0),
  mimeType: 'image/png',
  extension: 'png',
  width: 1,
  height: 1,
);

void main() {
  for (final failure in <Object>[
    const CommunityPolicyAccessException(
      failure: CommunityPolicyAccessFailure.unavailable,
    ),
    const CommunityPolicyAccessException(
      failure: CommunityPolicyAccessFailure.acceptanceRequired,
      policyVersion: 'community-policy-v1',
    ),
    const CommunityMembershipAccessException(
      failure: CommunityMembershipAccessFailure.suspended,
    ),
  ]) {
    test(
      'failed publish preflight prevents text and image store calls: $failure',
      () async {
        final store = _RecordingPostStore();
        final repository = _PreflightRepository(
          postStore: store,
          failure: failure,
        );

        await expectLater(
          repository.publishPost('safe text'),
          throwsA(same(failure)),
        );
        await expectLater(
          repository.publishPostWithImage('safe image text', _image),
          throwsA(same(failure)),
        );

        expect(repository.guardCalls, 2);
        expect(store.textCalls, 0);
        expect(store.imageCalls, 0);
      },
    );
  }

  test(
    'successful preflight runs before one text or image store call',
    () async {
      final store = _RecordingPostStore();
      final repository = _PreflightRepository(postStore: store);

      await repository.publishPost('safe text');
      await repository.publishPostWithImage('safe image text', _image);

      expect(repository.guardCalls, 2);
      expect(store.textCalls, 1);
      expect(store.imageCalls, 1);
    },
  );

  for (final authoritativeFailure in <Object>[
    const CommunityPolicyAccessException(
      failure: CommunityPolicyAccessFailure.unavailable,
    ),
    const CommunityPolicyAccessException(
      failure: CommunityPolicyAccessFailure.acceptanceRequired,
      policyVersion: 'community-policy-v2',
    ),
    const CommunityMembershipAccessException(
      failure: CommunityMembershipAccessFailure.suspended,
    ),
  ]) {
    test('Storage denial rechecks and exposes authoritative state: '
        '$authoritativeFailure', () async {
      const storageFailure = StorageException(
        'new row violates row-level security policy',
        statusCode: '403',
      );
      final store = _RecordingPostStore(imageFailure: storageFailure);
      final repository = _PreflightRepository(
        postStore: store,
        guardFailures: [null, authoritativeFailure],
      );

      await expectLater(
        repository.publishPostWithImage('safe image text', _image),
        throwsA(same(authoritativeFailure)),
      );

      expect(repository.guardCalls, 2);
      expect(store.imageCalls, 1);
    });
  }

  test('unrelated Storage denial remains the original error', () async {
    const storageFailure = StorageException(
      'invalid Community image path',
      statusCode: '403',
    );
    final store = _RecordingPostStore(imageFailure: storageFailure);
    final repository = _PreflightRepository(
      postStore: store,
      guardFailures: const [null, null],
    );

    await expectLater(
      repository.publishPostWithImage('safe image text', _image),
      throwsA(same(storageFailure)),
    );

    expect(repository.guardCalls, 2);
    expect(store.imageCalls, 1);
  });
}
