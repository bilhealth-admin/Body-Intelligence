import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/plan_engine.dart';
import '../../intelligence_center/services/coach_context_provider.dart';
import '../../nutrition/presentation/nutrition_copy.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../data/diet_plan_repository.dart';
import '../domain/diet_macro_plan.dart';
import '../domain/nutrition_pathway.dart';
import '../domain/nutrition_pathway_catalog.dart';
import '../domain/nutrition_pathway_localizer.dart';

part 'diet_plan_editor_components.dart';

class DietPlanEditorPage extends ConsumerStatefulWidget {
  const DietPlanEditorPage({super.key, required this.pathwayId});

  final String pathwayId;

  @override
  ConsumerState<DietPlanEditorPage> createState() => _DietPlanEditorPageState();
}

class _DietPlanEditorPageState extends ConsumerState<DietPlanEditorPage> {
  final _calories = TextEditingController();
  final _carbs = <int, TextEditingController>{
    for (var day = 1; day <= 7; day += 1) day: TextEditingController(),
  };
  final _protein = <int, TextEditingController>{
    for (var day = 1; day <= 7; day += 1) day: TextEditingController(),
  };
  final _fat = <int, TextEditingController>{
    for (var day = 1; day <= 7; day += 1) day: TextEditingController(),
  };
  final _resolvedTargets = <int, DietMacroTarget>{};
  DietFatLevel _fatLevel = DietFatLevel.medium;
  int _trimester = 1;
  bool _clinicianAcknowledged = false;
  bool _loading = true;
  bool _saving = false;
  bool _active = false;

  NutritionPathway? get _pathway {
    for (final pathway in nutritionPathways) {
      if (pathway.id == widget.pathwayId) return pathway;
    }
    return null;
  }

