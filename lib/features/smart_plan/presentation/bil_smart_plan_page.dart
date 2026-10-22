import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/bil_pearl_material.dart';
import '../../../app/theme/bil_pearl_finish.dart';
import '../../meal_planner/domain/meal_plan.dart';
import '../../nutrition/domain/dietary_preferences.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../data/bil_smart_plan_repository.dart';
import '../domain/bil_smart_plan.dart';
import '../domain/bil_smart_plan_engine.dart';
import '../services/bil_smart_plan_catalog.dart';

/// Local-first MVP surface. The authenticated owner and verified plan gate
/// are provided by AppRouter; no app-store or billing contract is changed.
class BilSmartPlanPage extends ConsumerStatefulWidget {
  const BilSmartPlanPage({super.key});

  @override
  ConsumerState<BilSmartPlanPage> createState() => _BilSmartPlanPageState();
}

class _BilSmartPlanPageState extends ConsumerState<BilSmartPlanPage> {
  BilSmartPlan? _plan;
  bool _busy = true;
  String? _error;
  int _tab = 0;
  int _weekOffset = 0;
  StreamSubscription<AuthState>? _authEvents;

  String _t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  String? get _owner => Supabase.instance.client.auth.currentUser?.id;

  BilSmartPlanRepository get _repository => BilSmartPlanRepository(
    preferences: ref.read(preferencesRepositoryProvider),
    currentOwnerId: () => Supabase.instance.client.auth.currentUser?.id,
  );

  @override
  void initState() {
    super.initState();
    _authEvents = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      setState(() { _plan = null; _busy = true; _error = null; });
      unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _authEvents?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final owner = _owner;
    if (owner == null) {
      if (mounted) setState(() {
        _busy = false; _error = 'sign_in_required'; _plan = null;
      });
      return;
    }
    try {
      final plan = await _repository.readFor(owner);
      if (!mounted || _owner != owner) return;
      setState(() { _plan = plan; _error = null; _busy = false; });
    } on Object catch (error) {
      if (!mounted || _owner != owner) return;
      setState(() {
        _plan = null; _busy = false; _error = error.toString();
      });
    }
  }

  Future<void> _save(BilSmartPlan next, {required int prior}) async {
    final owner = _owner;
    if (owner == null || next.ownerId != owner) return;
    setState(() => _busy = true);
    try {
      final saved = await _repository.save(next, expectedRevision: prior);
      if (!mounted || _owner != owner) return;
      setState(() { _plan = saved; _busy = false; _error = null; });
    } on Object catch (error) {
      if (!mounted || _owner != owner) return;
      setState(() { _busy = false; _error = error.toString(); });
      await _load();
    }
  }

