import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../foods/providers/food_provider.dart';
import '../services/food_presentation_localizer.dart';
import 'nutrition_entry_fields.dart';

class MealCopyPage extends ConsumerStatefulWidget {
  const MealCopyPage({
    required this.source,
    required this.initialDate,
    super.key,
  });
  final MealWithItems source;
  final DateTime initialDate;
  @override
  ConsumerState<MealCopyPage> createState() => _MealCopyPageState();
}

class _MealCopyPageState extends ConsumerState<MealCopyPage> {
  late MealRepository _repository;
  late DateTime _date;
  late String _type;
  bool _saving = false, _append = false, _retired = false;
  String? _error;
  String t(String en, String ar) => nutritionEntryText(context, en, ar);
  bool get _current =>
      mounted &&
      !_retired &&
      identical(_repository, ref.read(mealRepositoryProvider));
  @override
  void initState() {
    super.initState();
    _repository = ref.read(mealRepositoryProvider);
    _date = widget.initialDate;
    _type = widget.source.meal.type;
  }

  Future<void> _save() async {
    if (!_current || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final template = _repository.createTemplateFromHistoricalMeal(
        meal: widget.source,
        templateId: 'reuse-${widget.source.meal.uuid}',
        templateName: widget.source.meal.name,
      );
      await _repository.instantiateTemplate(
        template: template,
        date: _date,
        destinationMealType: _type,
        appendToExisting: _append,
      );
      if (mounted && _current) Navigator.pop(context, true);
    } on Object {
      if (_current) {
        setState(
          () => _error = t(
            'Could not copy. Check whether the destination day is closed or already contains food, and whether the source foods still exist. Nothing was partially copied.',
            'تعذر النسخ. راجع إغلاق اليوم أو وجود أطعمة في الوجهة وصلاحية أطعمة المصدر. لم تُنسخ وجبة جزئيًا.',
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
            'Account changed. Reopen the meal.',
            'تغيّر الحساب. أعد فتح الوجبة.',
          ),
        );
      }
    });
    final enabled = !_saving && !_retired;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(t('Copy previous meal', 'نسخ وجبة سابقة'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.source.meal.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              MaterialLocalizations.of(
                context,
              ).formatFullDate(widget.source.meal.date),
            ),
            for (final item in widget.source.items)
              ListTile(
                title: Text(
                  widget.source.foodsById[item.foodId] == null
                      ? t('Saved food', 'طعام مسجّل')
                      : FoodPresentationLocalizer.foodName(
                          name: widget.source.foodsById[item.foodId]!.name,
                          arabicName:
                              widget.source.foodsById[item.foodId]!.arabicName,
                          localeTag: locale,
                          isCustom:
                              widget.source.foodsById[item.foodId]!.isCustom,
                          source: widget.source.foodsById[item.foodId]!.source,
                        ),
                ),
                trailing: Text(
                  '${item.quantity} ${item.servingUnitSnapshot == 'serving' ? t('servings', 'حصص') : t('g', 'جم')}',
                ),
              ),
            const Divider(),
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
            CheckboxListTile(
              value: _append,
              onChanged: enabled
                  ? (value) => setState(() => _append = value == true)
                  : null,
              title: Text(
                t(
                  'Append if this meal already contains food',
                  'ضمّها إلى الأطعمة الموجودة إن كانت الوجهة تحتوي على وجبة',
                ),
              ),
              subtitle: Text(
                t(
                  'The source meal is unchanged. A second confirmation can intentionally copy the meal again.',
                  'الوجبة الأصلية لا تتغير. إعادة التأكيد لاحقًا قد تنسخ الوجبة مرة أخرى عمدًا.',
                ),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton.icon(
              key: const Key('confirm-copy-selected-meal'),
              onPressed: enabled ? _save : null,
              icon: const Icon(Icons.content_copy),
              label: Text(
                _saving
                    ? t('Copying…', 'جارٍ النسخ…')
                    : t('Confirm copy', 'تأكيد النسخ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
