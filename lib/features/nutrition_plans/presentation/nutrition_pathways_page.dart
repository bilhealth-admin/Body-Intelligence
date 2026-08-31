import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../commerce/presentation/premium_label_badge.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/nutrition_pathway.dart';
import '../domain/nutrition_pathway_catalog.dart';
import '../domain/nutrition_pathway_localizer.dart';
import '../../nutrition/presentation/nutrition_copy.dart';

class NutritionPathwaysPage extends ConsumerWidget {
  const NutritionPathwaysPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeTag = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final activeId = ref.watch(activeNutritionPathwayProvider).value;
    void open(NutritionPathway plan) =>
        context.push('/nutrition-plans/${Uri.encodeComponent(plan.id)}');

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: PremiumLabelBadge(
                key: Key('nutrition-pathways-premium-page-label'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 334,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: nutritionPathways.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) => _HeroCard(
                plan: nutritionPathways[index],
                localeTag: localeTag,
                selected: activeId == nutritionPathways[index].id,
                onOpen: open,
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
              localeTag: localeTag,
              selected: activeId == plan.id,
              onOpen: open,
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
    required this.localeTag,
    required this.selected,
    required this.onOpen,
  });
  final NutritionPathway plan;
  final String localeTag;
  final bool selected;
  final ValueChanged<NutritionPathway> onOpen;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 265,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(plan),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.asset(
                  plan.asset,
                  height: 175,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                PositionedDirectional(
                  top: 12,
                  end: 12,
                  child: _PathwayAccessBadge(
                    plan: plan,
                    localeTag: localeTag,
                    surface: 'hero',
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: Text(
                nutritionPathwayTitle(plan, localeTag),
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
                      localeTag,
                      'Current pathway',
                      'المسار الحالي',
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                nutritionPathwaySubtitle(plan, localeTag),
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
    required this.localeTag,
    required this.selected,
    required this.onOpen,
  });
  final NutritionPathway plan;
  final String localeTag;
  final bool selected;
  final ValueChanged<NutritionPathway> onOpen;

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
        key: Key('nutrition-pathway-row-${plan.id}'),
        minTileHeight: 78,
        onTap: () => onOpen(plan),
        title: Text(
          nutritionPathwayTitle(plan, localeTag),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          nutritionPathwaySubtitle(plan, localeTag),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PathwayAccessBadge(
              plan: plan,
              localeTag: localeTag,
              surface: 'row',
              compact: true,
            ),
            const SizedBox(width: 7),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PathwayAccessBadge extends StatelessWidget {
  const _PathwayAccessBadge({
    required this.plan,
    required this.localeTag,
    required this.surface,
    this.compact = false,
  });

  final NutritionPathway plan;
  final String localeTag;
  final String surface;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final premium = plan.access == NutritionPathwayAccess.premium;
    final label = nutritionTextForLanguage(localeTag, 'Free', 'مجاني');
    return Container(
      key: Key('nutrition-pathway-access-$surface-${plan.id}'),
      constraints: BoxConstraints(maxWidth: compact ? 86 : 116),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: LinearGradient(
          colors: premium
              ? const [Color(0xFFFFF0B7), Color(0xFFE4AD35)]
              : const [Color(0xFFE2FAF5), Color(0xFFAFE8DC)],
        ),
        border: Border.all(
          color: premium ? const Color(0xFFD99B26) : const Color(0xFF58B9A7),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            premium ? Icons.circle : Icons.lock_open_rounded,
            size: compact ? 14 : 16,
            color: premium ? const Color(0xFF4C3300) : const Color(0xFF006D60),
          ),
          if (!premium) ...[
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF006D60),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