  Future<void> _createPlan() async {
    if (_busy || _plan != null || _owner == null) return;
    final request = await showBilPearlBottomSheet<_PlanOptions>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const _PlanCreationSheet(),
    );
    if (!mounted || request == null) return;
    final owner = _owner;
    if (owner == null) return;
    setState(() => _busy = true);
    try {
      final dietary = await ref.read(dietaryPreferencesRepositoryProvider).read();
      final catalog = const BilSmartPlanCatalog();
      final gym = request.focus == BilPlanFocus.nutrition
          ? <BilVerifiedWorkout>[]
          : await catalog.gymSessions();
      final recipes = request.focus == BilPlanFocus.training
          ? <BilVerifiedRecipe>[]
          : catalog.recipes(
              dietary: dietary,
              preferences: MealPlanPreferences(diet: request.diet),
            );
      if (!mounted || _owner != owner) return;
      final creation = BilPlanCreationRequest(
        ownerId: owner,
        planId: const Uuid().v4(),
        startOn: DateTime.now(),
        horizon: request.horizon,
        focus: request.focus,
        workoutsPerWeek: request.focus == BilPlanFocus.nutrition
            ? 0 : request.workoutsPerWeek,
        confirmedPreferences: request.confirmedPreferences,
        workoutCatalog: gym,
        recipeCatalog: recipes,
        highRiskSymptoms: request.highRiskSymptoms,
        underMedicalReview: request.needsMedicalReview,
      );
      final safety = BilPlanSafety.assess(creation);
      if (safety.result != BilPlanSafetyResult.ready) {
        throw StateError(safety.reasons.join(', '));
      }
      final plan = const BilSmartPlanEngine().generate(
        creation, DateTime.now(),
      );
      await _save(plan, prior: 0);
    } on Object catch (error) {
      if (!mounted || _owner != owner) return;
      setState(() { _busy = false; _error = error.toString(); });
    }
  }

  Future<void> _changeStatus(BilPlanStatus target) async {
    final current = _plan;
    if (current == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        title: Text(_t('Confirm plan change', 'تأكيد تغيير حالة الخطة')),
        content: Text(target == BilPlanStatus.active
          ? _t('Activate this draft? Meals remain suggestions; nothing is logged automatically.',
              'اعتماد هذه المسودة؟ الوجبات مقترحات فقط ولن يُسجّل أي شيء تلقائيًا.')
          : _t('Pause your schedule? Existing records will stay unchanged.',
              'إيقاف الخطة مؤقتًا؟ لن تتغير سجلاتك السابقة.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: Text(_t('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: Text(_t('Confirm', 'تأكيد'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(current.withStatus(target, DateTime.now()),
        prior: current.revision);
  }

  Future<void> _confirmWorkout(BilPlanDay day) async {
    final current = _plan;
    if (current == null || _busy || day.workout == null) return;
    final completed = day.workout!.completed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        title: Text(completed
            ? _t('Undo completion?', 'التراجع عن إكمال التمرين؟')
            : _t('Did you finish this workout?', 'هل أنهيت هذا التمرين؟')),
        content: Text(_t('This confirms an actual workout, not merely a planned session.',
            'هذا تأكيد لتمرين تم تنفيذه فعلًا، وليس لمجرد وجوده بالخطة.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: Text(_t('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: Text(_t('Confirm', 'تأكيد'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final revised = current.recordWorkout(
        date: BilPlanDate.parse(day.date),
        now: DateTime.now(), completed: !completed,
      );
      await _save(revised, prior: current.revision);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Widget _panel({required Widget child}) => BilPearlMaterialCard(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _today(BilSmartPlan plan) {
    final day = plan.onDate(DateTime.now());
    if (day == null) return _panel(child: Text(_t(
      'This period has no session for today. Review the schedule or create a new period after completion.',
      'لا توجد جلسة مقررة اليوم ضمن هذه الفترة. راجع الجدول أو أنشئ فترة جديدة بعد انتهاء الخطة.',
    )));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_t('Today', 'اليوم'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(day.date, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          if (day.workout == null)
            Text(_t('Recovery / no workout scheduled', 'راحة / لا يوجد تمرين مجدول'))
          else ...[
            Text(_workoutTitle(day.workout!.templateId),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_t('Verified exercise references: ', 'عدد التمارين الموثقة: ') +
                day.workout!.exerciseIds.length.toString() +
                _t(' · Estimated session: ', ' · مدة الجلسة: ') +
                day.workout!.minutes.toString() + _t(' min', ' دقيقة')),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const ValueKey('bil-smart-plan-workout-steps'),
              title: Text(_t('Exercises in this session', 'تمارين هذه الجلسة')),
              children: [
                for (final id in day.workout!.exerciseIds)
                  ListTile(dense: true,
                    title: Text(const BilSmartPlanCatalog().exerciseTitle(id))),
              ],
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/wellness/workouts/routines'),
                icon: const Icon(Icons.fitness_center_outlined),
                label: Text(_t('Verified workout library', 'مكتبة التمارين الموثقة')),
              ),
              if (plan.status == BilPlanStatus.active)
                FilledButton.icon(
                  key: const ValueKey('bil-smart-plan-complete-workout'),
                  onPressed: _busy ? null : () => _confirmWorkout(day),
                  icon: Icon(day.workout!.completed
                      ? Icons.undo_rounded : Icons.check_circle_outline),
                  label: Text(day.workout!.completed
                      ? _t('Undo completion', 'تراجع')
                      : _t('Mark completed', 'إكمال التمرين')),
                ),
            ]),
          ],
        ],
      )),
      if (day.meals.isNotEmpty) _panel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_t('Suggested meals', 'الوجبات المقترحة'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(_t('Suggestions are not meal log entries.',
              'الاقتراحات لا تعني أن الوجبات تم تناولها أو تسجيلها.')),
          for (final meal in day.meals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restaurant_menu_rounded),
              title: Text(const BilSmartPlanCatalog().recipeTitle(meal.recipeId)),
              subtitle: Text(_mealSlot(meal.slot)),
            ),
          OutlinedButton.icon(
            onPressed: () => context.push('/meal-planner'),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(_t('Review meals', 'مراجعة الوجبات')),
          ),
        ],
      )),
    ]);
  }

  String _workoutTitle(String id) => switch (id) {
    'push-a' || 'push-b' => _t('Push session', 'تمارين الدفع'),
    'pull-a' || 'pull-b' => _t('Pull session', 'تمارين السحب'),
    'legs-a' || 'legs-b' => _t('Leg session', 'تمارين الرجلين'),
    _ => _t('Verified training session', 'جلسة تدريب موثقة'),
  };

  String _horizonName(BilPlanHorizon value) => switch (value) {
    BilPlanHorizon.week => _t('One week', 'أسبوع'),
    BilPlanHorizon.month => _t('One month', 'شهر'),
    BilPlanHorizon.threeMonths => _t('Three months', '3 أشهر'),
    BilPlanHorizon.sixMonths => _t('Six months', '6 أشهر'),
  };

  String _statusName(BilPlanStatus value) => switch (value) {
    BilPlanStatus.draft => _t('Draft', 'مسودة'),
    BilPlanStatus.active => _t('Active', 'نشطة'),
    BilPlanStatus.paused => _t('Paused', 'متوقفة مؤقتًا'),
    BilPlanStatus.completed => _t('Completed', 'مكتملة'),
  };

  String _mealSlot(BilPlanMealSlot slot) => switch (slot) {
    BilPlanMealSlot.breakfast => _t('Breakfast', 'الفطور'),
    BilPlanMealSlot.lunch => _t('Lunch', 'الغداء'),
    BilPlanMealSlot.dinner => _t('Dinner', 'العشاء'),
  };

  Widget _schedule(BilSmartPlan plan) {
    final first = _weekOffset * 7;
    final visible = plan.days.skip(first).take(7).toList(growable: false);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
          key: const ValueKey('bil-smart-plan-previous-week'),
          onPressed: first <= 0 ? null : () => setState(() => _weekOffset--),
          icon: const Icon(Icons.chevron_left_rounded)),
        Text(_t('Week ', 'الأسبوع ') + (_weekOffset + 1).toString()),
        IconButton(
          key: const ValueKey('bil-smart-plan-next-week'),
          onPressed: first + 7 >= plan.days.length ? null
              : () => setState(() => _weekOffset++),
          icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      for (final day in visible)
        _panel(child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(day.workout == null
              ? Icons.self_improvement_rounded : Icons.fitness_center_outlined),
          title: Text(day.date),
          subtitle: Text(day.workout == null
              ? _t('Rest / recovery', 'راحة / استشفاء')
              : _workoutTitle(day.workout!.templateId)),
          trailing: day.workout?.completed == true
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.chevron_right),
          onTap: () => _showDay(day),
        )),
    ]);
  }

  Future<void> _showDay(BilPlanDay day) async {
    await showBilPearlBottomSheet<void>(
      context: context, useSafeArea: true, isScrollControlled: true,
      builder: (context) => SafeArea(child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Text(day.date, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(day.workout == null ? _t('Recovery day', 'يوم راحة') :
              _workoutTitle(day.workout!.templateId)),
          for (final id in day.workout?.exerciseIds ?? const <String>[])
            ListTile(title: Text(const BilSmartPlanCatalog().exerciseTitle(id))),
          for (final meal in day.meals)
            ListTile(title: Text(
              const BilSmartPlanCatalog().recipeTitle(meal.recipeId)),
              subtitle: Text(_mealSlot(meal.slot))),
        ],
      )),
    );
  }

  Widget _progress(BilSmartPlan plan) {
    final done = plan.days.where((day) =>
        day.workout?.completed == true).length;
    final scheduled = plan.days.where((day) => day.workout != null).length;
    return _panel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('Training progress', 'تقدم التدريب'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: plan.workoutCompletion),
        const SizedBox(height: 10),
        Text(done.toString() + ' / ' + scheduled.toString() +
            _t(' confirmed sessions', ' جلسات مؤكدة')),
        const SizedBox(height: 12),
        Text(_t('Nutrition suggestions do not count as actual intake. Review the diary for recorded food.',
            'الوجبات المقترحة لا تُحسب كطعام مأكول. راجع سجل الطعام للاستهلاك الفعلي.')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('My Smart Plan', 'خطتي الذكية')),
        actions: [
          IconButton(onPressed: _busy ? null : _load,
              tooltip: _t('Refresh', 'تحديث'), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: BilPearlBackdrop(
        child: SafeArea(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              _panel(child: Row(children: [
                Icon(Icons.calendar_month_rounded, size: 30, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('BIL Smart Plan', 'BIL خطتي الذكية'),
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(_t('Your plan stays available without AI chat.',
                        'خطتك متاحة حتى لو تعذّر رد المدرب.')),
                  ],
                )),
              ])),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) _panel(child: Text(
                _t('Action not completed. Please review saved data and retry.',
                    'لم تكتمل العملية. راجع البيانات المحفوظة وحاول مجددًا.'),
                key: const ValueKey('bil-smart-plan-error'),
              )),
              if (!_busy && plan == null) _panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('Create your first plan', 'أنشئ خطتك الأولى'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_t('Select a duration, goal and verified catalog. You approve the draft before it becomes active.',
                      'اختر المدة والهدف والكتالوج الموثق، ثم راجع المسودة واعتمدها.')),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const ValueKey('bil-smart-plan-create'),
                    onPressed: _createPlan,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(_t('Create plan', 'إنشاء خطة')),
                  ),
                ],
              )),
              if (plan != null) ...[
                _panel(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.startDate + ' · ' + _horizonName(plan.horizon),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(_t('Status: ', 'الحالة: ') + _statusName(plan.status)),
                    const SizedBox(height: 8),
                    if (plan.status == BilPlanStatus.draft ||
                        plan.status == BilPlanStatus.paused)
                      FilledButton.icon(
                        onPressed: _busy ? null : () =>
                            _changeStatus(BilPlanStatus.active),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(_t('Approve and activate', 'اعتماد وتفعيل')),
                      ),
                    if (plan.status == BilPlanStatus.active)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () =>
                            _changeStatus(BilPlanStatus.paused),
                        icon: const Icon(Icons.pause_circle_outline),
                        label: Text(_t('Pause plan', 'إيقاف مؤقت')),
                      ),
                  ],
                )),
                SegmentedButton<int>(
                  key: const ValueKey('bil-smart-plan-tabs'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 0, label: Text(_t('Today','اليوم'))),
                    ButtonSegment(value: 1, label: Text(_t('Week','الجدول'))),
                    ButtonSegment(value: 2, label: Text(_t('Progress','التقدم'))),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (value) => setState(() => _tab = value.first),
                ),
                const SizedBox(height: 14),
                if (_tab == 0) _today(plan),
                if (_tab == 1) _schedule(plan),
                if (_tab == 2) _progress(plan),
              ],
              const SizedBox(height: 8),
              Text(_t(
                'BIL is for fitness and nutrition organization, not medical diagnosis or treatment. Consult a qualified professional for medical decisions.',
                'BIL لتنظيم التغذية والرياضة وليس للتشخيص أو العلاج. استشر مختصًا للقرارات الطبية.',
              ), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ))),
      ),
    );
  }
}

