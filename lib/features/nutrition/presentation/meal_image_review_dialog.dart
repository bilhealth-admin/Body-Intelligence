import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../data/database/app_database.dart';
import '../services/meal_image_gateway_contract.dart';

class MealImageReviewSelection {
  const MealImageReviewSelection({
    required this.candidate,
    required this.amount,
    required this.unit,
  });
  final MealImageCandidate candidate;
  final double amount;
  final String unit;
}

Future<Food?> showTrustedVisionFoodMatchDialog(
  BuildContext context, {
  required String recognizedName,
  required List<Food> foods,
}) {
  if (foods.isEmpty) return Future<Food?>.value(null);
  Food? selected;
  final copy = _VisionReviewCopy.ofLocale(Localizations.localeOf(context));
  return showDialog<Food>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(copy.matchTitle),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: [
              _NaturalText('${copy.recognized}: $recognizedName'),
              const SizedBox(height: 10),
              for (final food in foods)
                ListTile(
                  onTap: () => setState(() => selected = food),
                  leading: Icon(
                    identical(selected, food)
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: _NaturalText(food.name),
                  subtitle: _NaturalText(
                    '${food.servingSize} ${food.servingUnit} · ${food.source}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(copy.cancel),
          ),
          FilledButton(
            onPressed: selected == null
                ? null
                : () => Navigator.pop(dialogContext, selected),
            child: Text(copy.useFood),
          ),
        ],
      ),
    ),
  );
}

Future<List<MealImageReviewSelection>?> showMealImageReviewDialog(
  BuildContext context, {
  required MealImageAnalysis analysis,
}) {
  final copy = _VisionReviewCopy.ofLocale(Localizations.localeOf(context));
  final selected = <int>{};
  final amounts = <TextEditingController>[
    for (final item in analysis.candidates)
      TextEditingController(text: item.amount?.toString() ?? ''),
  ];
  final units = <TextEditingController>[
    for (final item in analysis.candidates)
      TextEditingController(text: item.unit ?? ''),
  ];
  return showDialog<List<MealImageReviewSelection>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(copy.review),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: [
              _NaturalText(analysis.notice),
              const SizedBox(height: 12),
              for (var index = 0; index < analysis.candidates.length; index++)
                _CandidateReviewCard(
                  candidate: analysis.candidates[index],
                  selected: selected.contains(index),
                  amount: amounts[index],
                  unit: units[index],
                  copy: copy,
                  onSelected: (value) => setDialogState(() {
                    value ? selected.add(index) : selected.remove(index);
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(copy.cancel),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () {
                    final result = <MealImageReviewSelection>[];
                    for (final index in selected) {
                      final amount = double.tryParse(
                        amounts[index].text.trim(),
                      );
                      final unit = units[index].text.trim();
                      if (amount == null ||
                          !amount.isFinite ||
                          amount <= 0 ||
                          amount > 100000 ||
                          unit.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(copy.amountRequired)),
                        );
                        return;
                      }
                      result.add(
                        MealImageReviewSelection(
                          candidate: analysis.candidates[index],
                          amount: amount,
                          unit: unit,
                        ),
                      );
                    }
                    Navigator.pop(dialogContext, result);
                  },
            child: Text(copy.continueLabel),
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    for (final controller in [...amounts, ...units]) {
      controller.dispose();
    }
  });
}

