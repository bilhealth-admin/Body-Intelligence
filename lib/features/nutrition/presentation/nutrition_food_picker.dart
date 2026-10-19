import 'food_translation_attribution.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../foods/providers/food_provider.dart';
import '../services/food_runtime_search_authority.dart';
import '../services/food_presentation_localizer.dart';

Future<Food?> selectNutritionFood(
  BuildContext context, {
  String initialQuery = '',
}) => showDialog<Food>(
  context: context,
  builder: (_) => NutritionFoodPicker(initialQuery: initialQuery),
);

/// The same authority used by Food Log; no separate approximate recipe catalog.
class NutritionFoodPicker extends ConsumerStatefulWidget {
  const NutritionFoodPicker({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  ConsumerState<NutritionFoodPicker> createState() =>
      _NutritionFoodPickerState();
}

class _NutritionFoodPickerState extends ConsumerState<NutritionFoodPicker> {
  late final _query = TextEditingController(text: widget.initialQuery);
  FoodRuntimeSearchAuthority? _authority;
  Stream<List<Food>>? _results;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() {
    _generation++;
    _authority = ref.read(foodRuntimeSearchAuthorityProvider);
    _results = _authority!.searchProgressively(_query.text.trim(), limit: 25);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(foodRuntimeSearchAuthorityProvider, (before, after) {
      if (identical(before, after) || !mounted) return;
      // Retire the picker rather than returning a row belonging to a previous account.
      Navigator.pop(context);
    });
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    return BilPearlMaterialAlertDialog(
      title: Text(
        ar ? 'اختر مكوّنًا بقيمه الغذائية' : 'Choose a food with nutrition',
      ),
      content: SizedBox(
        width: 520,
        height:
            ((MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom) *
                    .50)
                .clamp(100.0, 520.0),
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                labelText: ar ? 'ابحث عن الطعام' : 'Search foods',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(_search),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Food>>(
                key: ValueKey(_generation),
                stream: _results,
                builder: (context, snapshot) {
                  final foods = snapshot.data;
                  if (foods == null && snapshot.hasError) {
                    return Center(
                      child: Text(
                        ar
                            ? 'تعذر البحث. عدّل العبارة وأعد المحاولة.'
                            : 'Search unavailable. Edit the phrase and retry.',
                      ),
                    );
                  }
                  if (foods == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    children: [
                      if (snapshot.connectionState != ConnectionState.done)
                        const LinearProgressIndicator(),
                      if (foods.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            ar
                                ? 'لا يوجد تطابق محلي بعد. يمكنك اختيار طعام محفوظ أو البحث عن اسم أدق؛ لا تُختلق القيم للمكونات غير المرتبطة.'
                                : 'No local match yet. Choose a saved food or refine the name; unmatched ingredients never receive invented nutrition.',
                          ),
                        ),
                      for (final food in foods)
                        ListTile(
                          title: GoogleFoodNameText(
                            name: food.name,
                            arabicName: food.arabicName,
                            localeTag: locale,
                            isCustom: food.isCustom,
                            source: food.source,
                          ),
                          subtitle: Text(
                            '${food.servingSize} ${FoodPresentationLocalizer.servingUnit(food.servingUnit, locale)}',
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () {
                            if (identical(
                              ref.read(foodRuntimeSearchAuthorityProvider),
                              _authority,
                            )) {
                              Navigator.pop(context, food);
                            }
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.strings.text('Cancel')),
        ),
      ],
    );
  }
}