final class _PlanOptions {
  const _PlanOptions({
    required this.horizon, required this.focus,
    required this.workoutsPerWeek, required this.diet,
    required this.confirmedPreferences,
    required this.highRiskSymptoms, required this.needsMedicalReview,
  });
  final BilPlanHorizon horizon;
  final BilPlanFocus focus;
  final int workoutsPerWeek;
  final MealPlanDiet diet;
  final bool confirmedPreferences, highRiskSymptoms, needsMedicalReview;
}

class _PlanCreationSheet extends StatefulWidget {
  const _PlanCreationSheet();

  @override
  State<_PlanCreationSheet> createState() => _PlanCreationSheetState();
}

class _PlanCreationSheetState extends State<_PlanCreationSheet> {
  BilPlanHorizon horizon = BilPlanHorizon.month;
  BilPlanFocus focus = BilPlanFocus.combined;
  MealPlanDiet diet = MealPlanDiet.balanced;
  int sessions = 3;
  bool confirmedPreferences = false;
  bool riskSymptoms = false;
  bool medicalReview = false;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String arabic) => ar ? arabic : en;
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('Create a reviewable plan', 'إنشاء خطة للمراجعة'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(t('Select a duration', 'اختر المدة')),
          DropdownButton<BilPlanHorizon>(
            isExpanded: true, value: horizon,
            items: [
              for (final item in BilPlanHorizon.values)
                DropdownMenuItem(
                  value: item,
                  child: Text(switch (item) {
                    BilPlanHorizon.week => t('One week','أسبوع'),
                    BilPlanHorizon.month => t('One month','شهر'),
                    BilPlanHorizon.threeMonths => t('Three months','3 أشهر'),
                    BilPlanHorizon.sixMonths => t('Six months','6 أشهر'),
                  }),
                ),
            ],
            onChanged: (value) => setState(() => horizon = value ?? horizon),
          ),
          Text(t('Focus', 'نوع الخطة')),
          DropdownButton<BilPlanFocus>(
            isExpanded: true, value: focus,
            items: [
              DropdownMenuItem(value: BilPlanFocus.combined,
                child: Text(t('Training and nutrition','تدريب وتغذية'))),
              DropdownMenuItem(value: BilPlanFocus.training,
                child: Text(t('Training only','تدريب فقط'))),
              DropdownMenuItem(value: BilPlanFocus.nutrition,
                child: Text(t('Nutrition only','تغذية فقط'))),
            ],
            onChanged: (value) => setState(() => focus = value ?? focus),
          ),
          if (focus != BilPlanFocus.nutrition) ...[
            Text(t('Gym sessions per week: ', 'جلسات الجيم أسبوعيًا: ') +
                sessions.toString()),
            Slider(value: sessions.toDouble(), min: 2, max: 6, divisions: 4,
              label: sessions.toString(),
              onChanged: (value) => setState(() => sessions = value.round())),
            Text(t('Uses only BIL verified gym catalog sessions. Home workouts will be added after their routines are validated.',
              'يستخدم فقط جلسات الجيم الموثقة في BIL. تُضاف تمارين المنزل بعد اعتماد جداولها.')),
          ],
          if (focus != BilPlanFocus.training)
            DropdownButton<MealPlanDiet>(
              isExpanded: true, value: diet,
              items: [
                DropdownMenuItem(value: MealPlanDiet.balanced,
                  child: Text(t('Balanced recipes','وجبات متوازنة'))),
                DropdownMenuItem(value: MealPlanDiet.vegetarian,
                  child: Text(t('Vegetarian recipes','وجبات نباتية'))),
                DropdownMenuItem(value: MealPlanDiet.highProtein,
                  child: Text(t('High-protein recipes','وجبات عالية البروتين'))),
              ],
              onChanged: (value) => setState(() => diet = value ?? diet),
            ),
          CheckboxListTile(
            value: confirmedPreferences,
            onChanged: (value) => setState(() =>
                confirmedPreferences = value ?? false),
            title: Text(t('I reviewed my dietary exclusions, allergies and training availability.',
                'راجعت قيود الطعام والحساسية وتوفر التدريب الخاص بي.')),
          ),
          CheckboxListTile(
            value: riskSymptoms,
            onChanged: (value) => setState(() => riskSymptoms = value ?? false),
            title: Text(t('I have concerning symptoms or an injury affecting exercise.',
                'لدي أعراض مقلقة أو إصابة تؤثر على التمرين.')),
          ),
          CheckboxListTile(
            value: medicalReview,
            onChanged: (value) => setState(() => medicalReview = value ?? false),
            title: Text(t('My diet or training requires clinician supervision.',
                'نظامي الغذائي أو تدريبي يحتاج متابعة طبية.')),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('bil-smart-plan-review-draft'),
            onPressed: confirmedPreferences && !riskSymptoms && !medicalReview
                ? () => Navigator.pop(context, _PlanOptions(
                    horizon: horizon, focus: focus,
                    workoutsPerWeek: sessions, diet: diet,
                    confirmedPreferences: confirmedPreferences,
                    highRiskSymptoms: riskSymptoms,
                    needsMedicalReview: medicalReview,
                  ))
                : null,
            child: Text(t('Prepare a draft', 'تجهيز المسودة')),
          ),
          const SizedBox(height: 8),
          Text(t('No HealthKit writes, food logging, or AI submission occurs when preparing a draft.',
              'إنشاء المسودة لا يكتب في HealthKit أو سجل الطعام ولا يرسل بيانات إلى الذكاء الاصطناعي.')),
        ],
      )),
    ));
  }
}
