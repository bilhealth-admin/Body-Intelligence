import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../domain/trusted_recipe.dart';
import '../repositories/trusted_recipe_repository.dart';

final trustedRecipeRepositoryProvider = Provider<TrustedRecipeRepository>((
  ref,
) {
  return TrustedRecipeRepository(ref.watch(preferencesRepositoryProvider));
});

final trustedRecipesProvider = FutureProvider<List<SavedTrustedRecipe>>((ref) {
  return ref.watch(trustedRecipeRepositoryProvider).load();
});
