import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../profile/providers/user_profile_provider.dart';

class NutritionGoalSchedulePage extends ConsumerWidget {
  const NutritionGoalSchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(nutritionGoalScheduleProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_text(context, 'Scheduled goals'))),
      body: schedule.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            Center(child: Text(_text(context, 'Goals unavailable'))),
        data: (value) => ListView(
          children: [
            _section(context, 'Different goals by day'),
            for (var day = 1; day <= 7; day++)
              _targetTile(
                context,
                _weekday(context, day),
                value.dayTargets[day],
                () => _edit(context, value.dayTargets[day]).then((target) {
                  if (target.$1) {
                    ref
                        .read(nutritionGoalScheduleRepositoryProvider)
                        .saveDay(day, target.$2);
                  }
                }),
              ),
            _section(context, 'Goals by meal'),
            for (final meal in const ['breakfast', 'lunch', 'dinner', 'snack'])
              _targetTile(
                context,
                _text(context, meal),
                value.mealTargets[meal],
                () => _edit(context, value.mealTargets[meal]).then((target) {
                  if (target.$1) {
                    ref
                        .read(nutritionGoalScheduleRepositoryProvider)
                        .saveMeal(meal, target.$2);
                  }
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String key) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      _text(context, key),
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );

  Widget _targetTile(
    BuildContext context,
    String title,
    NutritionGoalTarget? target,
    VoidCallback onTap,
  ) => ListTile(
    title: Text(title),
    subtitle: Text(
      target == null
          ? _text(context, 'Use default goal')
          : '${target.calories.toStringAsFixed(0)} ${_text(context, 'kcal')} · '
                '${target.carbsPercent.toStringAsFixed(0)}% C · '
                '${target.proteinPercent.toStringAsFixed(0)}% P · '
                '${target.fatPercent.toStringAsFixed(0)}% F'
                    .replaceAll(String.fromCharCodes(const [194, 183]), '·'),
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );

  Future<(bool, NutritionGoalTarget?)> _edit(
    BuildContext context,
    NutritionGoalTarget? initial,
  ) async {
    final values = [
      TextEditingController(text: '${initial?.calories ?? 2000}'),
      TextEditingController(text: '${initial?.carbsPercent ?? 45}'),
      TextEditingController(text: '${initial?.proteinPercent ?? 30}'),
      TextEditingController(text: '${initial?.fatPercent ?? 25}'),
    ];
    final result = await showDialog<(bool, NutritionGoalTarget?)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text(context, 'Edit goal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              ('Calories', 0),
              ('Carbohydrates %', 1),
              ('Protein %', 2),
              ('Fat %', 3),
            ])
              TextField(
                controller: values[entry.$2],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _text(context, entry.$1),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, (true, null)),
            child: Text(_text(context, 'Use default')),
          ),
          FilledButton(
            onPressed: () {
              final numbers = values
                  .map((e) => double.tryParse(e.text))
                  .toList();
              if (numbers.any((e) => e == null)) return;
              final target = NutritionGoalTarget(
                calories: numbers[0]!,
                carbsPercent: numbers[1]!,
                proteinPercent: numbers[2]!,
                fatPercent: numbers[3]!,
              );
              if (target.isValid) Navigator.pop(dialogContext, (true, target));
            },
            child: Text(_text(context, 'Save')),
          ),
        ],
      ),
    );
    for (final controller in values) {
      controller.dispose();
    }
    return result ?? (false, null);
  }
}

String _weekday(BuildContext context, int weekday) {
  final monday = DateTime(2026, 1, 5 + weekday - 1);
  return MaterialLocalizations.of(
    context,
  ).formatFullDate(monday).split(',').first;
}

String _text(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  return _copy[language]?[key] ?? _copy['en']![key] ?? key;
}

const _copy = <String, Map<String, String>>{
  'en': {
    'Scheduled goals': 'Scheduled goals',
    'Goals unavailable': 'Goals unavailable',
    'Different goals by day': 'Different goals by day',
    'Goals by meal': 'Goals by meal',
    'Use default goal': 'Use default goal',
    'Use default': 'Use default',
    'Edit goal': 'Edit goal',
    'Calories': 'Calories',
    'Carbohydrates %': 'Carbohydrates %',
    'Protein %': 'Protein %',
    'Fat %': 'Fat %',
    'Save': 'Save',
    'kcal': 'kcal',
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  },
  'ar': {
    'Scheduled goals': 'الأهداف المجدولة',
    'Goals unavailable': 'تعذر عرض الأهداف',
    'Different goals by day': 'أهداف مختلفة حسب اليوم',
    'Goals by meal': 'الأهداف حسب الوجبة',
    'Use default goal': 'استخدام الهدف الافتراضي',
    'Use default': 'استخدام الافتراضي',
    'Edit goal': 'تعديل الهدف',
    'Calories': 'السعرات',
    'Carbohydrates %': 'الكربوهيدرات %',
    'Protein %': 'البروتين %',
    'Fat %': 'الدهون %',
    'Save': 'حفظ',
    'kcal': 'سعرة',
    'breakfast': 'الإفطار',
    'lunch': 'الغداء',
    'dinner': 'العشاء',
    'snack': 'وجبة خفيفة',
  },
  'fr': {
    'Scheduled goals': 'Objectifs planifiés',
    'Goals unavailable': 'Objectifs indisponibles',
    'Different goals by day': 'Objectifs selon le jour',
    'Goals by meal': 'Objectifs par repas',
    'Use default goal': "Utiliser l’objectif par défaut",
    'Use default': 'Par défaut',
    'Edit goal': "Modifier l’objectif",
    'Calories': 'Calories',
    'Carbohydrates %': 'Glucides %',
    'Protein %': 'Protéines %',
    'Fat %': 'Lipides %',
    'Save': 'Enregistrer',
    'kcal': 'kcal',
    'breakfast': 'Petit-déjeuner',
    'lunch': 'Déjeuner',
    'dinner': 'Dîner',
    'snack': 'Collation',
  },
  'es': {
    'Scheduled goals': 'Objetivos programados',
    'Goals unavailable': 'Objetivos no disponibles',
    'Different goals by day': 'Objetivos según el día',
    'Goals by meal': 'Objetivos por comida',
    'Use default goal': 'Usar objetivo predeterminado',
    'Use default': 'Usar predeterminado',
    'Edit goal': 'Editar objetivo',
    'Calories': 'Calorías',
    'Carbohydrates %': 'Carbohidratos %',
    'Protein %': 'Proteína %',
    'Fat %': 'Grasa %',
    'Save': 'Guardar',
    'kcal': 'kcal',
    'breakfast': 'Desayuno',
    'lunch': 'Almuerzo',
    'dinner': 'Cena',
    'snack': 'Tentempié',
  },
  'tr': {
    'Scheduled goals': 'Planlanmış hedefler',
    'Goals unavailable': 'Hedefler kullanılamıyor',
    'Different goals by day': 'Güne göre farklı hedefler',
    'Goals by meal': 'Öğün hedefleri',
    'Use default goal': 'Varsayılan hedefi kullan',
    'Use default': 'Varsayılanı kullan',
    'Edit goal': 'Hedefi düzenle',
    'Calories': 'Kalori',
    'Carbohydrates %': 'Karbonhidrat %',
    'Protein %': 'Protein %',
    'Fat %': 'Yağ %',
    'Save': 'Kaydet',
    'kcal': 'kcal',
    'breakfast': 'Kahvaltı',
    'lunch': 'Öğle yemeği',
    'dinner': 'Akşam yemeği',
    'snack': 'Ara öğün',
  },
};
