import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/presentation/recipe_library_page.dart';
import 'package:body_intelligence_log/features/wellness/services/recipe_image_delivery_client.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'non-ready result retries once and a later request can recover',
    () async {
      final resolver = _ScriptedRecipeImageResolver([
        const WellnessMediaCacheResult.unavailableOffline(),
        const WellnessMediaCacheResult.unavailableOffline(),
        WellnessMediaCacheResult.ready(
          File('recovered-recipe.png'),
          fromCache: true,
        ),
      ]);
      final cache = RecipeImageRequestCache();

      final unavailable = await cache.resolve('recipe-1', resolver);
      await Future<void>.delayed(Duration.zero);

      expect(unavailable.isReady, isFalse);
      expect(resolver.calls, RecipeImageRequestCache.maxAttemptsPerRequest);
      expect(cache.contains('recipe-1'), isFalse);

      final recovered = await cache.resolve('recipe-1', resolver);
      expect(recovered.isReady, isTrue);
      expect(resolver.calls, 3);
      expect(cache.contains('recipe-1'), isTrue);
    },
  );

  test(
    'exception retries once, evicts, and does not poison later calls',
    () async {
      final resolver = _ScriptedRecipeImageResolver([
        StateError('temporary-1'),
        StateError('temporary-2'),
        WellnessMediaCacheResult.ready(
          File('recovered-recipe.png'),
          fromCache: false,
        ),
      ]);
      final cache = RecipeImageRequestCache();

      await expectLater(cache.resolve('recipe-2', resolver), throwsStateError);
      await Future<void>.delayed(Duration.zero);

      expect(resolver.calls, RecipeImageRequestCache.maxAttemptsPerRequest);
      expect(cache.contains('recipe-2'), isFalse);

      final recovered = await cache.resolve('recipe-2', resolver);
      expect(recovered.isReady, isTrue);
      expect(resolver.calls, 3);
    },
  );

  test('concurrent callers share the exact in-flight future', () async {
    final pending = Completer<WellnessMediaCacheResult>();
    final resolver = _PendingRecipeImageResolver(pending.future);
    final cache = RecipeImageRequestCache();

    final first = cache.resolve('recipe-3', resolver);
    final second = cache.resolve('recipe-3', resolver);

    expect(identical(first, second), isTrue);
    expect(resolver.calls, 1);

    pending.complete(
      WellnessMediaCacheResult.ready(
        File('shared-recipe.png'),
        fromCache: true,
      ),
    );
    expect((await first).isReady, isTrue);
  });

  test(
    'keeps card thumbnails and detail originals as separate requests',
    () async {
      final resolver = _DualRecipeImageResolver();
      final cache = RecipeImageRequestCache();

      await cache.resolve('recipe-4', resolver);
      await cache.resolveDetail('recipe-4', resolver);

      expect(resolver.thumbnailCalls, 1);
      expect(resolver.detailCalls, 1);
      expect(cache.contains('recipe-4'), isTrue);
      expect(cache.containsDetail('recipe-4'), isTrue);
    },
  );
}

final class _ScriptedRecipeImageResolver implements RecipeImageResolver {
  _ScriptedRecipeImageResolver(this.outcomes);

  final List<Object> outcomes;
  int calls = 0;

  @override
  Future<WellnessMediaCacheResult> resolve(
    String canonicalId, {
    required bool online,
  }) async {
    final outcome = outcomes[calls++];
    if (outcome is WellnessMediaCacheResult) return outcome;
    throw outcome;
  }
}

final class _PendingRecipeImageResolver implements RecipeImageResolver {
  _PendingRecipeImageResolver(this.result);

  final Future<WellnessMediaCacheResult> result;
  int calls = 0;

  @override
  Future<WellnessMediaCacheResult> resolve(
    String canonicalId, {
    required bool online,
  }) {
    calls += 1;
    return result;
  }
}

final class _DualRecipeImageResolver
    implements RecipeImageResolver, RecipeDetailImageResolver {
  int thumbnailCalls = 0;
  int detailCalls = 0;

  @override
  Future<WellnessMediaCacheResult> resolve(
    String canonicalId, {
    required bool online,
  }) async {
    thumbnailCalls += 1;
    return WellnessMediaCacheResult.ready(
      File('thumbnail.webp'),
      fromCache: true,
    );
  }

  @override
  Future<WellnessMediaCacheResult> resolveDetail(
    String canonicalId, {
    required bool online,
  }) async {
    detailCalls += 1;
    return WellnessMediaCacheResult.ready(
      File('original.png'),
      fromCache: true,
    );
  }
}
