import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../data/database/app_database.dart';
import '../../../shared/widgets/actionable_error_state.dart';
import '../../../shared/widgets/premium_surface.dart';

class DailyExerciseSection extends StatelessWidget {
  const DailyExerciseSection({
    super.key,
    required this.arabic,
    required this.controller,
    required this.onBrowseWorkouts,
  });

  final bool arabic;
  final TextEditingController controller;
  final VoidCallback onBrowseWorkouts;

  String tr(String en, String ar) => _inputText(en, ar);

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      key: const Key('daily-log-exercise-section'),
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Exercise', 'التمرين'),
                  style: PremiumDesignTokens.cardHeading(context),
                ),
              ),
              TextButton.icon(
                onPressed: onBrowseWorkouts,
                icon: const Icon(Icons.explore_outlined),
                label: Text(tr('Browse workouts', 'استكشف التمارين')),
              ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          TextField(
            key: const Key('daily-log-exercise-notes'),
            controller: controller,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: tr('What did you do?', 'ما التمرين الذي أنجزته؟'),
              hintText: tr(
                'Example: brisk walk · 30 min',
                'مثال: مشي سريع · 30 دقيقة',
              ),
              prefixIcon: const Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Saved with this day. You can edit or clear it at any time.',
              'يُحفظ مع هذا اليوم، ويمكنك تعديله أو مسحه في أي وقت.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class DailyWaterSection extends StatelessWidget {
  const DailyWaterSection({
    super.key,
    required this.arabic,
    required this.controller,
    required this.entries,
    required this.saving,
    required this.onAdd,
    required this.onDelete,
    required this.onRetry,
  });

  final bool arabic;
  final TextEditingController controller;
  final AsyncValue<List<WaterEntry>> entries;
  final bool saving;
  final Future<void> Function([int? amount]) onAdd;
  final Future<void> Function(int) onDelete;
  final VoidCallback onRetry;

  String tr(String en, String ar) => _inputText(en, ar);

  @override
  Widget build(BuildContext context) {
    final unit = _inputText('ml', 'مل');
    return PremiumSurface(
      key: const Key('daily-log-water-section'),
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Water', 'الماء'),
            style: PremiumDesignTokens.cardHeading(context),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: controller,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('Water amount (ml)', 'كمية الماء (مل)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const Key('daily_log_add_water_action'),
                onPressed: saving ? null : () => onAdd(),
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.water_drop_outlined),
                label: Text(tr('Add water', 'إضافة ماء')),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in const [250, 350, 500])
                ActionChip(
                  avatar: const Icon(Icons.water_drop_outlined, size: 18),
                  label: Text('+$amount $unit'),
                  onPressed: saving ? null : () => onAdd(amount),
                ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          entries.when(
            data: (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${tr('Water total', 'إجمالي الماء')}: ${rows.fold<int>(0, (sum, row) => sum + row.amountMl)} $unit',
                ),
                for (final entry in rows)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.water_drop_outlined),
                    title: Text('${entry.amountMl} $unit'),
                    subtitle: Text(
                      '${entry.occurredAt.hour.toString().padLeft(2, '0')}:${entry.occurredAt.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: IconButton(
                      tooltip: tr('Remove water entry', 'حذف تسجيل الماء'),
                      onPressed: saving ? null : () => onDelete(entry.id),
                      icon: const Icon(Icons.close),
                    ),
                  ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => ActionableErrorState(
              title: tr('Water data unavailable', 'بيانات الماء غير متاحة'),
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class DailyBodyContextSection extends StatelessWidget {
  const DailyBodyContextSection({
    super.key,
    required this.arabic,
    required this.options,
    required this.selected,
    required this.otherController,
    required this.dailyNoteController,
    required this.labelFor,
    required this.onToggle,
    required this.onOtherChanged,
    required this.onDailyNoteChanged,
  });

  final bool arabic;
  final List<String> options;
  final Set<String> selected;
  final TextEditingController otherController;
  final TextEditingController dailyNoteController;
  final String Function(String option) labelFor;
  final void Function(String option, bool selected) onToggle;
  final VoidCallback onOtherChanged;
  final VoidCallback onDailyNoteChanged;

  String tr(String en, String ar) => _inputText(en, ar);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumSurface(
      key: const Key('daily-log-body-context'),
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Body context', 'سياق الجسم'),
            style: PremiumDesignTokens.cardHeading(context),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'Select anything that may help explain today’s measurements.',
              'اختر ما قد يساعد في تفسير قياسات اليوم.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          TextField(
            key: const Key('daily-log-note-field'),
            controller: dailyNoteController,
            maxLines: 3,
            onChanged: (_) => onDailyNoteChanged(),
            decoration: InputDecoration(
              labelText: tr('Private daily note', 'ملاحظة يومية خاصة'),
              hintText: tr('How did today feel?', 'كيف كان شعورك اليوم؟'),
              prefixIcon: const Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          ExpansionTile(
            key: const Key('body-context-options-expansion'),
            initiallyExpanded: selected.isNotEmpty,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
            ),
            title: Text(tr('Add body context', 'أضف سياق الجسم')),
            subtitle: Text(
              selected.isEmpty
                  ? tr('Optional', 'اختياري')
                  : tr(
                      '${selected.length} selected',
                      'تم اختيار ${selected.length}',
                    ),
            ),
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.55,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final active = selected.contains(option);
                  return _BodyContextTile(
                    key: Key('body-context-$option'),
                    option: option,
                    label: labelFor(option),
                    selected: active,
                    onTap: () => onToggle(option, !active),
                  );
                },
              ),
            ],
          ),
          if (selected.contains('other')) ...[
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            TextField(
              key: const Key('body-context-other-field'),
              controller: otherController,
              maxLines: 2,
              onChanged: (_) => onOtherChanged(),
              decoration: InputDecoration(
                labelText: tr('Other context', 'سياق آخر'),
                hintText: tr(
                  'Add a short optional note',
                  'أضف ملاحظة قصيرة اختيارية',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _inputText(String en, String ar) {
  final activeLocale = AppLocalizations.activeLocale;
  final tag = BilLocalePolicy.canonicalTag(activeLocale);
  final locale = activeLocale.languageCode.toLowerCase();
  if (locale == 'ar') return ar;
  if (en.endsWith(' selected')) {
    final count = en.split(' ').first;
    return switch (locale) {
      'fr' => '$count sélectionnés',
      'es' => '$count seleccionados',
      'tr' => '$count seçildi',
      _ => en,
    };
  }
  return _dailyInputCopy[en]?[locale] ?? RuntimeCopy.resolve(en, tag) ?? en;
}

const _dailyInputCopy = <String, Map<String, String>>{
  'Exercise': {'fr': 'Exercice', 'es': 'Ejercicio', 'tr': 'Egzersiz'},
  'Browse workouts': {
    'fr': 'Parcourir les entraînements',
    'es': 'Explorar entrenamientos',
    'tr': 'Antrenmanlara göz at',
  },
  'What did you do?': {
    'fr': 'Qu’avez-vous fait ?',
    'es': '¿Qué hiciste?',
    'tr': 'Ne yaptınız?',
  },
  'Example: brisk walk · 30 min': {
    'fr': 'Exemple : marche rapide · 30 min',
    'es': 'Ejemplo: caminata rápida · 30 min',
    'tr': 'Örnek: tempolu yürüyüş · 30 dk',
  },
  'Saved with this day. You can edit or clear it at any time.': {
    'fr':
        'Enregistré avec cette journée. Vous pouvez le modifier ou l’effacer à tout moment.',
    'es': 'Se guarda con este día. Puedes editarlo o borrarlo cuando quieras.',
    'tr':
        'Bu günle birlikte kaydedilir. İstediğiniz zaman düzenleyebilir veya silebilirsiniz.',
  },
  'Water': {'fr': 'Eau', 'es': 'Agua', 'tr': 'Su'},
  'ml': {'fr': 'ml', 'es': 'ml', 'tr': 'ml'},
  'Water amount (ml)': {
    'fr': 'Quantité d’eau (ml)',
    'es': 'Cantidad de agua (ml)',
    'tr': 'Su miktarı (ml)',
  },
  'Add water': {'fr': 'Ajouter de l’eau', 'es': 'Añadir agua', 'tr': 'Su ekle'},
  'Water total': {'fr': 'Total d’eau', 'es': 'Agua total', 'tr': 'Toplam su'},
  'Remove water entry': {
    'fr': 'Supprimer cette saisie d’eau',
    'es': 'Eliminar registro de agua',
    'tr': 'Su kaydını kaldır',
  },
  'Water data unavailable': {
    'fr': 'Données d’eau indisponibles',
    'es': 'Datos de agua no disponibles',
    'tr': 'Su verileri kullanılamıyor',
  },
  'Body context': {
    'fr': 'Contexte du corps',
    'es': 'Contexto corporal',
    'tr': 'Beden bağlamı',
  },
  'Select anything that may help explain today’s measurements.': {
    'fr': 'Sélectionnez tout élément pouvant expliquer les mesures du jour.',
    'es': 'Selecciona lo que pueda ayudar a explicar las mediciones de hoy.',
    'tr': 'Bugünkü ölçümleri açıklamaya yardımcı olabilecek öğeleri seçin.',
  },
  'Private daily note': {
    'fr': 'Note quotidienne privée',
    'es': 'Nota diaria privada',
    'tr': 'Özel günlük not',
  },
  'How did today feel?': {
    'fr': 'Comment s’est passée la journée ?',
    'es': '¿Cómo te sentiste hoy?',
    'tr': 'Bugün nasıl hissettiniz?',
  },
  'Add body context': {
    'fr': 'Ajouter un contexte corporel',
    'es': 'Añadir contexto corporal',
    'tr': 'Beden bağlamı ekle',
  },
  'Optional': {'fr': 'Facultatif', 'es': 'Opcional', 'tr': 'İsteğe bağlı'},
  'Other context': {
    'fr': 'Autre contexte',
    'es': 'Otro contexto',
    'tr': 'Diğer bağlam',
  },
  'Add a short optional note': {
    'fr': 'Ajoutez une courte note facultative',
    'es': 'Añade una nota breve opcional',
    'tr': 'Kısa bir isteğe bağlı not ekleyin',
  },
};

class _BodyContextTile extends StatelessWidget {
  const _BodyContextTile({
    super.key,
    required this.option,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String option;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  String? get imageAsset => switch (option) {
    'greatSleep' => 'assets/images/daily_context/great_sleep_v1.png',
    'poorSleep' => 'assets/images/daily_context/poor_sleep_v1.png',
    'travel' => 'assets/images/daily_context/travel_v1.png',
    'fasting' => 'assets/images/daily_context/fasting_v1.png',
    'highSodiumMeal' => 'assets/images/daily_context/high_sodium_meal_v1.png',
    'hardWorkout' => 'assets/images/daily_context/hard_workout_v1.png',
    'psychologicalStress' =>
      'assets/images/daily_context/psychological_stress_v1.png',
    'illnessSymptoms' => 'assets/images/daily_context/illness_symptoms_v1.png',
    'medication' => 'assets/images/daily_context/medication_v1.png',
    'lessWater' => 'assets/images/daily_context/less_water_v1.png',
    'moreWater' => 'assets/images/daily_context/more_water_v1.png',
    'constipation' => 'assets/images/daily_context/constipation_v1.png',
    'nothingNotable' => 'assets/images/daily_context/nothing_notable_v1.png',
    'other' => 'assets/images/daily_context/other_v1.png',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          width: selected ? 2 : 1,
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageAsset case final asset?)
              Image.asset(
                asset,
                fit: BoxFit.cover,
                semanticLabel: label,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    bodyContextIcon(option),
                    size: 34,
                    color: scheme.primary,
                  ),
                ),
              )
            else
              Center(
                child: Icon(
                  bodyContextIcon(option),
                  size: 34,
                  color: scheme.primary,
                ),
              ),
            if (imageAsset != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC07101D)],
                  ),
                ),
              ),
            PositionedDirectional(
              start: 10,
              end: 10,
              bottom: 9,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: imageAsset == null
                            ? scheme.onSurface
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: scheme.primary,
                      size: 22,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData bodyContextIcon(String value) => switch (value) {
  'poorSleep' => Icons.bedtime_outlined,
  'greatSleep' => Icons.hotel_class_outlined,
  'travel' => Icons.flight_outlined,
  'fasting' => Icons.nights_stay_outlined,
  'highSodiumMeal' => Icons.soup_kitchen_outlined,
  'hardWorkout' => Icons.fitness_center_outlined,
  'psychologicalStress' => Icons.psychology_outlined,
  'illnessSymptoms' => Icons.sick_outlined,
  'medication' => Icons.medication_outlined,
  'lessWater' => Icons.water_drop_outlined,
  'moreWater' => Icons.water_outlined,
  'constipation' => Icons.health_and_safety_outlined,
  'nothingNotable' => Icons.check_circle_outline,
  _ => Icons.more_horiz,
};
