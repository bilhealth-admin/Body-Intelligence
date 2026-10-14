import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import '../../../core/units/measurement_units.dart';
import '../domain/coach_message_presentation.dart';
import '../domain/food_v2/coach_food_v2.dart';
import 'workspace/coach_food_card_copy.dart';

/// One readable projection for widgets, selection, copy, share, and speech.
/// Its inputs are bounded local facts; model prose is never parsed as data.
final class CoachMessagePlainCopy {
  const CoachMessagePlainCopy(
    this.context, {
    this.system = MeasurementSystem.metric,
  });
  final BuildContext context;
  final MeasurementSystem system;
  CoachFoodCardCopy get food => CoachFoodCardCopy(context);
  String tr(String en, String ar) => food.tr(en, ar);
  String get locale => Localizations.localeOf(context).toLanguageTag();
  String get unavailable => '—';
  String get details => tr('Nutrition details', 'تفاصيل المغذيات');
  String get partial =>
      tr('Known subtotal · incomplete coverage', 'مجموع معلوم · تغطية جزئية');
  String get estimated => food.estimated;
  String get difference => tr('Difference', 'الفرق');
  String get weightLabel => tr('Weight', 'الوزن');
  String get dateLabel => tr('Date', 'التاريخ');
  String get recordedPoints =>
      tr('Recorded measurements only', 'القياسات المسجلة فقط');
  String get ownerChanged => food.ownerChanged;

  String metricLabel(String id) => switch (id) {
    'netCarbohydrates' => tr('Net carbs', 'صافي الكربوهيدرات'),
    'neck' => tr('Neck', 'الرقبة'),
    'waist' => tr('Waist', 'الخصر'),
    'hips' => tr('Hips', 'الورك'),
    'chest' => tr('Chest', 'الصدر'),
    'arm' => tr('Arm', 'الذراع'),
    'thigh' => tr('Thigh', 'الفخذ'),
    _ => _foodMetricLabel(id),
  };

  String _foodMetricLabel(String id) {
    for (final nutrient in FoodNutrient.values) {
      if (nutrient.name == id) return food.nutrient(nutrient);
    }
    return tr('Unavailable value', 'قيمة غير متاحة');
  }

  String columnTitle(CoachVisualNutritionColumn column) =>
      column.metrics.every((x) => x.unit == 'cm')
      ? tr('Body measurements', 'قياسات الجسم')
      : column.mealType == null
      ? tr('Day summary', 'ملخص اليوم')
      : food.meal(column.mealType!);

  String number(double value) {
    if (value > 0 && value < .005) return '<${food.number(.01)}';
    if (value < 0 && value > -.005) return '>−${food.number(.01)}';
    return food.number(value);
  }

  String metricUnit(CoachVisualMetric metric) =>
      metric.unit == 'cm' ? UnitConverter.heightUnit(system) : metric.unit;
  double _metricAmount(CoachVisualMetric metric, double value) =>
      metric.unit == 'cm' ? UnitConverter.heightFromCm(value, system) : value;
  String metricDifference(CoachVisualMetric metric, double value) {
    final displayed = _metricAmount(metric, value);
    return '${displayed > 0 ? '+' : ''}${number(displayed)} ${metricUnit(metric)}';
  }

  String amount(CoachVisualMetric metric) {
    final value = metric.knownSubtotal;
    if (value == null) return unavailable;
    final displayed = number(_metricAmount(metric, value));
    return metric.estimated ? '~$displayed' : displayed;
  }

  String value(CoachVisualMetric metric) => metric.knownSubtotal == null
      ? unavailable
      : '${amount(metric)} ${metricUnit(metric)}';

  String metricLine(CoachVisualMetric metric) {
    final coverage = metric.coverage == CoachVisualCoverage.partial
        ? ' · $partial'
        : '';
    return '${metricLabel(metric.id)}: ${metric.knownSubtotal == null ? food.unknown : value(metric)}$coverage${metric.estimated ? ' · $estimated' : ''}';
  }

  String day(String key) =>
      DateFormat.yMMMd(locale).format(DateTime.parse(key));

  String source(String kind) {
    for (final candidate in CoachFoodSourceKind.values) {
      if (candidate.wireName == kind) return food.sourceKind(candidate);
    }
    return switch (kind) {
      'daily_log_repository_ledger' => tr('Daily Log', 'السجل اليومي'),
      'known_food_subtotal' => tr(
        'Known food subtotal',
        'مجموع الطعام المعلوم',
      ),
      'saved_measurements' => tr('Saved measurement', 'القياس المحفوظ'),
      'saved_day_ledger' => tr('Saved day', 'اليوم المحفوظ'),
      'immutable_food_details' => tr(
        'Saved food details',
        'تفاصيل الطعام المحفوظة',
      ),
      'calculated_recipe' => food.sourceKind(
        CoachFoodSourceKind.calculatedRecipe,
      ),
      'declared_unit' => tr('Recorded serving', 'الحصة المسجلة'),
      'legacy_recorded' => tr('Saved record', 'السجل المحفوظ'),
      'estimated_portion' => food.estimatedPortion,
      'unavailable_evidence' => tr('Source unavailable', 'المصدر غير متاح'),
      _ => tr('Saved source', 'مصدر محفوظ'),
    };
  }

