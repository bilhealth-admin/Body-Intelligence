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
    MealImageGatewayPost? gatewayPost,
    MealImageAccessToken? accessToken,
    MealVisionImagePreprocessor? imagePreprocessor,
    this.requestedLocale,
  }) : _endpoint = endpoint ?? configuredEndpoint,
       _gatewayPost = gatewayPost ?? _post,
       _accessToken = accessToken ?? _currentAccessToken,
       _imagePreprocessor =
           imagePreprocessor ?? const DefaultMealVisionImagePreprocessor();

  static const configuredEndpoint = AppEnvironment.mealVisionEndpoint;

  final String _endpoint;
  final MealImageGatewayPost _gatewayPost;
  final MealImageAccessToken _accessToken;
  final MealVisionImagePreprocessor _imagePreprocessor;
  final String? requestedLocale;

  bool get configured => _endpoint.trim().isNotEmpty;

  Future<MealImageAnalysis> analyze(XFile image) async {
    final uri = Uri.tryParse(_endpoint.trim());
    if (!configured || uri == null || uri.scheme != 'https') {
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

    final idempotencyKey = const Uuid().v4();
    MealImageGatewayResponse? response;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
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
                'schema_version': 1,
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
              const Duration(seconds: 35),
              onTimeout: () => throw const MealImageAnalysisException(
                MealImageAnalysisFailure.serviceUnavailable,
              ),
            );
      } on MealImageAnalysisException catch (error) {
        if (attempt == 1 ||
            error.failure != MealImageAnalysisFailure.serviceUnavailable) {
          rethrow;
        }
      }
      if (response != null &&
          !_transientStatusCodes.contains(response.statusCode)) {
        break;
      }
    }
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
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.serviceUnavailable,
      );
    }
    if (utf8.encode(response.body).length > maximumMealImageResponseBytes) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.invalidResponse,
      );
    }
    return parseMealImageResponse(
      response.body,
      languageCode: _localeTag(requestedLocale ?? Platform.localeName),
    );
  }

  static const _allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};
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
