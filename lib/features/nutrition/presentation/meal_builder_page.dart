import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../foods/providers/food_provider.dart';
import '../domain/meal_builder.dart';
import '../services/food_presentation_localizer.dart';
import 'nutrition_entry_fields.dart';
import 'nutrition_food_picker.dart';

/// A real meal builder, not a redirect to Today. Nothing is written until the
/// complete reviewed list is confirmed; the repository commits it atomically.
class MealBuilderPage extends ConsumerStatefulWidget {
  const MealBuilderPage({required this.initialDate, super.key});
  final DateTime initialDate;
  @override
  ConsumerState<MealBuilderPage> createState() => _MealBuilderPageState();
}

class _MealBuilderPageState extends ConsumerState<MealBuilderPage> {
  final _name = TextEditingController();
  final _items = <({Food food, double grams})>[];
  late DateTime _date;
  late MealRepository _repository;
  String _type = 'breakfast';
  String? _error;
  bool _saving = false, _append = false, _retired = false;
  String t(String en, String ar) => nutritionEntryText(context, en, ar);
  bool get _current =>
      mounted &&
      !_retired &&
      identical(_repository, ref.read(mealRepositoryProvider));
  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _repository = ref.read(mealRepositoryProvider);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _label(Food food) => FoodPresentationLocalizer.foodName(
    name: food.name,
    arabicName: food.arabicName,
    localeTag: BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
    isCustom: food.isCustom,
    source: food.source,
  );

  Future<void> _addFood() async {
    final food = await selectNutritionFood(context);
    if (!mounted || !_current || food == null) return;
    final controller = TextEditingController(text: '100');
    final grams = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(_label(food)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: t('Quantity (g)', 'الكمية بالجرام'),
                    errorText: error,
                  ),
                ),
                Text(
                  t(
                    'Use a food record with a known mass basis; volume is never assumed to equal grams.',
                    'اختر سجل طعام ذا وزن معلوم؛ لا نعتبر المليلتر جرامًا دون بيانات.',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t('Cancel', 'إلغاء')),
              ),
              FilledButton(
                onPressed: () {
                  final amount = parseNutritionNumber(controller.text);
                  if (amount == null || amount <= 0 || amount > 100000) {
                    update(
                      () => error = t(
                        'Enter a valid positive amount.',
                        'أدخل كمية موجبة صحيحة.',
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, amount);
                },
                child: Text(t('Add', 'إضافة')),
              ),
            ],
          ),
        );
      },
    );
    // TextField detaches before controller disposal.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (_current && grams != null) {
      setState(() => _items.add((food: food, grams: grams)));
    }
  }

  Future<void> _save() async {
    if (!_current || _saving) return;
    if (_name.text.trim().isEmpty || _items.isEmpty) {
      setState(
        () => _error = t(
          'Name the meal and add at least one food.',
          'سمِّ الوجبة وأضف طعامًا واحدًا على الأقل.',
        ),
      );
      return;
    }
    final draft = MealBuilderDraft(
      name: _name.text.trim(),
      mealType: _type,
      items: [
        for (var i = 0; i < _items.length; i++)
          MealBuilderItemDraft(
            foodId: _items[i].food.id,
            quantityGrams: _items[i].grams,
            position: i + 1,
          ),
      ],
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.createMealFromDraft(
        draft: draft,
        date: _date,
        appendToExisting: _append,
      );
      if (mounted && _current) Navigator.pop(context, true);
    } on Object {
      if (_current) {
        setState(
          () => _error = t(
            'Could not save. Check the food mass basis and whether the day is closed or the destination already contains food. Your draft is kept.',
            'تعذر الحفظ. راجع أساس وزن الطعام، وإغلاق اليوم، ووجود أطعمة بالوجهة. مسودتك محفوظة هنا؛ لن نستبدل طعامًا قائمًا.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mealRepositoryProvider, (previous, next) {
      _retired = true;
      if (mounted) {
        setState(
          () => _error = t(
            'Account changed. Reopen the meal builder.',
            'تغيّر الحساب. أعد فتح إنشاء الوجبة.',
          ),
        );
      }
    });
    final enabled = !_saving && !_retired;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(t('Create meal', 'إنشاء وجبة'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              t(
                'Choose foods and weights, then save to the selected diary date. This meal will appear in My meals for reuse.',
                'اختر الأطعمة وأوزانها، ثم احفظها في تاريخ اليوميات المحدد. ستظهر الوجبة في «وجباتي» لإعادة استخدامها.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: enabled,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: t('Meal name', 'اسم الوجبة'),
              ),
            ),
            nutritionDestinationFields(
              context,
              date: _date,
              type: _type,
              enabled: enabled,
              onDate: (date) {
                if (mounted) setState(() => _date = date);
              },
              onType: (type) => setState(() => _type = type),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _items.length; i++)
              Card(
                child: ListTile(
                  title: Text(_label(_items[i].food)),
                  subtitle: Text('${_items[i].grams} ${t('g', 'جم')}'),
                  trailing: IconButton(
                    tooltip: t('Remove', 'إزالة'),
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: enabled
                        ? () => setState(() => _items.removeAt(i))
                        : null,
                  ),
                ),
              ),
            OutlinedButton.icon(
              key: const Key('meal-builder-add-food'),
              onPressed: enabled && _items.length < 100 ? _addFood : null,
              icon: const Icon(Icons.add),
              label: Text(t('Choose food', 'اختيار طعام')),
            ),
            CheckboxListTile(
              value: _append,
              onChanged: enabled
                  ? (value) => setState(() => _append = value == true)
                  : null,
              title: Text(
                t(
                  'Append to an existing meal at this destination',
                  'ضمّ الأطعمة إلى الوجبة الموجودة في الوجهة عند وجودها',
                ),
              ),
              subtitle: Text(
                t(
                  'Existing food and its nutrition are never replaced.',
                  'لن تُستبدل الأطعمة القائمة أو قيمها الغذائية.',
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              key: const Key('meal-builder-save'),
              onPressed: enabled ? _save : null,
              icon: const Icon(Icons.check),
              label: Text(
                _saving
                    ? t('Saving…', 'جارٍ الحفظ…')
                    : t('Confirm and save meal', 'تأكيد وحفظ الوجبة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
