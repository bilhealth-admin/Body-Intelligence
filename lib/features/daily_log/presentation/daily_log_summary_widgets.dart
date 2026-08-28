import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../commerce/presentation/premium_nutrition_glass.dart';
import 'macro_value_formatter.dart';

class DiaryDateNavigator extends StatelessWidget {
  const DiaryDateNavigator({
    super.key,
    required this.date,
    required this.arabic,
    this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime date;
  final bool arabic;
  final VoidCallback? onBack;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final semanticLabel = today
        ? _summaryText(context, 'today')
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final visualLabel = today
        ? semanticLabel
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${(date.year % 100).toString().padLeft(2, '0')}';
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('daily-log-date-bar'),
      height: 64,
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              const SizedBox(width: 48),
            const Spacer(),
            IconButton(
              tooltip: _summaryText(context, 'previous'),
              onPressed: onPrevious,
              icon: Icon(
                arabic
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
              ),
            ),
            Flexible(
              flex: 3,
              child: TextButton(
                onPressed: onPick,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  minimumSize: const Size(92, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Directionality(
                        textDirection: today
                            ? Directionality.of(context)
                            : TextDirection.ltr,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            visualLabel,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.25,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, size: 24),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: _summaryText(context, 'next'),
              onPressed: onNext,
              icon: Icon(
                arabic
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class DailyLogSnapshot extends StatelessWidget {
  const DailyLogSnapshot({
    super.key,
    required this.arabic,
    required this.meals,
    required this.water,
    this.calorieGoal,
  });

  final bool arabic;
  final List<MealWithItems> meals;
  final List<WaterEntry> water;
  final double? calorieGoal;

  @override
  Widget build(BuildContext context) {
    final items = meals.expand((entry) => entry.items).toList(growable: false);
    final calories = items.fold<double>(
      0,
      (total, item) => total + item.calories,
    );
    final protein = items.fold<double>(
      0,
      (total, item) => total + item.protein,
    );
    final carbs = items.fold<double>(0, (total, item) => total + item.carbs);
    final fat = items.fold<double>(0, (total, item) => total + item.fats);
    final macroEnergy = protein * 4 + carbs * 4 + fat * 9;
    final carbsPercent = macroEnergy == 0 ? 0.0 : carbs * 400 / macroEnergy;
    final fatPercent = macroEnergy == 0 ? 0.0 : fat * 900 / macroEnergy;
    final proteinPercent = macroEnergy == 0 ? 0.0 : protein * 400 / macroEnergy;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('daily-log-compact-summary'),
      constraints: const BoxConstraints(minHeight: 146),
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ring = DailyLogCalorieMacroRing(
            calories: calories,
            calorieGoal: null,
            carbs: carbs,
            fat: fat,
            protein: protein,
            dimension: 100,
          );
          final macros = Row(
            children: [
              Expanded(
                child: _MacroMetric(
                  color: const Color(0xFF0A8F88),
                  percent: carbsPercent,
                  grams: carbs,
                  label: _summaryText(context, 'carbs'),
                ),
              ),
              Expanded(
                child: _MacroMetric(
                  color: const Color(0xFF6F1096),
                  percent: fatPercent,
                  grams: fat,
                  label: _summaryText(context, 'fat'),
                ),
              ),
              Expanded(
                child: _MacroMetric(
                  color: const Color(0xFFC56A00),
                  percent: proteinPercent,
                  grams: protein,
                  label: _summaryText(context, 'proteinShort'),
                ),
              ),
            ],
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ring,
              const SizedBox(width: 8),
              Expanded(
                child: PremiumNutritionGlass(
                  key: const Key('daily-log-summary-macros-glass'),
                  compact: true,
                  borderRadius: 14,
                  child: macros,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DailyMealDetailSummary extends StatelessWidget {
  const DailyMealDetailSummary({
    super.key,
    required this.meal,
    this.calorieGoal,
  });

  final MealWithItems? meal;
  final double? calorieGoal;

  @override
  Widget build(BuildContext context) {
    final items = meal?.items ?? const <MealItem>[];
    final calories = items.fold<double>(
      0,
      (total, item) => total + item.calories,
    );
    final protein = items.fold<double>(
      0,
      (total, item) => total + item.protein,
    );
    final carbs = items.fold<double>(0, (total, item) => total + item.carbs);
    final fat = items.fold<double>(0, (total, item) => total + item.fats);
    final macroEnergy = protein * 4 + carbs * 4 + fat * 9;
    double ratio(double energy) => macroEnergy <= 0
        ? 0
        : (energy / macroEnergy).clamp(0.0, 1.0).toDouble();
    final sodium = knownNutrientTotal(
      items,
      TrackedNutrient.sodium,
      (item) => item.sodium,
    );
    final potassium = knownNutrientTotal(
      items,
      TrackedNutrient.potassium,
      (item) => item.potassium,
    );
    final magnesium = knownNutrientTotal(
      items,
      TrackedNutrient.magnesium,
      (item) => item.magnesium,
    );
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('daily-meal-detail-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final calorieRing = DailyLogCalorieMacroRing(
            calories: calories,
            calorieGoal: calorieGoal,
            carbs: carbs,
            fat: fat,
            protein: protein,
            dimension: 116,
          );
          final macroDials = PremiumNutritionGlass(
            key: const Key('daily-meal-detail-macros'),
            compact: true,
            borderRadius: 18,
            child: Row(
              children: [
                Expanded(
                  child: _MealMacroDial(
                    label: _summaryText(context, 'carbs'),
                    grams: carbs,
                    progress: ratio(carbs * 4),
                    color: const Color(0xFF0A8F88),
                  ),
                ),
                Expanded(
                  child: _MealMacroDial(
                    label: _summaryText(context, 'fat'),
                    grams: fat,
                    progress: ratio(fat * 9),
                    color: const Color(0xFF6F1096),
                  ),
                ),
                Expanded(
                  child: _MealMacroDial(
                    label: _summaryText(context, 'proteinShort'),
                    grams: protein,
                    progress: ratio(protein * 4),
                    color: const Color(0xFFC56A00),
                  ),
                ),
              ],
            ),
          );
          final stacked =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.45;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stacked) ...[
                Center(child: calorieRing),
                const SizedBox(height: 14),
                macroDials,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    calorieRing,
                    const SizedBox(width: 12),
                    Expanded(child: macroDials),
                  ],
                ),
              const SizedBox(height: 14),
              PremiumNutritionGlass(
                key: const Key('daily-meal-detail-minerals'),
                compact: true,
                borderRadius: 16,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    NutrientMetric(label: 'Sodium', value: sodium, unit: 'mg'),
                    NutrientMetric(
                      label: 'Potassium',
                      value: potassium,
                      unit: 'mg',
                    ),
                    NutrientMetric(
                      label: 'Magnesium',
                      value: magnesium,
                      unit: 'mg',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MealMacroDial extends StatelessWidget {
  const _MealMacroDial({
    required this.label,
    required this.grams,
    required this.progress,
    required this.color,
  });

  final String label;
  final double grams;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: .13),
                  strokeCap: StrokeCap.round,
                ),
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${formatDiaryMacroGrams(grams)} g',
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class DailyLogCalorieMacroRing extends StatelessWidget {
  const DailyLogCalorieMacroRing({
    super.key,
    required this.calories,
    required this.calorieGoal,
    required this.carbs,
    required this.fat,
    required this.protein,
    this.dimension = 126,
  });

  final double calories;
  final double? calorieGoal;
  final double carbs;
  final double fat;
  final double protein;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${calories.round()} ${_summaryText(context, 'kcal')}${calorieGoal == null ? '' : ' / ${calorieGoal!.round()}'}',
      child: SizedBox.square(
        dimension: dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(dimension),
              painter: _MacroRingPainter(
                carbs: carbs,
                fat: fat,
                protein: protein,
                track: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(dimension * 0.17),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      calories.round().toString(),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                    ),
                    Text(
                      _summaryText(context, 'kcal'),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (calorieGoal != null)
                      Text(
                        '/ ${calorieGoal!.round()}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRingPainter extends CustomPainter {
  const _MacroRingPainter({
    required this.carbs,
    required this.fat,
    required this.protein,
    required this.track,
  });

  final double carbs;
  final double fat;
  final double protein;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Color(0xFF0A8F88), Color(0xFF6F1096), Color(0xFFFFAB32)];
    final energies = [carbs * 4, fat * 9, protein * 4];
    final total = energies.fold<double>(0, (sum, value) => sum + value);
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 12) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = track);
    if (total <= 0) return;
    var start = -1.5707963267948966;
    for (var i = 0; i < energies.length; i++) {
      final sweep = 6.283185307179586 * energies[i] / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) =>
      carbs != oldDelegate.carbs ||
      fat != oldDelegate.fat ||
      protein != oldDelegate.protein ||
      track != oldDelegate.track;
}

class _MacroMetric extends StatelessWidget {
  const _MacroMetric({
    required this.color,
    required this.percent,
    required this.grams,
    required this.label,
  });

  final Color color;
  final double percent;
  final double grams;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${percent.round()}%',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${formatDiaryMacroGrams(grams)} g',
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class NutrientMetric extends StatelessWidget {
  const NutrientMetric({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final localizedUnit = _summaryText(context, unit);
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value == null
                    ? '${context.strings.text(label)}: ${context.strings.text('Unavailable')}'
                    : '${context.strings.text(label)} ${value!.toStringAsFixed(1)} $localizedUnit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _summaryText(BuildContext context, String key) {
  final active = Localizations.localeOf(context);
  final locale = active.languageCode.toLowerCase();
  final english = _dailySummaryCopy['en']?[key] ?? key;
  return _dailySummaryCopy[locale]?[key] ??
      RuntimeCopy.resolve(english, BilLocalePolicy.canonicalTag(active)) ??
      english;
}

const _dailySummaryCopy = <String, Map<String, String>>{
  'en': {
    'today': 'Today',
    'previous': 'Previous day',
    'next': 'Next day',
    'summary': 'Today’s recorded summary',
    'kcal': 'kcal',
    'carbs': 'Carbs',
    'fat': 'Fat',
    'proteinShort': 'Protein',
    'noWater': 'No water recorded',
    'mlWater': 'ml water',
    'protein': 'g protein',
    'water': 'ml water',
    'honest':
        'BIL shows only what you recorded and never fills missing values automatically.',
    'g': 'g',
    'mg': 'mg',
  },
  'ar': {
    'today': 'اليوم',
    'previous': 'اليوم السابق',
    'next': 'اليوم التالي',
    'summary': 'ملخص اليوم المسجّل',
    'kcal': 'سعرة',
    'carbs': 'كربوهيدرات',
    'fat': 'دهون',
    'proteinShort': 'بروتين',
    'noWater': 'لم يُسجّل ماء',
    'mlWater': 'مل ماء',
    'protein': 'جم بروتين',
    'water': 'مل ماء',
    'honest': 'يعرض BIL ما سُجّل فقط، ولا يملأ القيم الناقصة تلقائيًا.',
    'g': 'جم',
    'mg': 'مجم',
  },
  'fr': {
    'today': 'Aujourd’hui',
    'previous': 'Jour précédent',
    'next': 'Jour suivant',
    'summary': 'Résumé enregistré du jour',
    'kcal': 'kcal',
    'carbs': 'Glucides',
    'fat': 'Lipides',
    'proteinShort': 'Protéines',
    'noWater': 'Aucune eau enregistrée',
    'mlWater': 'ml d’eau',
    'protein': 'g de protéines',
    'water': 'ml d’eau',
    'honest':
        'BIL affiche uniquement ce que vous avez enregistré et ne complète jamais automatiquement les valeurs manquantes.',
    'g': 'g',
    'mg': 'mg',
  },
  'es': {
    'today': 'Hoy',
    'previous': 'Día anterior',
    'next': 'Día siguiente',
    'summary': 'Resumen registrado de hoy',
    'kcal': 'kcal',
    'carbs': 'Carbohidratos',
    'fat': 'Grasa',
    'proteinShort': 'Proteína',
    'noWater': 'No hay agua registrada',
    'mlWater': 'ml de agua',
    'protein': 'g de proteína',
    'water': 'ml de agua',
    'honest':
        'BIL solo muestra lo que registraste y nunca completa automáticamente los valores que faltan.',
    'g': 'g',
    'mg': 'mg',
  },
  'tr': {
    'today': 'Bugün',
    'previous': 'Önceki gün',
    'next': 'Sonraki gün',
    'summary': 'Bugünün kayıtlı özeti',
    'kcal': 'kcal',
    'carbs': 'Karbonhidrat',
    'fat': 'Yağ',
    'proteinShort': 'Protein',
    'noWater': 'Su kaydı yok',
    'mlWater': 'ml su',
    'protein': 'g protein',
    'water': 'ml su',
    'honest':
        'BIL yalnızca kaydettiğiniz verileri gösterir ve eksik değerleri otomatik olarak doldurmaz.',
    'g': 'g',
    'mg': 'mg',
  },
};

double? knownNutrientTotal(
  List<MealItem> items,
  TrackedNutrient nutrient,
  double Function(MealItem item) valueOf,
) {
  if (items.isEmpty ||
      items.any(
        (item) =>
            !NutrientEvidenceMask.contains(item.nutrientEvidenceMask, nutrient),
      )) {
    return null;
  }
  return items.fold<double>(0, (total, item) => total + valueOf(item));
}
