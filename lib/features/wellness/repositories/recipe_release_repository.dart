import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/recipe_release_manifest.dart';
import '../domain/wellness_content_pack.dart';
import '../../nutrition/domain/dietary_preferences.dart';

final class RecipeCatalogSummary {
  const RecipeCatalogSummary({
    required this.id,
    required this.fingerprint,
    required this.shard,
    required this.ordinal,
    required this.primaryLocale,
    required this.title,
    required this.localizedTitles,
    required this.totalMinutes,
    required this.mealTypes,
    required this.dietTags,
    required this.allergens,
    required this.imageStatus,
    this.region = 'global',
    this.cuisine,
  });

  final String id, fingerprint, primaryLocale, title, imageStatus;
  final String region;
  final String? cuisine;
  final Map<String, String> localizedTitles;
  final int shard, ordinal, totalMinutes;
  final List<String> mealTypes, dietTags, allergens;

  String get category {
    if (totalMinutes <= 20) return 'quick';
    if (dietTags.any((tag) => tag == 'vegan' || tag == 'vegetarian')) {
      return 'plant';
    }
    return 'regional';
  }

  ({String text, String locale, bool isFallback}) resolveTitle(String locale) {
    final requested = localizedTitles[locale];
    if (requested != null) {
      return (text: requested, locale: locale, isFallback: false);
    }
    final primary = localizedTitles[primaryLocale];
    return (
      text: primary ?? title,
      locale: primary != null ? primaryLocale : 'en',
      isFallback: true,
    );
  }

  String titleFor(String locale) => resolveTitle(locale).text;

  bool isCompatibleWith(DietaryPreferences preferences) =>
      DietaryCompatibility.allows(
        preferences: preferences,
        dietTags: dietTags,
        allergens: allergens,
      );
}

final class RecipeCatalogDetail {
  const RecipeCatalogDetail({required this.summary, required this.record});

  final RecipeCatalogSummary summary;
  final Map<String, dynamic> record;

  ({Map<String, dynamic> value, String locale, bool isFallback})
  resolveLocalization(String requested) {
    final localizations = record['localizations'] as Map<String, dynamic>;
    final primary = record['primaryLocale'] as String;
    if (localizations[requested] case final Map<String, dynamic> value) {
      return (value: value, locale: requested, isFallback: false);
    }
    if (localizations['en'] case final Map<String, dynamic> value) {
      return (value: value, locale: 'en', isFallback: true);
    }
    if (localizations[primary] case final Map<String, dynamic> value) {
      return (value: value, locale: primary, isFallback: true);
    }
    final entry = localizations.entries.first;
    return (
      value: entry.value as Map<String, dynamic>,
      locale: entry.key,
      isFallback: true,
    );
  }

  Map<String, dynamic> localization(String requested) =>
      resolveLocalization(requested).value;
}

/// Content-addressed public preview delivered through BIL's private-R2 proxy.
///
/// The client receives only the canonical id and SHA-pinned delivery URL. The
/// R2 bucket and object key remain an implementation detail of the Worker.
final class RecipeCatalogImageAsset {
  const RecipeCatalogImageAsset({
    required this.canonicalId,
    required this.url,
    required this.mimeType,
    required this.sha256,
    required this.sizeBytes,
    required this.width,
    required this.height,
  });

  final String canonicalId, mimeType, sha256;
  final Uri url;
  final int sizeBytes, width, height;

  WellnessMediaAsset get mediaAsset => WellnessMediaAsset(
    url: url,
    mimeType: mimeType,
    sha256: sha256,
    sizeBytes: sizeBytes,
    mediaRole: WellnessMediaRole.preview,
  );
}

/// Small, card-safe projection of the verified recipe detail record.
///
/// Nutrition and serving values intentionally stay out of the 1,500-item
/// discovery index. They are read from the hash-verified shard only when a
/// visible card needs them, then cached by [RecipeReleaseRepository].
final class RecipeCatalogCardFacts {
  const RecipeCatalogCardFacts({
    required this.kcalPerServing,
    required this.proteinGramsPerServing,
    required this.servings,
  });

