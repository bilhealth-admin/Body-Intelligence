import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:body_intelligence_log/features/wellness/services/recipe_image_delivery_client.dart';
import 'package:body_intelligence_log/features/wellness/services/recipe_thumbnail_manifest.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceManifestSha =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipeThumbnailManifest', () {
    test('accepts the exact additive v4 contract', () {
      final manifest = RecipeThumbnailManifest.fromJson(_manifestJson());

      expect(manifest.sourceImageManifestSha256, _sourceManifestSha);
      expect(manifest.totalSizeBytes, 1500 * 137);
      expect(manifest.assets, hasLength(1500));
      final first = manifest.assets['recipe-one']!;
      expect(first.sourceSha256, _digest('1'));
      expect(first.asset.mimeType, 'image/webp');
      expect(first.asset.width, 512);
      expect(first.asset.height, 341);
      expect(
        first.asset.url.toString(),
        'https://workouts.bilhealth.com/v4/recipes/thumbnails/'
        'recipe-one/${_digest('3')}.webp',
      );
    });

    test('rejects unapproved transforms and noncanonical delivery paths', () {
      final wrongTransform = _manifestJson();
      (wrongTransform['transformation'] as Map<String, dynamic>)['quality'] =
          79;
      expect(
        () => RecipeThumbnailManifest.fromJson(wrongTransform),
        throwsFormatException,
      );

      final wrongPath = _manifestJson();
      final entries = wrongPath['entries'] as List<dynamic>;
      (entries.first as Map<String, dynamic>)['delivery_path'] =
          '/v4/recipes/thumbnails/recipe-two/${_digest('3')}.webp';
      expect(
        () => RecipeThumbnailManifest.fromJson(wrongPath),
        throwsFormatException,
      );
    });
  });

  group('RecipeImageDeliveryClient', () {
    test(
      'bundled 1500-thumbnail manifest is pinned and bound to real v3',
      () async {
        final repository = RecipeReleaseRepository();
        final loader = BundledRecipeThumbnailManifestLoader();
        final cache = _RecordingMediaResolver((asset, {required online}) async {
          return WellnessMediaCacheResult.ready(
            File('${asset.sha256}.webp'),
            fromCache: true,
          );
        });
        final client = RecipeImageDeliveryClient(
          repository: repository,
          cache: cache,
          thumbnailManifestLoader: loader,
        );

        final result = await client.resolve(
          'aji-gallina-ligero',
          online: false,
        );
        final manifest = await loader.load();

        expect(result.isReady, isTrue);
        expect(manifest.assets, hasLength(1500));
        expect(manifest.totalSizeBytes, 73802850);
        expect(
          manifest.sourceImageManifestSha256,
          await repository.loadImageManifestSha256(),
        );
        expect(cache.assets, hasLength(1));
        expect(cache.assets.single.mimeType, 'image/webp');
        expect(
          cache.assets.single.url.path,
          startsWith('/v4/recipes/thumbnails/aji-gallina-ligero/'),
        );
      },
    );

    test('uses v4 for cards and the original v3 asset for details', () async {
      final original = _original('recipe-one', _digest('1'));
      final thumbnail = _thumbnail(
        'recipe-one',
        sourceSha256: original.sha256,
        digest: _digest('3'),
      );
      final cache = _RecordingMediaResolver((asset, {required online}) async {
        return WellnessMediaCacheResult.ready(
          File('thumbnail.webp'),
          fromCache: false,
        );
      });
      final loader = _FakeThumbnailLoader(_thumbnailManifest([thumbnail]));
      final client = RecipeImageDeliveryClient(
        repository: _FakeImageCatalog([original]),
        cache: cache,
        thumbnailManifestLoader: loader,
      );

      final result = await client.resolve('recipe-one', online: true);
      final detailResult = await client.resolveDetail(
        'recipe-one',
        online: true,
      );

      expect(result.isReady, isTrue);
      expect(detailResult.isReady, isTrue);
      expect(cache.assets, hasLength(2));
      expect(cache.assets.first.sha256, thumbnail.asset.sha256);
      expect(cache.assets.first.mimeType, 'image/webp');
      expect(cache.assets.last.sha256, original.sha256);
      expect(cache.assets.last.mimeType, original.mimeType);
      expect(cache.assets.last.url.path, contains('/v3/recipes/images/'));
      expect(cache.onlineValues, [isTrue, isTrue]);
      expect(loader.calls, 1);
    });

    test('falls back to the unchanged v3 original after v4 failure', () async {
      final original = _original('recipe-one', _digest('1'));
      final thumbnail = _thumbnail(
        'recipe-one',
        sourceSha256: original.sha256,
        digest: _digest('3'),
      );
      final cache = _RecordingMediaResolver((asset, {required online}) async {
        if (asset.sha256 == thumbnail.asset.sha256) {
          throw const FormatException('corrupt thumbnail');
        }
        return WellnessMediaCacheResult.ready(
          File('original.jpg'),
          fromCache: true,
        );
      });
      final client = RecipeImageDeliveryClient(
        repository: _FakeImageCatalog([original]),
        cache: cache,
        thumbnailManifestLoader: _FakeThumbnailLoader(
          _thumbnailManifest([thumbnail]),
        ),
      );

      final result = await client.resolve('recipe-one', online: true);

      expect(result.isReady, isTrue);
      expect(cache.assets.map((asset) => asset.sha256), [
        thumbnail.asset.sha256,
        original.sha256,
      ]);
      expect(cache.assets.last.url.path, original.url.path);
      expect(cache.assets.last.mimeType, original.mimeType);
    });

    test('falls back offline when the thumbnail is not cached', () async {
      final original = _original('recipe-one', _digest('1'));
      final thumbnail = _thumbnail(
        'recipe-one',
        sourceSha256: original.sha256,
        digest: _digest('3'),
      );
      final cache = _RecordingMediaResolver((asset, {required online}) async {
        if (asset.sha256 == thumbnail.asset.sha256) {
          return const WellnessMediaCacheResult.unavailableOffline();
        }
        return WellnessMediaCacheResult.ready(
          File('cached-original.jpg'),
          fromCache: true,
        );
      });
      final client = RecipeImageDeliveryClient(
        repository: _FakeImageCatalog([original]),
        cache: cache,
        thumbnailManifestLoader: _FakeThumbnailLoader(
          _thumbnailManifest([thumbnail]),
        ),
      );

      final result = await client.resolve('recipe-one', online: false);

      expect(result.isReady, isTrue);
      expect(result.fromCache, isTrue);
      expect(cache.onlineValues, [isFalse, isFalse]);
      expect(cache.assets.map((asset) => asset.sha256), [
        thumbnail.asset.sha256,
        original.sha256,
      ]);
    });

    test(
      'rejects stale source binding before resolving any v4 bytes',
      () async {
        final original = _original('recipe-one', _digest('1'));
        final thumbnail = _thumbnail(
          'recipe-one',
          sourceSha256: _digest('9'),
          digest: _digest('3'),
        );
        final cache = _RecordingMediaResolver((asset, {required online}) async {
          return WellnessMediaCacheResult.ready(
            File('original.jpg'),
            fromCache: true,
          );
        });
        final client = RecipeImageDeliveryClient(
          repository: _FakeImageCatalog([original]),
          cache: cache,
          thumbnailManifestLoader: _FakeThumbnailLoader(
            _thumbnailManifest([thumbnail]),
          ),
        );

        await client.resolve('recipe-one', online: true);

        expect(cache.assets, hasLength(1));
        expect(cache.assets.single.sha256, original.sha256);
        expect(cache.assets.single.url.path, contains('/v3/recipes/images/'));
      },
    );

    test(
      'loads and verifies the bundled manifest once for many cards',
      () async {
        final originals = [
          _original('recipe-one', _digest('1')),
          _original('recipe-two', _digest('2')),
        ];
        final thumbnails = [
          _thumbnail(
            'recipe-one',
            sourceSha256: originals[0].sha256,
            digest: _digest('3'),
          ),
          _thumbnail(
            'recipe-two',
            sourceSha256: originals[1].sha256,
            digest: _digest('4'),
          ),
        ];
        final catalog = _FakeImageCatalog(originals);
        final loader = _FakeThumbnailLoader(_thumbnailManifest(thumbnails));
        final cache = _RecordingMediaResolver((asset, {required online}) async {
          return WellnessMediaCacheResult.ready(
            File('${asset.sha256}.webp'),
            fromCache: true,
          );
        });
        final client = RecipeImageDeliveryClient(
          repository: catalog,
          cache: cache,
          thumbnailManifestLoader: loader,
        );

        await Future.wait([
          client.resolve('recipe-one', online: true),
          client.resolve('recipe-two', online: true),
        ]);

        expect(loader.calls, 1);
        expect(catalog.allAssetsCalls, 1);
        expect(catalog.manifestShaCalls, 1);
        expect(
          cache.assets.map((asset) => asset.sha256).toSet(),
          thumbnails.map((entry) => entry.asset.sha256).toSet(),
        );
      },
    );
  });
}

