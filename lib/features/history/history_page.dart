import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/weight_analysis.dart';
import '../../engine/progress_analysis.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../shared/widgets/wheel_number_field.dart';
import '../../shared/widgets/actionable_empty_state.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../../shared/widgets/premium_surface.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

part 'widgets/weight_trend_painter.dart';
part 'widgets/history_page_components.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    WeightEntry? entry,
  ]) async {
    final system =
        ref.read(measurementSystemProvider).value ?? MeasurementSystem.metric;
    var displayed = UnitConverter.weightFromKg(entry?.weight ?? 60, system);
    var selectedDate = entry?.date ?? DateTime.now();
    var measurementContext = entry?.measurementContext ?? 'differentConditions';
    final value =
        await showDialog<
          ({double weight, DateTime date, String measurementContext})
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                context.strings.text(
                  entry == null ? 'Add weight' : 'Edit weight',
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WheelNumberField(
                        value: displayed,
                        minimum: UnitConverter.weightFromKg(20, system),
                        maximum: UnitConverter.weightFromKg(350, system),
                        step: UnitConverter.weightStep(system),
                        decimalPlaces: 1,
                        unit: UnitConverter.weightUnit(system),
                        label: context.strings.text('Weight'),
                        onChanged: (next) =>
                            setDialogState(() => displayed = next),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(context.strings.text('Measurement date')),
                        subtitle: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(selectedDate),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: measurementContext,
                        decoration: InputDecoration(
                          labelText: context.strings.text(
                            'Measurement conditions',
                          ),
                        ),
                        items:
                            const [
                                  'morning',
                                  'afterBathroom',
                                  'beforeFoodDrink',
                                  'differentConditions',
                                ]
                                .map(
                                  (contextValue) => DropdownMenuItem(
                                    value: contextValue,
                                    child: Text(
                                      context.strings.text(contextValue),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (next) => setDialogState(
                          () => measurementContext =
                              next ?? 'differentConditions',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.strings.text('Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, (
                    weight: UnitConverter.weightToKg(displayed, system),
                    date: selectedDate,
                    measurementContext: measurementContext,
                  )),
                  child: Text(context.strings.text('Save')),
                ),
              ],
            ),
          ),
        );
    if (value == null) return;
    final repository = ref.read(weightRepositoryProvider);
    try {
      if (entry == null) {
        await repository.addWeight(
          value.weight,
          date: value.date,
          measurementContext: value.measurementContext,
        );
      } else {
        await repository.updateWeight(
          id: entry.id,
          weight: value.weight,
          date: value.date,
          note: entry.note,
          measurementContext: value.measurementContext,
        );
      }
    } on StateError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              'A weight entry already exists for this date.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    WeightEntry entry,
  ) async {
    final system =
        ref.read(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final displayed = UnitConverter.weightFromKg(entry.weight, system);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.strings.text('Delete weight?')),
        content: Text(
          '${context.strings.text('Delete')} ${displayed.toStringAsFixed(1)} ${UnitConverter.weightUnit(system)} ${context.strings.text('from history?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(weightRepositoryProvider).deleteWeight(entry.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(weightHistoryProvider);
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final unit = UnitConverter.weightUnit(system);
    final profile = ref.watch(userProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Weight history'))),
      floatingActionButton: history.value?.isNotEmpty == true
          ? FloatingActionButton(
              tooltip: context.strings.text('Add weight'),
              onPressed: () => _edit(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: history.when(
        loading: () => Semantics(
          label: context.strings.text('Loading weight history'),
          liveRegion: true,
          child: ExcludeSemantics(
            child: ListView(
              padding: PremiumDesignTokens.screenPadding,
              children: [
                const _HistorySkeletonBlock(height: 220),
                const SizedBox(height: PremiumDesignTokens.spaceSm),
                const _HistorySkeletonBlock(height: 96),
                const SizedBox(height: PremiumDesignTokens.spaceSm),
                const _HistorySkeletonBlock(height: 96),
                const SizedBox(height: PremiumDesignTokens.spaceSm),
                const _HistorySkeletonBlock(height: 96),
              ],
            ),
          ),
        ),
        error: (_, _) => ListView(
          padding: PremiumDesignTokens.screenPadding,
          children: [
            _HistoryContextBanner(
              icon: Icons.warning_amber_rounded,
              title: context.strings.text(
                'Weight history is temporarily unavailable',
              ),
              subtitle: context.strings.text(
                'Some local records could not be read. Trend interpretation is hidden until local data is available again.',
              ),
            ),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            ActionableErrorState(
              title: context.strings.text('Could not load weight history'),
              onRetry: () => ref.invalidate(weightHistoryProvider),
            ),
          ],
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return ActionableEmptyState(
              icon: Icons.monitor_weight_outlined,
              title: context.strings.text('Build your first comparable trend'),
              body: context.strings.text(
                'One measurement establishes a starting point. BIL waits for more comparable days before describing a trend.',
              ),
              actionLabel: context.strings.text('Record first weight'),
              onAction: () => _edit(context, ref),
            );
          }
          final chronological = rows.reversed.toList();
          final trend = WeightAnalysis.calculateWeeklyTrend(
            chronological.map((row) => row.weight).toList(),
          );
          final analysis = ProgressAnalysis.evaluate(
            samples: chronological
                .map(
                  (row) => ProgressSample(date: row.date, weightKg: row.weight),
                )
                .toList(),
            goalWeightKg: profile?.targetWeight,
          );
          final locale = Localizations.localeOf(
            context,
          ).languageCode.toLowerCase();
          final recent = chronological.length > 30
              ? chronological.sublist(chronological.length - 30)
              : chronological;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              PremiumDesignTokens.spaceMd,
              PremiumDesignTokens.spaceMd,
              PremiumDesignTokens.spaceMd,
              96,
            ),
            children: [
              PremiumSurface(
                padding: PremiumDesignTokens.cardPaddingLarge,
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          context.strings.text('Weight trend'),
                          style: PremiumDesignTokens.cardHeading(context),
                        ),
                      ),
                      const SizedBox(height: PremiumDesignTokens.spaceSm),
                      WeightTrendChart(
                        weights: recent.map((row) => row.weight).toList(),
                        variability: analysis.variabilityKg,
                        semanticsLabel: context.strings.text(
                          'Recorded weight trend over time',
                        ),
                      ),
                      const SizedBox(height: PremiumDesignTokens.spaceSm),
                      _HistoryExplainabilityChips(
                        confidenceLabel: _confidenceLabel(
                          analysis.confidence,
                          locale,
                        ),
                        sampleCount: analysis.sampleCount,
                        spanDays: analysis.spanDays,
                        system: system,
                        weeklyDirectionKg: analysis.weeklyDirectionKg,
                      ),
                      const SizedBox(height: PremiumDesignTokens.spaceSm),
                      Text(
                        '${context.strings.text('Seven-day change')}: ${trend == null ? context.strings.text('More data needed') : '${UnitConverter.weightFromKg(trend, system).toStringAsFixed(2)} $unit'}',
                      ),
                      Text(
                        '${context.strings.text('Smoothed weekly direction')}: ${analysis.weeklyDirectionKg == null ? context.strings.text('At least four entries needed') : '${analysis.weeklyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(analysis.weeklyDirectionKg!, system).toStringAsFixed(2)} $unit/${context.strings.text('week')}'}',
                      ),
                      Text(
                        '${_historyText(locale, 'monthlyDirection')}: ${analysis.monthlyDirectionKg == null ? _historyText(locale, 'longerWindow') : '${analysis.monthlyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(analysis.monthlyDirectionKg!, system).toStringAsFixed(1)} $unit'}',
                      ),
                      Text(
                        '${_historyText(locale, 'confidence')}: ${_confidenceLabel(analysis.confidence, locale)} · ${analysis.sampleCount} ${_historyText(locale, 'measurementsAcross')} ${analysis.spanDays} ${_historyText(locale, 'days')}',
                      ),
                      if (analysis.variabilityKg != null)
                        Text(
                          '${_historyText(locale, 'variation')}: ${_historyText(locale, 'about')} ${UnitConverter.weightFromKg(analysis.variabilityKg!, system).toStringAsFixed(2)} $unit',
                        ),
                      _HistoryGoalProjectionCard(
                        analysis: analysis,
                        system: system,
                        locale: locale,
                      ),
                      Text(
                        context.strings.text(
                          'Scale trends include water, glycogen, digestive content, and measurement variation; they do not prove fat or muscle change.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...rows.map(
                (entry) => PremiumSurface(
                  child: ListTile(
                    title: Text(
                      '${UnitConverter.weightFromKg(entry.weight, system).toStringAsFixed(1)} $unit',
                    ),
                    subtitle: Text(
                      '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () => _edit(context, ref, entry),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, entry),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _confidenceLabel(ProgressConfidence confidence, String locale) =>
    _historyText(locale, switch (confidence) {
      ProgressConfidence.insufficient => 'insufficient',
      ProgressConfidence.low => 'low',
      ProgressConfidence.medium => 'medium',
      ProgressConfidence.high => 'high',
    });

String _historyText(String locale, String key) =>
    _historyCopy[locale]?[key] ?? _historyCopy['en']![key]!;

const _historyCopy = <String, Map<String, String>>{
  'en': {
    'monthlyDirection': 'Approximate monthly direction',
    'longerWindow': 'a longer evidence window is needed',
    'confidence': 'Confidence',
    'measurementsAcross': 'measurements across',
    'days': 'days',
    'variation': 'Variation around the direction',
    'about': 'about',
    'insufficient': 'insufficient',
    'low': 'low',
    'medium': 'medium',
    'high': 'high',
    'smoothBand': 'Smoothed line with a variation band',
    'showRaw': 'Show raw measurements',
    'bandHelp':
        'The shaded band shows variation around the trend, not statistical certainty.',
    'goalTitle': 'Cautious goal estimate',
    'noGoal':
        'No goal date is shown until evidence is sufficient and the direction aligns with the goal.',
    'needFour':
        'At least four comparable measurements are needed before estimating a goal date.',
    'withheld':
        'Confidence is insufficient right now, so the estimated date is withheld.',
    'nearFlat':
        'The direction is near flat; a clearer change is needed before estimating.',
    'weeklyUnavailable': 'Weekly direction is not available yet.',
    'currentDirection': 'Current direction',
  },
  'ar': {
    'monthlyDirection': 'الاتجاه الشهري التقريبي',
    'longerWindow': 'نحتاج بيانات تمتد لفترة أطول',
    'confidence': 'الثقة',
    'measurementsAcross': 'قياسًا خلال',
    'days': 'يومًا',
    'variation': 'التذبذب حول الاتجاه',
    'about': 'نحو',
    'insufficient': 'غير كافية',
    'low': 'منخفضة',
    'medium': 'متوسطة',
    'high': 'مرتفعة',
    'smoothBand': 'الخط الممهّد مع نطاق التذبذب',
    'showRaw': 'إظهار القياسات الخام',
    'bandHelp': 'النطاق المظلل يوضح التذبذب حول الاتجاه، وليس يقينًا إحصائيًا.',
    'goalTitle': 'توقع حذر للهدف',
    'noGoal':
        'لا يظهر تاريخ هدف حتى تصبح الأدلة كافية ويتوافق الاتجاه مع الهدف.',
    'needFour':
        'نحتاج أربعة قياسات قابلة للمقارنة على الأقل قبل حساب تاريخ الهدف.',
    'withheld': 'الثقة غير كافية الآن، لذا نؤجل التاريخ التقديري.',
    'nearFlat': 'الاتجاه قريب من الثبات؛ نحتاج تغيرًا أوضح قبل التقدير.',
    'weeklyUnavailable': 'الاتجاه الأسبوعي غير متاح بعد.',
    'currentDirection': 'الاتجاه الحالي',
  },
  'fr': {
    'monthlyDirection': 'Tendance mensuelle approximative',
    'longerWindow': 'une période de données plus longue est nécessaire',
    'confidence': 'Confiance',
    'measurementsAcross': 'mesures sur',
    'days': 'jours',
    'variation': 'Variation autour de la tendance',
    'about': 'environ',
    'insufficient': 'insuffisante',
    'low': 'faible',
    'medium': 'moyenne',
    'high': 'élevée',
    'smoothBand': 'Courbe lissée avec bande de variation',
    'showRaw': 'Afficher les mesures brutes',
    'bandHelp':
        'La bande ombrée montre la variation autour de la tendance, pas une certitude statistique.',
    'goalTitle': 'Estimation prudente de l’objectif',
    'noGoal':
        'Aucune date d’objectif n’est affichée avant que les preuves soient suffisantes et que la tendance corresponde à l’objectif.',
    'needFour':
        'Au moins quatre mesures comparables sont nécessaires pour estimer une date.',
    'withheld':
        'La confiance est actuellement insuffisante ; la date estimée est donc masquée.',
    'nearFlat':
        'La tendance est presque stable ; un changement plus net est nécessaire.',
    'weeklyUnavailable':
        'La tendance hebdomadaire n’est pas encore disponible.',
    'currentDirection': 'Tendance actuelle',
  },
  'es': {
    'monthlyDirection': 'Tendencia mensual aproximada',
    'longerWindow': 'se necesita un periodo de datos más largo',
    'confidence': 'Confianza',
    'measurementsAcross': 'mediciones durante',
    'days': 'días',
    'variation': 'Variación alrededor de la tendencia',
    'about': 'aproximadamente',
    'insufficient': 'insuficiente',
    'low': 'baja',
    'medium': 'media',
    'high': 'alta',
    'smoothBand': 'Línea suavizada con banda de variación',
    'showRaw': 'Mostrar mediciones sin procesar',
    'bandHelp':
        'La banda sombreada muestra variación alrededor de la tendencia, no certeza estadística.',
    'goalTitle': 'Estimación prudente del objetivo',
    'noGoal':
        'No se muestra una fecha objetivo hasta que haya pruebas suficientes y la tendencia coincida con el objetivo.',
    'needFour':
        'Se necesitan al menos cuatro mediciones comparables para estimar una fecha.',
    'withheld':
        'La confianza es insuficiente, por lo que se oculta la fecha estimada.',
    'nearFlat': 'La tendencia es casi plana; hace falta un cambio más claro.',
    'weeklyUnavailable': 'La tendencia semanal aún no está disponible.',
    'currentDirection': 'Tendencia actual',
  },
  'tr': {
    'monthlyDirection': 'Yaklaşık aylık yön',
    'longerWindow': 'daha uzun bir veri aralığı gerekli',
    'confidence': 'Güven',
    'measurementsAcross': 'ölçüm, toplam',
    'days': 'gün',
    'variation': 'Yön çevresindeki değişkenlik',
    'about': 'yaklaşık',
    'insufficient': 'yetersiz',
    'low': 'düşük',
    'medium': 'orta',
    'high': 'yüksek',
    'smoothBand': 'Değişkenlik bantlı yumuşatılmış çizgi',
    'showRaw': 'Ham ölçümleri göster',
    'bandHelp':
        'Gölgeli bant eğilim çevresindeki değişimi gösterir; istatistiksel kesinlik değildir.',
    'goalTitle': 'Temkinli hedef tahmini',
    'noGoal':
        'Kanıt yeterli olana ve yön hedefle uyumlu hale gelene kadar hedef tarihi gösterilmez.',
    'needFour':
        'Hedef tarihi tahmin etmek için en az dört karşılaştırılabilir ölçüm gerekir.',
    'withheld':
        'Güven şu anda yetersiz olduğundan tahmini tarih gösterilmiyor.',
    'nearFlat':
        'Yön neredeyse sabit; tahmin için daha belirgin değişim gerekir.',
    'weeklyUnavailable': 'Haftalık yön henüz kullanılamıyor.',
    'currentDirection': 'Geçerli yön',
  },
};
