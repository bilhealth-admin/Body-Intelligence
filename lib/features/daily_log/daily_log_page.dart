import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;

import '../../data/database/app_database.dart';
import '../../data/database/nutrient_evidence.dart';
import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../../shared/widgets/premium_surface.dart';
import '../foods/providers/food_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../commerce/domain/commerce_entitlement.dart';
import '../commerce/providers/commerce_providers.dart';
import '../settings/premium_meal_features_page.dart';
import '../community/presentation/product_review_submission_dialog.dart';
import '../nutrition/presentation/food_barcode_scanner_page.dart';
import '../nutrition/presentation/meal_image_guide_launcher.dart';
import '../nutrition/presentation/product_identity_copy.dart';
import '../nutrition/presentation/barcode_food_review_dialog.dart';
import '../nutrition/presentation/barcode_runtime_copy.dart';
import '../nutrition/presentation/meal_vision_ui_copy.dart';
import '../nutrition/presentation/meal_image_review_dialog.dart';
import '../nutrition/services/food_search_assistance.dart';
import '../nutrition/services/meal_image_analysis_service.dart';
import '../nutrition/services/meal_voice_input_service.dart';
import '../nutrition/services/bil_speech_to_text.dart';
import '../connected_health/food_name_health_sync_policy.dart';
import '../global_platform/core/global_platform_core.dart';
import '../global_platform/runtime/global_product_composition_root.dart';
import 'providers/daily_log_provider.dart';
import 'presentation/daily_log_summary_widgets.dart';
import 'presentation/daily_log_input_sections.dart';
import 'presentation/daily_log_meals_list.dart';
import 'presentation/quick_macro_entry_dialog.dart';
import 'water_mutation_coordinator.dart';

part 'daily_log_page_actions.dart';
part 'daily_log_meal_entry.dart';

class DailyLogPage extends ConsumerStatefulWidget {
  const DailyLogPage({
    super.key,
    this.initialMealType,
    this.focusMealEntry = false,
    this.initialAction,
    this.returnPath,
  });

  final String? initialMealType;
  final bool focusMealEntry;
  final String? initialAction;
  final String? returnPath;

  @override
  ConsumerState<DailyLogPage> createState() => _DailyLogPageState();
}

class _DailyLogPageState extends ConsumerState<DailyLogPage> {
  final notes = TextEditingController();
  final exerciseNotes = TextEditingController();
  final water = TextEditingController(text: '250');
  final quantity = TextEditingController(text: '100');
  final foodSearch = SearchController();
  static const FoodSearchAssistance _searchAssistance = FoodSearchAssistance();
  final scrollController = ScrollController();
  final mealEntryKey = GlobalKey();
  final waterSectionKey = GlobalKey();
  final exerciseSectionKey = GlobalKey();
  bool mealFocusApplied = false;
  bool initialActionApplied = false;
  String? initialActionInFlight;
  late final WaterMutationCoordinator waterMutations;
  bool get waterSaving => waterMutations.busy;
  bool mealSaving = false;
  bool mealImageBusy = false;
  Food? selectedFood;
  String mealType = 'breakfast';

