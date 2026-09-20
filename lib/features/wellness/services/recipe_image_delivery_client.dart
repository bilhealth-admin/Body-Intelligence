import '../repositories/recipe_release_repository.dart';
import 'recipe_thumbnail_manifest.dart';
import 'wellness_media_cache.dart';

abstract interface class RecipeImageResolver {
  /// Resolves a card/list thumbnail, preferring the additive v4 variant.
  Future<WellnessMediaCacheResult> resolve(
    String canonicalId, {
    required bool online,
  });
}

/// Resolves the original recipe image used by large detail surfaces.
///
/// This is deliberately additive to [RecipeImageResolver] so existing card
/// resolver implementations keep compiling and cannot accidentally be used as
/// the only source for a large 16:9 detail image.
abstract interface class RecipeDetailImageResolver {
  Future<WellnessMediaCacheResult> resolveDetail(
    String canonicalId, {
    required bool online,
  });
}

/// Resolves one canonical recipe preview through the signed release contract.
///
/// Recipe images are public discovery previews, not paid instructions. The
/// shared media cache therefore downloads the digest-pinned URL without a
/// Bearer token, verifies exact bytes and SHA-256, and only then exposes the
/// local file. Premium recipe interaction remains gated by the existing
/// verified subscription policy in the presentation/domain layer.
final class RecipeImageDeliveryClient
    implements RecipeImageResolver, RecipeDetailImageResolver {
  RecipeImageDeliveryClient({
    RecipeImageCatalog? repository,
    WellnessMediaResolver? cache,
    RecipeThumbnailManifestLoader? thumbnailManifestLoader,
  }) : _repository = repository ?? RecipeReleaseRepository(),
       _cache = cache ?? WellnessMediaCache(),
       _thumbnailManifestLoader =
           thumbnailManifestLoader ?? BundledRecipeThumbnailManifestLoader(),
       _ownsCache = cache == null;

  final RecipeImageCatalog _repository;
  final WellnessMediaResolver _cache;
  final RecipeThumbnailManifestLoader _thumbnailManifestLoader;
  final bool _ownsCache;
  Future<Map<String, RecipeCatalogImageAsset>>? _verifiedThumbnailsFuture;

  @override
  Future<WellnessMediaCacheResult> resolve(
    String canonicalId, {
    required bool online,
  }) async {
    final original = await _repository.loadImageAsset(canonicalId);
    try {
      final thumbnails = await (_verifiedThumbnailsFuture ??=
          _loadVerifiedThumbnails());
      final thumbnail = thumbnails[canonicalId];
      if (thumbnail != null) {
        final result = await _cache.resolve(
          thumbnail.mediaAsset,
          online: online,
        );
        if (result.isReady) return result;
      }
    } catch (_) {
      // v4 is an additive optimization. A missing/invalid manifest, corrupt
      // download, or unavailable offline thumbnail must never hide a verified
      // original that the existing v3 client can still serve.
    }
    return _cache.resolve(original.mediaAsset, online: online);
  }

  @override
  Future<WellnessMediaCacheResult> resolveDetail(
    String canonicalId, {
    required bool online,
  }) async {
    final original = await _repository.loadImageAsset(canonicalId);
    return _cache.resolve(original.mediaAsset, online: online);
  }

  Future<Map<String, RecipeCatalogImageAsset>> _loadVerifiedThumbnails() async {
    final manifest = await _thumbnailManifestLoader.load();
    final sourceManifestSha256 = await _repository.loadImageManifestSha256();
    final originals = await _repository.loadImageAssets();
    if (manifest.sourceImageManifestSha256 != sourceManifestSha256 ||
        manifest.assets.length != originals.length) {
      throw const FormatException(
        'Recipe thumbnail manifest is not bound to this catalog.',
      );
    }
    final verified = <String, RecipeCatalogImageAsset>{};
    for (final original in originals) {
      final thumbnail = manifest.assets[original.canonicalId];
      if (thumbnail == null ||
          thumbnail.canonicalId != original.canonicalId ||
          thumbnail.sourceSha256 != original.sha256) {
        throw const FormatException(
          'Recipe thumbnail source identity does not match v3.',
        );
      }
      verified[original.canonicalId] = thumbnail.asset;
    }
    if (verified.length != manifest.assets.length) {
      throw const FormatException(
        'Recipe thumbnail identities do not match the source catalog.',
      );
    }
    return Map.unmodifiable(verified);
  }

  void dispose() {
    if (_ownsCache) (_cache as WellnessMediaCache).dispose();
  }
}
