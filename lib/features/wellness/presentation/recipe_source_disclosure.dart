import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../nutrition/services/food_presentation_localizer.dart';
import '../domain/recipe_source_copy.dart';

class RecipeSourceDisclosure extends StatelessWidget {
  const RecipeSourceDisclosure({required this.ingredients, super.key});
  final List<Map<String, dynamic>> ingredients;

  @override
  Widget build(BuildContext context) {
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    return ExpansionTile(
      key: const Key('recipe-source-disclosure'),
      tilePadding: EdgeInsets.zero,
      title: Text(context.strings.text('Source')),
      subtitle: Text(RecipeSourceCopy.weighingBasis(locale)),
      children: [
        for (final ingredient in ingredients)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              FoodPresentationLocalizer.foodName(
                name:
                    ingredient['sourceDescription'] as String? ??
                    ingredient['itemId'] as String,
                localeTag: locale,
              ),
            ),
            subtitle: Text(
              '${ingredient['recordId']} · '
              '${context.strings.number(ingredient['grams'] as num)} '
              '${FoodPresentationLocalizer.servingUnit('g', locale)} · '
              '${RecipeSourceCopy.state(ingredient['sourcePreparation'] as String? ?? 'as-sold', locale)}',
            ),
          ),
      ],
    );
  }
}