  final double kcalPerServing;
  final double proteinGramsPerServing;
  final int servings;

  factory RecipeCatalogCardFacts.fromDetail(RecipeCatalogDetail detail) {
    final record = detail.record;
    final nutrition = record['nutrition'];
    final serving = record['serving'];
    if (nutrition is! Map<String, dynamic> ||
        serving is! Map<String, dynamic> ||
        nutrition['perServing'] is! Map<String, dynamic>) {
      throw const FormatException('Recipe card facts are unavailable.');
    }
    final perServing = nutrition['perServing'] as Map<String, dynamic>;
    final kcal = perServing['kcal'];
    final protein = perServing['proteinG'];
    final count = serving['count'];
    if (kcal is! num ||
        !kcal.isFinite ||
        kcal < 0 ||
        protein is! num ||
        !protein.isFinite ||
        protein < 0 ||
        count is! int ||
        count <= 0) {
      throw const FormatException('Recipe card facts are invalid.');
    }
    return RecipeCatalogCardFacts(
      kcalPerServing: kcal.toDouble(),
      proteinGramsPerServing: protein.toDouble(),
      servings: count,
    );
  }
}

final class RecipeReleaseRepository {
  RecipeReleaseRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const manifestPath =
      'assets/catalogs/recipes/v1/release-manifest.json';
  final AssetBundle _bundle;
  Future<List<RecipeCatalogSummary>>? _indexFuture;
  RecipeReleaseManifest? _manifest;
  Map<String, RecipeCatalogSummary> _byId = const {};
  Map<String, RecipeCatalogImageAsset> _imageAssets = const {};
  final Map<int, Future<List<Map<String, dynamic>>>> _shards = {};
  final Map<String, Future<RecipeCatalogCardFacts>> _cardFacts = {};

  Future<List<RecipeCatalogSummary>> loadIndex() {
    return _indexFuture ??= _loadIndex().catchError((Object error) {
      _indexFuture = null;
      throw error;
    });
  }

