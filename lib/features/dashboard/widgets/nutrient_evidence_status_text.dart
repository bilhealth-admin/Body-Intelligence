import 'package:flutter/material.dart';

import '../../../engine/nutrient_evidence_engine.dart';

class NutrientEvidenceStatusText extends StatelessWidget {
  const NutrientEvidenceStatusText({
    super.key,
    required this.state,
    this.informational = false,
  });

  final NutrientEvidenceState state;
  final bool informational;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final text = switch (state) {
      NutrientEvidenceState.unavailable =>
        arabic
            ? 'القيمة غير متاحة في أدلة الطعام المسجلة.'
            : 'Value unavailable in the logged food evidence.',
      NutrientEvidenceState.partial =>
        informational
            ? arabic
                  ? 'دليل جزئي؛ لا يشمل الإجمالي الأطعمة ذات القيم غير المتاحة.'
                  : 'Partial evidence; foods with unavailable values are excluded.'
            : arabic
            ? 'دليل جزئي: الإجمالي يشمل الأطعمة ذات القيم المعروفة فقط.'
            : 'Partial evidence: total includes only foods with known values.',
      NutrientEvidenceState.complete => '',
    };
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}
