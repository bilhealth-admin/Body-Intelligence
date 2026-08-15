final class RecipeReleaseManifest {
  const RecipeReleaseManifest({
    required this.canonicalSha256,
    required this.canonicalSizeBytes,
    required this.indexPath,
    required this.indexSizeBytes,
    required this.indexSha256,
    required this.imageManifestPath,
    required this.imageManifestSizeBytes,
    required this.imageManifestSha256,
    required this.provenancePath,
    required this.provenanceSizeBytes,
    required this.provenanceSha256,
    required this.shards,
  });

  static const schemaVersion = 1;
  static const recordCount = 1500;
  static const shardSize = 50;
  static const shardCount = 30;

  final String canonicalSha256;
  final int canonicalSizeBytes;
  final String indexPath, indexSha256;
  final int indexSizeBytes;
  final String imageManifestPath, imageManifestSha256;
  final int imageManifestSizeBytes;
  final String provenancePath, provenanceSha256;
  final int provenanceSizeBytes;
  final List<RecipeShardDescriptor> shards;

  factory RecipeReleaseManifest.fromJson(Map<String, dynamic> json) {
    _exactKeys(json, const {
      'schema_version',
      'record_count',
      'shard_size',
      'canonical_sha256',
      'canonical_size_bytes',
      'index_path',
      'index_size_bytes',
      'index_sha256',
      'image_manifest_path',
      'image_manifest_size_bytes',
      'image_manifest_sha256',
      'provenance_path',
      'provenance_size_bytes',
      'provenance_sha256',
      'shards',
    });
    if (_integer(json, 'schema_version') != schemaVersion ||
        _integer(json, 'record_count') != recordCount ||
        _integer(json, 'shard_size') != shardSize) {
      throw const FormatException('Unsupported recipe release contract.');
    }
    final rawShards = json['shards'];
    if (rawShards is! List || rawShards.length != shardCount) {
      throw const FormatException('Recipe release requires 30 shards.');
    }
    final shards = <RecipeShardDescriptor>[];
    final indexPath = _assetPath(json, 'index_path');
    final imageManifestPath = _assetPath(json, 'image_manifest_path');
    final provenancePath = _assetPath(json, 'provenance_path');
    final paths = <String>{indexPath, imageManifestPath, provenancePath};
    for (var ordinal = 0; ordinal < rawShards.length; ordinal++) {
      final raw = rawShards[ordinal];
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid recipe shard descriptor.');
      }
      final shard = RecipeShardDescriptor.fromJson(raw);
      if (shard.ordinal != ordinal ||
          shard.count != shardSize ||
          !paths.add(shard.path)) {
        throw const FormatException('Recipe shards are not canonical.');
      }
      shards.add(shard);
    }
    return RecipeReleaseManifest(
      canonicalSha256: _digest(json, 'canonical_sha256'),
      canonicalSizeBytes: _positiveInteger(json, 'canonical_size_bytes'),
      indexPath: indexPath,
      indexSizeBytes: _boundedSize(json, 'index_size_bytes', 4 * 1024 * 1024),
      indexSha256: _digest(json, 'index_sha256'),
      imageManifestPath: imageManifestPath,
      imageManifestSizeBytes: _boundedSize(
        json,
        'image_manifest_size_bytes',
        4 * 1024 * 1024,
      ),
      imageManifestSha256: _digest(json, 'image_manifest_sha256'),
      provenancePath: provenancePath,
      provenanceSizeBytes: _boundedSize(
        json,
        'provenance_size_bytes',
        2 * 1024 * 1024,
      ),
      provenanceSha256: _digest(json, 'provenance_sha256'),
      shards: List.unmodifiable(shards),
    );
  }
}

final class RecipeShardDescriptor {
  const RecipeShardDescriptor({
    required this.ordinal,
    required this.path,
    required this.firstId,
    required this.lastId,
    required this.count,
    required this.sizeBytes,
    required this.sha256,
  });

  final int ordinal, count, sizeBytes;
  final String path, firstId, lastId, sha256;

  factory RecipeShardDescriptor.fromJson(Map<String, dynamic> json) {
    _exactKeys(json, const {
      'ordinal',
      'path',
      'first_id',
      'last_id',
      'count',
      'size_bytes',
      'sha256',
    });
    final first = _text(json, 'first_id');
    final last = _text(json, 'last_id');
    if (first.compareTo(last) > 0) {
      throw const FormatException('Recipe shard boundaries are reversed.');
    }
    return RecipeShardDescriptor(
      ordinal: _integer(json, 'ordinal'),
      path: _assetPath(json, 'path'),
      firstId: first,
      lastId: last,
      count: _positiveInteger(json, 'count'),
      sizeBytes: _boundedSize(json, 'size_bytes', 2 * 1024 * 1024),
      sha256: _digest(json, 'sha256'),
    );
  }
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(json.keys.toSet()).isNotEmpty) {
    throw const FormatException('Release object fields are invalid.');
  }
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw FormatException('Invalid release field: $key');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

int _positiveInteger(Map<String, dynamic> json, String key) {
  final value = _integer(json, key);
  if (value <= 0) throw FormatException('$key must be positive.');
  return value;
}

int _boundedSize(Map<String, dynamic> json, String key, int maximum) {
  final value = _positiveInteger(json, key);
  if (value > maximum) throw FormatException('$key exceeds its size bound.');
  return value;
}

String _digest(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('$key must be a lowercase SHA-256 digest.');
  }
  return value;
}

String _assetPath(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  if (!value.startsWith('assets/catalogs/recipes/v1/') ||
      value.contains('..') ||
      value.contains('\\') ||
      value.contains('://') ||
      value.startsWith('/')) {
    throw FormatException('$key is not a safe recipe asset path.');
  }
  return value;
}