  Future<List<RecipeCatalogSummary>> _loadIndex() async {
    final manifestBytes = await _readBounded(manifestPath, 512 * 1024);
    final manifestMap = await compute(_decodeObject, manifestBytes);
    final manifest = RecipeReleaseManifest.fromJson(manifestMap);
    _manifest = manifest;
    final imageBytes = await _readBounded(
      manifest.imageManifestPath,
      manifest.imageManifestSizeBytes,
    );
    _verifyBytes(
      imageBytes,
      expectedBytes: manifest.imageManifestSizeBytes,
      expectedSha256: manifest.imageManifestSha256,
    );
    final images = await compute(_decodeObject, imageBytes);
    final imageManifest = _validateImageManifest(images);
    final provenanceBytes = await _readBounded(
      manifest.provenancePath,
      manifest.provenanceSizeBytes,
    );
    _verifyBytes(
      provenanceBytes,
      expectedBytes: manifest.provenanceSizeBytes,
      expectedSha256: manifest.provenanceSha256,
    );
    final provenance = await compute(_decodeObject, provenanceBytes);
    final provenanceImageCount = _validateProvenance(provenance);
    if (provenanceImageCount !=
        imageManifest.states.values
            .where((value) => value == 'external_candidate')
            .length) {
      throw const FormatException('Recipe image provenance count mismatch.');
    }
    final indexBytes = await _readBounded(
      manifest.indexPath,
      manifest.indexSizeBytes,
    );
    _verifyBytes(
      indexBytes,
      expectedBytes: manifest.indexSizeBytes,
      expectedSha256: manifest.indexSha256,
    );
    final index = await compute(_decodeObject, indexBytes);
    _exactKeys(index, const {'schema_version', 'record_count', 'entries'});
    if (index['schema_version'] != 1 || index['record_count'] != 1500) {
      throw const FormatException('Unsupported recipe index.');
    }
    final entries = index['entries'];
    if (entries is! List || entries.length != 1500) {
      throw const FormatException('Recipe index must contain 1500 entries.');
    }
    final ids = <String>{};
    final fingerprints = <String>{};
    final result = <RecipeCatalogSummary>[];
    for (var index = 0; index < entries.length; index++) {
      final raw = entries[index];
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Recipe index entry must be an object.');
      }
      _exactKeys(raw, const {
        'canonical_id',
        'content_fingerprint',
        'shard',
        'ordinal',
        'primary_locale',
        'title',
        'localized_titles',
        'total_minutes',
        'meal_types',
        'diet_tags',
        'allergens',
        'image_status',
        'region',
        'cuisine_key',
      });
      final id = _text(raw['canonical_id'], 'canonical_id');
      final fingerprint = _digest(raw['content_fingerprint']);
      final shard = _integer(raw['shard'], 'shard');
      final ordinal = _integer(raw['ordinal'], 'ordinal');
      if (!ids.add(id) ||
          !fingerprints.add(fingerprint) ||
          shard != index ~/ 50 ||
          ordinal != index % 50) {
        throw const FormatException('Recipe index ordering is invalid.');
      }
      result.add(
        RecipeCatalogSummary(
          id: id,
          fingerprint: fingerprint,
          shard: shard,
          ordinal: ordinal,
          primaryLocale: _text(raw['primary_locale'], 'primary_locale'),
          title: _text(raw['title'], 'title'),
          localizedTitles: _stringMap(
            raw['localized_titles'],
            'localized_titles',
          ),
          totalMinutes: _integer(raw['total_minutes'], 'total_minutes'),
          mealTypes: _strings(raw['meal_types'], 'meal_types'),
          dietTags: _strings(raw['diet_tags'], 'diet_tags'),
          allergens: _strings(raw['allergens'], 'allergens'),
          imageStatus: _text(raw['image_status'], 'image_status'),
          region: _text(raw['region'], 'region'),
          cuisine: _text(raw['cuisine_key'], 'cuisine_key'),
        ),
      );
    }
    for (final recipe in result) {
      if (imageManifest.states[recipe.id] != recipe.imageStatus) {
        throw const FormatException('Recipe index/image state mismatch.');
      }
    }
    _byId = Map.unmodifiable({for (final recipe in result) recipe.id: recipe});
    _imageAssets = imageManifest.assets;
    return List.unmodifiable(result);
  }

  /// Returns the SHA/size/MIME-pinned public preview for one catalog-owned id.
  Future<RecipeCatalogImageAsset> loadImageAsset(String canonicalId) async {
    await loadIndex();
    final asset = _imageAssets[canonicalId];
    if (asset == null || !_byId.containsKey(canonicalId)) {
      throw const FormatException(
        'Recipe image identity is not catalog-owned.',
      );
    }
    return asset;
  }

  /// Exposes the immutable delivery contract in canonical catalog order.
  Future<List<RecipeCatalogImageAsset>> loadImageAssets() async {
    final index = await loadIndex();
    final assets = <RecipeCatalogImageAsset>[];
    for (final recipe in index) {
      final asset = _imageAssets[recipe.id];
      if (asset == null) {
        throw const FormatException(
          'Recipe image delivery contract is incomplete.',
        );
      }
      assets.add(asset);
    }
    return List.unmodifiable(assets);
  }

  Future<RecipeCatalogDetail> loadDetail(RecipeCatalogSummary summary) async {
    await loadIndex();
    final authoritative = _byId[summary.id];
    if (authoritative == null ||
        !identical(authoritative, summary) ||
        summary.shard < 0 ||
        summary.shard >= 30 ||
        summary.ordinal < 0 ||
        summary.ordinal >= 50) {
      throw const FormatException('Recipe summary is not catalog-owned.');
    }
    final records = await (_shards[summary.shard] ??= _loadShard(summary.shard)
        .catchError((Object error) {
          _shards.remove(summary.shard);
          throw error;
        }));
    final record = records[summary.ordinal];
    if (record['canonicalId'] != summary.id ||
        record['contentFingerprint'] != summary.fingerprint) {
      throw const FormatException('Recipe index/shard identity mismatch.');
    }
    return RecipeCatalogDetail(summary: summary, record: record);
  }

  /// Loads the compact facts needed by a visible discovery card.
  ///
  /// Identity is resolved from this repository's authoritative index so a
  /// caller can safely pass only a canonical id. The underlying shard and the
  /// projection future are both cached, avoiding one decode per card.
  Future<RecipeCatalogCardFacts> loadCardFacts(String canonicalId) {
    return _cardFacts.putIfAbsent(canonicalId, () async {
      await loadIndex();
      final summary = _byId[canonicalId];
      if (summary == null) {
        throw const FormatException('Recipe identity is not catalog-owned.');
      }
      final detail = await loadDetail(summary);
      return RecipeCatalogCardFacts.fromDetail(detail);
    });
  }

  Future<List<Map<String, dynamic>>> _loadShard(int ordinal) async {
    final manifest = _manifest!;
    final descriptor = manifest.shards[ordinal];
    final bytes = await _readBounded(descriptor.path, descriptor.sizeBytes);
    _verifyBytes(
      bytes,
      expectedBytes: descriptor.sizeBytes,
      expectedSha256: descriptor.sha256,
    );
    final decoded = await compute(_decodeObject, bytes);
    _exactKeys(decoded, const {'schema_version', 'shard_index', 'records'});
    final records = decoded['records'];
    if (decoded['schema_version'] != 1 ||
        decoded['shard_index'] != ordinal ||
        records is! List ||
        records.length != 50) {
      throw const FormatException('Recipe shard contract is invalid.');
    }
    final typed = List<Map<String, dynamic>>.unmodifiable(
      records.map((record) {
        if (record is! Map<String, dynamic>) {
          throw const FormatException('Recipe record must be an object.');
        }
        _validateRecipeRecord(record);
        return Map<String, dynamic>.unmodifiable(record);
      }),
    );
    if (typed.first['canonicalId'] != descriptor.firstId ||
        typed.last['canonicalId'] != descriptor.lastId) {
      throw const FormatException('Recipe shard boundaries are invalid.');
    }
    return typed;
  }

  Future<Uint8List> _readBounded(String path, int maximumBytes) async {
    if (maximumBytes <= 0 || maximumBytes > 8 * 1024 * 1024) {
      throw const FormatException('Recipe asset size bound is invalid.');
    }
    final data = await _bundle.load(path);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.length > maximumBytes) {
      throw const FormatException('Recipe asset exceeds its size bound.');
    }
    return bytes;
  }
}

