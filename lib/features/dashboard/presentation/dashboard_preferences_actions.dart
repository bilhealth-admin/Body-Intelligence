part of 'dashboard_preferences_page.dart';

extension _DashboardPreferencesActions on _DashboardPreferencesPageState {
  Future<bool> _guardedSave(Future<void> Function() operation) async {
    if (_saving) return false;
    _updateState(() => _saving = true);
    try {
      await operation();
      return true;
    } catch (_) {
      if (mounted) _showSaveFailure(context);
      return false;
    } finally {
      if (mounted) _updateState(() => _saving = false);
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
        // Clean up the removed, no-longer-rendered dashboard control.
        'dashboard.section.daily_intelligence',
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
    final selected = current
        .where(DashboardNutrientGoalIds.dashboardCards.contains)
        .toSet();
    var savingCards = false;
    final labels = <String, (String, String, String, String, String)>{
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
                        for (final id
                            in DashboardNutrientGoalIds.dashboardCards)
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
                                      DashboardNutrientGoalIds.dashboardCards
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
}
