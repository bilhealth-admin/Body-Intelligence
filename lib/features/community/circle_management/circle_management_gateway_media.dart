part of 'circle_management_gateway.dart';

extension _CircleManagementGatewayMedia on RepositoryCircleManagementGateway {
  Future<ManagedCommunityCircle> _hydrateCircle(
    ManagedCommunityCircle circle,
  ) async {
    final avatar = await _signMedia(
      circle.avatar,
      circle.slug,
      CircleMediaKind.avatar,
    );
    final cover = await _signMedia(
      circle.cover,
      circle.slug,
      CircleMediaKind.cover,
    );
    _check();
    return circle.withMedia(avatar: avatar, cover: cover);
  }

  Future<CircleMediaReference?> _signMedia(
    CircleMediaReference? media,
    String slug,
    CircleMediaKind kind,
  ) async {
    if (media == null) return null;
    final parts = media.objectPath.split('/');
    if (parts.length != 4 ||
        parts[1] != slug ||
        parts[2] != kind.name ||
        !circleUuidPattern.hasMatch(parts[0])) {
      throw const FormatException('Circle media target mismatch');
    }
    _check();
    try {
      final url = await _transport.sign(media);
      _check();
      final uri = Uri.tryParse(url);
      final local =
          uri?.scheme == 'http' &&
          const ['127.0.0.1', 'localhost', '::1'].contains(uri?.host);
      if (uri == null ||
          !(uri.scheme == 'https' || local) ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid circle media URL');
      }
      return media.withSignedUrl(url);
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } on Object {
      _check();
      // Failure to sign an image leaves a real reference without an image URL;
      // it does not erase the circle, invent a cover, or imply upload success.
      return media.withSignedUrl(null);
    }
  }

  Future<CircleMutationReceipt> _hydrateReceipt(
    CircleMutationReceipt receipt,
  ) async => CircleMutationReceipt(
    ownerId: receipt.ownerId,
    requestId: receipt.requestId,
    operation: receipt.operation,
    circleSlug: receipt.circleSlug,
    inviteId: receipt.inviteId,
    mediaId: receipt.mediaId,
    circle: receipt.circle == null
        ? null
        : await _hydrateCircle(receipt.circle!),
    invite: receipt.invite,
    media: receipt.media,
  );
}