int _validateProvenance(Map<String, dynamic> value) {
  _exactKeys(value, const {
    'schema_version',
    'source_inputs',
    'localization_repairs',
    'localization_ingredient_count_mismatches',
    'nutrition_claim',
    'image_claim',
  });
  if (value['schema_version'] != 1 ||
      value['source_inputs'] is! List ||
      value['localization_repairs'] is! List ||
      value['localization_ingredient_count_mismatches'] is! List) {
    throw const FormatException('Recipe provenance is invalid.');
  }
  for (final source in value['source_inputs'] as List) {
    if (source is! Map<String, dynamic>) {
      throw const FormatException('Recipe source evidence is invalid.');
    }
    _exactKeys(source, const {'logical_name', 'sha256', 'size_bytes'});
    _text(source['logical_name'], 'logical_name');
    _digest(source['sha256']);
    _positiveInteger(source['size_bytes'], 'size_bytes');
  }
  for (final repair in value['localization_repairs'] as List) {
    if (repair is! Map<String, dynamic>) {
      throw const FormatException('Recipe repair evidence is invalid.');
    }
    _exactKeys(repair, const {
      'canonical_id',
      'content_fingerprint',
      'before_localizations_sha256',
      'after_localizations_sha256',
    });
    _text(repair['canonical_id'], 'canonical_id');
    _digest(repair['content_fingerprint']);
    _digest(repair['before_localizations_sha256']);
    _digest(repair['after_localizations_sha256']);
  }
  final nutrition = value['nutrition_claim'];
  final images = value['image_claim'];
  if (nutrition is! Map<String, dynamic> || images is! Map<String, dynamic>) {
    throw const FormatException('Recipe provenance claims are invalid.');
  }
  _exactKeys(nutrition, const {
    'calculated_value_record_count',
    'recipe_level_source_reference_count',
    'ingredient_evidence_complete_record_count',
    'ingredient_evidence_incomplete_record_count',
    'external_review_assertion',
    'professional_attestation_artifact',
  });
  final complete = nutrition['ingredient_evidence_complete_record_count'];
  final incomplete = nutrition['ingredient_evidence_incomplete_record_count'];
  if (nutrition['calculated_value_record_count'] != 1500 ||
      nutrition['recipe_level_source_reference_count'] != 1500 ||
      complete is! int ||
      incomplete is! int ||
      complete + incomplete != 1500 ||
      nutrition['external_review_assertion'] != 'owner_asserted_unbound' ||
      nutrition['professional_attestation_artifact'] != null) {
    throw const FormatException('Recipe nutrition claim is invalid.');
  }
  _exactKeys(images, const {'external_candidates', 'externally_available'});
  if (images['external_candidates'] is! int ||
      images['externally_available'] != 0) {
    throw const FormatException('Recipe image claim is invalid.');
  }
  return images['external_candidates'] as int;
}

