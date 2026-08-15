import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../domain/nutrition_pathway.dart';
import '../domain/nutrition_pathway_translations.dart';
import '../../nutrition/presentation/nutrition_copy.dart';

class NutritionPathwaysPage extends ConsumerWidget {
  const NutritionPathwaysPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final activeId = ref.watch(activeNutritionPathwayProvider).value;
    Future<void> select(NutritionPathway plan) async {
      await ref
          .read(preferencesRepositoryProvider)
          .set('activeNutritionPathway', plan.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      context.push('/plan?pathway=${Uri.encodeComponent(plan.id)}');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          nutritionText(context, 'Nutrition pathways', 'المسارات الغذائية'),
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              nutritionText(
                context,
                'Choose a pathway built around your goal.',
                'اختر مساراً يناسب هدفك وحالتك.',
              ),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              nutritionText(
                context,
                'Compare first, then create an editable draft. Your goals never change without approval.',
                'قارن أولاً، ثم أنشئ مسودة قابلة للمراجعة. لا تتغير أهدافك دون موافقتك.',
              ),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF667085),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 320,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) => _HeroCard(
                plan: nutritionPathways[index],
                languageCode: languageCode,
                selected: activeId == nutritionPathways[index].id,
                onSelect: select,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
            child: Text(
              nutritionText(context, 'All pathways', 'جميع المسارات'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...nutritionPathways.map(
            (plan) => _PlanRow(
              plan: plan,
              languageCode: languageCode,
              selected: activeId == plan.id,
              onSelect: select,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.plan,
    required this.languageCode,
    required this.selected,
    required this.onSelect,
  });
  final NutritionPathway plan;
  final String languageCode;
  final bool selected;
  final Future<void> Function(NutritionPathway) onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 265,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showPlan(context, plan, languageCode, onSelect),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              plan.asset,
              height: 175,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: Text(
                _planTitle(plan, languageCode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Chip(
                  avatar: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    nutritionTextForLanguage(
                      languageCode,
                      'Current pathway',
                      'المسار الحالي',
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                _planSubtitle(plan, languageCode),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF667085), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.languageCode,
    required this.selected,
    required this.onSelect,
  });
  final NutritionPathway plan;
  final String languageCode;
  final bool selected;
  final Future<void> Function(NutritionPathway) onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 78,
        onTap: () => _showPlan(context, plan, languageCode, onSelect),
        title: Text(
          _planTitle(plan, languageCode),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _planSubtitle(plan, languageCode),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
        ),
      ),
    ),
  );
}

void _showPlan(
  BuildContext context,
  NutritionPathway plan,
  String languageCode,
  Future<void> Function(NutritionPathway) onSelect,
) {
  final restricted = plan.safety != NutritionPathwaySafety.standard;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _planTitle(plan, languageCode),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _planSubtitle(plan, languageCode),
                style: const TextStyle(color: Color(0xFF667085), height: 1.45),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _planTags(
                  plan,
                  languageCode,
                ).map((tag) => Chip(label: Text(tag))).toList(),
              ),
              const SizedBox(height: 18),
              _PlanDetail(
                icon: Icons.route_outlined,
                title: nutritionTextForLanguage(
                  languageCode,
                  'Approach',
                  'المنهج',
                ),
                value: _planApproach(plan, languageCode).join('\n'),
              ),
              const SizedBox(height: 12),
              _PlanDetail(
                icon: Icons.monitor_heart_outlined,
                title: nutritionTextForLanguage(
                  languageCode,
                  'Monitoring',
                  'المتابعة',
                ),
                value: _planTracking(plan, languageCode).join('\n'),
              ),
              if (restricted) ...[
                const SizedBox(height: 14),
                Text(
                  nutritionTextForLanguage(
                    languageCode,
                    'This pathway requires clinician review before activation.',
                    'هذا المسار يتطلب مراجعة مختص قبل تفعيله.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF9A6700),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed:
                    plan.safety == NutritionPathwaySafety.medicalSupervision
                    ? null
                    : () => onSelect(plan),
                child: Text(
                  plan.safety == NutritionPathwaySafety.medicalSupervision
                      ? nutritionTextForLanguage(
                          languageCode,
                          'Medical supervision required',
                          'يتطلب إشرافًا طبيًا',
                        )
                      : nutritionTextForLanguage(
                          languageCode,
                          'Review in My Plan',
                          'مراجعة المسار ضمن خطتي',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _planTitle(NutritionPathway plan, String languageCode) =>
    switch (languageCode) {
      'ar' => plan.arTitle,
      'en' => plan.enTitle,
      _ => nutritionPathwayTranslations[languageCode]![plan.id]!.title,
    };
String _planSubtitle(NutritionPathway plan, String languageCode) =>
    switch (languageCode) {
      'ar' => plan.arSubtitle,
      'en' => plan.enSubtitle,
      _ => nutritionPathwayTranslations[languageCode]![plan.id]!.subtitle,
    };
List<String> _planTags(NutritionPathway plan, String code) => switch (code) {
  'ar' => plan.arTags,
  'en' => plan.enTags,
  _ => nutritionPathwayTranslations[code]![plan.id]!.tags,
};
List<String> _planApproach(NutritionPathway plan, String code) =>
    switch (code) {
      'ar' => plan.arApproach,
      'en' => plan.enApproach,
      _ => nutritionPathwayTranslations[code]![plan.id]!.approach,
    };
List<String> _planTracking(NutritionPathway plan, String code) =>
    switch (code) {
      'ar' => plan.arTracking,
      'en' => plan.enTracking,
      _ => nutritionPathwayTranslations[code]![plan.id]!.tracking,
    };

class _PlanDetail extends StatelessWidget {
  const _PlanDetail({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: const Color(0xFF087F8C)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 3),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF667085),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
