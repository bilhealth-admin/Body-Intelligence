part of 'premium_dashboard_benchmark.dart';

class _VisualInsightShortcut extends StatelessWidget {
  const _VisualInsightShortcut({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String imageAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 154,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(imageAsset, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xF20B1420), Color(0x190B1420)],
                      stops: [0, .82],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 14,
                  end: 12,
                  bottom: 13,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: .82),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceDiscoverGrid extends StatelessWidget {
  const _ReferenceDiscoverGrid({
    required this.arabic,
    required this.premiumUnlocked,
  });
  final bool arabic;
  final bool premiumUnlocked;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final tileHeight = 164 + (textScale - 1).clamp(0, 2) * 72;
    final items = <(String, IconData, String, String, String, bool)>[
      (
        'assets/images/nutrition_plans/carb_cycling_lifestyle_v1.webp',
        Icons.calendar_view_week_rounded,
        _referenceText(context, 'Diet', 'الدايت'),
        _referenceText(
          context,
          'Free weekly macro plans',
          'خطط مغذيات أسبوعية مجانية',
        ),
        '/nutrition-plans',
        false,
      ),
      (
        'assets/images/flagship/bil_sleep_insights_v2.png',
        Icons.bedtime_outlined,
        _referenceText(context, 'Sleep', 'النوم'),
        _referenceText(
          context,
          'Sleep and nutrition insights',
          'رؤى النوم والتغذية',
        ),
        '/wellness/sleep',
        true,
      ),
      (
        'assets/images/flagship/bil_meal_discovery_v1.png',
        Icons.menu_book_outlined,
        _referenceText(context, 'Recipes', 'الوصفات'),
        _referenceText(
          context,
          '1,500 recipes with nutrition',
          '1500 وصفة مع قيمها الغذائية',
        ),
        '/wellness/recipes',
        true,
      ),
      (
        'assets/images/flagship/bil_movement_v1.png',
        Icons.fitness_center_rounded,
        _referenceText(context, 'Workouts', 'التمارين'),
        _referenceText(
          context,
          'Explore 10 training categories with clear movement guidance and reusable routines.',
          'استكشف 10 فئات تدريبية مع إرشادات حركة واضحة وروتينات قابلة لإعادة الاستخدام.',
        ),
        '/wellness/workouts/routines',
        true,
      ),
      (
        'assets/images/connected_health/bil_medical_hub.png',
        Icons.sync_rounded,
        _referenceText(context, 'Sync up', 'المزامنة'),
        _referenceText(
          context,
          'Watch and health synchronization',
          'مزامنة الساعة والصحة',
        ),
        '/connected-health',
        false,
      ),
      if (AppEnvironment.communityConfigured) ...[
        (
          'assets/images/flagship/bil_body_intelligence_journey_v1.png',
          Icons.group_outlined,
          _referenceText(context, 'Friends', 'الأصدقاء'),
          _referenceText(context, 'Your support squad', 'دائرة دعمك'),
          '/community/connections',
          false,
        ),
        (
          'assets/images/dashboard/bio_intelligence_v1.png',
          Icons.forum_outlined,
          _referenceText(context, 'Community', 'المجتمع'),
          _referenceText(
            context,
            'Food & fitness inspiration',
            'إلهام غذائي ورياضي',
          ),
          '/community',
          false,
        ),
      ],
    ];
    final pairedItemCount = items.length.isOdd
        ? items.length - 1
        : items.length;
    return _ReferenceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _referenceText(context, 'Discover', 'اكتشف'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pairedItemCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: tileHeight.toDouble(),
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _DiscoverTile(
                imageAsset: item.$1,
                fallbackIcon: item.$2,
                label: item.$3,
                subtitle: item.$4,
                route: item.$5,
                premium: item.$6 && !premiumUnlocked,
              );
            },
          ),
          if (pairedItemCount != items.length) ...[
            const SizedBox(height: 10),
            SizedBox(
              key: const Key('dashboard-discover-balanced-final-tile'),
              height: tileHeight.toDouble(),
              child: _DiscoverTile(
                imageAsset: items.last.$1,
                fallbackIcon: items.last.$2,
                label: items.last.$3,
                subtitle: items.last.$4,
                route: items.last.$5,
                premium: items.last.$6 && !premiumUnlocked,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.imageAsset,
    required this.fallbackIcon,
    required this.label,
    required this.subtitle,
    required this.route,
    required this.premium,
  });

  final String imageAsset;
  final IconData fallbackIcon;
  final String label;
  final String subtitle;
  final String route;
  final bool premium;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label. $subtitle',
    child: Material(
      color: const Color(0xFF071B2A),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  fallbackIcon,
                  size: 44,
                  color: const Color(0xFF69E5F5),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x14020A12), Color(0xF2081624)],
                  stops: [0.18, 1],
                ),
              ),
            ),
            PositionedDirectional(
              start: 12,
              end: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: .86),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB3071928),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    premium
                        ? Icons.workspace_premium_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                    color: premium ? const Color(0xFFFFCB55) : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReferenceAiCoachCard extends StatelessWidget {
  const _ReferenceAiCoachCard({required this.arabic});

  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('dashboard-mobile-ai-coach-entry'),
        onTap: () => context.push('/intelligence-center'),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [Color(0xFF12394E), Color(0xFF071923)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30071822),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC8F3FF),
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/ai_coach/bil_male_smart_coach_v1.png',
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/images/flagship/bil_body_intelligence_journey_v1.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(.18, -.72),
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _referenceText(context, 'BIL AI Coach', 'مدرب BIL الذكي'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _referenceText(
                        context,
                        'Ask about your body, meals, and training',
                        'اسأل عن جسمك ووجباتك وتمارينك',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFC3D7E0),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFFC8F3FF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactIntelligenceCard extends StatelessWidget {
  const _CompactIntelligenceCard({
    required this.arabic,
    required this.title,
    required this.reason,
    required this.confidence,
    required this.onAction,
    required this.onExplain,
  });

  final bool arabic;
  final String title;
  final String reason;
  final String confidence;
  final VoidCallback? onAction;
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) => _ReferenceCard(
    child: InkWell(
      key: const Key('dashboard-compact-one-best-action'),
      onTap: onAction ?? onExplain,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.auto_awesome_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _referenceText(
                          context,
                          'One best action',
                          'أفضل إجراء',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(confidence),
                  ],
                ),
                const SizedBox(height: 5),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onExplain != null)
            IconButton(
              tooltip: _referenceText(context, 'Why this?', 'لماذا؟'),
              onPressed: onExplain,
              icon: const Icon(Icons.info_outline_rounded),
            )
          else
            const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}