  bool get _isPregnancy => widget.pathwayId == 'pregnancy';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_pathway == null || !dietPresets.containsKey(widget.pathwayId)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final repository = ref.read(dietPlanRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.read(widget.pathwayId),
      repository.readActivePathway(),
    ]);
    if (!mounted) return;
    _applyDraft(results[0]! as DietDraft);
    setState(() {
      _active = results[1] == widget.pathwayId;
      _loading = false;
    });
  }

  void _applyDraft(DietDraft draft) {
    _calories.text = (draft.prePregnancyCalories ?? draft.calories)
        .round()
        .toString();
    _fatLevel = draft.fatLevel;
    _trimester = draft.pregnancyTrimester ?? 1;
    final week = draft.resolveWeek();
    _resolvedTargets.clear();
    for (var day = 1; day <= 7; day += 1) {
      final target = week?[day];
      if (target == null) continue;
      _resolvedTargets[day] = target;
      _writeTarget(day, target);
    }
  }

  double? get _baseCalories => double.tryParse(_calories.text.trim());

  double? get _effectiveCalories {
    final base = _baseCalories;
    if (base == null) return null;
    if (!_isPregnancy) return base;
    return base +
        (PregnancyNutritionGuidance.extraCaloriesByTrimester[_trimester] ?? 0);
  }

  DietDraft? _draft() {
    final calories = _effectiveCalories;
    if (calories == null) return null;
    final carbs = <int, double>{};
    final protein = <int, double>{};
    final fat = <int, double>{};
    for (var day = 1; day <= 7; day += 1) {
      final carbValue = double.tryParse(_carbs[day]!.text.trim());
      final proteinValue = double.tryParse(_protein[day]!.text.trim());
      final fatValue = double.tryParse(_fat[day]!.text.trim());
      if (carbValue == null || proteinValue == null || fatValue == null) {
        return null;
      }
      carbs[day] = carbValue;
      protein[day] = proteinValue;
      fat[day] = fatValue;
    }
    final draft = DietDraft(
      pathwayId: widget.pathwayId,
      calories: calories,
      fatLevel: _fatLevel,
      carbsByWeekday: carbs,
      proteinByWeekday: protein,
      fatByWeekday: fat,
      pregnancyTrimester: _isPregnancy ? _trimester : null,
      prePregnancyCalories: _isPregnancy ? _baseCalories : null,
    );
    return draft.resolveWeek() == null ? null : draft;
  }

  String _macroText(double value) {
    if ((value - value.round()).abs() < .00005) return '${value.round()}';
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _writeTarget(
    int day,
    DietMacroTarget target, {
    DietMacroComponent? preserve,
  }) {
    if (preserve != DietMacroComponent.carbs) {
      _carbs[day]!.text = _macroText(target.carbsGrams);
    }
    if (preserve != DietMacroComponent.protein) {
      _protein[day]!.text = _macroText(target.proteinGrams);
    }
    if (preserve != DietMacroComponent.fat) {
      _fat[day]!.text = _macroText(target.fatGrams);
    }
  }

  void _onCaloriesChanged(String _) {
    final calories = _effectiveCalories;
    if (calories == null || !calories.isFinite || calories <= 0) {
      setState(() {});
      return;
    }
    for (var day = 1; day <= 7; day += 1) {
      final current = _resolvedTargets[day];
      if (current == null) continue;
      final target = DietMacroAllocator.rescale(
        current: current,
        calories: calories,
      );
      if (target == null) continue;
      _resolvedTargets[day] = target;
      _writeTarget(day, target);
    }
    setState(() {});
  }

  void _onMacroChanged(int day, DietMacroComponent component, String source) {
    final grams = double.tryParse(source.trim());
    final current = _resolvedTargets[day];
    if (grams == null || current == null) {
      setState(() {});
      return;
    }
    final target = DietMacroAllocator.rebalance(
      current: current,
      edited: component,
      grams: grams,
      fallbackFatLevel: _fatLevel,
    );
    if (target == null) {
      setState(() {});
      return;
    }
    _resolvedTargets[day] = target;
    _writeTarget(day, target, preserve: component);
    setState(() {});
  }

  void _applyPregnancyDefaults(int trimester) {
    final base = _baseCalories;
    if (base == null) return;
    final draft = PregnancyNutritionGuidance.forTrimester(
      prePregnancyCalories: base,
      trimester: trimester,
    );
    setState(() {
      _trimester = trimester;
      _fatLevel = draft.fatLevel;
      _applyDraft(draft);
    });
  }

  Future<void> _save() async {
    final pathway = _pathway;
    final draft = _draft();
    if (pathway == null || draft == null) {
      _snack(
        nutritionText(
          context,
          'Macronutrients',
          'راجع السعرات الثابتة وجميع قيم الماكروز اليومية.',
        ),
      );
      return;
    }
    if (pathway.safety == NutritionPathwaySafety.medicalSupervision) return;
    if (pathway.safety == NutritionPathwaySafety.clinicianReview &&
        !_clinicianAcknowledged) {
      _snack(
        nutritionText(
          context,
          'Confirm clinician review before activation.',
          'أكد مراجعة المختص قبل التفعيل.',
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(dietPlanCommandProvider)
          .activate(draft, clinicianReviewConfirmed: _clinicianAcknowledged);
      if (!mounted) return;
      setState(() => _active = true);
      ref.invalidate(nutritionGoalScheduleProvider);
      ref.invalidate(activeNutritionPathwayProvider);
      ref.invalidate(coachContextSnapshotProvider);
      _snack(
        nutritionText(
          context,
          'Weekly diet targets activated. Existing diary entries were not changed.',
          'تم تفعيل أهداف الدايت الأسبوعية دون تغيير سجلات اليوميات السابقة.',
        ),
      );
    } on NutritionPathwayActivationException catch (error) {
      if (!mounted) return;
      _snack(_activationFailureMessage(error.failure));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _activationFailureMessage(NutritionPathwayActivationFailure failure) =>
      switch (failure) {
        NutritionPathwayActivationFailure.premiumRequired => nutritionText(
          context,
          'Subscription check unavailable',
          'تعذر التحقق من اشتراك Premium. أعد فتح المسار بعد تحديث اشتراكك.',
        ),
        NutritionPathwayActivationFailure.clinicianReviewRequired =>
          nutritionText(
            context,
            'Confirm clinician review before activation.',
            'أكد مراجعة المختص قبل التفعيل.',
          ),
        NutritionPathwayActivationFailure.medicalSupervisionRequired =>
          nutritionText(
            context,
            'This protocol stays locked without active medical supervision.',
            'يبقى هذا المسار مقفلاً دون إشراف طبي.',
          ),
        NutritionPathwayActivationFailure.unknownPathway ||
        NutritionPathwayActivationFailure.invalidAuthorization => nutritionText(
          context,
          'Unavailable',
          'هذا المسار الغذائي غير متاح.',
        ),
      };

  NutritionGoalTarget? _recommendedTarget() {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return null;
    final goal = ref.read(activeGoalProvider).value;
    final latestWeight = ref.read(latestWeightProvider).value?.weight;
    final latestBodyMeasurement = ref
        .read(bodyMeasurementHistoryProvider)
        .value
        ?.firstOrNull;
    final recommendation = PlanEngine.recommend(
      BodyProfile(
        age: profile.age,
        gender: profile.gender,
        height: profile.height,
        weight: latestWeight ?? profile.currentWeight,
        targetWeight: profile.targetWeight,
        activityLevel: profile.activityLevel,
        exercises: profile.exercises,
        goalType: goal?.type ?? 'maintain',
        waistCm: latestBodyMeasurement?.waistCm ?? profile.waist,
        neckCm: latestBodyMeasurement?.neckCm ?? profile.neck,
        hipCm: latestBodyMeasurement?.hipsCm,
      ),
    );
    final targets = recommendation.targets;
    final carbEnergy = targets.carbs * 4.0;
    final proteinEnergy = targets.protein * 4.0;
    final fatEnergy = targets.fats * 9.0;
    final macroEnergy = carbEnergy + proteinEnergy + fatEnergy;
    if (macroEnergy <= 0) return null;
    return NutritionGoalTarget(
      calories: targets.calories.toDouble(),
      carbsPercent: carbEnergy / macroEnergy * 100,
      proteinPercent: proteinEnergy / macroEnergy * 100,
      fatPercent: fatEnergy / macroEnergy * 100,
    );
  }

  Future<void> _resetToRecommended() async {
    final target = _recommendedTarget();
    if (target == null) {
      _snack(
        nutritionText(
          context,
          'Complete your profile first.',
          'أكمل ملفك الشخصي أولاً.',
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dietPlanRepositoryProvider).resetToRecommended(target);
      if (!mounted) return;
      setState(() {
        _applyRecommendedTarget(target);
        _active = false;
        _clinicianAcknowledged = false;
      });
      ref.invalidate(nutritionGoalScheduleProvider);
      ref.invalidate(activeNutritionPathwayProvider);
      ref.invalidate(coachContextSnapshotProvider);
      _snack(
        nutritionText(
          context,
          'Recommended targets restored from your latest weight and goal.',
          'تمت استعادة الأهداف الموصى بها من أحدث وزن وهدف لك.',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyRecommendedTarget(NutritionGoalTarget target) {
    final extra = _isPregnancy
        ? (PregnancyNutritionGuidance.extraCaloriesByTrimester[_trimester] ?? 0)
        : 0.0;
    final editableCalories = math.max(.01, target.calories - extra);
    _calories.text = editableCalories.round().toString();
    final macroTarget = DietMacroTarget(
      calories: target.calories,
      carbsGrams: target.calories * target.carbsPercent / 100 / 4,
      proteinGrams: target.calories * target.proteinPercent / 100 / 4,
      fatGrams: target.calories * target.fatPercent / 100 / 9,
    );
    for (var day = 1; day <= 7; day += 1) {
      _resolvedTargets[day] = macroTarget;
      _writeTarget(day, macroTarget);
    }

    final proteinEnergy = target.calories * target.proteinPercent / 100;
    final fatEnergy = target.calories * target.fatPercent / 100;
    final remaining = proteinEnergy + fatEnergy;
    if (remaining <= 0) {
      _fatLevel = DietFatLevel.medium;
      return;
    }
    final desiredFatShare = fatEnergy / remaining;
    _fatLevel = DietFatLevel.values.reduce(
      (best, candidate) =>
          (candidate.remainingEnergyShare - desiredFatShare).abs() <
              (best.remainingEnergyShare - desiredFatShare).abs()
          ? candidate
          : best,
    );
  }

  void _snack(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  void dispose() {
    _calories.dispose();
    for (final controller in _carbs.values) {
      controller.dispose();
    }
    for (final controller in _protein.values) {
      controller.dispose();
    }
    for (final controller in _fat.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pathway = _pathway;
    if (pathway == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            nutritionText(
              context,
              'Diet not found',
              'لم يتم العثور على الدايت',
            ),
          ),
        ),
      );
    }
    final localeTag = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final draft = _draft();
    final week = draft?.resolveWeek();
    final restricted = pathway.safety != NutritionPathwaySafety.standard;
    final medicallyLocked =
        pathway.safety == NutritionPathwaySafety.medicalSupervision;
    final editable = !medicallyLocked;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(nutritionPathwayTitle(pathway, localeTag)),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('diet-plan-reset-recommended'),
            onPressed: _loading || _saving || medicallyLocked
                ? null
                : _resetToRecommended,
            tooltip: nutritionText(
              context,
              'Reset to recommended',
              'العودة إلى الموصى به',
            ),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE4E7EC))),
          ),
          child: FilledButton.icon(
            key: const Key('diet-plan-activate'),
            onPressed: _loading || _saving || medicallyLocked ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              medicallyLocked
                  ? nutritionText(
                      context,
                      'Medical supervision required',
                      'يتطلب إشرافًا طبيًا',
                    )
                  : _active
                  ? nutritionText(context, 'Save', 'حفظ تعديلات الأهداف')
                  : nutritionText(
                      context,
                      'Activate weekly targets',
                      'تفعيل أهداف الأسبوع',
                    ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                _DietHero(pathway: pathway, localeTag: localeTag),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: _EvidenceNotice(pathwayId: pathway.id),
                ),
                if (_isPregnancy)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: _PregnancyControls(
                      baseCaloriesController: _calories,
                      trimester: _trimester,
                      effectiveCalories: _effectiveCalories,
                      enabled: editable,
                      onChanged: _applyPregnancyDefaults,
                      onBaseChanged: (_) => _applyPregnancyDefaults(_trimester),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: _CaloriesField(
                      controller: _calories,
                      enabled: editable,
                      onChanged: _onCaloriesChanged,
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: _MacroEditingNotice(),
                ),
                if (_isPregnancy)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: _PregnancyNutrientGuide(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
                  child: Text(
                    nutritionText(
                      context,
                      'Your week · edit each day',
                      'أسبوعك · عدّل كل يوم',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                for (var day = 1; day <= 7; day += 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: _DietDayCard(
                      weekday: day,
                      carbController: _carbs[day]!,
                      proteinController: _protein[day]!,
                      fatController: _fat[day]!,
                      target: week?[day],
                      enabled: editable,
                      onCarbsChanged: (value) =>
                          _onMacroChanged(day, DietMacroComponent.carbs, value),
                      onProteinChanged: (value) => _onMacroChanged(
                        day,
                        DietMacroComponent.protein,
                        value,
                      ),
                      onFatChanged: (value) =>
                          _onMacroChanged(day, DietMacroComponent.fat, value),
                    ),
                  ),
                if (restricted)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    child: _ClinicianReview(
                      medicallyLocked: medicallyLocked,
                      enabled: editable,
                      acknowledged: _clinicianAcknowledged,
                      onChanged: medicallyLocked
                          ? null
                          : (value) => setState(
                              () => _clinicianAcknowledged = value ?? false,
                            ),
                    ),
                  ),
              ],
            ),
    );
  }
}
