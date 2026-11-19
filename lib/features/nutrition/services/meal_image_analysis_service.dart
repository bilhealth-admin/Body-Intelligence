import 'meal_image_estimate_contract.dart';
import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/environment/app_environment.dart';
import 'meal_image_gateway_contract.dart';
import 'meal_vision_image_preprocessor.dart';

export 'meal_image_gateway_contract.dart';

class MealImageAnalysisService {
  MealImageAnalysisService({
    String? endpoint,
    this.schemaVersion =
        const bool.fromEnvironment('BIL_GEMINI_PHOTO_ESTIMATES_V2') ? 2 : 1,
    MealImageGatewayPost? gatewayPost,
    MealImageAccessToken? accessToken,
    MealVisionImagePreprocessor? imagePreprocessor,
    this.requestedLocale,
    this.requestTimeout = const Duration(seconds: 35),
    this.operationTimeout = const Duration(seconds: 75),
    this.inProgressPollDelay = const Duration(seconds: 2),
  }) : _endpoint = endpoint ?? configuredEndpoint,
       _gatewayPost = gatewayPost ?? _post,
       _accessToken = accessToken ?? _currentAccessToken,
       _imagePreprocessor =
           imagePreprocessor ?? const DefaultMealVisionImagePreprocessor();

  static const configuredEndpoint = AppEnvironment.mealVisionEndpoint;

  final String _endpoint;
  final int schemaVersion;
  bool get usesGeminiEstimates => schemaVersion == 2;
  final MealImageGatewayPost _gatewayPost;
  final MealImageAccessToken _accessToken;
  final MealVisionImagePreprocessor _imagePreprocessor;
  final String? requestedLocale;
  final Duration requestTimeout;
  final Duration operationTimeout;
  final Duration inProgressPollDelay;

  bool get configured => _endpoint.trim().isNotEmpty;

  Future<MealImageAnalysis> analyze(XFile image) => _analyze(image);

  /// The schema2 caller captures its authenticated visit before any picker or
  /// consent await. A stale selected photo never uploads under a later visit.
  Future<MealImageAnalysis> analyzeForOwner(
    XFile image, {
    required bool Function() isCurrent,
  }) => _analyze(image, isCurrent: isCurrent);

