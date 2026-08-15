part of 'premium_dashboard_benchmark.dart';

class _ReferenceDashboardPhone extends StatelessWidget {
  const _ReferenceDashboardPhone({
    required this.arabic,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbohydratesConsumed,
    required this.carbohydratesGoal,
    required this.fatConsumed,
    required this.fatGoal,
    required this.fiberConsumed,
    required this.fiberGoal,
    required this.sugarConsumed,
    required this.sodiumConsumed,
    required this.sodiumGoal,
    required this.carbohydratesEvidenceValue,
    required this.fiberEvidenceValue,
    required this.sugarEvidenceValue,
    required this.sodiumEvidenceValue,
    required this.nutrientDashboardPreset,
    required this.weightTrendValues,
    required this.stepTrendValues,
    required this.weightUnit,
    required this.loggingItems,
    required this.progressSection,
    required this.personalHealthAi,
    required this.bodyTwinSummary,
    required this.actionTitle,
    required this.actionReason,
    required this.confidence,
    required this.onAction,
    required this.onExplain,
    required this.visibleSections,
  });

  final bool arabic;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbohydratesConsumed;
  final int carbohydratesGoal;
  final int fatConsumed;
  final int fatGoal;
  final int fiberConsumed;
  final int? fiberGoal;
  final int sugarConsumed;
  final int sodiumConsumed;
  final int? sodiumGoal;
  final double? carbohydratesEvidenceValue;
  final double? fiberEvidenceValue;
  final double? sugarEvidenceValue;
  final double? sodiumEvidenceValue;
  final String nutrientDashboardPreset;
  final List<double> weightTrendValues;
  final List<double> stepTrendValues;
  final String weightUnit;
  final List<DashboardLoggingItem> loggingItems;
  final Widget? progressSection;
  final Widget? personalHealthAi;
  final String bodyTwinSummary;
  final String actionTitle;
  final String actionReason;
  final String confidence;
  final VoidCallback? onAction;
  final VoidCallback? onExplain;
  final Set<String> visibleSections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String tr(String en, String ar) => _referenceText(context, en, ar);
    final hasCalorieGoal = caloriesGoal > 0;
    final remaining = (caloriesGoal - caloriesConsumed).clamp(0, caloriesGoal);
    final progress = caloriesGoal <= 0
        ? 0.0
        : (caloriesConsumed / caloriesGoal).clamp(0.0, 1.0);
    final meals = loggingItems
        .where(
          (item) =>
              item.label.toLowerCase().contains('meal') ||
              item.label.contains('الوجب'),
        )
        .firstOrNull;
    final water = loggingItems
        .where(
          (item) =>
              item.label.toLowerCase().contains('water') ||
              item.label.contains('الماء'),
        )
        .firstOrNull;
    final weight = loggingItems
        .where(
          (item) =>
              item.label.toLowerCase().contains('weight') ||
              item.label.contains('الوزن'),
        )
        .firstOrNull;

