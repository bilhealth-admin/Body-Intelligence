import '../repositories/recipe_release_repository.dart';
import 'wellness_media_cache.dart';

abstract interface class RecipeImageResolver {
  Future<WellnessMediaCacheResult> resolve(
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
final class RecipeImageDeliveryClient implements RecipeImageResolver {
  RecipeImageDeliveryClient({
    RecipeReleaseRepository? repository,
    WellnessMediaCache? cache,
  }) : _repository = repository ?? RecipeReleaseRepository(),
       _cache = cache ?? WellnessMediaCache(),
       _ownsCache = cache == null;

  final RecipeReleaseRepository _repository;
  final WellnessMediaCache _cache;
  final bool _ownsCache;

  @override
  Future<WellnessMediaCacheResult> resolve(
    String canonicalId, {
    required bool online,
  }) async {
    final asset = await _repository.loadImageAsset(canonicalId);
    return _cache.resolve(asset.mediaAsset, online: online);
  }

  void dispose() {
    if (_ownsCache) _cache.dispose();
  }
}
