import 'package:flutter/material.dart';

import '../nutrition_plans/domain/nutrition_pathway.dart';
import 'profile_locale_copy.dart';

/// Shows the selected pathway's safety and save-before-apply context.
///
/// Kept separate from the editable plan form so the form stays focused on
/// editing targets while this card explains the selected pathway.
class PlanPathwayContextCard extends StatelessWidget {
  const PlanPathwayContextCard({required this.pathway, super.key});

  final NutritionPathway pathway;

  @override
  Widget build(BuildContext context) {
    final reviewRequired =
        pathway.safety == NutritionPathwaySafety.clinicianReview;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    profileLocaleText(
                      context,
                      pathway.enTitle,
                      pathway.arTitle,
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              profileLocaleText(
                context,
                pathway.enSubtitle,
                pathway.arSubtitle,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              reviewRequired
                  ? profileLocaleText(
                      context,
                      'Review draft only. Clinician review is required before activation.',
                      'مسودة للمراجعة فقط. يلزم مختص قبل التفعيل.',
                    )
                  : profileLocaleText(
                      context,
                      'Selecting a pathway does not change your targets. No values apply until you save the plan.',
                      'اختيار المسار لا يغيّر أهدافك. لا تُطبق أي قيم حتى تضغط حفظ الخطة.',
                    ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: reviewRequired
                    ? const Color(0xFF9A6700)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
