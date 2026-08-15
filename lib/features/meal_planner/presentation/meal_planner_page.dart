import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../domain/meal_plan.dart';
import '../services/meal_plan_engine.dart';

class MealPlannerPage extends ConsumerStatefulWidget {
  const MealPlannerPage({super.key});

  @override
  ConsumerState<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends ConsumerState<MealPlannerPage> {
  static const _preferencesKey = 'mealPlanner.preferences.v1';
  static const _planKey = 'mealPlanner.week.v1';
  static const _groceryChecksKey = 'mealPlanner.groceryChecks.v1';
  final _engine = const MealPlanEngine();
  MealPlanPreferences _preferences = const MealPlanPreferences();
  WeeklyMealPlan? _plan;
  var _loading = true;
  var _saving = false;
  final _checkedGrocery = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(preferencesRepositoryProvider);
    try {
      final values = await Future.wait([
        repository.get(_preferencesKey),
        repository.get(_planKey),
        repository.get(_groceryChecksKey),
      ]);
      if (!mounted) return;
      setState(() {
        final preferences = values[0];
        final plan = values[1];
        if (preferences != null) {
          _preferences = MealPlanPreferences.fromJson(
            jsonDecode(preferences) as Map<String, dynamic>,
          );
        }
        if (plan != null) _plan = WeeklyMealPlan.decode(plan);
        final checks = values[2];
        if (checks != null) {
          _checkedGrocery
            ..clear()
            ..addAll((jsonDecode(checks) as List).cast<String>());
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _saving = true);
    final plan = _engine.generate(_preferences);
    try {
      final repository = ref.read(preferencesRepositoryProvider);
      await repository.set(_preferencesKey, jsonEncode(_preferences.toJson()));
      await repository.set(_planKey, plan.encode());
      await repository.remove(_groceryChecksKey);
      if (mounted) {
        setState(() {
          _plan = plan;
          _checkedGrocery.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final copy = _PlannerCopy(language);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(copy.text('title')),
          bottom: TabBar(
            tabs: [
              Tab(text: copy.text('week')),
              Tab(text: copy.text('grocery')),
              Tab(text: copy.text('prepMode')),
              Tab(text: copy.text('preferences')),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _week(copy),
                  _grocery(copy),
                  _prep(copy),
                  _preferencesView(copy),
                ],
              ),
      ),
    );
  }

  Widget _week(_PlannerCopy copy) {
    final plan = _plan;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          copy.text('hero'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(copy.text('heroBody')),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('generate-weekly-meal-plan'),
          onPressed: _saving ? null : _generate,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(_saving ? copy.text('saving') : copy.text('generate')),
        ),
        if (plan == null) ...[
          const SizedBox(height: 36),
          Icon(
            Icons.calendar_month_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(copy.text('empty'), textAlign: TextAlign.center),
        ] else ...[
          const SizedBox(height: 20),
          ...plan.meals.map((meal) {
            final recipe = recipeById(meal.recipeId)!;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${meal.day + 1}')),
                title: Text(recipe.title),
                subtitle: Text(
                  '${copy.day(meal.day)} • ${recipe.minutes} ${copy.text('minutes')} • ${recipe.meal}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRecipe(copy, recipe),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _grocery(_PlannerCopy copy) {
    final plan = _plan;
    if (plan == null) return Center(child: Text(copy.text('generateFirst')));
    final items = _engine.groceryList(plan, _preferences).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          copy.text('groceryTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(copy.text('groceryBody')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('share-meal-plan-grocery-list'),
          onPressed: () => _shareGrocery(copy, items),
          icon: const Icon(Icons.ios_share_outlined),
          label: Text(copy.text('shareGrocery')),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => CheckboxListTile(
            value: _checkedGrocery.contains(item.key),
            onChanged: (checked) => _toggleGrocery(item.key, checked == true),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(item.key),
            subtitle: Text(_amount(item.value)),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleGrocery(String key, bool checked) async {
    final wasChecked = _checkedGrocery.contains(key);
    setState(() {
      checked ? _checkedGrocery.add(key) : _checkedGrocery.remove(key);
    });
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set(_groceryChecksKey, jsonEncode(_checkedGrocery.toList()..sort()));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        wasChecked ? _checkedGrocery.add(key) : _checkedGrocery.remove(key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _PlannerCopy(
              Localizations.localeOf(context).languageCode,
            ).text('saveFailed'),
          ),
        ),
      );
    }
  }

  Future<void> _shareGrocery(
    _PlannerCopy copy,
    List<MapEntry<String, double>> items,
  ) async {
    final lines = <String>[
      copy.text('groceryTitle'),
      '',
      ...items.map(
        (item) =>
            '${_checkedGrocery.contains(item.key) ? '✓' : '☐'} ${item.key}: ${_amount(item.value)}',
      ),
      '',
      copy.text('shareNotice'),
    ];
    try {
      await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.text('shareFailed'))));
    }
  }

  Widget _prep(_PlannerCopy copy) {
    final plan = _plan;
    if (plan == null) return Center(child: Text(copy.text('generateFirst')));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          copy.text('prepTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(copy.text('prepBody')),
        const SizedBox(height: 12),
        ...plan.meals.map((meal) {
          final recipe = recipeById(meal.recipeId)!;
          final details = plannerRecipeDetails[recipe.id]!;
          return Card(
            child: ExpansionTile(
              title: Text('${copy.day(meal.day)} — ${recipe.title}'),
              subtitle: Text(
                '${copy.text('prep')}: ${details.prepMinutes} ${copy.text('minutes')} • '
                '${copy.text('cook')}: ${recipe.minutes} ${copy.text('minutes')}',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: details.steps.indexed
                  .map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${step.$1 + 1}. ${step.$2}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          );
        }),
      ],
    );
  }

  Widget _preferencesView(_PlannerCopy copy) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          copy.text('preferencesTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<MealPlanDiet>(
          initialValue: _preferences.diet,
          decoration: InputDecoration(labelText: copy.text('diet')),
          items: MealPlanDiet.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(copy.diet(value)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(
            () => _preferences = MealPlanPreferences(
              diet: value!,
              budget: _preferences.budget,
              maxMinutes: _preferences.maxMinutes,
              servings: _preferences.servings,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<MealPlanBudget>(
          initialValue: _preferences.budget,
          decoration: InputDecoration(labelText: copy.text('budget')),
          items: MealPlanBudget.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(copy.budget(value)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(
            () => _preferences = MealPlanPreferences(
              diet: _preferences.diet,
              budget: value!,
              maxMinutes: _preferences.maxMinutes,
              servings: _preferences.servings,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${copy.text('maxTime')}: ${_preferences.maxMinutes} ${copy.text('minutes')}',
        ),
        Slider(
          value: _preferences.maxMinutes.toDouble(),
          min: 10,
          max: 60,
          divisions: 10,
          onChanged: (value) => setState(
            () => _preferences = MealPlanPreferences(
              diet: _preferences.diet,
              budget: _preferences.budget,
              maxMinutes: value.round(),
              servings: _preferences.servings,
            ),
          ),
        ),
        Text('${copy.text('servings')}: ${_preferences.servings}'),
        Slider(
          value: _preferences.servings.toDouble(),
          min: 1,
          max: 8,
          divisions: 7,
          onChanged: (value) => setState(
            () => _preferences = MealPlanPreferences(
              diet: _preferences.diet,
              budget: _preferences.budget,
              maxMinutes: _preferences.maxMinutes,
              servings: value.round(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(copy.text('safety'), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  void _showRecipe(_PlannerCopy copy, PlannerRecipe recipe) {
    final details = plannerRecipeDetails[recipe.id];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              recipe.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ...recipe.ingredients.entries.map(
              (item) => Text(
                '• ${item.key}: ${_amount(item.value * _preferences.servings)}',
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 12),
              Text(
                '${copy.text('prep')}: ${details.prepMinutes} ${copy.text('minutes')} • '
                '${copy.text('cook')}: ${recipe.minutes} ${copy.text('minutes')}',
              ),
              const SizedBox(height: 10),
              Text(
                '${details.calories.toStringAsFixed(0)} kcal • '
                'P ${details.protein.toStringAsFixed(0)} g • '
                'C ${details.carbs.toStringAsFixed(0)} g • '
                'F ${details.fat.toStringAsFixed(0)} g',
              ),
              Text(
                '${copy.text('fiber')} ${details.fiber.toStringAsFixed(0)} g • '
                '${copy.text('sugar')} ${details.sugar.toStringAsFixed(0)} g • '
                '${copy.text('sodium')} ${details.sodium.toStringAsFixed(0)} mg • '
                '${copy.text('potassium')} ${details.potassium.toStringAsFixed(0)} mg',
              ),
              const SizedBox(height: 12),
              ...details.steps.indexed.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${step.$1 + 1}. ${step.$2}'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.text('estimateNotice'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push('/daily-log?action=food');
              },
              child: Text(copy.text('reviewLog')),
            ),
            const SizedBox(height: 8),
            Text(
              copy.text('logNotice'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _amount(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);
}

class _PlannerCopy {
  _PlannerCopy(this.language);
  final String language;
  String text(String key) =>
      (_copy[language] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;
  String day(int index) => text('day$index');
  String diet(MealPlanDiet value) => text('diet_${value.name}');
  String budget(MealPlanBudget value) => text('budget_${value.name}');
}

const _copy = <String, Map<String, String>>{
  'en': {
    'title': 'Meal Planner',
    'week': 'Week',
    'grocery': 'Grocery list',
    'prepMode': 'Meal prep',
    'preferences': 'Preferences',
    'hero': 'A week built around you',
    'heroBody':
        'Choose your time, budget and eating style. BIL creates a practical seven-day plan you can review before logging.',
    'generate': 'Build my week',
    'saving': 'Saving…',
    'empty': 'Set your preferences, then build your first week.',
    'minutes': 'min',
    'generateFirst': 'Build a weekly plan first.',
    'groceryTitle': 'Your grocery list',
    'groceryBody':
        'Quantities are combined for your selected servings. Check package sizes before buying.',
    'shareGrocery': 'Share grocery list',
    'shareNotice':
        'Created in BIL. Check quantities, allergies and package sizes before shopping.',
    'saveFailed': 'The grocery list could not be saved. Try again.',
    'shareFailed': 'The grocery list could not be shared.',
    'preferencesTitle': 'Plan preferences',
    'diet': 'Eating style',
    'budget': 'Budget',
    'maxTime': 'Maximum cooking time',
    'servings': 'Servings',
    'safety':
        'Allergies and medical restrictions must be checked by you before using a recipe. Nutrition is never logged without your confirmation.',
    'reviewLog': 'Review and log',
    'logNotice':
        'BIL opens the diary so you can match verified foods and portions before saving.',
    'diet_balanced': 'Balanced',
    'diet_vegetarian': 'Vegetarian',
    'diet_highProtein': 'High protein',
    'budget_value': 'Value',
    'budget_standard': 'Standard',
    'day0': 'Monday',
    'day1': 'Tuesday',
    'day2': 'Wednesday',
    'day3': 'Thursday',
    'day4': 'Friday',
    'day5': 'Saturday',
    'day6': 'Sunday',
    'prep': 'Prep',
    'cook': 'Cook',
    'fiber': 'Fiber',
    'sugar': 'Sugar',
    'sodium': 'Sodium',
    'potassium': 'Potassium',
    'prepTitle': 'Prep your week',
    'prepBody':
        'Open each day to see the ordered method and time. Batch compatible ingredients only when food-safety rules allow.',
    'estimateNotice':
        'Planning estimate only. Match verified foods and portions before saving nutrition.',
  },
  'ar': {
    'title': 'مخطط الوجبات',
    'week': 'الأسبوع',
    'grocery': 'قائمة التسوق',
    'prepMode': 'تحضير الوجبات',
    'preferences': 'التفضيلات',
    'hero': 'أسبوع مصمم لك',
    'heroBody':
        'اختر الوقت والميزانية ونمط الطعام، وسيبني BIL خطة عملية لسبعة أيام تراجعها قبل التسجيل.',
    'generate': 'أنشئ أسبوعي',
    'saving': 'جارٍ الحفظ…',
    'empty': 'اضبط تفضيلاتك ثم أنشئ أسبوعك الأول.',
    'minutes': 'د',
    'generateFirst': 'أنشئ خطة أسبوعية أولًا.',
    'groceryTitle': 'قائمة التسوق',
    'groceryBody':
        'جُمعت الكميات حسب عدد الحصص. تحقق من أحجام العبوات قبل الشراء.',
    'shareGrocery': 'مشاركة قائمة التسوق',
    'shareNotice':
        'أُنشئت في BIL. تحقق من الكميات والحساسية وأحجام العبوات قبل الشراء.',
    'saveFailed': 'تعذر حفظ قائمة التسوق. حاول مرة أخرى.',
    'shareFailed': 'تعذرت مشاركة قائمة التسوق.',
    'preferencesTitle': 'تفضيلات الخطة',
    'diet': 'نمط الطعام',
    'budget': 'الميزانية',
    'maxTime': 'أقصى وقت للطهي',
    'servings': 'الحصص',
    'safety':
        'يجب أن تتحقق بنفسك من الحساسية والقيود الطبية. لا تُسجل التغذية دون تأكيدك.',
    'reviewLog': 'راجع وسجّل',
    'logNotice': 'يفتح BIL اليوميات لمطابقة الطعام والحصة الموثقين قبل الحفظ.',
    'diet_balanced': 'متوازن',
    'diet_vegetarian': 'نباتي',
    'diet_highProtein': 'عالي البروتين',
    'budget_value': 'اقتصادي',
    'budget_standard': 'قياسي',
    'day0': 'الاثنين',
    'day1': 'الثلاثاء',
    'day2': 'الأربعاء',
    'day3': 'الخميس',
    'day4': 'الجمعة',
    'day5': 'السبت',
    'day6': 'الأحد',
    'prep': 'تحضير',
    'cook': 'طهي',
    'fiber': 'ألياف',
    'sugar': 'سكر',
    'sodium': 'صوديوم',
    'potassium': 'بوتاسيوم',
    'prepTitle': 'حضّر أسبوعك',
    'prepBody':
        'افتح كل يوم لرؤية الطريقة المرتبة والوقت. حضّر المكونات المشتركة فقط مع الالتزام بقواعد سلامة الغذاء.',
    'estimateNotice':
        'قيم تقديرية للتخطيط فقط. طابق الأطعمة والحصص الموثقة قبل حفظ التغذية.',
  },
  'fr': {
    'title': 'Planificateur de repas',
    'week': 'Semaine',
    'grocery': 'Courses',
    'prepMode': 'Préparation',
    'preferences': 'Préférences',
    'hero': 'Une semaine faite pour vous',
    'heroBody':
        'Choisissez temps, budget et alimentation. BIL crée un plan de sept jours à vérifier avant journalisation.',
    'generate': 'Créer ma semaine',
    'saving': 'Enregistrement…',
    'empty': 'Réglez vos préférences puis créez votre semaine.',
    'minutes': 'min',
    'generateFirst': 'Créez d’abord un plan hebdomadaire.',
    'groceryTitle': 'Votre liste de courses',
    'groceryBody': 'Les quantités sont regroupées selon les portions choisies.',
    'shareGrocery': 'Partager la liste',
    'shareNotice':
        'Créée dans BIL. Vérifiez quantités, allergies et formats avant les achats.',
    'saveFailed': 'La liste n’a pas pu être enregistrée. Réessayez.',
    'shareFailed': 'La liste n’a pas pu être partagée.',
    'preferencesTitle': 'Préférences du plan',
    'diet': 'Alimentation',
    'budget': 'Budget',
    'maxTime': 'Temps de cuisson maximal',
    'servings': 'Portions',
    'safety':
        'Vérifiez vous-même allergies et restrictions médicales. Rien n’est journalisé sans confirmation.',
    'reviewLog': 'Vérifier et journaliser',
    'logNotice':
        'BIL ouvre le journal pour choisir aliments et portions vérifiés.',
    'diet_balanced': 'Équilibré',
    'diet_vegetarian': 'Végétarien',
    'diet_highProtein': 'Riche en protéines',
    'budget_value': 'Économique',
    'budget_standard': 'Standard',
    'day0': 'Lundi',
    'day1': 'Mardi',
    'day2': 'Mercredi',
    'day3': 'Jeudi',
    'day4': 'Vendredi',
    'day5': 'Samedi',
    'day6': 'Dimanche',
    'prep': 'Préparation',
    'cook': 'Cuisson',
    'fiber': 'Fibres',
    'sugar': 'Sucres',
    'sodium': 'Sodium',
    'potassium': 'Potassium',
    'prepTitle': 'Préparez votre semaine',
    'prepBody':
        'Ouvrez chaque jour pour voir la méthode et le temps. Regroupez les ingrédients seulement dans le respect de la sécurité alimentaire.',
    'estimateNotice':
        'Estimation de planification uniquement. Vérifiez aliments et portions avant l’enregistrement.',
  },
  'es': {
    'title': 'Planificador de comidas',
    'week': 'Semana',
    'grocery': 'Compra',
    'prepMode': 'Preparación',
    'preferences': 'Preferencias',
    'hero': 'Una semana hecha para ti',
    'heroBody':
        'Elige tiempo, presupuesto y estilo. BIL crea un plan de siete días para revisar antes de registrar.',
    'generate': 'Crear mi semana',
    'saving': 'Guardando…',
    'empty': 'Configura tus preferencias y crea tu semana.',
    'minutes': 'min',
    'generateFirst': 'Crea primero un plan semanal.',
    'groceryTitle': 'Tu lista de compra',
    'groceryBody': 'Las cantidades se combinan según las porciones elegidas.',
    'shareGrocery': 'Compartir la lista',
    'shareNotice':
        'Creada en BIL. Revisa cantidades, alergias y tamaños antes de comprar.',
    'saveFailed': 'No se pudo guardar la lista. Inténtalo de nuevo.',
    'shareFailed': 'No se pudo compartir la lista.',
    'preferencesTitle': 'Preferencias del plan',
    'diet': 'Estilo de alimentación',
    'budget': 'Presupuesto',
    'maxTime': 'Tiempo máximo de cocina',
    'servings': 'Porciones',
    'safety':
        'Comprueba alergias y restricciones médicas. Nada se registra sin tu confirmación.',
    'reviewLog': 'Revisar y registrar',
    'logNotice':
        'BIL abre el diario para elegir alimentos y porciones verificados.',
    'diet_balanced': 'Equilibrado',
    'diet_vegetarian': 'Vegetariano',
    'diet_highProtein': 'Alto en proteína',
    'budget_value': 'Económico',
    'budget_standard': 'Estándar',
    'day0': 'Lunes',
    'day1': 'Martes',
    'day2': 'Miércoles',
    'day3': 'Jueves',
    'day4': 'Viernes',
    'day5': 'Sábado',
    'day6': 'Domingo',
    'prep': 'Preparación',
    'cook': 'Cocción',
    'fiber': 'Fibra',
    'sugar': 'Azúcar',
    'sodium': 'Sodio',
    'potassium': 'Potasio',
    'prepTitle': 'Prepara tu semana',
    'prepBody':
        'Abre cada día para ver el método y el tiempo. Agrupa ingredientes solo cuando lo permitan las normas de seguridad alimentaria.',
    'estimateNotice':
        'Estimación solo para planificar. Verifica alimentos y porciones antes de guardar.',
  },
  'tr': {
    'title': 'Öğün Planlayıcı',
    'week': 'Hafta',
    'grocery': 'Alışveriş',
    'prepMode': 'Öğün hazırlığı',
    'preferences': 'Tercihler',
    'hero': 'Size göre hazırlanmış bir hafta',
    'heroBody':
        'Süreyi, bütçeyi ve beslenme biçimini seçin. BIL kayıttan önce gözden geçireceğiniz yedi günlük plan oluşturur.',
    'generate': 'Haftamı oluştur',
    'saving': 'Kaydediliyor…',
    'empty': 'Tercihlerinizi ayarlayıp ilk haftanızı oluşturun.',
    'minutes': 'dk',
    'generateFirst': 'Önce haftalık plan oluşturun.',
    'groceryTitle': 'Alışveriş listeniz',
    'groceryBody': 'Miktarlar seçilen porsiyonlara göre birleştirilir.',
    'shareGrocery': 'Listeyi paylaş',
    'shareNotice':
        'BIL içinde oluşturuldu. Alışverişten önce miktarları, alerjileri ve paketleri kontrol edin.',
    'saveFailed': 'Alışveriş listesi kaydedilemedi. Tekrar deneyin.',
    'shareFailed': 'Alışveriş listesi paylaşılamadı.',
    'preferencesTitle': 'Plan tercihleri',
    'diet': 'Beslenme biçimi',
    'budget': 'Bütçe',
    'maxTime': 'En uzun pişirme süresi',
    'servings': 'Porsiyon',
    'safety':
        'Alerjileri ve tıbbi kısıtlamaları kendiniz kontrol edin. Onayınız olmadan besin kaydı yapılmaz.',
    'reviewLog': 'İncele ve kaydet',
    'logNotice':
        'BIL doğrulanmış yiyecek ve porsiyon seçmeniz için günlüğü açar.',
    'diet_balanced': 'Dengeli',
    'diet_vegetarian': 'Vejetaryen',
    'diet_highProtein': 'Yüksek protein',
    'budget_value': 'Ekonomik',
    'budget_standard': 'Standart',
    'day0': 'Pazartesi',
    'day1': 'Salı',
    'day2': 'Çarşamba',
    'day3': 'Perşembe',
    'day4': 'Cuma',
    'day5': 'Cumartesi',
    'day6': 'Pazar',
    'prep': 'Hazırlık',
    'cook': 'Pişirme',
    'fiber': 'Lif',
    'sugar': 'Şeker',
    'sodium': 'Sodyum',
    'potassium': 'Potasyum',
    'prepTitle': 'Haftanızı hazırlayın',
    'prepBody':
        'Sıralı yöntemi ve süreyi görmek için her günü açın. Ortak malzemeleri yalnızca gıda güvenliği uygunsa birlikte hazırlayın.',
    'estimateNotice':
        'Yalnızca planlama tahminidir. Kaydetmeden önce doğrulanmış yiyecek ve porsiyonları eşleştirin.',
  },
};