    final overviewCards = <Widget>[];
    if (visibleSections.contains(DashboardSectionIds.calories)) {
      overviewCards.add(
        _ReferenceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    tr('Calories', 'السعرات'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/daily-log'),
                    child: Text(tr('Edit', 'تعديل')),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  SizedBox.square(
                    dimension: 126,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 118,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 9,
                            strokeCap: StrokeCap.round,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasCalorieGoal ? '$remaining' : '—',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              hasCalorieGoal
                                  ? tr('Remaining', 'المتبقي')
                                  : tr('Set a goal', 'حدد هدفًا'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        _ReferenceEquationRow(
                          label: tr('Goal', 'الهدف'),
                          value: caloriesGoal,
                          icon: Icons.flag_outlined,
                          honestEmpty: !hasCalorieGoal,
                        ),
                        _ReferenceEquationRow(
                          label: tr('Food', 'الطعام'),
                          value: caloriesConsumed,
                          icon: Icons.restaurant_outlined,
                        ),
                        _ReferenceEquationRow(
                          label: tr('Exercise', 'التمرين'),
                          value: 0,
                          icon: Icons.local_fire_department_outlined,
                          honestEmpty: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    }
    if (visibleSections.contains(DashboardSectionIds.macros)) {
      overviewCards.add(
        _ReferenceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Macros', 'المغذيات'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _MacroProgress(
                      label: tr('Protein', 'البروتين'),
                      value: proteinConsumed,
                      goal: proteinGoal,
                      color: const Color(0xFFF2B632),
                    ),
                  ),
                  Expanded(
                    child: _MacroProgress(
                      label: tr('Carbs', 'الكربوهيدرات'),
                      value: carbohydratesConsumed,
                      goal: carbohydratesGoal,
                      color: const Color(0xFF7656C9),
                    ),
                  ),
                  Expanded(
                    child: _MacroProgress(
                      label: tr('Fat', 'الدهون'),
                      value: fatConsumed,
                      goal: fatGoal,
                      color: const Color(0xFF38A66B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      );
      overviewCards.add(
        _NutrientPlanCard(
          title: tr('Heart Healthy', 'صحة القلب'),
          accent: const Color(0xFF38A66B),
          rows: [
            _NutrientPlanRow(
              label: tr('Saturated fat', 'الدهون المشبعة'),
              value: null,
              goal: null,
            ),
            _NutrientPlanRow(
              label: tr('Sodium', 'الصوديوم'),
              value: sodiumEvidenceValue?.round(),
              goal: sodiumGoal,
              unit: 'mg',
            ),
            _NutrientPlanRow(
              label: tr('Fiber', 'الألياف'),
              value: fiberEvidenceValue?.round(),
              goal: fiberGoal,
              minimumGoal: true,
            ),
          ],
          onTap: () => context.push('/analytics/nutrition?tab=nutrients'),
        ),
      );
      overviewCards.add(
        _NutrientPlanCard(
          title: tr('Carb Conscious', 'واعٍ بالكربوهيدرات'),
          accent: const Color(0xFF2878D0),
          rows: [
            _NutrientPlanRow(
              label: tr('Carbs', 'الكربوهيدرات'),
              value: carbohydratesEvidenceValue?.round(),
              goal: carbohydratesGoal,
            ),
            _NutrientPlanRow(
              label: tr('Sugar', 'السكر'),
              value: sugarEvidenceValue?.round(),
              goal: null,
            ),
            _NutrientPlanRow(
              label: tr('Fiber', 'الألياف'),
              value: fiberEvidenceValue?.round(),
              goal: fiberGoal,
              minimumGoal: true,
            ),
          ],
          onTap: () => context.push('/analytics/nutrition?tab=nutrients'),
        ),
      );
    }

    return Column(
      key: const Key('premium-dashboard-benchmark'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (visibleSections.contains(DashboardSectionIds.aiCoach)) ...[
          _ReferenceAiCoachCard(arabic: arabic),
          const SizedBox(height: 12),
        ],
        if (overviewCards.isNotEmpty)
          _OverviewCardsCarousel(
            cards: overviewCards,
            initialPage: switch (nutrientDashboardPreset) {
              'Heart healthy' => 2,
              'Low carb' => 3,
              _ => 0,
            },
          ),
        if (visibleSections.contains(DashboardSectionIds.calories)) ...[
          const SizedBox(height: 8),
          if (hasCalorieGoal)
            _DailyGoalStrip(
              arabic: arabic,
              consumed: caloriesConsumed,
              goal: caloriesGoal,
              onTap: () => context.go('/daily-log'),
            )
          else
            _MissingDailyGoalCard(
              onTap: () => context.push('/profile-settings'),
            ),
        ],
        const SizedBox(height: 12),
        Visibility(
          visible: visibleSections.contains(DashboardSectionIds.activity),
          child: Row(
            children: [
              Expanded(
                child: _ReferenceStatusCard(
                  icon: Icons.directions_walk_rounded,
                  title: tr('Steps', 'الخطوات'),
                  value: '—',
                  detail: tr('Connect a source', 'اربط مصدرًا'),
                  onTap: () => context.push('/connected-health'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReferenceStatusCard(
                  icon: Icons.fitness_center_rounded,
                  title: tr('Exercise', 'التمرين'),
                  value: '—',
                  detail: tr('No activity logged', 'لا نشاط مسجل'),
                  onTap: () => context.push('/wellness/workouts'),
                ),
              ),
            ],
          ),
        ),
        if (visibleSections.contains(DashboardSectionIds.activity)) ...[
          const SizedBox(height: 12),
          _ReferenceTrendRail(
            weightValues: weightTrendValues,
            stepValues: stepTrendValues,
            weightUnit: weightUnit,
          ),
        ],
        if (visibleSections.contains(DashboardSectionIds.quickLog)) ...[
          const SizedBox(height: 12),
          _ReferenceCard(
            child: Row(
              children: [
                Expanded(
                  child: _LogShortcut(
                    icon: Icons.restaurant_rounded,
                    label: tr('Food', 'الطعام'),
                    recorded: meals?.recorded ?? false,
                    onTap: () => context.go('/daily-log?focus=meal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LogShortcut(
                    icon: Icons.water_drop_rounded,
                    label: tr('Water', 'الماء'),
                    recorded: water?.recorded ?? false,
                    onTap: () => context.go('/daily-log?action=water'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LogShortcut(
                    icon: Icons.monitor_weight_rounded,
                    label: tr('Weight', 'الوزن'),
                    recorded: weight?.recorded ?? false,
                    onTap: () => context.push('/daily-check-in'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (visibleSections.contains(DashboardSectionIds.bestAction))
          _CompactIntelligenceCard(
            arabic: arabic,
            title: actionTitle,
            reason: actionReason,
            confidence: confidence,
            onAction: onAction,
            onExplain: onExplain,
          ),
        if (visibleSections.contains(DashboardSectionIds.progress) &&
            progressSection != null) ...[
          const SizedBox(height: 12),
          Row(
            key: const Key('dashboard-summary-and-bio-rail'),
            children: [
              Expanded(
                child: _VisualInsightShortcut(
                  key: const Key('dashboard-mobile-summary-card'),
                  title: tr('Today Summary', 'ملخص اليوم'),
                  subtitle: tr(
                    'Meals, water and progress',
                    'وجباتك وماؤك وتقدمك',
                  ),
                  imageAsset: 'assets/images/dashboard/today_summary_v1.png',
                  onTap: () => context.go('/daily-log'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VisualInsightShortcut(
                  key: const Key('dashboard-mobile-bio-intelligence-card'),
                  title: tr('Bio Intelligence', 'الذكاء الحيوي'),
                  subtitle: personalHealthAi == null
                      ? tr('Build your body signal', 'ابنِ إشارتك الحيوية')
                      : tr('Understand your signals', 'افهم إشارات جسمك'),
                  imageAsset: 'assets/images/dashboard/bio_intelligence_v1.png',
                  onTap: () => context.go('/analytics'),
                ),
              ),
            ],
          ),
        ],
        if (visibleSections.contains(DashboardSectionIds.connectedHealth)) ...[
          const SizedBox(height: 12),
          _CompactHealthCard(arabic: arabic),
        ],
        const SizedBox(height: 12),
        if (visibleSections.contains(DashboardSectionIds.bodyTwin))
          _BodyTwinImageCard(
            key: const Key('dashboard-mobile-body-twin-snapshot'),
            title: tr('Body Twin', 'التوأم الجسدي'),
            summary: bodyTwinSummary,
            onTap: () => context.go('/analytics'),
          ),
        if (visibleSections.contains(DashboardSectionIds.discover)) ...[
          const SizedBox(height: 12),
          _NutritionHeroStrip(arabic: arabic),
          const SizedBox(height: 12),
          _ReferenceDiscoverGrid(arabic: arabic),
        ],
      ],
    );
  }
}

String _referenceText(BuildContext context, String en, String ar) {
  final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  if (locale == 'ar') return ar;
  return _referencePhoneCopy[en]?[locale] ?? dashboardFiveLocaleText(en, ar);
}

const _referencePhoneCopy = <String, Map<String, String>>{
  'Calories': {'fr': 'Calories', 'es': 'Calorías', 'tr': 'Kalori'},
  'Edit': {'fr': 'Modifier', 'es': 'Editar', 'tr': 'Düzenle'},
  'Remaining': {'fr': 'Restant', 'es': 'Restante', 'tr': 'Kalan'},
  'Goal': {'fr': 'Objectif', 'es': 'Objetivo', 'tr': 'Hedef'},
  'Food': {'fr': 'Alimentation', 'es': 'Comida', 'tr': 'Yemek'},
  'Exercise': {'fr': 'Exercice', 'es': 'Ejercicio', 'tr': 'Egzersiz'},
  'Macros': {'fr': 'Macros', 'es': 'Macros', 'tr': 'Makrolar'},
  'Heart Healthy': {
    'fr': 'Santé du cœur',
    'es': 'Salud del corazón',
    'tr': 'Kalp sağlığı',
  },
  'Carb Conscious': {
    'fr': 'Maîtrise des glucides',
    'es': 'Control de carbohidratos',
    'tr': 'Karbonhidrat kontrollü',
  },
  'Saturated fat': {
    'fr': 'Graisses saturées',
    'es': 'Grasa saturada',
    'tr': 'Doymuş yağ',
  },
  'Protein': {'fr': 'Protéines', 'es': 'Proteína', 'tr': 'Protein'},
  'Fat': {'fr': 'Lipides', 'es': 'Grasa', 'tr': 'Yağ'},
  'Steps': {'fr': 'Pas', 'es': 'Pasos', 'tr': 'Adım'},
  'Connect a source': {
    'fr': 'Connecter une source',
    'es': 'Conectar una fuente',
    'tr': 'Bir kaynak bağla',
  },
  'No activity logged': {
    'fr': 'Aucune activité enregistrée',
    'es': 'No hay actividad registrada',
    'tr': 'Kayıtlı etkinlik yok',
  },
  'Water': {'fr': 'Eau', 'es': 'Agua', 'tr': 'Su'},
  'Weight': {'fr': 'Poids', 'es': 'Peso', 'tr': 'Kilo'},
  'Today Summary': {
    'fr': 'Résumé du jour',
    'es': 'Resumen de hoy',
    'tr': 'Bugünün özeti',
  },
  'Bio Intelligence': {
    'fr': 'Intelligence biologique',
    'es': 'Inteligencia biológica',
    'tr': 'Biyo zekâ',
  },
  'Build your body signal': {
    'fr': 'Construisez votre signal corporel',
    'es': 'Crea tu señal corporal',
    'tr': 'Beden sinyalinizi oluşturun',
  },
  'Understand your signals': {
    'fr': 'Comprenez vos signaux',
    'es': 'Comprende tus señales',
    'tr': 'Sinyallerinizi anlayın',
  },
  'Body Twin': {
    'fr': 'Jumeau corporel',
    'es': 'Gemelo corporal',
    'tr': 'Beden ikizi',
  },
  'left': {'fr': 'restantes', 'es': 'restantes', 'tr': 'kaldı'},
  'Sleep': {'fr': 'Sommeil', 'es': 'Sueño', 'tr': 'Uyku'},
  'Eat right, sleep tight': {
    'fr': 'Bien manger, mieux dormir',
    'es': 'Come bien, duerme mejor',
    'tr': 'İyi beslen, iyi uyu',
  },
  'Recipes': {'fr': 'Recettes', 'es': 'Recetas', 'tr': 'Tarifler'},
  'Cook, eat, log, repeat': {
    'fr': 'Cuisinez, mangez, notez, recommencez',
    'es': 'Cocina, come, registra y repite',
    'tr': 'Pişir, ye, kaydet, tekrarla',
  },
  'Workouts': {
    'fr': 'Entraînements',
    'es': 'Entrenamientos',
    'tr': 'Antrenmanlar',
  },
  'Moving is self-care': {
    'fr': 'Bouger, c’est prendre soin de soi',
    'es': 'Moverse es cuidarse',
    'tr': 'Hareket etmek öz bakımdır',
  },
  'Sync up': {'fr': 'Synchroniser', 'es': 'Sincronizar', 'tr': 'Senkronize et'},
  'Link apps & devices': {
    'fr': 'Connectez vos applications et appareils',
    'es': 'Conecta aplicaciones y dispositivos',
    'tr': 'Uygulamaları ve cihazları bağla',
  },
  'Friends': {'fr': 'Amis', 'es': 'Amigos', 'tr': 'Arkadaşlar'},
  'Your support squad': {
    'fr': 'Votre cercle de soutien',
    'es': 'Tu grupo de apoyo',
    'tr': 'Destek ekibiniz',
  },
  'Community': {'fr': 'Communauté', 'es': 'Comunidad', 'tr': 'Topluluk'},
  'Food & fitness inspiration': {
    'fr': 'Inspiration nutrition et forme',
    'es': 'Inspiración de nutrición y ejercicio',
    'tr': 'Beslenme ve fitness ilhamı',
  },
  'Discover': {'fr': 'Découvrir', 'es': 'Descubrir', 'tr': 'Keşfet'},
  'BIL AI Coach': {
    'fr': 'Coach IA BIL',
    'es': 'Coach IA de BIL',
    'tr': 'BIL Yapay Zekâ Koçu',
  },
  'Ask about your body, meals, and training': {
    'fr': 'Posez vos questions sur votre corps, vos repas et vos entraînements',
    'es': 'Pregunta sobre tu cuerpo, comidas y entrenamiento',
    'tr': 'Vücudunuz, öğünleriniz ve antrenmanınız hakkında sorun',
  },
  'One best action': {
    'fr': 'Meilleure action',
    'es': 'Mejor acción',
    'tr': 'En iyi eylem',
  },
  'Why this?': {'fr': 'Pourquoi ?', 'es': '¿Por qué?', 'tr': 'Neden?'},
  'Health & devices': {
    'fr': 'Santé et appareils',
    'es': 'Salud y dispositivos',
    'tr': 'Sağlık ve cihazlar',
  },
  'Connect a trusted source to show real measurements.': {
    'fr': 'Connectez une source fiable pour afficher des mesures réelles.',
    'es': 'Conecta una fuente fiable para mostrar mediciones reales.',
    'tr': 'Gerçek ölçümleri göstermek için güvenilir bir kaynak bağlayın.',
  },
};

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
  const _ReferenceDiscoverGrid({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final tileHeight = 140 + (textScale - 1).clamp(0, 2) * 64;
    final items = <(IconData, String, String, String)>[
      (
        Icons.bedtime_outlined,
        _referenceText(context, 'Sleep', 'النوم'),
        _referenceText(
          context,
          'Eat right, sleep tight',
          'غذاء أفضل، نوم أفضل',
        ),
        '/wellness/sleep',
      ),
      (
        Icons.menu_book_outlined,
        _referenceText(context, 'Recipes', 'الوصفات'),
        _referenceText(context, 'Cook, eat, log, repeat', 'اطبخ وسجّل وكرّر'),
        '/wellness/recipes',
      ),
      (
        Icons.fitness_center_rounded,
        _referenceText(context, 'Workouts', 'التمارين'),
        _referenceText(context, 'Moving is self-care', 'الحركة عناية بالنفس'),
        '/wellness/workouts',
      ),
      (
        Icons.sync_rounded,
        _referenceText(context, 'Sync up', 'المزامنة'),
        _referenceText(
          context,
          'Link apps & devices',
          'اربط التطبيقات والأجهزة',
        ),
        '/connected-health',
      ),
      if (AppEnvironment.communityConfigured) ...[
        (
          Icons.group_outlined,
          _referenceText(context, 'Friends', 'الأصدقاء'),
          _referenceText(context, 'Your support squad', 'دائرة دعمك'),
          '/community/connections',
        ),
        (
          Icons.forum_outlined,
          _referenceText(context, 'Community', 'المجتمع'),
          _referenceText(
            context,
            'Food & fitness inspiration',
            'إلهام غذائي ورياضي',
          ),
          '/community',
        ),
      ],
    ];
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
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: tileHeight.toDouble(),
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _DiscoverTile(
                icon: item.$1,
                label: item.$2,
                subtitle: item.$3,
                route: item.$4,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _NutritionHeroStrip extends StatelessWidget {
  const _NutritionHeroStrip({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = 118 + (textScale - 1).clamp(0, 2) * 70;
    return Material(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink.image(
        image: const AssetImage(
          'assets/images/brand/generated/bil_dashboard_nutrition_hero_v1.png',
        ),
        height: height.toDouble(),
        fit: BoxFit.cover,
        child: InkWell(
          onTap: () => context.push('/wellness/recipes'),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xE8061525), Color(0x20061525)],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          arabic
                              ? 'وجبات تناسب يومك'
                              : 'Meals that fit your day',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          arabic
                              ? 'وصفات حقيقية مع المصدر والقيم الغذائية.'
                              : 'Real recipes with sources and nutrition.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFE7F3FA)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1D4A60),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFC8F3FF),
                  size: 25,
                ),
              ),
              const SizedBox(width: 15),
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
                    const SizedBox(height: 5),
                    Text(
                      _referenceText(
                        context,
                        'Ask about your body, meals, and training',
                        'اسأل عن جسمك ووجباتك وتمارينك',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFC3D7E0),
                        height: 1.35,
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

class _CompactHealthCard extends StatelessWidget {
  const _CompactHealthCard({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) => _ReferenceCard(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.watch_rounded),
      ),
      title: Text(
        _referenceText(context, 'Health & devices', 'الصحة والأجهزة'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        _referenceText(
          context,
          'Connect a trusted source to show real measurements.',
          'اربط مصدرًا موثوقًا لعرض القياسات الفعلية.',
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/connected-health'),
    ),
  );
}
