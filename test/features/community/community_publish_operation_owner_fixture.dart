part of 'community_publish_operation_test.dart';

const _otherOwner = '22222222-2222-4222-8222-222222222222';
const _draftId = '33333333-3333-4333-8333-333333333333';
const _postId = '44444444-4444-4444-8444-444444444444';
const _ownerJournal = 'bil.community.publish.operation.v1.$_owner';

String _cachedOwnerSession(String owner, {String revision = 'initial'}) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return jsonEncode({
    'access_token': 'e30.$payload.$revision',
    'refresh_token': 'synthetic-refresh-$revision',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 4102444800,
    'user': {
      'id': owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-05T00:00:00Z',
    },
  });
}

String _requestOwner(http.Request request) {
  final token =
      request.headers['Authorization'] ?? request.headers['authorization'];
  final payload = token!.split(' ').last.split('.')[1];
  final json =
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))))
          as Map;
  return json['sub'] as String;
}

Future<void> _changeOperationOwner(
  SupabaseClient client, {
  bool roundTrip = false,
}) async {
  final delivered = <({String? eventOwner, String? currentOwner})>[];
  final changed = Completer<void>();
  final returned = Completer<void>();
  final observation = client.auth.onAuthStateChange.listen((state) {
    delivered.add((
      eventOwner: state.session?.user.id,
      currentOwner: client.auth.currentUser?.id,
    ));
    if (state.session?.user.id == _otherOwner && !changed.isCompleted) {
      changed.complete();
    } else if (state.session?.user.id == _owner &&
        changed.isCompleted &&
        !returned.isCompleted) {
      returned.complete();
    }
  });
  addTearDown(observation.cancel);
  final second = client.auth.recoverSession(_cachedOwnerSession(_otherOwner));
  if (roundTrip) {
    // Both public SDK calls update currentSession synchronously before their
    // queued stream events. Checking currentUser alone would miss this visit.
    final first = client.auth.recoverSession(_cachedOwnerSession(_owner));
    await Future.wait([second, first]);
    await returned.future;
    expect(
      delivered,
      contains((eventOwner: _otherOwner, currentOwner: _owner)),
    );
    expect(
      delivered.map((item) => item.eventOwner),
      containsAllInOrder([_otherOwner, _owner]),
    );
  } else {
    await second;
    await changed.future;
    expect(client.auth.currentUser?.id, _otherOwner);
  }
}

class _HeldOperationResponse {
  _HeldOperationResponse(this.matches) {
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
  }

  final bool Function(http.Request) matches;
  final entered = Completer<void>();
  final release = Completer<void>();

  Future<void> waitUntilEntered() =>
      entered.future.timeout(const Duration(seconds: 10));

  Future<void> call(http.Request request) async {
    if (!entered.isCompleted && matches(request)) {
      entered.complete();
      await release.future;
    }
  }
}

_HeldOperationResponse _holdRpc(_OperationBackend backend, String rpc) {
  final hold = _HeldOperationResponse(
    (request) => request.url.path.endsWith('/rpc/$rpc'),
  );
  backend.beforeResponse = hold.call;
  return hold;
}

List<String> _rpcNames(_OperationBackend backend) => [
  for (final request in backend.requests)
    if (request.url.path.contains('/rpc/')) request.url.path.split('/').last,
];

void _installDraftRpc(_OperationBackend backend) {
  backend.additionalRpc = (rpc, params) {
    Object? response;
    switch (rpc) {
      case 'bil_assert_community_publish_ready':
        response = null;
      case 'bil_upsert_my_community_post_draft_v1':
        response = params['p_draft_id'];
      case 'bil_set_my_community_post_draft_media_v1':
        response = <String>[];
      case 'bil_delete_my_community_post_draft_v1':
      case 'bil_consume_my_community_post_draft_v1':
        response = ['$_owner/$_draftId/private.png'];
      case 'bil_get_my_community_post_draft_v1':
        final image = _image();
        response = {
          'draft_id': _draftId,
          'body': 'Original private draft',
          'topic_slugs': [],
          'mentions': [],
          'collaborators': [],
          'hashtags': [],
          'poll_options': [],
          'poll_allow_multiple': false,
          'created_at': '2026-10-06T00:00:00Z',
          'updated_at': '2026-10-06T01:00:00Z',
          'media': [
            {
              'position': 0,
              'object_path': '$_owner/$_draftId/private.png',
              'mime_type': image.mimeType,
              'bytes': image.byteLength,
              'width': image.width,
              'height': image.height,
            },
          ],
        };
      default:
        return null;
    }
    return http.Response(jsonEncode(response), 200);
  };
}