void _validateRecipeRecord(Map<String, dynamic> value) {
  final id = _text(value['canonicalId'], 'canonicalId');
  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id)) {
    throw const FormatException('Recipe ID is invalid.');
  }
  _digest(value['contentFingerprint']);
  final locale = value['primaryLocale'];
  final localizations = value['localizations'];
  final ingredients = value['ingredients'];
  final method = value['method'];
  final nutrition = value['nutrition'];
  if (!const {'ar', 'en', 'es', 'fr', 'tr'}.contains(locale) ||
      localizations is! Map<String, dynamic> ||
      !localizations.containsKey(locale) ||
      ingredients is! List ||
      ingredients.isEmpty ||
      method is! List ||
      method.isEmpty ||
      nutrition is! Map<String, dynamic> ||
      nutrition['status'] != 'calculated' ||
      nutrition['sourceRefs'] is! List ||
      (nutrition['sourceRefs'] as List).isEmpty ||
      nutrition['perServing'] is! Map<String, dynamic>) {
    throw const FormatException('Recipe record structure is invalid.');
  }
  for (final localization in localizations.values) {
    if (localization is! Map<String, dynamic> ||
        localization['title'] is! String ||
        localization['ingredients'] is! List ||
        localization['steps'] is! List) {
      throw const FormatException('Recipe localization is invalid.');
    }
  }
}

final class _ValidatedRecipeImages {
  const _ValidatedRecipeImages({required this.states, required this.assets});

  final Map<String, String> states;
  final Map<String, RecipeCatalogImageAsset> assets;
}

