import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _draft = '33333333-3333-4333-8333-333333333333';

class _DraftBackend {
  _DraftBackend(this.photos);
  final List<CommunityPostImageDraft> photos;
  String owner = _owner;
  final sessions = <String, String>{};
  final dataRequests = <http.Request>[];
  final badImages = <int>{};
  final metadata = <Map<String, Object>>[];
  Future<void> Function(http.Request)? beforeResponse;
  List<Object> listResponse = [];
  late final client = SupabaseClient(
    'https://draft-mosaic.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(MockClient(_respond)),
  );

  Map<String, Object?> draftJson() => {
    'draft_id': _draft,
    'title': 'A private four-photo draft',
    'body': 'The complete body stays in the repository.',
    'topic_slugs': ['nutrition'],
    'mentions': [],
    'collaborators': [],
    'hashtags': ['healthyhabits'],
    'poll_question': 'Which habit helps?',
    'poll_options': ['Food', 'Sleep'],
    'poll_allow_multiple': false,
    'created_at': '2026-10-05T09:00:00Z',
    'updated_at': '2026-10-06T10:00:00Z',
    'media': metadata,
  };

  Future<http.Response> _respond(http.Request request) async {
    if (request.url.path == '/auth/v1/token') {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      return _json(request, {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'email': 'draft@example.invalid',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-10-06T00:00:00Z',
        },
      });
    }
    dataRequests.add(request);
    await beforeResponse?.call(request);
    if (request.url.path == '/rest/v1/rpc/bil_get_my_community_post_draft_v1') {
      expect(jsonDecode(request.body), {'p_draft_id': _draft});
      return _json(request, draftJson());
    }
    if (request.url.path ==
        '/rest/v1/rpc/bil_list_my_community_post_drafts_v1') {
      return _json(request, listResponse);
    }
    if (request.url.path.startsWith('/storage/v1/object/')) {
      final index = int.parse(request.url.pathSegments.last.split('.').first);
      return http.Response.bytes(
        badImages.contains(index) ? [1, 2, 3] : photos[index].bytes,
        200,
        headers: {'content-type': photos[index].mimeType},
        request: request,
      );
    }
    throw StateError('Unexpected fixture request: ${request.url}');
  }

  http.Response _json(http.Request request, Object? value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  Future<void> prepare() async {
    metadata.addAll([
      for (var index = 3; index >= 0; index--)
        {
          'position': index,
          'object_path': '$_owner/$_draft/$index.${photos[index].extension}',
          'mime_type': photos[index].mimeType,
          'bytes': photos[index].byteLength,
          'width': photos[index].width,
          'height': photos[index].height,
        },
    ]);
    for (final value in [_other, _owner]) {
      owner = value;
      await client.auth.signInWithPassword(
        email: 'draft@example.invalid',
        password: 'synthetic',
      );
      sessions[value] = jsonEncode(client.auth.currentSession!.toJson());
    }
  }

  Future<void> roundTrip() async {
    final other = client.auth.recoverSession(sessions[_other]!);
    final original = client.auth.recoverSession(sessions[_owner]!);
    await Future.wait([other, original]);
  }

  Iterable<http.Request> get mediaRequests =>
      dataRequests.where((request) => request.url.path.startsWith('/storage/'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<CommunityPostImageDraft> photos;
  late List<CommunityPostImagePreview> thumbnails;
  late _DraftBackend backend;
  late CommunityRepository repository;
  setUpAll(() async {
    photos = [
      for (final name in [
        'shakshuka',
        'lentil_soup',
        'quinoa_tabbouleh',
        'yogurt_oat_bowl',
      ])
        validateCommunityPostImage(
          await File(
            'assets/images/professional/recipes/$name.jpg',
          ).readAsBytes(),
        ),
    ];
    thumbnails = [
      for (final photo in photos)
        await createCommunityPostImagePreviewAsync(
          photo.bytes,
          expectedMimeType: photo.mimeType,
          expectedByteLength: photo.byteLength,
          expectedWidth: photo.width,
          expectedHeight: photo.height,
        ),
    ];
  });
  setUp(() async {
    backend = _DraftBackend(photos);
    await backend.prepare();
    repository = CommunityRepository(backend.client);
  });
  tearDown(() async => backend.client.dispose());

  test(
    'four-photo preview reads metadata once and preserves server order',
    () async {
      final preview = await repository.loadMyCommunityDraftMosaicPreview(
        _draft,
      );
      expect(preview.draft.draftId, _draft);
      expect(preview.draft.pollOptions, ['Food', 'Sleep']);
      expect(
        backend.dataRequests.where(
          (request) => request.url.path.contains('/rpc/'),
        ),
        hasLength(1),
      );
      expect(backend.mediaRequests, hasLength(4));
      expect(preview.images, hasLength(4));
      for (var index = 0; index < 4; index++) {
        expect(preview.images[index]!.bytes, thumbnails[index].bytes);
        expect(
          backend.mediaRequests.elementAt(index).url.pathSegments.last,
          '$index.${photos[index].extension}',
        );
      }
    },
  );

  test('preview photo bound is enforced before transport', () async {
    for (final invalid in [0, 5]) {
      await expectLater(
        repository.loadMyCommunityDraftMosaicPreview(
          _draft,
          maxImages: invalid,
        ),
        throwsArgumentError,
      );
    }
    expect(backend.dataRequests, isEmpty);
    final preview = await repository.loadMyCommunityDraftMosaicPreview(
      _draft,
      maxImages: 2,
    );
    expect(preview.images, hasLength(2));
    expect(backend.mediaRequests, hasLength(2));
    expect(preview.draft.media, hasLength(4));
  });

  test(
    'one invalid photo retains other slots and complete poll metadata',
    () async {
      backend.badImages.add(1);
      final preview = await repository.loadMyCommunityDraftMosaicPreview(
        _draft,
      );
      expect(preview.images[1], isNull);
      expect(preview.images[0]!.bytes, thumbnails[0].bytes);
      expect(preview.images[2]!.bytes, thumbnails[2].bytes);
      expect(preview.images[3]!.bytes, thumbnails[3].bytes);
      expect(preview.draft.body, 'The complete body stays in the repository.');
      expect(preview.draft.pollOptions, ['Food', 'Sleep']);
      expect(backend.mediaRequests, hasLength(4));
    },
  );

  test(
    'metadata byte mismatch is one failed slot, not a false success',
    () async {
      backend.metadata.singleWhere((row) => row['position'] == 2)['bytes'] = 1;
      final preview = await repository.loadMyCommunityDraftMosaicPreview(
        _draft,
      );
      expect(preview.images[2], isNull);
      expect(
        preview.images.whereType<CommunityPostImagePreview>(),
        hasLength(3),
      );
    },
  );

  test('bounded previews never replace the four editor originals', () async {
    final preview = await repository.loadMyCommunityDraftMosaicPreview(_draft);
    expect(preview.images, hasLength(4));
    var retainedBytes = 0;
    for (var index = 0; index < 4; index++) {
      final image = preview.images[index]!;
      expect(image.width, lessThanOrEqualTo(256));
      expect(image.height, lessThanOrEqualTo(256));
      expect(image.byteLength, lessThanOrEqualTo(64 * 1024));
      expect(image, isNot(isA<CommunityPostImageDraft>()));
      expect(image.bytes, isNot(photos[index].bytes));
      retainedBytes += image.byteLength;
    }
    expect(retainedBytes, lessThanOrEqualTo(256 * 1024));
    final editor = await repository.loadMyCommunityDraft(_draft);
    expect(editor.images, hasLength(4));
    expect(editor.draft.media.map((media) => media.position), [3, 2, 1, 0]);
    for (var index = 0; index < 4; index++) {
      final original = photos[editor.draft.media[index].position];
      expect(editor.images[index].bytes, original.bytes);
      expect(editor.images[index].width, original.width);
      expect(editor.images[index].height, original.height);
    }
    final legacy = await repository.loadMyCommunityDraftPreview(_draft);
    expect(legacy.image!.bytes, photos.first.bytes);
    expect(backend.mediaRequests, hasLength(9));
    expect(preview.draft.body, editor.draft.body);
    expect(preview.draft.pollOptions, editor.draft.pollOptions);
  });

  for (final field in ['mime_type', 'width', 'height']) {
    test(
      'preview rejects original $field mismatch before retaining it',
      () async {
        backend.metadata.singleWhere((row) => row['position'] == 2)[field] =
            field == 'mime_type' ? 'image/png' : 1;
        final preview = await repository.loadMyCommunityDraftMosaicPreview(
          _draft,
        );
        expect(preview.images[2], isNull);
        expect(
          preview.images.whereType<CommunityPostImagePreview>(),
          hasLength(3),
        );
        expect(backend.mediaRequests, hasLength(4));
      },
    );
  }

  for (final malformed in [
    'duplicate position',
    'foreign owner',
    'fifth image',
  ]) {
    test('malformed $malformed starts no storage download', () async {
      switch (malformed) {
        case 'duplicate position':
          backend.metadata.first['position'] = 2;
        case 'foreign owner':
          backend.metadata.first['object_path'] = '$_other/$_draft/3.jpg';
        case 'fifth image':
          backend.metadata.add(Map.of(backend.metadata.first));
      }
      await expectLater(
        repository.loadMyCommunityDraftMosaicPreview(_draft),
        throwsFormatException,
      );
      expect(backend.mediaRequests, isEmpty);
    });
  }

  for (final boundary in ['metadata', 'first photo', 'list']) {
    test(
      'actual queued ABA cancels $boundary and starts no late request',
      () async {
        final reached = Completer<void>();
        final release = Completer<void>();
        backend.beforeResponse = (request) async {
          final selected = boundary == 'first photo'
              ? request.url.path.startsWith('/storage/')
              : request.url.path.contains(
                  boundary == 'list' ? 'bil_list_' : 'bil_get_',
                );
          if (selected && !reached.isCompleted) {
            reached.complete();
            await release.future;
          }
        };
        final pending = boundary == 'list'
            ? repository.listMyCommunityDrafts()
            : repository.loadMyCommunityDraftMosaicPreview(_draft);
        final assertion = expectLater(
          pending,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        await reached.future.timeout(const Duration(seconds: 5));
        await backend.roundTrip();
        expect(backend.client.auth.currentUser!.id, _owner);
        release.complete();
        await assertion;
        expect(
          backend.mediaRequests,
          hasLength(boundary == 'first photo' ? 1 : 0),
        );
        expect(
          backend.dataRequests,
          hasLength(boundary == 'first photo' ? 2 : 1),
        );
      },
    );
  }

  test(
    'list uses the existing UTC timestamp and UUID cursor without mutation',
    () async {
      final before = DateTime.parse('2026-10-06T11:00:00+02:00');
      await repository.listMyCommunityDrafts(
        before: before,
        beforeId: _draft,
        limit: 20,
      );
      expect(backend.dataRequests, hasLength(1));
      expect(jsonDecode(backend.dataRequests.single.body), {
        'p_before': '2026-10-06T09:00:00.000Z',
        'p_before_id': _draft,
        'p_limit': 20,
      });
    },
  );

  test(
    'Profile badge limit50 reaches RPC while invalid limits start no request',
    () async {
      await repository.listMyCommunityDrafts(limit: 50);
      expect(backend.dataRequests, hasLength(1));
      expect(jsonDecode(backend.dataRequests.single.body), {
        'p_before': null,
        'p_before_id': null,
        'p_limit': 50,
      });
      for (final limit in [0, 51]) {
        await expectLater(
          repository.listMyCommunityDrafts(limit: limit),
          throwsArgumentError,
        );
        expect(backend.dataRequests, hasLength(1));
      }
      await expectLater(
        repository.listMyCommunityDrafts(before: DateTime.utc(2026, 10, 6)),
        throwsArgumentError,
      );
      expect(backend.dataRequests, hasLength(1));
    },
  );
}
