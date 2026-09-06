import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../repositories/recipe_release_repository.dart';

/// One additive, content-addressed recipe thumbnail.
final class RecipeThumbnailAsset {
  const RecipeThumbnailAsset({
    required this.canonicalId,
    required this.sourceSha256,
    required this.asset,
  });

  final String canonicalId;
  final String sourceSha256;
  final RecipeCatalogImageAsset asset;
}

/// Bundled v4 thumbnail contract bound to the bundled v1 source manifest.
final class RecipeThumbnailManifest {
  const RecipeThumbnailManifest({
    required this.sourceImageManifestSha256,
    required this.totalSizeBytes,
    required this.assets,
  });

  static const schemaVersion = 4;
  static const recordCount = 1500;

  final String sourceImageManifestSha256;
  final int totalSizeBytes;
  final Map<String, RecipeThumbnailAsset> assets;

  factory RecipeThumbnailManifest.fromJson(Map<String, dynamic> json) {
    _exactThumbnailKeys(json, const {
      'schema_version',
      'record_count',
      'source_image_manifest_sha256',
      'total_size_bytes',
      'transformation',
      'entries',
    });
    if (json['schema_version'] != schemaVersion ||
        json['record_count'] != recordCount) {
      throw const FormatException('Unsupported recipe thumbnail contract.');
    }
    final sourceManifestSha256 = _thumbnailDigest(
      json['source_image_manifest_sha256'],
      'source_image_manifest_sha256',
    );
    _validateTransformation(json['transformation']);
    final entries = json['entries'];
    if (entries is! List || entries.length != recordCount) {
      throw const FormatException('Recipe thumbnail count is invalid.');
    }
    final assets = <String, RecipeThumbnailAsset>{};
    var measuredTotal = 0;
    for (final raw in entries) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Recipe thumbnail entry is invalid.');
      }
      _exactThumbnailKeys(raw, const {
        'canonical_id',
        'source_sha256',
        'object_path',
        'delivery_path',
        'mime_type',
        'size_bytes',
        'sha256',
        'width',
        'height',
      });
      final id = _thumbnailText(raw['canonical_id'], 'canonical_id');
      if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id) ||
          assets.containsKey(id)) {
        throw const FormatException('Recipe thumbnail identity is invalid.');
      }
      final sourceSha256 = _thumbnailDigest(
        raw['source_sha256'],
        'source_sha256',
      );
      final digest = _thumbnailDigest(raw['sha256'], 'sha256');
      final sizeBytes = _thumbnailPositiveInteger(
        raw['size_bytes'],
        'size_bytes',
      );
      final width = _thumbnailPositiveInteger(raw['width'], 'width');
      final height = _thumbnailPositiveInteger(raw['height'], 'height');
      final objectPath = _thumbnailText(raw['object_path'], 'object_path');
      final deliveryPath = _thumbnailText(
        raw['delivery_path'],
        'delivery_path',
      );
      if (raw['mime_type'] != 'image/webp' ||
          width > 512 ||
          height > 512 ||
          sizeBytes > 2 * 1024 * 1024 ||
          objectPath != 'recipes/v4/thumbnails/512/$id-$digest.webp' ||
          deliveryPath != '/v4/recipes/thumbnails/$id/$digest.webp') {
        throw const FormatException('Recipe thumbnail media is invalid.');
      }
      measuredTotal += sizeBytes;
      assets[id] = RecipeThumbnailAsset(
        canonicalId: id,
        sourceSha256: sourceSha256,
        asset: RecipeCatalogImageAsset(
          canonicalId: id,
          url: Uri.https('workouts.bilhealth.com', deliveryPath),
          mimeType: 'image/webp',
          sha256: digest,
          sizeBytes: sizeBytes,
          width: width,
          height: height,
        ),
      );
    }
    final declaredTotal = _thumbnailPositiveInteger(
      json['total_size_bytes'],
      'total_size_bytes',
    );
    if (declaredTotal != measuredTotal) {
      throw const FormatException('Recipe thumbnail byte total is invalid.');
    }
    return RecipeThumbnailManifest(
      sourceImageManifestSha256: sourceManifestSha256,
      totalSizeBytes: declaredTotal,
      assets: Map.unmodifiable(assets),
    );
  }
}

abstract interface class RecipeThumbnailManifestLoader {
  Future<RecipeThumbnailManifest> load();
}

/// Reads the immutable thumbnail manifest shipped with the app.
///
/// The original v1 image manifest remains untouched and authoritative. If this
/// additive asset is absent or malformed, the caller falls back to v3 pixels.
final class BundledRecipeThumbnailManifestLoader
    implements RecipeThumbnailManifestLoader {
  BundledRecipeThumbnailManifestLoader({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const manifestPath =
      'assets/catalogs/recipes/v1/recipe-thumbnails-v4.json';
  static const manifestSha256 =
      '24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029';
  static const manifestSizeBytes = 899684;
  static const _maximumManifestBytes = 2 * 1024 * 1024;

  final AssetBundle _bundle;
  Future<RecipeThumbnailManifest>? _manifestFuture;

  @override
  Future<RecipeThumbnailManifest> load() {
    return _manifestFuture ??= _load().catchError((Object error) {
      _manifestFuture = null;
      throw error;
    });
  }

  Future<RecipeThumbnailManifest> _load() async {
    final data = await _bundle.load(manifestPath);
    if (data.lengthInBytes != manifestSizeBytes ||
        data.lengthInBytes > _maximumManifestBytes) {
      throw const FormatException('Recipe thumbnail manifest size is invalid.');
    }
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (sha256.convert(bytes).toString() != manifestSha256) {
      throw const FormatException(
        'Recipe thumbnail manifest integrity mismatch.',
      );
    }
    final json = await compute(_decodeRecipeThumbnailObject, bytes);
    return RecipeThumbnailManifest.fromJson(json);
  }
}

Map<String, dynamic> _decodeRecipeThumbnailObject(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Recipe thumbnail manifest must be an object.');
  }
  return decoded;
}

void _validateTransformation(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Recipe thumbnail transformation is invalid.');
  }
  _exactThumbnailKeys(value, const {
    'codec',
    'fit',
    'max_height',
    'max_width',
    'method',
    'quality',
    'resampling',
    'version',
  });
  if (value['codec'] != 'libwebp' ||
      value['fit'] != 'contain-no-upscale' ||
      value['max_height'] != 512 ||
      value['max_width'] != 512 ||
      value['method'] != 6 ||
      value['quality'] != 78 ||
      value['resampling'] != 'lanczos' ||
      value['version'] != 1) {
    throw const FormatException('Unsupported recipe thumbnail transformation.');
  }
}

void _exactThumbnailKeys(Map<String, dynamic> value, Set<String> expected) {
  final actual = value.keys.toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw const FormatException('Recipe thumbnail fields are invalid.');
  }
}

String _thumbnailText(Object? value, String field) {
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw FormatException('$field is invalid.');
  }
  return value;
}

String _thumbnailDigest(Object? value, String field) {
  final digest = _thumbnailText(value, field);
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
    throw FormatException('$field is not a lowercase SHA-256 digest.');
  }
  return digest;
}

int _thumbnailPositiveInteger(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw FormatException('$field must be a positive integer.');
  }
  return value;
}