Map<String, dynamic> _manifestJson() => {
  'schema_version': 4,
  'record_count': 1500,
  'source_image_manifest_sha256': _sourceManifestSha,
  'total_size_bytes': 1500 * 137,
  'transformation': {
    'codec': 'libwebp',
    'fit': 'contain-no-upscale',
    'max_height': 512,
    'max_width': 512,
    'method': 6,
    'quality': 78,
    'resampling': 'lanczos',
    'version': 1,
  },
  'entries': [
    for (var index = 0; index < 1500; index++)
      _thumbnailJson(
        index == 0 ? 'recipe-one' : 'recipe-$index',
        sourceSha256: index == 0 ? _digest('1') : _indexedDigest(index),
        digest: index == 0 ? _digest('3') : _indexedDigest(index + 1500),
        sizeBytes: 137,
        width: 512,
        height: 341,
      ),
  ],
};

Map<String, dynamic> _thumbnailJson(
  String id, {
  required String sourceSha256,
  required String digest,
  required int sizeBytes,
  required int width,
  required int height,
}) => {
  'canonical_id': id,
  'source_sha256': sourceSha256,
  'object_path': 'recipes/v4/thumbnails/512/$id-$digest.webp',
  'delivery_path': '/v4/recipes/thumbnails/$id/$digest.webp',
  'mime_type': 'image/webp',
  'size_bytes': sizeBytes,
  'sha256': digest,
  'width': width,
  'height': height,
};