  void _updateState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    waterMutations = WaterMutationCoordinator(
      onBusyChanged: (_) {
        if (mounted) setState(() {});
      },
    );
    if (const {
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    }.contains(widget.initialMealType)) {
      mealType = widget.initialMealType!;
    }
    if (widget.focusMealEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusMealEntry());
    }
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyInitialAction(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant DailyLogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final actionChanged = oldWidget.initialAction != widget.initialAction;
    if (!oldWidget.focusMealEntry && widget.focusMealEntry) {
      mealFocusApplied = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusMealEntry());
    }
    if (widget.initialAction != null && actionChanged) {
      initialActionApplied = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyInitialAction(),
      );
    }
  }

  Future<void> _applyInitialAction() async {
    if (!mounted || initialActionApplied) return;
    final action = widget.initialAction;
    if (action == null || initialActionInFlight != null) return;
    initialActionApplied = true;
    initialActionInFlight = action;
    try {
      switch (action) {
        case 'barcode':
          await _scanBarcode();
        case 'voice':
          await _captureMealVoice();
        case 'photo':
          await _analyzeMealImage();
        case 'water':
          await _reveal(waterSectionKey);
        case 'notes':
          final location = Uri(
            path: '/daily-log/body-context',
            queryParameters: {'from': widget.returnPath ?? '/daily-log'},
          ).toString();
          await context.push(location);
        case 'exercise':
          await _reveal(exerciseSectionKey);
        case 'quick-macros':
          await _quickAddMacrosV2();
      }
    } finally {
      if (initialActionInFlight == action) initialActionInFlight = null;
      if (mounted && widget.initialAction != action) {
        initialActionApplied = false;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _applyInitialAction(),
        );
      }
    }
  }

  Future<void> _reveal(GlobalKey key) async {
    final target = key.currentContext;
    if (!mounted || target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: .08,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _focusMealEntry() {
    final mealContext = mealEntryKey.currentContext;
    if (!mounted || mealContext == null) return;
    mealFocusApplied = true;
    Scrollable.ensureVisible(
      mealContext,
      alignment: 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    notes.dispose();
    exerciseNotes.dispose();
    water.dispose();
    quantity.dispose();
    foodSearch.dispose();
    scrollController.dispose();
    super.dispose();
  }

  bool get _arabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  String _tr(String en, String ar) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    if (locale == 'ar') return ar;
    return _dailyLogCopy[en]?[locale] ?? context.strings.text(en);
  }

  String _unit(String value) {
    if (!_arabic) return value;
    return switch (value.toLowerCase()) {
      'g' => 'جم',
      'mg' => 'مجم',
      'ml' => 'مل',
      'kcal' => 'سعرة',
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodsProvider);
    final date = ref.watch(selectedLogDateProvider);
    final meals = ref.watch(dailyMealsProvider);
    final waterEntries = ref.watch(dailyWaterProvider);
    final ledger = ref.watch(selectedDailyLedgerProvider);
    final goalSchedule =
        ref.watch(nutritionGoalScheduleProvider).value ??
        const NutritionGoalSchedule();
    final verifiedSubscription = ref.watch(verifiedSubscriptionStateProvider);
    final premiumMealFeatures =
        verifiedSubscription.value?.grants(
          CommerceEntitlement.advancedIntelligence,
        ) ??
        false;
    final AsyncValue<Map<String, double>> mealCalorieState = premiumMealFeatures
        ? ref.watch(mealCalorieGoalsProvider)
        : const AsyncData(<String, double>{});
    final AsyncValue<MealMacroDisplay?> mealMacroState = premiumMealFeatures
        ? ref.watch(mealMacroDisplayProvider)
        : const AsyncData<MealMacroDisplay?>(null);
    final mealCalorieGoals = mealCalorieState.value ?? const <String, double>{};
    final mealMacroDisplay = mealMacroState.value;
    final showFoodInsights =
        ref.watch(dailyLogPreferenceProvider('diary.foodInsights')).value ??
        true;
    final showAllMeals =
        ref.watch(dailyLogPreferenceProvider('diary.showAllMeals')).value ??
        true;
    final showFoodTimestamps =
        ref
            .watch(dailyLogPreferenceProvider('diary.showFoodTimestamps'))
            .value ??
        false;
    final useNetCarbs =
        ref.watch(dailyLogPreferenceProvider('diary.useNetCarbs')).value ??
        false;
    final alwaysShowWater =
        ref.watch(dailyLogPreferenceProvider('diary.alwaysShowWater')).value ??
        true;
    final usualMeals = ref.watch(usualMealsProvider(mealType));
    ref.listen(selectedDailyLogProvider, (_, next) {
      next.whenData((log) {
        final value = log?.notes ?? '';
        if (notes.text != value) notes.text = value;
        final exerciseValue = log?.exerciseNotes ?? '';
        if (exerciseNotes.text != exerciseValue) {
          exerciseNotes.text = exerciseValue;
        }
      });
    });
    final mutationBusy = mealSaving || waterSaving;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || mutationBusy) return;
        context.go(widget.returnPath ?? '/dashboard');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.strings.text('Diary')),
          actions: [
            IconButton(
              key: const Key('daily-log-copy-multiple-days'),
              tooltip: _tr('Copy to multiple days', 'نسخ إلى عدة أيام'),
              onPressed: mutationBusy ? null : _copyToMultipleDays,
              icon: const Icon(Icons.date_range_rounded),
            ),
            IconButton(
              key: const Key('daily-log-copy-previous-day'),
              tooltip: _tr('Copy previous day meals', 'نسخ وجبات اليوم السابق'),
              onPressed: mutationBusy ? null : _copyPreviousDayMeals,
              icon: const Icon(Icons.content_copy_rounded),
            ),
          ],
          leading: BackButton(
            onPressed: mutationBusy
                ? null
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(widget.returnPath ?? '/dashboard');
                    }
                  },
          ),
        ),
        body: Semantics(
          container: true,
          child: foods.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ActionableErrorState(
              title: context.strings.text('Could not load the food catalog.'),
              onRetry: () => ref.invalidate(foodsProvider),
            ),
            data: (items) {
              if (mealCalorieState.isLoading || mealMacroState.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (mealCalorieState.hasError || mealMacroState.hasError) {
                return ActionableErrorState(
                  title: context.strings.text(
                    'Meal display settings could not be loaded.',
                  ),
                  onRetry: () {
                    ref.invalidate(mealCalorieGoalsProvider);
                    ref.invalidate(mealMacroDisplayProvider);
                  },
                );
              }
              if (widget.focusMealEntry && !mealFocusApplied) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _focusMealEntry(),
                );
              }
              return ListView(
                controller: scrollController,
                padding: PremiumDesignTokens.screenPadding.add(
                  const EdgeInsets.only(bottom: 116),
                ),
                children: [
                  if (!widget.focusMealEntry) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        _tr('Record your day', 'سجّل يومك'),
                        style: PremiumDesignTokens.screenHeading(context),
                      ),
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceSm),
                    DiaryDateNavigator(
                      date: date,
                      arabic: _arabic,
                      onPrevious: mutationBusy
                          ? null
                          : () =>
                                ref
                                    .read(selectedLogDateProvider.notifier)
                                    .state = date.subtract(
                                  const Duration(days: 1),
                                ),
                      onNext:
                          date.isBefore(
                            DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                            ),
                          )
                          ? mutationBusy
                                ? null
                                : () =>
                                      ref
                                          .read(
                                            selectedLogDateProvider.notifier,
                                          )
                                          .state = date.add(
                                        const Duration(days: 1),
                                      )
                          : null,
                      onPick: mutationBusy
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 1),
                                ),
                              );
                              if (picked != null) {
                                ref
                                        .read(selectedLogDateProvider.notifier)
                                        .state =
                                    picked;
                              }
                            },
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceSm),
                  ],
                  DailyLogSnapshot(
                    arabic: _arabic,
                    meals: meals.value ?? const [],
                    water: waterEntries.value ?? const [],
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  _buildMealEntry(usualMeals: usualMeals, date: date),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  DailyMealsList(
                    arabic: _arabic,
                    meals: meals,
                    showEmptyMealSlots: showAllMeals,
                    showFoodInsights: showFoodInsights,
                    showFoodTimestamps: showFoodTimestamps,
                    useNetCarbs: useNetCarbs,
                    dailyGoal: goalSchedule.targetFor(date),
                    mealGoals: goalSchedule.mealTargets,
                    mealCalorieGoals: mealCalorieGoals,
                    mealMacroDisplay: mealMacroDisplay,
                    onAdd: (type) {
                      _updateState(() {
                        mealType = type;
                        selectedFood = null;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) foodSearch.openView();
                      });
                    },
                    onEdit: _editMealItem,
                    onActions: _showItemActions,
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceLg),
                  if (alwaysShowWater ||
                      (waterEntries.value?.isNotEmpty ?? false)) ...[
                    DailyWaterSection(
                      key: waterSectionKey,
                      arabic: _arabic,
                      controller: water,
                      entries: waterEntries,
                      saving: waterSaving,
                      onAdd: _addWater,
                      onDelete: _deleteWater,
                      onRetry: () => ref.invalidate(dailyWaterProvider),
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceLg),
                  ],
                  DailyExerciseSection(
                    key: exerciseSectionKey,
                    arabic: _arabic,
                    controller: exerciseNotes,
                    onBrowseWorkouts: () => context.push('/wellness/workouts'),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceLg),
                  PremiumSurface(
                    key: const Key('daily-log-body-context-link'),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: PremiumDesignTokens.cardPaddingLarge,
                      leading: const Icon(Icons.accessibility_new_rounded),
                      title: Text(_tr('Body context', 'سياق الجسم')),
                      subtitle: Text(
                        _tr(
                          'Add sleep, travel, stress, hydration, and other context on a focused page.',
                          'أضف النوم والسفر والإجهاد والترطيب والسياقات الأخرى في صفحة مخصصة.',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/daily-log/body-context'),
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceLg),
                  PremiumSurface(
                    key: const Key('daily-log-lifecycle-card'),
                    child: ledger.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => ActionableErrorState(
                        title: _tr(
                          'Diary status could not be loaded.',
                          'تعذر تحميل حالة اليوميات.',
                        ),
                        onRetry: () =>
                            ref.invalidate(selectedDailyLedgerProvider),
                      ),
                      data: (snapshot) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            snapshot.state == DayLifecycleState.closed
                                ? _tr('Diary completed', 'اكتملت اليوميات')
                                : _tr('Complete diary', 'إكمال اليوميات'),
                            style: PremiumDesignTokens.cardHeading(context),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            snapshot.state == DayLifecycleState.closed
                                ? _tr(
                                    'This day is frozen as a reviewed nutrition snapshot. Reopen it before making changes.',
                                    'تم تثبيت هذا اليوم كلقطة تغذية تمت مراجعتها. أعد فتحه قبل إجراء تغييرات.',
                                  )
                                : _tr(
                                    'Review today’s entries, then complete the diary to preserve an authoritative snapshot.',
                                    'راجع مدخلات اليوم، ثم أكمل اليوميات لحفظ لقطة موثوقة.',
                                  ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            key: Key(
                              snapshot.state == DayLifecycleState.closed
                                  ? 'daily-log-reopen-day'
                                  : 'daily-log-complete-day',
                            ),
                            onPressed:
                                snapshot.state == DayLifecycleState.closed
                                ? _reopenDiary
                                : _completeDiary,
                            icon: Icon(
                              snapshot.state == DayLifecycleState.closed
                                  ? Icons.lock_open_rounded
                                  : Icons.task_alt_rounded,
                            ),
                            label: Text(
                              snapshot.state == DayLifecycleState.closed
                                  ? _tr('Reopen diary', 'إعادة فتح اليوميات')
                                  : _tr('Complete diary', 'إكمال اليوميات'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceLg),
                  Semantics(
                    button: true,
                    label: context.strings.text('Save log'),
                    child: FilledButton(
                      key: const Key('daily_log_save_primary_action'),
                      onPressed: _save,
                      child: Text(context.strings.text('Save log')),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double? _parsePositiveQuantity(String raw) {
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0.1 || value > 100000) {
      return null;
    }
    return value;
  }
}

const _dailyLogCopy = <String, Map<String, String>>{
  'Quick Add macros': {
    'fr': 'Ajout rapide des macros',
    'es': 'Añadir macros rápidamente',
    'tr': 'Makroları hızlı ekle',
  },
  'Calories': {'fr': 'Calories', 'es': 'Calorías', 'tr': 'Kalori'},
  'Protein (g)': {
    'fr': 'Protéines (g)',
    'es': 'Proteínas (g)',
    'tr': 'Protein (g)',
  },
  'Carbohydrates (g)': {
    'fr': 'Glucides (g)',
    'es': 'Carbohidratos (g)',
    'tr': 'Karbonhidrat (g)',
  },
  'Fat (g)': {'fr': 'Lipides (g)', 'es': 'Grasas (g)', 'tr': 'Yağ (g)'},
  'Time': {'fr': 'Heure', 'es': 'Hora', 'tr': 'Saat'},
  'Add': {'fr': 'Ajouter', 'es': 'Añadir', 'tr': 'Ekle'},
  'Enter at least one valid calorie or macro value.': {
    'fr': 'Saisissez au moins une valeur valide de calories ou de macros.',
    'es': 'Introduce al menos un valor válido de calorías o macros.',
    'tr': 'En az bir geçerli kalori veya makro değeri girin.',
  },
  'Quick Add saved locally.': {
    'fr': 'Ajout rapide enregistré localement.',
    'es': 'La adición rápida se guardó localmente.',
    'tr': 'Hızlı ekleme yerel olarak kaydedildi.',
  },
  'Copy to multiple days': {
    'fr': 'Copier vers plusieurs jours',
    'es': 'Copiar a varios días',
    'tr': 'Birden fazla güne kopyala',
  },
  'Choose how many upcoming empty days receive this diary. Existing days are never replaced.': {
    'fr':
        'Choisissez le nombre de jours vides à venir qui recevront ce journal. Les jours existants ne sont jamais remplacés.',
    'es':
        'Elige cuántos días vacíos próximos recibirán este diario. Los días existentes nunca se reemplazan.',
    'tr':
        'Bu günlüğün kopyalanacağı boş gelecek gün sayısını seçin. Mevcut günler asla değiştirilmez.',
  },
  'One of the selected days already has meals. Nothing was copied.': {
    'fr':
        'Un des jours sélectionnés contient déjà des repas. Rien n’a été copié.',
    'es':
        'Uno de los días seleccionados ya contiene comidas. No se copió nada.',
    'tr': 'Seçilen günlerden birinde zaten öğün var. Hiçbir şey kopyalanmadı.',
  },
  'Diary copied to {count} days.': {
    'fr': 'Journal copié vers {count} jours.',
    'es': 'Diario copiado a {count} días.',
    'tr': 'Günlük {count} güne kopyalandı.',
  },
  'Copy previous day meals': {
    'fr': 'Copier les repas de la veille',
    'es': 'Copiar las comidas del día anterior',
    'tr': 'Önceki günün öğünlerini kopyala',
  },
  'Record your day': {
    'fr': 'Consignez votre journée',
    'es': 'Registra tu día',
    'tr': 'Gününüzü kaydedin',
  },
  'Body context': {
    'fr': 'Contexte du corps',
    'es': 'Contexto corporal',
    'tr': 'Beden bağlamı',
  },
  'Add sleep, travel, stress, hydration, and other context on a focused page.': {
    'fr':
        'Ajoutez le sommeil, les voyages, le stress, l’hydratation et d’autres éléments sur une page dédiée.',
    'es':
        'Añade sueño, viajes, estrés, hidratación y otros datos en una página específica.',
    'tr':
        'Uyku, seyahat, stres, sıvı alımı ve diğer bağlamları özel bir sayfada ekleyin.',
  },
  'Copy yesterday’s meals?': {
    'fr': 'Copier les repas d’hier ?',
    'es': '¿Copiar las comidas de ayer?',
    'tr': 'Dünün öğünleri kopyalansın mı?',
  },
  'Cancel': {'fr': 'Annuler', 'es': 'Cancelar', 'tr': 'İptal'},
  'Copy': {'fr': 'Copier', 'es': 'Copiar', 'tr': 'Kopyala'},
  'Edit quantity': {
    'fr': 'Modifier la quantité',
    'es': 'Editar cantidad',
    'tr': 'Miktarı düzenle',
  },
  'Duplicate item': {
    'fr': 'Dupliquer l’élément',
    'es': 'Duplicar elemento',
    'tr': 'Öğeyi çoğalt',
  },
  'Copies the same quantity and saved nutrition snapshot.': {
    'fr': 'Copie la même quantité et l’instantané nutritionnel enregistré.',
    'es': 'Copia la misma cantidad y la instantánea nutricional guardada.',
    'tr': 'Aynı miktarı ve kaydedilmiş besin anlık görüntüsünü kopyalar.',
  },
  'Remove favorite': {
    'fr': 'Retirer des favoris',
    'es': 'Quitar de favoritos',
    'tr': 'Favorilerden kaldır',
  },
  'Add favorite': {
    'fr': 'Ajouter aux favoris',
    'es': 'Añadir a favoritos',
    'tr': 'Favorilere ekle',
  },
  'Delete from meal': {
    'fr': 'Supprimer du repas',
    'es': 'Eliminar de la comida',
    'tr': 'Öğünden sil',
  },
  'Submit for review': {
    'fr': 'Envoyer pour vérification',
    'es': 'Enviar para revisión',
    'tr': 'İncelemeye gönder',
  },
  'Image analysis unavailable': {
    'fr': 'Analyse d’image indisponible',
    'es': 'El análisis de imágenes no está disponible',
    'tr': 'Görüntü analizi kullanılamıyor',
  },
  'OK': {'fr': 'OK', 'es': 'Aceptar', 'tr': 'Tamam'},
  'Take a photo': {
    'fr': 'Prendre une photo',
    'es': 'Hacer una foto',
    'tr': 'Fotoğraf çek',
  },
  'Choose from device': {
    'fr': 'Choisir sur l’appareil',
    'es': 'Elegir del dispositivo',
    'tr': 'Cihazdan seç',
  },
  'Review image suggestions': {
    'fr': 'Vérifier les suggestions de l’image',
    'es': 'Revisar las sugerencias de la imagen',
    'tr': 'Görüntü önerilerini incele',
  },
};
double? dailyLogAmountInGrams({required double amount, required String unit}) {
  if (!amount.isFinite || amount <= 0) return null;
  return switch (unit.trim().toLowerCase()) {
    'kg' || 'kgs' || 'kilogram' || 'kilograms' => amount * 1000,
    'oz' || 'ozs' || 'ounce' || 'ounces' => amount * 28.349523125,
    'lb' || 'lbs' || 'pound' || 'pounds' => amount * 453.59237,
    'mg' || 'mgs' || 'milligram' || 'milligrams' => amount / 1000,
    _ => amount,
  };
}
