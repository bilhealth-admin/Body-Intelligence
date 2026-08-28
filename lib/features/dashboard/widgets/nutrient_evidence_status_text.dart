import 'package:flutter/material.dart';

import '../../../engine/nutrient_evidence_engine.dart';
import '../dashboard_five_locale_copy.dart';

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
    final locale = Localizations.localeOf(context);
    final text = switch (state) {
      NutrientEvidenceState.unavailable => dashboardFiveLocaleText(
        'Value unavailable in the logged food evidence.',
        'القيمة غير متاحة في أدلة الطعام المسجلة.',
        locale: locale,
      ),
      NutrientEvidenceState.partial =>
        informational
            ? dashboardFiveLocaleText(
                'Partial evidence; foods with unavailable values are excluded.',
                'دليل جزئي؛ لا يشمل الإجمالي الأطعمة ذات القيم غير المتاحة.',
                locale: locale,
              )
            : dashboardFiveLocaleText(
                'Partial evidence: total includes only foods with known values.',
                'دليل جزئي: الإجمالي يشمل الأطعمة ذات القيم المعروفة فقط.',
                locale: locale,
              ),
      NutrientEvidenceState.complete => '',
    };
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}
