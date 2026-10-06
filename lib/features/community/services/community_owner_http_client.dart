import 'package:http/http.dart' as http;

import 'community_owner_operation.dart';

/// Installed below Supabase's AuthHttpClient, where token resolution has
/// completed but the data request has not yet entered the real transport.
/// This also fences SDK retries without changing shared Authorization headers.
class CommunityOwnerHttpClient extends http.BaseClient {
  CommunityOwnerHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // GoTrue owns auth refresh and its session-version checks. Cancelling auth
    // transport itself could make a harmless closed editor sign the user out.
    // The subsequent data request still crosses this fence after refresh.
    if (request.url.path.contains('/auth/v1/')) return _inner.send(request);
    final validation = CommunityOwnerOperation.checkBeforeDataSend();
    if (validation != null) return _sendValidated(request, validation);
    // No await between the owner check and handing off the immutable request.
    return _inner.send(request);
  }

  Future<http.StreamedResponse> _sendValidated(
    http.BaseRequest request,
    Future<void> validation,
  ) async {
    await validation;
    CommunityOwnerOperation.checkCurrent();
    // The local snapshot was checked after token resolution, and the final
    // owner check remains adjacent to the actual transport handoff.
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
