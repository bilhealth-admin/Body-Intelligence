import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../providers/dashboard_preferences_provider.dart';

@visibleForTesting
String dashboardPremiumFeatureDestination(bool paid, String featureRoute) =>
    paid ? featureRoute : '/plans';

class DashboardPreferencesPage extends ConsumerStatefulWidget {
  const DashboardPreferencesPage({super.key});

  @override
  ConsumerState<DashboardPreferencesPage> createState() =>
      _DashboardPreferencesPageState();
}

class _DashboardPreferencesPageState
    extends ConsumerState<DashboardPreferencesPage> {
  bool _saving = false;
  int _streamRevision = 0;

  Future<bool> _guardedSave(Future<void> Function() operation) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await operation();
      return true;
    } catch (_) {
      if (mounted) _showSaveFailure(context);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _copy(
    BuildContext context, {
    required String en,
    required String ar,
    required String fr,
    required String es,
    required String tr,
  }) {
    final locale = Localizations.localeOf(context);
    final resolved = RuntimeCopy.resolve(
      en,
      BilLocalePolicy.canonicalTag(locale),
    );
    if (resolved != null) return resolved;
    return switch (locale.languageCode) {
      'ar' => ar,
      'fr' => fr,
      'es' => es,
      'tr' => tr,
      _ => en,
    };
  }

  String _sectionCopy(BuildContext context, String english, String arabic) {
    const translations = <String, (String, String, String)>{
      'AI Coach': ('Coach IA', 'Coach de IA', 'Yapay zekâ koçu'),
      'A private conversation with your health intelligence': (
        'Une conversation privée avec votre intelligence santé',
        'Una conversación privada con tu inteligencia de salud',
        'Sağlık zekânızla özel bir görüşme',
      ),
      'Calories': ('Calories', 'Calorías', 'Kalori'),
      'Goal, food, exercise, and remaining energy': (
        'Objectif, alimentation, exercice et énergie restante',
        'Objetivo, comida, ejercicio y energía restante',
        'Hedef, yemek, egzersiz ve kalan enerji',
      ),
      'Macros': ('Macronutriments', 'Macronutrientes', 'Makrolar'),
      'Protein and fat progress': (
        'Progression des protéines et lipides',
        'Progreso de proteínas y grasas',
        'Protein ve yağ ilerlemesi',
      ),
      'Activity': ('Activité', 'Actividad', 'Aktivite'),
      'Steps and exercise status': (
        'Pas et état des exercices',
        'Pasos y estado del ejercicio',
        'Adımlar ve egzersiz durumu',
      ),
      'Quick log': ('Saisie rapide', 'Registro rápido', 'Hızlı kayıt'),
      'Food, water, and weight shortcuts': (
        'Raccourcis alimentation, eau et poids',
        'Accesos de comida, agua y peso',
        'Yemek, su ve kilo kısayolları',
      ),
      'Discover': ('Découvrir', 'Descubrir', 'Keşfet'),
      'Sleep, recipes, workouts, and community': (
        'Sommeil, recettes, entraînements et communauté',
        'Sueño, recetas, entrenamientos y comunidad',
        'Uyku, tarifler, egzersizler ve topluluk',
      ),
      'Personal intelligence': (
        'Intelligence personnelle',
        'Inteligencia personal',
        'Kişisel zekâ',
      ),
      'One Best Action, evidence, and Body Twin': (
        'Meilleure action, preuves et jumeau corporel',
        'Mejor acción, evidencia y gemelo corporal',
        'En iyi eylem, kanıt ve beden ikizi',
      ),
      'Daily intelligence': (
        'Intelligence quotidienne',
        'Inteligencia diaria',
        'Günlük zekâ',
      ),
      'Explanations, confidence, and evidence': (
        'Explications, confiance et preuves',
        'Explicaciones, confianza y evidencia',
        'Açıklamalar, güven ve kanıt',
      ),
      'Progress': ('Progrès', 'Progreso', 'İlerleme'),
      'Measured trends from your saved records': (
        'Tendances mesurées depuis vos données',
        'Tendencias medidas de tus registros',
        'Kayıtlarınızdan ölçülen eğilimler',
      ),
      'Connected health': (
        'Santé connectée',
        'Salud conectada',
        'Bağlı sağlık',
      ),
      'Health sources and synchronization status': (
        'Sources de santé et état de synchronisation',
        'Fuentes de salud y estado de sincronización',
        'Sağlık kaynakları ve eşitleme durumu',
      ),
      'Body Twin': ('Jumeau corporel', 'Gemelo corporal', 'Beden ikizi'),
      'Your explainable body model and its evidence': (
        'Votre modèle corporel explicable et ses preuves',
        'Tu modelo corporal explicable y su evidencia',
        'Açıklanabilir beden modeliniz ve kanıtları',
      ),
    };
    final translated = translations[english];
    final locale = Localizations.localeOf(context);
    final resolved = RuntimeCopy.resolve(
      english,
      BilLocalePolicy.canonicalTag(locale),
    );
    if (resolved != null) return resolved;
    return switch (locale.languageCode) {
      'ar' => arabic,
      'fr' => translated?.$1 ?? english,
      'es' => translated?.$2 ?? english,
      'tr' => translated?.$3 ?? english,
      _ => english,
    };
  }

  Future<void> _applyPreset(
    BuildContext context,
    WidgetRef ref,
    String preset,
    Set<String> visible,
  ) async {
    await _guardedSave(() async {
      final repository = ref.read(preferencesRepositoryProvider);
      await repository.setMany({
        'dashboard.preset': preset,
        for (final section in DashboardSectionIds.all)
          'dashboard.section.$section': '${visible.contains(section)}',
      });
    });
  }

  Future<void> _setSectionVisibility(
    BuildContext context,
    WidgetRef ref,
    String section,
    bool visible,
  ) async {
    await _guardedSave(() async {
      await ref.read(preferencesRepositoryProvider).setMany({
        'dashboard.section.$section': '$visible',
        'dashboard.preset': 'custom',
      });
    });
  }

  Future<void> _restoreDefaults(BuildContext context, WidgetRef ref) async {
    await _guardedSave(() async {
      final repository = ref.read(preferencesRepositoryProvider);
      await repository.removeMany([
        'dashboard.preset',
        for (final section in DashboardSectionIds.all)
          'dashboard.section.$section',
        'dashboard.nutrientGoalCards',
      ]);
    });
  }

  void _showSaveFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _sectionCopy(
            context,
            'Today preferences could not be saved. Please try again.',
            'تعذّر حفظ تفضيلات شاشة اليوم. حاول مرة أخرى.',
          ),
        ),
      ),
    );
  }

  Future<void> _chooseNutrientCards(
    BuildContext context,
    WidgetRef ref,
    Set<String> current,
  ) async {
    final repository = ref.read(preferencesRepositoryProvider);
    final selected = current.toSet();
    var savingCards = false;
    final labels = <String, (String, String, String, String, String)>{
      DashboardNutrientGoalIds.protein: (
        'Protein',
        'البروتين',
        'Protéines',
        'Proteína',
        'Protein',
      ),
      DashboardNutrientGoalIds.carbohydrates: (
        'Carbohydrates',
        'الكربوهيدرات',
        'Glucides',
        'Carbohidratos',
        'Karbonhidratlar',
      ),
      DashboardNutrientGoalIds.fat: (
        'Fat',
        'الدهون',
        'Lipides',
        'Grasas',
        'Yağ',
      ),
      DashboardNutrientGoalIds.fiber: (
        'Fiber',
        'الألياف',
        'Fibres',
        'Fibra',
        'Lif',
      ),
      DashboardNutrientGoalIds.sodium: (
        'Sodium',
        'الصوديوم',
        'Sodium',
        'Sodio',
        'Sodyum',
      ),
      DashboardNutrientGoalIds.potassium: (
        'Potassium',
        'البوتاسيوم',
        'Potassium',
        'Potasio',
        'Potasyum',
      ),
    };
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => PopScope(
          canPop: !savingCards,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _copy(
                      context,
                      en: 'Add nutrient goal cards',
                      ar: 'إضافة بطاقات أهداف المغذيات',
                      fr: 'Ajouter des cartes de nutriments',
                      es: 'Añadir tarjetas de nutrientes',
                      tr: 'Besin hedefi kartları ekle',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final id in DashboardNutrientGoalIds.all)
                          CheckboxListTile(
                            key: Key('dashboard-nutrient-goal-$id'),
                            value: selected.contains(id),
                            title: Text(
                              _copy(
                                context,
                                en: labels[id]!.$1,
                                ar: labels[id]!.$2,
                                fr: labels[id]!.$3,
                                es: labels[id]!.$4,
                                tr: labels[id]!.$5,
                              ),
                            ),
                            onChanged: savingCards
                                ? null
                                : (enabled) => setSheetState(() {
                                    enabled == true
                                        ? selected.add(id)
                                        : selected.remove(id);
                                  }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: savingCards
                          ? null
                          : () async {
                              setSheetState(() => savingCards = true);
                              try {
                                await repository.setMany({
                                  'dashboard.nutrientGoalCards':
                                      DashboardNutrientGoalIds.all
                                          .where(selected.contains)
                                          .join(','),
                                  'dashboard.preset': 'custom',
                                });
                                if (sheetContext.mounted) {
                                  setSheetState(() => savingCards = false);
                                  final route = ModalRoute.of(sheetContext);
                                  if (route != null) {
                                    Navigator.of(
                                      sheetContext,
                                    ).removeRoute(route);
                                  }
                                }
                              } catch (_) {
                                if (sheetContext.mounted) {
                                  setSheetState(() => savingCards = false);
                                  _showSaveFailure(sheetContext);
                                }
                              }
                            },
                      child: Text(
                        _copy(
                          context,
                          en: 'Save cards',
                          ar: 'حفظ البطاقات',
                          fr: 'Enregistrer',
                          es: 'Guardar',
                          tr: 'Kartları kaydet',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLockedNutrientPreview(BuildContext context) async {
    final upgrade = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _sectionCopy(
                sheetContext,
                'Add nutrient goal cards',
                'إضافة بطاقات أهداف المغذيات',
              ),
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _sectionCopy(
                sheetContext,
                'Choose the nutrients you want to track as dashboard cards. This is an independent Premium feature.',
                'اختر المغذيات التي تريد متابعتها كبطاقات في الداشبورد. هذه ميزة Premium مستقلة.',
              ),
            ),
            const SizedBox(height: 12),
            for (final label in const [
              'Protein',
              'Carbohydrates',
              'Fat',
              'Fiber',
              'Sodium',
              'Potassium',
            ])
              ListTile(
                dense: true,
                leading: const Icon(Icons.lock_outline_rounded),
                title: Text(context.strings.text(label)),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheetContext, true),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(
                _sectionCopy(
                  sheetContext,
                  'View Premium plans',
                  'عرض خطط Premium',
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (upgrade == true && context.mounted) context.push('/plans');
  }

  @override
  Widget build(BuildContext context) {
    final verifiedSubscription = ref.watch(verifiedSubscriptionStateProvider);
    final entitlementResolved = verifiedSubscription.hasValue;
    final paid =
        verifiedSubscription.value?.grants(
          CommerceEntitlement.advancedIntelligence,
        ) ??
        false;
    final presets =
        <
          ({
            String id,
            IconData icon,
            String titleEn,
            String titleAr,
            String titleFr,
            String titleEs,
            String titleTr,
            String bodyEn,
            String bodyAr,
            String bodyFr,
            String bodyEs,
            String bodyTr,
            Set<String> sections,
            bool premium,
          })
        >[
          (
            id: 'calorie',
            icon: Icons.local_fire_department_outlined,
            titleEn: 'Calorie focused',
            titleAr: 'تركيز السعرات',
            titleFr: 'Centré sur les calories',
            titleEs: 'Enfoque en calorías',
            titleTr: 'Kalori odaklı',
            bodyEn: 'Calories consumed, activity, and remaining energy.',
            bodyAr: 'السعرات المستهلكة والنشاط والطاقة المتبقية.',
            bodyFr: 'Calories consommées, activité et énergie restante.',
            bodyEs: 'Calorías consumidas, actividad y energía restante.',
            bodyTr: 'Tüketilen kalori, aktivite ve kalan enerji.',
            sections: {
              DashboardSectionIds.calories,
              DashboardSectionIds.activity,
              DashboardSectionIds.quickLog,
              DashboardSectionIds.aiCoach,
              DashboardSectionIds.discover,
            },
            premium: false,
          ),
          (
            id: 'macros',
            icon: Icons.donut_large_rounded,
            titleEn: 'Macronutrients focused',
            titleAr: 'تركيز المغذيات الكبرى',
            titleFr: 'Centré sur les macronutriments',
            titleEs: 'Enfoque en macronutrientes',
            titleTr: 'Makro besin odaklı',
            bodyEn: 'Carbs, protein, fat, and remaining calories.',
            bodyAr: 'الكربوهيدرات والبروتين والدهون والسعرات المتبقية.',
            bodyFr: 'Glucides, protéines, lipides et calories restantes.',
            bodyEs: 'Carbohidratos, proteína, grasa y calorías restantes.',
            bodyTr: 'Karbonhidrat, protein, yağ ve kalan kalori.',
            sections: {
              DashboardSectionIds.calories,
              DashboardSectionIds.macros,
              DashboardSectionIds.quickLog,
              DashboardSectionIds.aiCoach,
              DashboardSectionIds.discover,
            },
            premium: true,
          ),
          (
            id: 'heart',
            icon: Icons.monitor_heart_outlined,
            titleEn: 'Heart and activity view',
            titleAr: 'عرض القلب والنشاط',
            titleFr: 'Vue cœur et activité',
            titleEs: 'Vista de corazón y actividad',
            titleTr: 'Kalp ve aktivite görünümü',
            bodyEn: 'Nutrition, activity, and connected health together.',
            bodyAr: 'التغذية والنشاط والصحة المتصلة في عرض واحد.',
            bodyFr: 'Nutrition, activité et santé connectée réunies.',
            bodyEs: 'Nutrición, actividad y salud conectada juntas.',
            bodyTr: 'Beslenme, aktivite ve bağlı sağlık bir arada.',
            sections: {
              DashboardSectionIds.calories,
              DashboardSectionIds.macros,
              DashboardSectionIds.activity,
              DashboardSectionIds.connectedHealth,
              DashboardSectionIds.progress,
              DashboardSectionIds.aiCoach,
            },
            premium: true,
          ),
          (
            id: 'low_carb',
            icon: Icons.eco_outlined,
            titleEn: 'Low carb',
            titleAr: 'كربوهيدرات منخفضة',
            titleFr: 'Faible en glucides',
            titleEs: 'Bajo en carbohidratos',
            titleTr: 'Düşük karbonhidrat',
            bodyEn: 'Macros, calories, quick logging, and evidence.',
            bodyAr: 'المغذيات والسعرات والتسجيل السريع والأدلة.',
            bodyFr: 'Macros, calories, saisie rapide et preuves.',
            bodyEs: 'Macros, calorías, registro rápido y evidencia.',
            bodyTr: 'Makrolar, kalori, hızlı kayıt ve kanıt.',
            sections: {
              DashboardSectionIds.calories,
              DashboardSectionIds.macros,
              DashboardSectionIds.quickLog,
              DashboardSectionIds.dailyIntelligence,
              DashboardSectionIds.aiCoach,
            },
            premium: true,
          ),
        ];
    final items = <(String, IconData, String, String, String, String)>[
      (
        DashboardSectionIds.aiCoach,
        Icons.auto_awesome_rounded,
        'AI Coach',
        'مدرب BIL الذكي',
        'A private conversation with your health intelligence',
        'محادثة خاصة مع ذكائك الصحي الشخصي',
      ),
      (
        DashboardSectionIds.calories,
        Icons.local_fire_department_outlined,
        'Calories',
        'السعرات',
        'Goal, food, exercise, and remaining energy',
        'الهدف والطعام والتمرين والطاقة المتبقية',
      ),
      (
        DashboardSectionIds.macros,
        Icons.donut_large_rounded,
        'Macros',
        'العناصر الكبرى',
        'Protein and fat progress',
        'تقدم البروتين والدهون',
      ),
      (
        DashboardSectionIds.activity,
        Icons.directions_walk_rounded,
        'Activity',
        'النشاط',
        'Steps and exercise status',
        'حالة الخطوات والتمارين',
      ),
      (
        DashboardSectionIds.quickLog,
        Icons.add_circle_outline_rounded,
        'Quick log',
        'التسجيل السريع',
        'Food, water, and weight shortcuts',
        'اختصارات الطعام والماء والوزن',
      ),
      (
        DashboardSectionIds.discover,
        Icons.explore_outlined,
        'Discover',
        'اكتشف',
        'Sleep, recipes, workouts, and community',
        'النوم والوصفات والتمارين والمجتمع',
      ),
      (
        DashboardSectionIds.bestAction,
        Icons.auto_awesome_outlined,
        'Personal intelligence',
        'الذكاء الشخصي',
        'One Best Action, evidence, and Body Twin',
        'أفضل إجراء والأدلة والتوأم الجسدي',
      ),
      (
        DashboardSectionIds.dailyIntelligence,
        Icons.psychology_alt_outlined,
        'Daily intelligence',
        'ذكاء اليوم',
        'Explanations, confidence, and evidence',
        'التفسير والثقة والأدلة',
      ),
      (
        DashboardSectionIds.progress,
        Icons.show_chart_rounded,
        'Progress',
        'التقدم',
        'Measured trends from your saved records',
        'الاتجاهات المقاسة من سجلاتك المحفوظة',
      ),
      (
        DashboardSectionIds.connectedHealth,
        Icons.health_and_safety_outlined,
        'Connected health',
        'الصحة المتصلة',
        'Health sources and synchronization status',
        'مصادر الصحة وحالة المزامنة',
      ),
      (
        DashboardSectionIds.bodyTwin,
        Icons.accessibility_new_rounded,
        'Body Twin',
        'التوأم الجسدي',
        'Your explainable body model and its evidence',
        'نموذج جسمك القابل للتفسير وأدلته',
      ),
    ];

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _saving
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go('/dashboard'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            _sectionCopy(context, 'Customize Today', 'تخصيص شاشة اليوم'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            if (_saving) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            Text(
              _sectionCopy(
                context,
                'Choose what appears on Today. Your data stays saved and every card can be restored at any time.',
                'اختر ما يظهر في شاشة اليوم. تبقى بياناتك محفوظة ويمكن إعادة أي بطاقة في أي وقت.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Text(
              _copy(
                context,
                en: 'Choose the information that matters most to you',
                ar: 'اختر المعلومات الأكثر أهمية لك',
                fr: 'Choisissez les informations les plus importantes pour vous',
                es: 'Elige la información más importante para ti',
                tr: 'Sizin için en önemli bilgileri seçin',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            StreamBuilder<String?>(
              key: ValueKey(_streamRevision),
              stream: ref
                  .watch(preferencesRepositoryProvider)
                  .watch('dashboard.preset'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListTile(
                    leading: const Icon(Icons.error_outline_rounded),
                    title: Text(
                      _sectionCopy(
                        context,
                        'Saved view could not be loaded.',
                        'تعذر تحميل العرض المحفوظ.',
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => setState(() => _streamRevision++),
                      child: Text(
                        _sectionCopy(context, 'Retry', 'إعادة المحاولة'),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Semantics(
                    liveRegion: true,
                    label: _sectionCopy(
                      context,
                      'Loading saved view',
                      'جارٍ تحميل العرض المحفوظ',
                    ),
                    child: const LinearProgressIndicator(),
                  );
                }
                final selected = snapshot.data;
                return SizedBox(
                  height: 190,
                  child: ListView(
                    key: const Key('dashboard-preset-carousel'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    children: [
                      for (final preset in presets)
                        SizedBox(
                          width: 310,
                          child: Card(
                            child: ListTile(
                              key: Key('dashboard-preset-${preset.id}'),
                              leading: Icon(preset.icon),
                              title: Text(
                                _copy(
                                  context,
                                  en: preset.titleEn,
                                  ar: preset.titleAr,
                                  fr: preset.titleFr,
                                  es: preset.titleEs,
                                  tr: preset.titleTr,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                _copy(
                                  context,
                                  en: preset.bodyEn,
                                  ar: preset.bodyAr,
                                  fr: preset.bodyFr,
                                  es: preset.bodyEs,
                                  tr: preset.bodyTr,
                                ),
                              ),
                              trailing:
                                  preset.premium &&
                                      verifiedSubscription.hasError
                                  ? IconButton(
                                      tooltip: _sectionCopy(
                                        context,
                                        'Retry subscription check',
                                        'إعادة فحص الاشتراك',
                                      ),
                                      onPressed: () => ref.invalidate(
                                        verifiedSubscriptionStateProvider,
                                      ),
                                      icon: const Icon(Icons.refresh_rounded),
                                    )
                                  : preset.premium && !entitlementResolved
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : preset.premium && !paid
                                  ? const Icon(
                                      Icons.workspace_premium_rounded,
                                      color: Color(0xFFF2B632),
                                    )
                                  : selected == preset.id
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                              onTap:
                                  _saving ||
                                      (preset.premium && !entitlementResolved)
                                  ? null
                                  : preset.premium && !paid
                                  ? () => context.push('/plans')
                                  : () => _applyPreset(
                                      context,
                                      ref,
                                      preset.id,
                                      preset.sections,
                                    ),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: 310,
                        child: Card(
                          child: ListTile(
                            key: const Key('dashboard-preset-custom'),
                            leading: const Icon(Icons.tune_rounded),
                            title: Text(
                              _copy(
                                context,
                                en: 'Custom',
                                ar: 'مخصص',
                                fr: 'Personnalisé',
                                es: 'Personalizado',
                                tr: 'Özel',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _copy(
                                context,
                                en: 'Choose each card below.',
                                ar: 'اختر كل بطاقة أدناه.',
                                fr: 'Choisissez chaque carte ci-dessous.',
                                es: 'Elige cada tarjeta a continuación.',
                                tr: 'Aşağıdan her kartı seçin.',
                              ),
                            ),
                            trailing: selected == 'custom'
                                ? Icon(
                                    Icons.check_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : null,
                            onTap: _saving
                                ? null
                                : () => _guardedSave(
                                    () => ref
                                        .read(preferencesRepositoryProvider)
                                        .set('dashboard.preset', 'custom'),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              _copy(
                context,
                en: 'Custom cards',
                ar: 'البطاقات المخصصة',
                fr: 'Cartes personnalisées',
                es: 'Tarjetas personalizadas',
                tr: 'Özel kartlar',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 84,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final state = ref.watch(
                        dashboardSectionVisibleProvider(item.$1),
                      );
                      if (state.hasError) {
                        return ListTile(
                          key: Key('dashboard-section-${item.$1}-error'),
                          contentPadding: const EdgeInsets.all(10),
                          title: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _sectionCopy(context, item.$3, item.$4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: TextButton(
                            onPressed: () => ref.invalidate(
                              dashboardSectionVisibleProvider(item.$1),
                            ),
                            child: Text(
                              _sectionCopy(context, 'Retry', 'إعادة المحاولة'),
                            ),
                          ),
                        );
                      }
                      if (state.isLoading) {
                        return Semantics(
                          liveRegion: true,
                          label: _sectionCopy(
                            context,
                            'Loading saved setting',
                            'جارٍ تحميل الإعداد المحفوظ',
                          ),
                          child: const Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final visible = state.value!;
                      return SwitchListTile.adaptive(
                        key: Key('dashboard-section-${item.$1}'),
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(
                          10,
                          6,
                          6,
                          6,
                        ),
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$2, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _sectionCopy(context, item.$3, item.$4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        value: visible,
                        onChanged: _saving || state.isLoading
                            ? null
                            : (value) => _setSectionVisibility(
                                context,
                                ref,
                                item.$1,
                                value,
                              ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('dashboard-edit-step-goal'),
                    leading: const Icon(Icons.directions_walk_rounded),
                    title: Text(
                      _copy(
                        context,
                        en: 'Daily step goal',
                        ar: 'هدف الخطوات اليومي',
                        fr: 'Objectif quotidien de pas',
                        es: 'Objetivo diario de pasos',
                        tr: 'Günlük adım hedefi',
                      ),
                    ),
                    subtitle: Text(
                      _copy(
                        context,
                        en: 'Edit goal',
                        ar: 'تعديل الهدف',
                        fr: 'Modifier l’objectif',
                        es: 'Editar objetivo',
                        tr: 'Hedefi düzenle',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _saving
                        ? null
                        : () => context.push('/connected-health/steps'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('dashboard-edit-nutrition-goals'),
                    leading: const Icon(Icons.track_changes_rounded),
                    title: Text(
                      _copy(
                        context,
                        en: 'Nutrition goals',
                        ar: 'أهداف التغذية',
                        fr: 'Objectifs nutritionnels',
                        es: 'Objetivos nutricionales',
                        tr: 'Beslenme hedefleri',
                      ),
                    ),
                    subtitle: Text(
                      _copy(
                        context,
                        en: 'Edit goal',
                        ar: 'تعديل الهدف',
                        fr: 'Modifier l’objectif',
                        es: 'Editar objetivo',
                        tr: 'Hedefi düzenle',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _saving
                        ? null
                        : () => context.push('/settings/nutrition-goals'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('dashboard-edit-exercise-settings'),
                    leading: const Icon(Icons.fitness_center_rounded),
                    title: Text(
                      _copy(
                        context,
                        en: 'Exercise settings',
                        ar: 'إعدادات التمارين',
                        fr: 'Paramètres d’exercice',
                        es: 'Ajustes de ejercicio',
                        tr: 'Egzersiz ayarları',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _saving
                        ? null
                        : () => context.push('/settings/exercise-calories'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Semantics(
                label: paid
                    ? _sectionCopy(
                        context,
                        'Add nutrient goal cards, Premium active',
                        'إضافة بطاقات أهداف المغذيات، Premium مفعّلة',
                      )
                    : _sectionCopy(
                        context,
                        'Add nutrient goal cards, locked Premium feature',
                        'إضافة بطاقات أهداف المغذيات، ميزة Premium مقفلة',
                      ),
                button: entitlementResolved || verifiedSubscription.hasError,
                child: ListTile(
                  key: const Key('dashboard-add-nutrient-goal-cards'),
                  leading: Consumer(
                    builder: (context, ref, _) {
                      final state = ref.watch(
                        dashboardNutrientGoalCardsProvider,
                      );
                      if (state.isLoading) {
                        return const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      return Icon(
                        state.hasError
                            ? Icons.error_outline_rounded
                            : Icons.add_chart_rounded,
                      );
                    },
                  ),
                  title: Text(
                    _copy(
                      context,
                      en: 'Add nutrient goal cards',
                      ar: 'إضافة بطاقات أهداف المغذيات',
                      fr: 'Ajouter des cartes de nutriments',
                      es: 'Añadir tarjetas de nutrientes',
                      tr: 'Besin hedefi kartları ekle',
                    ),
                  ),
                  subtitle: Consumer(
                    builder: (context, ref, _) {
                      final state = ref.watch(
                        dashboardNutrientGoalCardsProvider,
                      );
                      if (state.isLoading) {
                        return Text(
                          _sectionCopy(
                            context,
                            'Loading saved cards',
                            'جارٍ تحميل البطاقات المحفوظة',
                          ),
                        );
                      }
                      if (state.hasError) {
                        return Text(
                          _sectionCopy(
                            context,
                            'Cards could not be loaded. Tap to retry.',
                            'تعذر تحميل البطاقات. اضغط لإعادة المحاولة.',
                          ),
                        );
                      }
                      final count = state.value!.length;
                      return Text(
                        _copy(
                          context,
                          en: '$count ${_sectionCopy(context, 'selected', 'محددة')}',
                          ar: '$count محددة',
                          fr: '$count sélectionnées',
                          es: '$count seleccionadas',
                          tr: '$count seçildi',
                        ),
                      );
                    },
                  ),
                  trailing: verifiedSubscription.hasError
                      ? IconButton(
                          tooltip: _sectionCopy(
                            context,
                            'Retry subscription check',
                            'إعادة فحص الاشتراك',
                          ),
                          onPressed: () =>
                              ref.invalidate(verifiedSubscriptionStateProvider),
                          icon: const Icon(Icons.refresh_rounded),
                        )
                      : !entitlementResolved
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : !paid
                      ? const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFF2B632),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    if (verifiedSubscription.hasError) {
                      ref.invalidate(verifiedSubscriptionStateProvider);
                      return;
                    }
                    if (!entitlementResolved || _saving) return;
                    if (!paid) {
                      _showLockedNutrientPreview(context);
                      return;
                    }
                    final state = ref.read(dashboardNutrientGoalCardsProvider);
                    if (state.isLoading) return;
                    if (state.hasError) {
                      ref.invalidate(dashboardNutrientGoalCardsProvider);
                      return;
                    }
                    _chooseNutrientCards(context, ref, state.value!);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _restoreDefaults(context, ref),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(
                _sectionCopy(
                  context,
                  'Restore default view',
                  'استعادة العرض الافتراضي',
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            key: const Key('dashboard-preferences-done'),
            onPressed: _saving
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go('/dashboard'),
            child: Text(_sectionCopy(context, 'Done editing', 'إنهاء التعديل')),
          ),
        ),
      ),
    );
  }
}