class _CandidateReviewCard extends StatelessWidget {
  const _CandidateReviewCard({
    required this.candidate,
    required this.selected,
    required this.amount,
    required this.unit,
    required this.copy,
    required this.onSelected,
  });
  final MealImageCandidate candidate;
  final bool selected;
  final TextEditingController amount, unit;
  final _VisionReviewCopy copy;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final low = candidate.confidence < 0.55;
    return Card(
      color: low ? Theme.of(context).colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected,
              onChanged: (value) => onSelected(value == true),
              title: _NaturalText(candidate.name),
              subtitle: Text(
                '${copy.confidence}: ${(candidate.confidence * 100).round()}%'
                '${low ? ' · ${copy.lowConfidence}' : ''}',
              ),
            ),
            if (candidate.evidence.isNotEmpty) _NaturalText(candidate.evidence),
            if (candidate.alternatives.isNotEmpty)
              _NaturalText(
                '${copy.alternatives}: ${candidate.alternatives.map((item) => '${item.name} ${(item.confidence * 100).round()}%').join(', ')}',
              ),
            if (candidate.uncertainty != null)
              _NaturalText('${copy.uncertainty}: ${candidate.uncertainty}'),
            for (final warning in candidate.warnings)
              _NaturalText(
                '⚠ $warning',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: copy.amount),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unit,
                    decoration: InputDecoration(labelText: copy.unit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NaturalText extends StatelessWidget {
  const _NaturalText(this.text, {this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr,
    child: Text(text, style: style, textAlign: TextAlign.start),
  );
}

class _VisionReviewCopy {
  const _VisionReviewCopy(this.v);
  final Map<String, String> v;
  String get review => v['review']!;
  String get cancel => v['cancel']!;
  String get continueLabel => v['continue']!;
  String get confidence => v['confidence']!;
  String get lowConfidence => v['low']!;
  String get alternatives => v['alternatives']!;
  String get uncertainty => v['uncertainty']!;
  String get amount => v['amount']!;
  String get unit => v['unit']!;
  String get amountRequired => v['required']!;
  String get matchTitle => v['match']!;
  String get recognized => v['recognized']!;
  String get useFood => v['use']!;
  static _VisionReviewCopy ofLocale(Locale locale) {
    final primary = _all[locale.languageCode];
    if (primary != null) return primary;
    final english = _all['en']!.v;
    final tag = BilLocalePolicy.canonicalTag(locale);
    return _VisionReviewCopy({
      for (final entry in english.entries)
        entry.key: RuntimeCopy.resolve(entry.value, tag) ?? entry.value,
    });
  }

  static const _all = <String, _VisionReviewCopy>{
    'en': _VisionReviewCopy({
      'review': 'Review every visible item',
      'cancel': 'Cancel',
      'continue': 'Match selected foods',
      'confidence': 'Confidence',
      'low': 'Low confidence',
      'alternatives': 'Alternatives',
      'uncertainty': 'Uncertainty',
      'amount': 'Amount',
      'unit': 'Unit',
      'required': 'Enter a valid amount and unit for every selected item.',
      'match': 'Choose the catalog food record',
      'recognized': 'Image suggestion',
      'use': 'Use this food',
    }),
    'ar': _VisionReviewCopy({
      'review': 'راجع كل عنصر ظاهر',
      'cancel': 'إلغاء',
      'continue': 'مطابقة الأطعمة المحددة',
      'confidence': 'الثقة',
      'low': 'ثقة منخفضة',
      'alternatives': 'البدائل',
      'uncertainty': 'عدم اليقين',
      'amount': 'الكمية',
      'unit': 'الوحدة',
      'required': 'أدخل كمية ووحدة صحيحتين لكل عنصر محدد.',
      'match': 'اختر سجل الطعام الموثوق',
      'recognized': 'اقتراح الصورة',
      'use': 'استخدام هذا الطعام',
    }),
    'fr': _VisionReviewCopy({
      'review': 'Vérifier chaque élément visible',
      'cancel': 'Annuler',
      'continue': 'Associer les aliments sélectionnés',
      'confidence': 'Confiance',
      'low': 'Confiance faible',
      'alternatives': 'Alternatives',
      'uncertainty': 'Incertitude',
      'amount': 'Quantité',
      'unit': 'Unité',
      'required':
          'Saisissez une quantité et une unité valides pour chaque élément.',
      'match': 'Choisir la fiche alimentaire fiable',
      'recognized': 'Suggestion de l’image',
      'use': 'Utiliser cet aliment',
    }),
    'es': _VisionReviewCopy({
      'review': 'Revisar cada elemento visible',
      'cancel': 'Cancelar',
      'continue': 'Buscar alimentos seleccionados',
      'confidence': 'Confianza',
      'low': 'Confianza baja',
      'alternatives': 'Alternativas',
      'uncertainty': 'Incertidumbre',
      'amount': 'Cantidad',
      'unit': 'Unidad',
      'required': 'Introduce una cantidad y unidad válidas para cada elemento.',
      'match': 'Elegir el registro alimentario fiable',
      'recognized': 'Sugerencia de la imagen',
      'use': 'Usar este alimento',
    }),
    'tr': _VisionReviewCopy({
      'review': 'Görünen her öğeyi inceleyin',
      'cancel': 'İptal',
      'continue': 'Seçilen yiyecekleri eşleştir',
      'confidence': 'Güven',
      'low': 'Düşük güven',
      'alternatives': 'Alternatifler',
      'uncertainty': 'Belirsizlik',
      'amount': 'Miktar',
      'unit': 'Birim',
      'required': 'Seçilen her öğe için geçerli miktar ve birim girin.',
      'match': 'Güvenilir yiyecek kaydını seçin',
      'recognized': 'Görsel önerisi',
      'use': 'Bu yiyeceği kullan',
    }),
  };
}
