import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../../data/database/database_provider.dart';
import '../../../shared/widgets/secondary_page_app_bar.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../foods/providers/food_provider.dart';
import '../../recipe_import/providers/trusted_recipe_providers.dart';
import '../../recipe_import/domain/trusted_recipe.dart';
import '../../recipe_import/services/trusted_recipe_diary_service.dart';
import '../food_page.dart';

part 'meals_tab.dart';
part 'recipes_tab.dart';
part 'meals_recipes_components.dart';

class MealsRecipesFoodsPage extends ConsumerStatefulWidget {
  const MealsRecipesFoodsPage({super.key});

  @override
  ConsumerState<MealsRecipesFoodsPage> createState() =>
      _MealsRecipesFoodsPageState();
}

class _MealsRecipesFoodsPageState extends ConsumerState<MealsRecipesFoodsPage> {
  Future<String?>? preference;

  @override
  void initState() {
    super.initState();
    preference = PreferencesRepository(
      ref.read(databaseProvider),
    ).get('diary.defaultSearchTab');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: preference,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: FilledButton.icon(
                onPressed: () => setState(
                  () => preference = PreferencesRepository(
                    ref.read(databaseProvider),
                  ).get('diary.defaultSearchTab'),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_c(context, 'Retry')),
              ),
            ),
          );
        }
        final initialIndex = switch (snapshot.data) {
          'meals' => 0,
          'recipes' => 1,
          'my_foods' || _ => 2,
        };
        return DefaultTabController(
          length: 3,
          initialIndex: initialIndex,
          child: Scaffold(
            appBar: SecondaryPageAppBar(
              title: Text(_c(context, 'My nutrition')),
            ),
            body: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerHeight: 1,
                  tabs: [
                    Tab(text: _c(context, 'My meals')),
                    Tab(text: _c(context, 'My recipes')),
                    Tab(text: _c(context, 'My foods')),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      _MealsTab(),
                      _RecipesTab(),
                      FoodPage(embedded: true, userOwnedOnly: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
