import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;

import '../../data/database/app_database.dart';
import '../../data/database/nutrient_evidence.dart';
import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../app/services/runtime_permission_policy.dart';
import '../../app/services/store_review_prompt_service.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../../shared/widgets/premium_surface.dart';
import '../foods/providers/food_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../commerce/domain/commerce_entitlement.dart';
import '../commerce/providers/commerce_providers.dart';
import '../commerce/presentation/premium_barcode_access.dart';
import '../commerce/presentation/premium_nutrition_glass.dart';
import '../ads/presentation/safe_free_ad_anchor.dart';
import '../settings/premium_meal_features_page.dart';
import '../community/presentation/product_review_submission_dialog.dart';
import '../nutrition/presentation/food_barcode_scanner_page.dart';
import '../nutrition/presentation/product_identity_copy.dart';
import '../nutrition/presentation/barcode_food_review_dialog.dart';
import '../nutrition/presentation/barcode_runtime_copy.dart';
import '../nutrition/presentation/meal_vision_ui_copy.dart';
import '../nutrition/presentation/meal_image_review_dialog.dart';
import '../nutrition/services/food_search_assistance.dart';
import '../nutrition/services/food_presentation_localizer.dart';
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

part 'daily_log_page_actions.dart';
part 'daily_log_meal_entry.dart';
part 'daily_log_meal_search.dart';
part 'daily_log_mutation_actions.dart';
part 'daily_log_capture_actions.dart';
part 'daily_log_copy.dart';
part 'daily_log_meal_entry_components.dart';
part 'daily_log_navigation_actions.dart';

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
  final quantity = TextEditingController(text: '100');
  final foodSearch = SearchController();
  static const FoodSearchAssistance _searchAssistance = FoodSearchAssistance();
  final scrollController = ScrollController();
  final mealEntryKey = GlobalKey();
  final exerciseSectionKey = GlobalKey();
  bool mealFocusApplied = false;
  bool initialActionApplied = false;
  String? initialActionInFlight;
  bool mealSaving = false;
  bool mealImageBusy = false;
  bool mealSearchActive = false;
  Food? selectedFood;
  int? expandedNutritionFactsFoodId;
  String mealType = 'breakfast';
  String mealQuantityUnit = 'g';

  void _updateState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    if (const {
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    }.contains(widget.initialMealType)) {
      mealType = widget.initialMealType!;
    }
    if (widget.focusMealEntry) {
      mealSearchActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusMealEntry();
        _openFoodSearchAfterBuild();
      });
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
      mealSearchActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusMealEntry();
        _openFoodSearchAfterBuild();
      });
    }
    if (widget.initialAction != null && actionChanged) {
      initialActionApplied = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyInitialAction(),
      );
    }
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

  void _leaveMealDetail() {
    if (widget.focusMealEntry) {
      context.go(widget.returnPath ?? '/daily-log');
      return;
    }
    _updateState(() {
      selectedFood = null;
      mealSearchActive = false;
    });
  }

  @override
  void dispose() {
    notes.dispose();
    exerciseNotes.dispose();
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
    final mutationBusy = mealSaving;
    final today = DateUtils.dateOnly(DateTime.now());
    final latestPlannableDate = DateTime(
      today.year + 1,
      today.month,
      today.day,
    );
    final mealRows = meals.value ?? const <MealWithItems>[];
    MealWithItems? focusedMeal;
    for (final row in mealRows) {
      if (row.meal.type == mealType) {
        focusedMeal = row;
        break;
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || mutationBusy) return;
        if (selectedFood != null) {
          _updateState(() {
            selectedFood = null;
          });
          return;
        }
        if (mealSearchActive || widget.focusMealEntry) {
          _leaveMealDetail();
          return;
        }
        context.go(widget.returnPath ?? '/dashboard');
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F5F8),
          body: SafeArea(
            bottom: false,
            child: Semantics(
              container: true,
              child: foods.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => ActionableErrorState(
                  title: context.strings.text(
                    'Could not load the food catalog.',
                  ),
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
                  if (selectedFood != null) {
                    return ListView(
                      key: const Key('daily-log-focused-food-detail'),
                      controller: scrollController,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        0,
                        16,
                        48,
                      ),
                      children: [
                        SizedBox(
                          height: 56,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: BackButton(
                              onPressed: mutationBusy
                                  ? null
                                  : () {
                                      _updateState(() => selectedFood = null);
                                      _openFoodSearchAfterBuild();
                                    },
                            ),
                          ),
                        ),
                        _buildMealEntry(),
                      ],
                    );
                  }
                  if (mealSearchActive || widget.focusMealEntry) {
                    return ListView(
                      key: const Key('daily-log-focused-meal-page'),
                      controller: scrollController,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        0,
                        16,
                        48,
                      ),
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: Row(
                            children: [
                              BackButton(
                                key: const Key('daily-meal-detail-back'),
                                onPressed: mutationBusy
                                    ? null
                                    : _leaveMealDetail,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      key: const Key('daily-meal-detail-title'),
                                      context.strings.text(
                                        '${mealType[0].toUpperCase()}${mealType.substring(1)}',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    Text(
                                      intl.DateFormat.yMMMd(
                                        _mealLocale,
                                      ).format(date),
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildMealEntry(),
                        const SizedBox(height: 12),
                        DailyMealDetailSummary(
                          meal: focusedMeal,
                          calorieGoal: mealCalorieGoals[mealType],
                        ),
                        const SizedBox(height: 12),
                        DailyMealDetailItems(
                          meal: focusedMeal,
                          onEdit: _editMealItem,
                          onActions: _showItemActions,
                        ),
                      ],
                    );
                  }
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      196,
                    ),
                    children: [
                      if (!widget.focusMealEntry) ...[
                        DiaryDateNavigator(
                          date: date,
                          arabic: _arabic,
                          onBack: mutationBusy
                              ? null
                              : () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go(
                                      widget.returnPath ?? '/dashboard',
                                    );
                                  }
                                },
                          onPrevious: mutationBusy
                              ? null
                              : () =>
                                    ref
                                        .read(selectedLogDateProvider.notifier)
                                        .state = date.subtract(
                                      const Duration(days: 1),
                                    ),
                          onNext: date.isBefore(latestPlannableDate)
                              ? mutationBusy
                                    ? null
                                    : () =>
                                          ref
                                              .read(
                                                selectedLogDateProvider
                                                    .notifier,
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
                                    lastDate: latestPlannableDate,
                                  );
                                  if (picked != null) {
                                    ref
                                            .read(
                                              selectedLogDateProvider.notifier,
                                            )
                                            .state =
                                        picked;
                                  }
                                },
                        ),
                        const SizedBox(height: 8),
                        DailyLogSnapshot(
                          key: const Key('daily-log-today-summary'),
                          arabic: _arabic,
                          meals: meals.value ?? const [],
                          water: waterEntries.value ?? const [],
                          calorieGoal: goalSchedule.targetFor(date)?.calories,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          key: const Key('daily-log-action-row'),
                          children: [
                            Expanded(
                              child: KeyedSubtree(
                                key: const Key('daily-log-copy-previous-day'),
                                child: _DiaryActionButton(
                                  key: const Key('daily-log-action-copy'),
                                  icon: Icons.copy_all_rounded,
                                  label: _tr('Copy from', 'نسخ من'),
                                  onPressed: mutationBusy
                                      ? null
                                      : _showDiaryCopyOptions,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: KeyedSubtree(
                                key: const Key('daily-log-edit-settings'),
                                child: _DiaryActionButton(
                                  key: const Key('daily-log-action-edit'),
                                  icon: Icons.edit_outlined,
                                  label: _tr('Edit', 'تعديل'),
                                  onPressed: mutationBusy
                                      ? null
                                      : () => context.push('/settings/diary'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SafeFreeAdAnchor(
                          key: Key('daily-log-free-ad-slot'),
                          surface: SafeFreeAdSurface.dailyLog,
                        ),
                        const SizedBox(height: 12),
                      ] else
                        SizedBox(
                          height: 56,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: BackButton(
                              onPressed: mutationBusy
                                  ? null
                                  : () {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go(
                                          widget.returnPath ?? '/dashboard',
                                        );
                                      }
                                    },
                            ),
                          ),
                        ),
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
                            mealSearchActive = true;
                          });
                          _openFoodSearchAfterBuild();
                        },
                        onEdit: _editMealItem,
                        onActions: _showItemActions,
                      ),
                      const SizedBox(height: PremiumDesignTokens.spaceSm),
                      if (alwaysShowWater ||
                          (waterEntries.value?.isNotEmpty ?? false)) ...[
                        DailyWaterShortcut(
                          entries: waterEntries,
                          onTap: () => context.push(
                            '/daily-log/water?from=${Uri.encodeComponent('/daily-log')}',
                          ),
                        ),
                        const SizedBox(height: PremiumDesignTokens.spaceSm),
                      ],
                      DailyExerciseSection(
                        key: exerciseSectionKey,
                        arabic: _arabic,
                        controller: exerciseNotes,
                        onBrowseWorkouts: () =>
                            context.push('/wellness/workouts'),
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
                                      ? _tr(
                                          'Reopen diary',
                                          'إعادة فتح اليوميات',
                                        )
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
        ),
      ),
    );
  }
}