  String sources(CoachVisualNutritionColumn column) {
    final labels = column.sourceKinds.map(source).toSet().join(' · ');
    final limited = column.sourceRevisionsComplete
        ? ''
        : ' · ${tr('Source details are summarized', 'تفاصيل المصادر مختصرة')}';
    return labels + limited;
  }

  String weight(CoachVisualWeightPoint point) =>
      '${number(UnitConverter.weightFromKg(point.kg, system))} ${UnitConverter.weightUnit(system)}';

  String weightDelta(CoachVisualWeightPoint a, CoachVisualWeightPoint b) {
    final delta = UnitConverter.weightFromKg(b.kg - a.kg, system);
    return '${delta > 0 ? '+' : ''}${number(delta)} ${UnitConverter.weightUnit(system)}';
  }

  String? previousWeightNote(
    CoachVisualWeightPoint previous,
    CoachVisualWeightPoint saved,
  ) {
    final delta = weightDelta(previous, saved);
    final conditionsDiffer =
        previous.context != saved.context ||
        const {
          '',
          'differentConditions',
          'unspecified',
        }.contains(saved.context);
    return tr(
          'Difference from weight recorded on ${day(previous.dayKey)}: $delta.',
          'الفرق عن الوزن المسجل بتاريخ ${day(previous.dayKey)}: $delta.',
        ) +
        (conditionsDiffer
            ? ' ${tr('Measurement conditions may differ.', 'قد تختلف ظروف القياس.')}'
            : '');
  }

  String? previousMeasurementNote(
    CoachVisualNutritionColumn previous,
    CoachVisualNutritionColumn saved,
  ) {
    final changes = <String>[];
    for (final metric in saved.metrics) {
      final candidates = previous.metrics.where((x) => x.id == metric.id);
      if (candidates.isEmpty) continue;
      final difference = coachVisualMetricDifference(candidates.first, metric);
      if (difference == null) continue;
      changes.add(
        '${metricLabel(metric.id)}: ${metricDifference(metric, difference)}',
      );
    }
    if (changes.isEmpty) return null;
    return '${tr('Difference from measurements recorded on ${day(previous.dayKey)}:', 'الفرق عن القياسات المسجلة بتاريخ ${day(previous.dayKey)}:')}\n${changes.join(' · ')}';
  }

  String point(CoachVisualWeightPoint point) =>
      '${day(point.dayKey)} · ${weight(point)}';

  /// Null forbids the whole message, including fallback text, for a foreign
  /// owner or a cancelled visit. Caller must not substitute health text for it.
  String? plain({
    required String fallback,
    required CoachMessagePresentation? presentation,
    required String expectedOwnerKey,
    required bool Function() ownerVisitIsCurrent,
    String? archivedOwnerKey,
  }) {
    if (!ownerVisitIsCurrent() ||
        (archivedOwnerKey != null && archivedOwnerKey != expectedOwnerKey) ||
        (presentation != null && presentation.ownerKey != expectedOwnerKey)) {
      return null;
    }
    final lines = <String>[];
    if (presentation == null) {
      lines.add(fallback);
    } else if (presentation.kind == CoachVisualKind.weight) {
      lines.add(
        '$weightLabel · ${day(presentation.fromDay)} – ${day(presentation.throughDay)}',
      );
      for (final point in presentation.weightPoints) {
        lines.add(this.point(point));
      }
      if (presentation.weightPoints.length > 1) {
        lines.add(
          '$difference: ${weightDelta(presentation.weightPoints[presentation.weightPoints.length - 2], presentation.weightPoints.last)}',
        );
      }
      lines.add(recordedPoints);
    } else {
      for (final column in presentation.columns) {
        lines.add('${columnTitle(column)} · ${day(column.dayKey)}');
        lines.addAll(column.metrics.map(metricLine));
        final evidence = sources(column);
        if (evidence.isNotEmpty) lines.add('${food.sources}: $evidence');
      }
      if (presentation.columns.length == 2) {
        final a = presentation.columns.first;
        final b = presentation.columns.last;
        for (final metric in a.metrics) {
          final candidates = b.metrics.where((x) => x.id == metric.id);
          if (candidates.isEmpty) continue;
          final delta = coachVisualMetricDifference(metric, candidates.first);
          if (delta == null) continue;
          lines.add(
            '$difference · ${metricLabel(metric.id)}: ${metricDifference(metric, delta)}',
          );
        }
      }
    }
    if (presentation != null) lines.addAll(presentation.notes);
    return ownerVisitIsCurrent() ? lines.join('\n') : null;
  }
}