String _digest(String character) => List.filled(64, character).join();

String _indexedDigest(int value) => value.toRadixString(16).padLeft(64, '0');

RecipeCatalogImageAsset _original(String id, String digest) =>
    RecipeCatalogImageAsset(
      canonicalId: id,
      url: Uri.https(
        'workouts.bilhealth.com',
        '/v3/recipes/images/$id/$digest',
      ),
      mimeType: 'image/jpeg',
      sha256: digest,
      sizeBytes: 2048,
      width: 1200,
      height: 800,
    );

RecipeThumbnailAsset _thumbnail(
  String id, {
  required String sourceSha256,
  required String digest,
}) => RecipeThumbnailAsset(
  canonicalId: id,
  sourceSha256: sourceSha256,
  asset: RecipeCatalogImageAsset(
    canonicalId: id,
    url: Uri.https(
      'workouts.bilhealth.com',
      '/v4/recipes/thumbnails/$id/$digest.webp',
    ),
    mimeType: 'image/webp',
    sha256: digest,
    sizeBytes: 128,
    width: 512,
    height: 341,
  ),
);

RecipeThumbnailManifest _thumbnailManifest(
  List<RecipeThumbnailAsset> entries,
) => RecipeThumbnailManifest(
  sourceImageManifestSha256: _sourceManifestSha,
  totalSizeBytes: entries.fold(
    0,
    (total, entry) => total + entry.asset.sizeBytes,
  ),
  assets: Map.unmodifiable({
    for (final entry in entries) entry.canonicalId: entry,
  }),
);

final class _FakeImageCatalog implements RecipeImageCatalog {
  _FakeImageCatalog(List<RecipeCatalogImageAsset> assets)
    : _assets = Map.unmodifiable({
        for (final asset in assets) asset.canonicalId: asset,
      });

  final Map<String, RecipeCatalogImageAsset> _assets;
  int allAssetsCalls = 0;
  int manifestShaCalls = 0;

  @override
  Future<RecipeCatalogImageAsset> loadImageAsset(String canonicalId) async {
    final asset = _assets[canonicalId];
    if (asset == null) throw const FormatException('unknown recipe');
    return asset;
  }

  @override
  Future<List<RecipeCatalogImageAsset>> loadImageAssets() async {
    allAssetsCalls += 1;
    return List.unmodifiable(_assets.values);
  }

  @override
  Future<String> loadImageManifestSha256() async {
    manifestShaCalls += 1;
    return _sourceManifestSha;
  }
}

final class _FakeThumbnailLoader implements RecipeThumbnailManifestLoader {
  _FakeThumbnailLoader(this.manifest);

  final RecipeThumbnailManifest manifest;
  int calls = 0;

  @override
  Future<RecipeThumbnailManifest> load() async {
    calls += 1;
    return manifest;
  }
}

typedef _ResolveHandler =
    Future<WellnessMediaCacheResult> Function(
      WellnessMediaAsset asset, {
      required bool online,
    });

final class _RecordingMediaResolver implements WellnessMediaResolver {
  _RecordingMediaResolver(this._handler);

  final _ResolveHandler _handler;
  final List<WellnessMediaAsset> assets = [];
  final List<bool> onlineValues = [];

  @override
  Future<WellnessMediaCacheResult> resolve(
    WellnessMediaAsset asset, {
    required bool online,
  }) {
    assets.add(asset);
    onlineValues.add(online);
    return _handler(asset, online: online);
  }
}
