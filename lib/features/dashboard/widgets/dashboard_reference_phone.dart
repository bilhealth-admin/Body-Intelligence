part of 'premium_dashboard_benchmark.dart';

class _ReferenceDashboardPhone extends StatelessWidget {
  const _ReferenceDashboardPhone({
    required this.arabic,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.baseCaloriesGoal,
    required this.caloriesBurned,
    required this.netCalories,
    required this.remainingCalories,
    required this.burnedCaloriesApplied,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbohydratesConsumed,
    required this.carbohydratesGoal,
    required this.fatConsumed,
    required this.fatGoal,
    required this.fiberGoal,
    required this.sodiumGoal,
    required this.fiberEvidenceValue,
    required this.sodiumEvidenceValue,
    required this.nutrientDashboardPreset,
    required this.weightTrendValues,
    required this.stepTrendValues,
    required this.weightUnit,
    required this.loggingItems,
    required this.progressSection,
    required this.connectedHealth,
    required this.bodyTwinSummary,
    required this.actionTitle,
    required this.actionReason,
    required this.confidence,
    required this.onAction,
    required this.onExplain,
    required this.visibleSections,
    required this.premiumUnlocked,
  });

  final bool arabic;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int baseCaloriesGoal;
  final int caloriesBurned;
  final int netCalories;
  final int? remainingCalories;
  final bool burnedCaloriesApplied;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbohydratesConsumed;
  final int carbohydratesGoal;
  final int fatConsumed;
  final int fatGoal;
  final int? fiberGoal;
  final int? sodiumGoal;
  final double? fiberEvidenceValue;
  final double? sodiumEvidenceValue;
  final String nutrientDashboardPreset;
  final List<double> weightTrendValues;
  final List<double> stepTrendValues;
  final String weightUnit;
  final List<DashboardLoggingItem> loggingItems;
  final Widget? progressSection;
  final Widget? connectedHealth;
  final String bodyTwinSummary;
  final String actionTitle;
  final String actionReason;
  final String confidence;
  final VoidCallback? onAction;
  final VoidCallback? onExplain;
  final Set<String> visibleSections;
  final bool premiumUnlocked;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => _referenceText(context, en, ar);
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
        _ReferenceCaloriesCard(
          consumed: caloriesConsumed,
          goal: caloriesGoal,
          baseGoal: baseCaloriesGoal,
          burned: caloriesBurned,
          net: netCalories,
          remainingOverride: remainingCalories,
          burnedApplied: burnedCaloriesApplied,
          onEdit: () => context.go('/daily-log'),
        ),
      );
    }
    if (visibleSections.contains(DashboardSectionIds.macros)) {
      overviewCards.add(
        PremiumDashboardCardLock(
          key: const Key('dashboard-macros-premium-lock'),
          locked: !premiumUnlocked,
          title: tr('Nutrient goals', 'أهداف المغذيات'),
          detail: tr(
            'See protein, carbs, and fat progress at a glance.',
            'تابع تقدم البروتين والكربوهيدرات والدهون بلمحة.',
          ),
          borderRadius: 12,
          showLabel: false,
          onTap: () => context.push('/plans'),
          child: _ReferenceMacrosCard(
            onEdit: () => context.push('/settings/nutrition-goals'),
            macros: [
              _MacroProgress(
                label: tr('Carbs', 'الكربوهيدرات'),
                value: carbohydratesConsumed,
                goal: carbohydratesGoal,
                color: const Color(0xFF1475E8),
              ),
              _MacroProgress(
                label: tr('Fat', 'الدهون'),
                value: fatConsumed,
                goal: fatGoal,
                color: const Color(0xFF00A0D8),
              ),
              _MacroProgress(
                label: tr('Protein', 'البروتين'),
                value: proteinConsumed,
                goal: proteinGoal,
                color: const Color(0xFF0D5A9D),
              ),
            ],
          ),
        ),
      );
      overviewCards.add(
        PremiumDashboardCardLock(
          key: const Key('dashboard-heart-premium-lock'),
          locked: !premiumUnlocked,
          title: tr('Heart health', 'صحة القلب'),
          detail: tr(
            'Follow saturated fat, sodium, and fiber with clear rings.',
            'تابع الدهون المشبعة والصوديوم والألياف بدوائر واضحة.',
          ),
          borderRadius: 12,
          showLabel: false,
          onTap: () => context.push('/plans'),
          child: _CircularNutrientCard(
            key: const Key('dashboard-heart-circle-card'),
            title: tr('Heart Healthy', 'صحة القلب'),
            onTap: () => context.push('/analytics/nutrition?tab=nutrients'),
            rings: [
              _MacroProgress(
                label: tr('Saturated fat', 'الدهون المشبعة'),
                value: null,
                goal: null,
                color: const Color(0xFFF2B632),
              ),
              _MacroProgress(
                label: tr('Sodium', 'الصوديوم'),
                value: sodiumEvidenceValue?.round(),
                goal: sodiumGoal,
                unit: 'mg',
                color: const Color(0xFF7656C9),
              ),
              _MacroProgress(
                label: tr('Fiber', 'الألياف'),
                value: fiberEvidenceValue?.round(),
                goal: fiberGoal,
                color: const Color(0xFF38A66B),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      key: const Key('premium-dashboard-benchmark'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!premiumUnlocked &&
            (visibleSections.contains(DashboardSectionIds.macros) ||
                visibleSections.contains(
                  DashboardSectionIds.connectedHealth,
                ))) ...[
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: PremiumLabelBadge(key: Key('dashboard-premium-page-label')),
          ),
          const SizedBox(height: 12),
        ],
        if (visibleSections.contains(DashboardSectionIds.aiCoach)) ...[
          _ReferenceAiCoachCard(arabic: arabic),
          const SizedBox(height: 12),
        ],
        // Reuse the full Health Hub instead of a second phone-only imitation.
        if (visibleSections.contains(DashboardSectionIds.connectedHealth) &&
            connectedHealth != null) ...[
          connectedHealth!,
          const SizedBox(height: 12),
        ],
        if (overviewCards.isNotEmpty)
          _OverviewCardsCarousel(
            cards: overviewCards,
            initialPage: nutrientDashboardPreset == 'Heart healthy' ? 2 : 0,
          ),
        if (visibleSections.contains(DashboardSectionIds.macros)) ...[
          const SafeFreeAdAnchor(
            key: Key('dashboard-free-ad-slot'),
            surface: SafeFreeAdSurface.dashboard,
          ),
        ],
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
          _VisualInsightShortcut(
            key: const Key('dashboard-mobile-summary-card'),
            title: tr('Today Summary', 'ملخص اليوم'),
            subtitle: tr('Meals, water and progress', 'وجباتك وماؤك وتقدمك'),
            imageAsset: 'assets/images/dashboard/today_summary_v1.png',
            onTap: () => context.go('/daily-log'),
          ),
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
          _ReferenceDiscoverGrid(
            arabic: arabic,
            premiumUnlocked: premiumUnlocked,
          ),
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
  'consumed': {'fr': 'Consommé', 'es': 'Consumido', 'tr': 'Tüketilen'},
  'Carbs': {'fr': 'Glucides', 'es': 'Carbohidratos', 'tr': 'Karbonhidratlar'},
  'Sugar': {'fr': 'Sucre', 'es': 'Azúcar', 'tr': 'Şeker'},
  'Premium nutrition circles': {
    'fr': 'Cercles nutritionnels Premium',
    'es': 'Círculos nutricionales Premium',
    'tr': 'Premium besin halkaları',
  },
  'Nutrient goals': {
    'fr': 'Objectifs nutritionnels',
    'es': 'Objetivos de nutrientes',
    'tr': 'Besin hedefleri',
  },
  'See protein, carbs, and fat progress at a glance.': {
    'fr': 'Suivez en un coup d’œil les protéines, glucides et lipides.',
    'es':
        'Consulta de un vistazo el progreso de proteínas, carbohidratos y grasas.',
    'tr': 'Protein, karbonhidrat ve yağ ilerlemesini bir bakışta görün.',
  },
  'Premium heart health': {
    'fr': 'Santé cardiaque Premium',
    'es': 'Salud cardíaca Premium',
    'tr': 'Premium kalp sağlığı',
  },
  'Heart health': {
    'fr': 'Santé cardiaque',
    'es': 'Salud cardíaca',
    'tr': 'Kalp sağlığı',
  },
  'Follow saturated fat, sodium, and fiber with clear rings.': {
    'fr':
        'Suivez les graisses saturées, le sodium et les fibres avec des anneaux clairs.',
    'es': 'Sigue las grasas saturadas, el sodio y la fibra con anillos claros.',
    'tr': 'Doymuş yağ, sodyum ve lifi net halkalarla takip edin.',
  },
  'Premium nutrient goals': {
    'fr': 'Objectifs nutritionnels Premium',
    'es': 'Objetivos de nutrientes Premium',
    'tr': 'Premium besin hedefleri',
  },
  'Heart, sodium, fiber, and custom targets': {
    'fr': 'Objectifs personnalisés pour le cœur, le sodium et les fibres',
    'es': 'Objetivos personalizados de corazón, sodio y fibra',
    'tr': 'Kalp, sodyum, lif ve özel hedefler',
  },
  'Custom macro goals': {
    'fr': 'Objectifs macro personnalisés',
    'es': 'Objetivos de macros personalizados',
    'tr': 'Özel makro hedefleri',
  },
  'Carbs, sugar, fiber, and personal limits': {
    'fr': 'Glucides, sucre, fibres et limites personnelles',
    'es': 'Carbohidratos, azúcar, fibra y límites personales',
    'tr': 'Karbonhidrat, şeker, lif ve kişisel sınırlar',
  },
  'Steps, sleep, heart rate, and permitted signals': {
    'fr': 'Pas, sommeil, fréquence cardiaque et signaux autorisés',
    'es': 'Pasos, sueño, frecuencia cardíaca y señales permitidas',
    'tr': 'Adımlar, uyku, kalp atışı ve izinli sinyaller',
  },
  'Sleep and nutrition insights': {
    'fr': 'Analyses du sommeil et de la nutrition',
    'es': 'Información sobre sueño y nutrición',
    'tr': 'Uyku ve beslenme içgörüleri',
  },
  '1,500 recipes with nutrition': {
    'fr': '1 500 recettes avec nutrition',
    'es': '1.500 recetas con nutrición',
    'tr': 'Besin değerleriyle 1.500 tarif',
  },
  '200+ home workout videos\n100+ video-guided weight-training plans': {
    'fr':
        'Plus de 200 vidéos d’entraînement à domicile\nPlus de 100 programmes de musculation guidés en vidéo',
    'es':
        'Más de 200 vídeos de entrenamiento en casa\nMás de 100 planes de pesas guiados en vídeo',
    'tr':
        '200+ ev antrenmanı videosu\n100+ video rehberli ağırlık antrenmanı planı',
  },
  'Watch and health synchronization': {
    'fr': 'Synchronisation montre et santé',
    'es': 'Sincronización de reloj y salud',
    'tr': 'Saat ve sağlık eşitlemesi',
  },
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
  'Workout Videos': {
    'fr': 'Vidéos d’entraînement',
    'es': 'Vídeos de entrenamiento',
    'tr': 'Egzersiz videoları',
  },
  '300+ home workout videos': {
    'fr': 'Plus de 300 vidéos d’entraînement à domicile',
    'es': 'Más de 300 vídeos de entrenamiento en casa',
    'tr': '300’den fazla ev antrenmanı videosu',
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
