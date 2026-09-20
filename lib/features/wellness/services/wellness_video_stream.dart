import 'dart:async';
import 'dart:io';

import '../domain/wellness_content_pack.dart';
import 'wellness_access_token.dart';

/// A range-capable network source for the native video player.
///
/// [httpHeaders] pins playback to the entity inspected by the resolver's HEAD
/// request. It can also contain the current BIL bearer for the canonical,
/// protected workout origin. Callers must never persist or log these headers.
final class WellnessVideoStream {
  const WellnessVideoStream({required this.uri, required this.httpHeaders});

  final Uri uri;
  final Map<String, String> httpHeaders;
}

/// Resolves trusted first-party workout videos without downloading them first.
///
/// This is a playback availability and entity-pinning check, not full byte
/// verification. SHA-256 remains verified only when `WellnessMediaCache`
/// performs an explicit download. A first-party validation or transport
/// failure throws and must not silently bypass to an unpinned network player.
final class WellnessVideoStreamResolver {
  WellnessVideoStreamResolver({
    HttpClient? client,
    WellnessAccessTokenLoader? accessTokenLoader,
    this.idleTimeout = const Duration(seconds: 15),
  }) : _client = client ?? HttpClient(),
       _ownsClient = client == null,
       _accessTokenLoader =
           accessTokenLoader ?? loadCurrentWellnessAccessToken {
    if (idleTimeout <= Duration.zero) {
      throw ArgumentError.value(idleTimeout, 'idleTimeout', 'Must be positive');
    }
    if (_ownsClient) _client.connectionTimeout = idleTimeout;
  }

  static const _deliveryHost = 'workouts.bilhealth.com';
  static const _responseCancelTimeout = Duration(seconds: 1);
  static final _movementPath = RegExp(
    r'^/v2/objects/workouts/v1/(?:home|gym-six-month)/movements/'
    r'[a-z0-9]+(?:-[a-z0-9]+)*\.mp4$',
  );
  static final _digest = RegExp(r'^[a-f0-9]{64}$');

  final HttpClient _client;
  final bool _ownsClient;
  final WellnessAccessTokenLoader _accessTokenLoader;
  final Duration idleTimeout;

  /// Returns `null` only for a valid asset hosted outside BIL's first-party
  /// workout origin, allowing the caller to use its digest-verifying download.
  Future<WellnessVideoStream?> resolve(WellnessMediaAsset asset) async {
    _validateMetadata(asset);
    final uri = asset.url;
    if (uri.host.toLowerCase() != _deliveryHost) return null;
    if (asset.mimeType != 'video/mp4') {
      throw const FormatException(
        'First-party streamed wellness media must be video/mp4.',
      );
    }
    _validateCanonicalFirstPartyUri(uri);

    HttpClientRequest? request;
    HttpClientResponse? response;
    var abandoned = false;
    try {
      request = await _client
          .headUrl(uri)
          .then((lateRequest) {
            // Future.timeout cannot cancel headUrl. Abort an eventual request
            // after the attempt has already expired.
            if (abandoned) _abort(lateRequest);
            return lateRequest;
          })
          .timeout(
            idleTimeout,
            onTimeout: () {
              abandoned = true;
              throw TimeoutException(
                'Wellness video connection timed out.',
                idleTimeout,
              );
            },
          );
      request.followRedirects = false;
      applyWellnessBearer(request, _accessTokenLoader, uri);

      response = await request
          .close()
          .then((lateResponse) {
            // Abort closes the request, but also cancel a response that races
            // the timeout so it cannot remain alive behind a later retry.
            if (abandoned) unawaited(_cancelResponse(lateResponse));
            return lateResponse;
          })
          .timeout(
            idleTimeout,
            onTimeout: () {
              abandoned = true;
              _abort(request!);
              throw TimeoutException(
                'Wellness video headers timed out.',
                idleTimeout,
              );
            },
          );

      final etag = _validateHead(response, asset);
      final authorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      return WellnessVideoStream(
        uri: uri,
        httpHeaders: Map.unmodifiable({
          HttpHeaders.ifMatchHeader: etag,
          if (authorization != null && authorization.isNotEmpty)
            HttpHeaders.authorizationHeader: authorization,
        }),
      );
    } catch (_) {
      abandoned = true;
      if (request != null) _abort(request);
      rethrow;
    } finally {
      if (response != null) await _cancelResponse(response);
    }
  }

  void dispose() {
    if (_ownsClient) _client.close(force: false);
  }

  static void _validateMetadata(WellnessMediaAsset asset) {
    final uri = asset.url;
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Wellness video URL must use HTTPS.');
    }
    if (asset.mimeType != 'video/mp4' && asset.mimeType != 'video/webm') {
      throw const FormatException('Wellness video MIME type is invalid.');
    }
    if (!_digest.hasMatch(asset.sha256) || asset.sizeBytes <= 0) {
      throw const FormatException('Invalid wellness video integrity metadata.');
    }
  }

  static void _validateCanonicalFirstPartyUri(Uri uri) {
    final hasNonDefaultPort = uri.hasPort && uri.port != 443;
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        hasNonDefaultPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.toString().contains('%') ||
        !_movementPath.hasMatch(uri.path)) {
      throw const FormatException(
        'First-party wellness video URL is not canonical.',
      );
    }
  }

  static String _validateHead(
    HttpClientResponse response,
    WellnessMediaAsset asset,
  ) {
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Wellness video HEAD returned ${response.statusCode}.',
        uri: asset.url,
      );
    }
    if (response.contentLength != asset.sizeBytes) {
      throw const FormatException(
        'Wellness video length does not match catalog metadata.',
      );
    }
    final contentType = response.headers.contentType?.mimeType.toLowerCase();
    if (contentType != 'video/mp4') {
      throw const FormatException('Wellness video MIME type is invalid.');
    }
    final acceptRanges = response.headers
        .value(HttpHeaders.acceptRangesHeader)
        ?.trim()
        .toLowerCase();
    if (acceptRanges != 'bytes') {
      throw const FormatException(
        'Wellness video server must support byte ranges.',
      );
    }
    final etag = response.headers.value(HttpHeaders.etagHeader)?.trim();
    if (etag == null || !_isStrongQuotedEtag(etag)) {
      throw const FormatException(
        'Wellness video requires a strong quoted ETag.',
      );
    }
    return etag;
  }

  static bool _isStrongQuotedEtag(String value) {
    if (value.length < 3 ||
        value.startsWith('W/') ||
        !value.startsWith('"') ||
        !value.endsWith('"')) {
      return false;
    }
    final opaqueTag = value.substring(1, value.length - 1);
    return opaqueTag.isNotEmpty &&
        !opaqueTag.contains('"') &&
        !RegExp(r'[\u0000-\u0020\u007f]').hasMatch(opaqueTag);
  }

  static void _abort(HttpClientRequest request) {
    try {
      request.abort();
    } catch (_) {
      // Transport cleanup must not mask the validation or timeout failure.
    }
  }

  static Future<void> _cancelResponse(HttpClientResponse response) async {
    try {
      await response.listen(null).cancel().timeout(_responseCancelTimeout);
    } catch (_) {
      // Best-effort cleanup must not change the resolver's result.
    }
  }
}
