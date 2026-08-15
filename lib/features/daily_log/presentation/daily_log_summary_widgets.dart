import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../shared/widgets/premium_surface.dart';

class DiaryDateNavigator extends StatelessWidget {
  const DiaryDateNavigator({
    super.key,
    required this.date,
    required this.arabic,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime date;
  final bool arabic;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final label = today
        ? _summaryText(context, 'today')
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: _summaryText(context, 'previous'),
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: _summaryText(context, 'next'),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class DailyLogSnapshot extends StatelessWidget {
  const DailyLogSnapshot({
    super.key,
    required this.arabic,
    required this.meals,
    required this.water,
  });

  final bool arabic;
  final List<MealWithItems> meals;
  final List<WaterEntry> water;

  @override
  Widget build(BuildContext context) {
    final items = meals.expand((entry) => entry.items);
    final calories = items.fold<double>(
      0,
      (total, item) => total + item.calories,
    );
    final protein = items.fold<double>(
      0,
      (total, item) => total + item.protein,
    );
    final waterMl = water.fold<int>(
      0,
      (total, entry) => total + entry.amountMl,
    );
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _summaryText(context, 'summary'),
            style: PremiumDesignTokens.cardHeading(context),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.local_fire_department_outlined,
                  value: calories == 0 ? '—' : calories.round().toString(),
                  label: _summaryText(context, 'kcal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.fitness_center_outlined,
                  value: protein == 0 ? '—' : protein.toStringAsFixed(1),
                  label: _summaryText(context, 'protein'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.water_drop_outlined,
                  value: waterMl == 0 ? '—' : waterMl.toString(),
                  label: _summaryText(context, 'water'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _summaryText(context, 'honest'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
    return Chip(
      avatar: const Icon(Icons.science_outlined, size: 17),
      label: Text(
        value == null
            ? '${context.strings.text(label)}: ${context.strings.text('Unavailable')}'
            : '${context.strings.text(label)} ${value!.toStringAsFixed(1)} $localizedUnit',
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

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
