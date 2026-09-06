part of 'recipe_library_page.dart';

/// Shares image delivery work across recipe cards and lets transient failures
/// recover on a later rebuild without creating an unbounded retry loop.
@visibleForTesting
class RecipeImageRequestCache {
  static const maxAttemptsPerRequest = 2;

  final Map<
    ({String recipeId, _RecipeImageRequestKind kind}),
    Future<WellnessMediaCacheResult>
  >
  _requests = {};

  Future<WellnessMediaCacheResult> resolve(
    String recipeId,
    RecipeImageResolver resolver,
  ) => _resolve(
    recipeId,
    _RecipeImageRequestKind.thumbnail,
    () => resolver.resolve(recipeId, online: true),
  );

  Future<WellnessMediaCacheResult> resolveDetail(
    String recipeId,
    RecipeDetailImageResolver resolver,
  ) => _resolve(
    recipeId,
    _RecipeImageRequestKind.detail,
    () => resolver.resolveDetail(recipeId, online: true),
  );

  Future<WellnessMediaCacheResult> _resolve(
    String recipeId,
    _RecipeImageRequestKind kind,
    Future<WellnessMediaCacheResult> Function() request,
  ) {
    final key = (recipeId: recipeId, kind: kind);
    final cached = _requests[key];
    if (cached != null) return cached;

    final operation = _resolveWithRetry(request);
    _requests[key] = operation;
    unawaited(
      operation.then<void>(
        (result) {
          if (!result.isReady) _removeIfCurrent(key, operation);
        },
        onError: (Object _, StackTrace _) {
          _removeIfCurrent(key, operation);
        },
      ),
    );
    return operation;
  }

  @visibleForTesting
  bool contains(String recipeId) => _requests.containsKey((
    recipeId: recipeId,
    kind: _RecipeImageRequestKind.thumbnail,
  ));

  @visibleForTesting
  bool containsDetail(String recipeId) => _requests.containsKey((
    recipeId: recipeId,
    kind: _RecipeImageRequestKind.detail,
  ));

  Future<WellnessMediaCacheResult> _resolveWithRetry(
    Future<WellnessMediaCacheResult> Function() request,
  ) async {
    for (var attempt = 1; attempt <= maxAttemptsPerRequest; attempt++) {
      try {
        final result = await request();
        if (result.isReady || attempt == maxAttemptsPerRequest) return result;
      } on Object {
        if (attempt == maxAttemptsPerRequest) rethrow;
      }
    }
    throw StateError('recipe_image_retry_exhausted');
  }

  void _removeIfCurrent(
    ({String recipeId, _RecipeImageRequestKind kind}) key,
    Future<WellnessMediaCacheResult> operation,
  ) {
    if (identical(_requests[key], operation)) {
      _requests.remove(key);
    }
  }
}

enum _RecipeImageRequestKind { thumbnail, detail }