_ValidatedRecipeImages _validateImageManifest(Map<String, dynamic> value) {
  _exactKeys(value, const {
    'schema_version',
    'record_count',
    'external_candidate_count',
    'placeholder_count',
    'entries',
    'excluded_source_files',
  });
  final entries = value['entries'];
  final external = value['external_candidate_count'];
  final placeholders = value['placeholder_count'];
  if (value['schema_version'] != 1 ||
      value['record_count'] != 1500 ||
      external is! int ||
      placeholders is! int ||
      external + placeholders != 1500 ||
      entries is! List ||
      entries.length != 1500) {
    throw const FormatException('Recipe image manifest is invalid.');
  }
  final ids = <String>{};
  final objectPaths = <String>{};
  final digests = <String>{};
  final states = <String, String>{};
  final assets = <String, RecipeCatalogImageAsset>{};
  var externalRows = 0;
  for (final entry in entries) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('Recipe image entry must be an object.');
    }
    final id = _text(entry['canonical_id'], 'canonical_id');
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id) || !ids.add(id)) {
      throw const FormatException('Duplicate recipe image identity.');
    }
    final status = entry['status'];
    states[id] = status is String ? status : '';
    if (status == 'external_candidate') {
      _exactKeys(entry, const {
        'canonical_id',
        'status',
        'object_path',
        'mime_type',
        'size_bytes',
        'sha256',
        'width',
        'height',
        'review_status',
      });
      externalRows++;
      final digest = _digest(entry['sha256']);
      final sizeBytes = _positiveInteger(entry['size_bytes'], 'size_bytes');
      final width = _positiveInteger(entry['width'], 'width');
      final height = _positiveInteger(entry['height'], 'height');
      final path = _text(entry['object_path'], 'object_path');
      final expectedExtension = entry['mime_type'] == 'image/png'
          ? '.png'
          : '.jpg';
      if (path != 'recipes/v1/images/$id$expectedExtension' ||
          path.contains('..') ||
          path.contains('\\') ||
          path.contains('://') ||
          !objectPaths.add(path) ||
          !digests.add(digest) ||
          sizeBytes > 8 * 1024 * 1024) {
        throw const FormatException('Unsafe recipe image object path.');
      }
      if (!const {'image/png', 'image/jpeg'}.contains(entry['mime_type']) ||
          entry['review_status'] != 'review_evidence_unbound') {
        throw const FormatException('Recipe image evidence is invalid.');
      }
      if ((path.endsWith('.png') && entry['mime_type'] != 'image/png') ||
          (path.endsWith('.jpg') && entry['mime_type'] != 'image/jpeg')) {
        throw const FormatException('Recipe image extension/MIME mismatch.');
      }
      assets[id] = RecipeCatalogImageAsset(
        canonicalId: id,
        url: Uri.https(
          'workouts.bilhealth.com',
          '/v3/recipes/images/$id/$digest',
        ),
        mimeType: entry['mime_type'] as String,
        sha256: digest,
        sizeBytes: sizeBytes,
        width: width,
        height: height,
      );
    } else if (status == 'placeholder') {
      _exactKeys(entry, const {'canonical_id', 'status', 'seed'});
      final seed = _text(entry['seed'], 'seed');
      if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(seed)) {
        throw const FormatException('Recipe placeholder seed is invalid.');
      }
    } else {
      throw const FormatException('Unknown recipe image status.');
    }
  }
  if (externalRows != external || assets.length != external) {
    throw const FormatException('Recipe image counts are inconsistent.');
  }
  return _ValidatedRecipeImages(
    states: Map.unmodifiable(states),
    assets: Map.unmodifiable(assets),
  );
}

Map<String, dynamic> _decodeObject(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Recipe release asset must be an object.');
  }
  return decoded;
}

void _verifyBytes(
  Uint8List bytes, {
  required int expectedBytes,
  required String expectedSha256,
}) {
  if (bytes.length != expectedBytes ||
      sha256.convert(bytes).toString() != expectedSha256) {
    throw const FormatException('Recipe release asset integrity mismatch.');
  }
}

void _exactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(value.keys.toSet()).isNotEmpty) {
    throw const FormatException('Recipe release fields are invalid.');
  }
}

String _text(Object? value, String field) {
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw FormatException('$field is invalid.');
  }
  return value;
}

String _digest(Object? value) {
  final result = _text(value, 'digest');
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(result)) {
    throw const FormatException('Digest is invalid.');
  }
  return result;
}

int _integer(Object? value, String field) {
  if (value is! int || value < 0) throw FormatException('$field is invalid.');
  return value;
}

int _positiveInteger(Object? value, String field) {
  final result = _integer(value, field);
  if (result <= 0) throw FormatException('$field must be positive.');
  return result;
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field is invalid.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

Map<String, String> _stringMap(Object? value, String field) {
  if (value is! Map<String, dynamic> ||
      value.isEmpty ||
      value.values.any((item) => item is! String || item.trim().isEmpty)) {
    throw FormatException('$field is invalid.');
  }
  return Map<String, String>.unmodifiable(value.cast<String, String>());
}