  Future<MealImageAnalysis> _analyze(
    XFile image, {
    bool Function()? isCurrent,
  }) async {
    void checkVisit() {
      if (usesGeminiEstimates && isCurrent?.call() != true) {
        throw const MealImageAnalysisException(
          MealImageAnalysisFailure.authenticationRequired,
        );
      }
    }

    checkVisit();
    final uri = Uri.tryParse(_endpoint.trim());
    if (!const {1, 2}.contains(schemaVersion) ||
        !configured ||
        uri == null ||
        uri.scheme != 'https') {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.notConfigured,
      );
    }
    final token = _accessToken()?.trim();
    if (token == null || token.isEmpty) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.authenticationRequired,
      );
    }
    final bytes = await image.readAsBytes();
    checkVisit();
    final mimeType = image.mimeType ?? _mimeType(image.path);
    if (bytes.isEmpty ||
        bytes.length > maximumMealImageBytes ||
        !_allowedMimeTypes.contains(mimeType) ||
        !_matchesSignature(bytes, mimeType)) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.invalidImage,
      );
    }
    final prepared = await _imagePreprocessor.prepare(
      bytes: bytes,
      mimeType: mimeType,
    );

    checkVisit();
    final idempotencyKey = const Uuid().v4();
    MealImageGatewayResponse? response;
    final operation = Stopwatch()..start();
    var transientAttempts = 0;
    while (operation.elapsed < operationTimeout) {
      final remaining = operationTimeout - operation.elapsed;
      final timeout = remaining < requestTimeout ? remaining : requestTimeout;
      try {
        checkVisit();
        response =
            await _gatewayPost(
              uri: uri,
              headers: {
                HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
                HttpHeaders.authorizationHeader: 'Bearer $token',
                'x-idempotency-key': idempotencyKey,
                'accept': ContentType.json.mimeType,
              },
              body: jsonEncode({
                'schema_version': schemaVersion,
                'mime_type': prepared.mimeType,
                'image_base64': base64Encode(prepared.bytes),
                'image_sha256': prepared.sha256,
                'image_width': prepared.width,
                'image_height': prepared.height,
                'image_reencoded': prepared.reencoded,
                'requested_locale': _localeTag(
                  requestedLocale ?? Platform.localeName,
                ),
              }),
            ).timeout(
              timeout,
              onTimeout: () => throw const MealImageAnalysisException(
                MealImageAnalysisFailure.serviceUnavailable,
              ),
            );
      } on MealImageAnalysisException catch (error) {
        if (transientAttempts++ >= 1 ||
            error.failure != MealImageAnalysisFailure.serviceUnavailable) {
          rethrow;
        }
        continue;
      }
      checkVisit();
      if (_isSameRequestInProgress(response)) {
        if (operation.elapsed + inProgressPollDelay >= operationTimeout) break;
        await Future<void>.delayed(inProgressPollDelay);
        response = null;
        continue;
      }
      if (_isLanguageMismatch(response) ||
          !_transientStatusCodes.contains(response.statusCode)) {
        break;
      }
      if (transientAttempts++ >= 1) break;
      response = null;
    }
    checkVisit();
    if (response == null) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.serviceUnavailable,
      );
    }
    if (response.statusCode == HttpStatus.unauthorized) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.authenticationRequired,
      );
    }
    if (response.statusCode == 402) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.boostRequired,
      );
    }
    if (response.statusCode == HttpStatus.tooManyRequests) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.rateLimited,
      );
    }
    if (response.statusCode == HttpStatus.unprocessableEntity) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.nonFoodOrUnrecognized,
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      if (_isLanguageMismatch(response)) {
        throw const MealImageAnalysisException(
          MealImageAnalysisFailure.languageMismatch,
        );
      }
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.serviceUnavailable,
      );
    }
    if (utf8.encode(response.body).length > maximumMealImageResponseBytes) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.invalidResponse,
      );
    }
    if (usesGeminiEstimates) {
      return parseGeminiMealImageResponse(
        response.body,
        languageCode: _localeTag(requestedLocale ?? Platform.localeName),
      );
    }
    return parseMealImageResponse(
      response.body,
      languageCode: _localeTag(requestedLocale ?? Platform.localeName),
    );
  }

  static const _allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  // A language-contract failure is not transient: do not run the same paid
  // analysis twice. Interpret only a bounded machine code, never remote copy.
  static bool _isLanguageMismatch(MealImageGatewayResponse response) {
    if (response.statusCode == HttpStatus.ok || response.body.length >= 2048) {
      return false;
    }
    try {
      final failure = jsonDecode(response.body);
      return failure is Map && failure['error'] == 'vision_language_mismatch';
    } on FormatException {
      return false;
    }
  }

  static bool _isSameRequestInProgress(MealImageGatewayResponse response) {
    if (response.statusCode != HttpStatus.conflict ||
        response.body.length >= 2048) {
      return false;
    }
    try {
      final failure = jsonDecode(response.body);
      return failure is Map &&
          failure['error'] == 'request_already_processed' &&
          failure['state'] == 'reserved';
    } on FormatException {
      return false;
    }
  }

  static const _transientStatusCodes = {
    HttpStatus.badGateway,
    HttpStatus.serviceUnavailable,
    HttpStatus.gatewayTimeout,
  };

  static String? _currentAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  static String _localeTag(String locale) {
    final parts = locale.trim().replaceAll('_', '-').split('-');
    if (parts.isEmpty || !RegExp(r'^[A-Za-z]{2,3}$').hasMatch(parts.first)) {
      return 'en';
    }
    final normalized = <String>[parts.first.toLowerCase()];
    for (final part in parts.skip(1).take(2)) {
      if (RegExp(r'^[A-Za-z]{4}$').hasMatch(part)) {
        normalized.add(
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        );
      } else if (RegExp(r'^[A-Za-z]{2}$').hasMatch(part)) {
        normalized.add(part.toUpperCase());
      } else if (RegExp(r'^\d{3}$').hasMatch(part)) {
        normalized.add(part);
      } else {
        break;
      }
    }
    return normalized.join('-');
  }

  static String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static bool _matchesSignature(List<int> bytes, String mimeType) {
    if (mimeType == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    }
    if (mimeType == 'image/png') {
      const signature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
      if (bytes.length < signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[index] != signature[index]) return false;
      }
      return true;
    }
    if (mimeType == 'image/webp') {
      return bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    }
    return false;
  }

  static Future<MealImageGatewayResponse> _post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      headers.forEach(request.headers.set);
      request.write(body);
      final response = await request.close();
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 30));
      return MealImageGatewayResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } on MealImageAnalysisException {
      rethrow;
    } catch (_) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.serviceUnavailable,
      );
    } finally {
      client.close(force: true);
    }
  }
}
