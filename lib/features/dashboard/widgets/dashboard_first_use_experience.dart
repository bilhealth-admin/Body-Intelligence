import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/first_meal_milestone.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../providers/dashboard_provider.dart';
import 'first_meal_celebration.dart';
import 'first_use_context_coachmark.dart';

final _firstFoodMilestoneStatusProvider = StreamProvider<String?>(
  (ref) => ref
      .watch(preferencesRepositoryProvider)
      .watch(firstMealCelebrationPreferenceKey),
);

final _firstFoodStreakStatusProvider = StreamProvider<String?>(
  (ref) => ref
      .watch(preferencesRepositoryProvider)
      .watch(firstMealStreakGuidePreferenceKey),
);

/// Non-modal food walkthrough. Skip is always available and never changes data.
class DashboardFirstUseExperience extends ConsumerStatefulWidget {
  const DashboardFirstUseExperience({
    super.key,
    required this.ownerScope,
    required this.ownerReady,
    required this.child,
  });

  final String ownerScope;
  final bool ownerReady;
  final Widget child;

  @override
  ConsumerState<DashboardFirstUseExperience> createState() =>
      _DashboardFirstUseExperienceState();
}

class _DashboardFirstUseExperienceState
    extends ConsumerState<DashboardFirstUseExperience> {
  bool _ready = false;
  bool _canGuide = false;
  bool _saving = false;
  bool _streakDismissed = false;
  int _step = 0;

  String get _guideKey =>
      'experience.dashboard_food_guide.v1.${widget.ownerScope}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant DashboardFirstUseExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerScope != widget.ownerScope ||
        oldWidget.ownerReady != widget.ownerReady) {
      _ready = false;
      _canGuide = false;
      _saving = false;
      _streakDismissed = false;
      _step = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted || !widget.ownerReady) return;
    final scope = widget.ownerScope;
    final preferences = ref.read(preferencesRepositoryProvider);
    String? prior;
    try {
      prior = await preferences.get(_guideKey);
    } catch (_) {
      prior = 'unavailable';
    }
    if (!mounted || widget.ownerScope != scope || !widget.ownerReady) return;
    setState(() {
      _ready = true;
      _canGuide = prior == null;
    });
    if (mounted && widget.ownerScope == scope) {
      await FirstMealCelebration.showIfPending(context, preferences);
    }
  }

  Future<void> _finish({required bool openFood}) async {
    if (_saving) return;
    final scope = widget.ownerScope;
    final key = _guideKey;
    final preferences = ref.read(preferencesRepositoryProvider);
    setState(() {
      _saving = true;
      _canGuide = false;
    });
    try {
      await preferences.set(key, openFood ? 'started' : 'dismissed');
    } catch (_) {
      // Skip always works for this visit when persistence is unavailable.
    }
    // A stale callback must never navigate a different signed-in owner.
    if (!mounted || !widget.ownerReady || widget.ownerScope != scope) return;
    setState(() => _saving = false);
    if (openFood) context.go('/daily-log?foodLog=1&from=%2Fdashboard');
  }

  Future<void> _dismissStreak() async {
    if (_streakDismissed) return;
    final scope = widget.ownerScope;
    setState(() => _streakDismissed = true);
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set(firstMealStreakGuidePreferenceKey, 'seen');
    } on Object {
      // This optional guide must never trap the user on a storage error.
    }
    if (!mounted || widget.ownerScope != scope) return;
  }

  @override
  Widget build(BuildContext context) {
    final meals = ref.watch(allMealsProvider);
    final firstFoodStatus = ref.watch(_firstFoodMilestoneStatusProvider);
    final streakStatus = ref.watch(_firstFoodStreakStatusProvider);
    // Empty meal buckets are not evidence of a recorded food item, and a
    // previously celebrated/deleted first food must not reopen onboarding.
    final hasLoggedFood =
        meals.value?.any((meal) => meal.items.isNotEmpty) ?? false;
    final needsGuide =
        widget.ownerReady &&
        _ready &&
        _canGuide &&
        meals.hasValue &&
        firstFoodStatus.hasValue &&
        firstFoodStatus.value == null &&
        !hasLoggedFood;
    final needsStreakGuide =
        widget.ownerReady &&
        _ready &&
        !_streakDismissed &&
        !needsGuide &&
        meals.hasValue &&
        hasLoggedFood &&
        firstFoodStatus.value == 'done' &&
        streakStatus.value == 'ready';
    // Put the optional walkthrough in the normal Home scroll flow.
    // A fixed bottom overlay covered calories/weight and could intercept
    // underlying controls, especially with large text or narrow viewports.
    return Column(
      key: const Key('dashboard-first-use-inline-region'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (needsGuide) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _FoodGuideStep(
                step: _step,
                saving: _saving,
                onSkip: () => _finish(openFood: false),
                onNext: () {
                  if (_step == 0) {
                    setState(() => _step = 1);
                  } else {
                    _finish(openFood: true);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (needsStreakGuide) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _StreakGuideStep(onFinish: _dismissStreak),
            ),
          ),
          const SizedBox(height: 12),
        ],
        widget.child,
      ],
    );
  }
}

class _FoodGuideStep extends StatelessWidget {
  const _FoodGuideStep({
    required this.step,
    required this.saving,
    required this.onSkip,
    required this.onNext,
  });

  final int step;
  final bool saving;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  String _copy(
    BuildContext context, {
    required String en,
    required String ar,
    required String fr,
    required String es,
    required String tr,
  }) => switch (Localizations.localeOf(context).languageCode) {
    'ar' => ar,
    'fr' => fr,
    'es' => es,
    'tr' => tr,
    _ => en,
  };

  @override
  Widget build(BuildContext context) {
    final second = step == 1;
    final title = second
        ? _copy(
            context,
            en: 'Find your food',
            ar: 'ابحث عن طعامك',
            fr: 'Recherchez votre aliment',
            es: 'Busca tu alimento',
            tr: 'Yemeğini ara',
          )
        : _copy(
            context,
            en: 'Log your first meal!',
            ar: 'سجّل أول وجبة!',
            fr: 'Enregistrez votre premier repas !',
            es: '¡Registra tu primera comida!',
            tr: 'İlk öğününü kaydet!',
          );
    final message = second
        ? _copy(
            context,
            en: 'Search for a food, choose its serving, then confirm. Nothing is saved automatically.',
            ar: 'ابحث عن الطعام، حدّد الكمية، ثم أكّد الحفظ. لا نسجّل شيئًا تلقائيًا.',
            fr: 'Recherchez, choisissez la portion et confirmez.',
            es: 'Busca, elige la porción y confirma.',
            tr: 'Yemeği ara, porsiyonu seç ve onayla.',
          )
        : _copy(
            context,
            en: 'A quick guided start, completely optional.',
            ar: 'بداية تفاعلية سريعة، ويمكنك تخطيها متى شئت.',
            fr: 'Un départ guidé, entièrement facultatif.',
            es: 'Una introducción guiada y opcional.',
            tr: 'Tamamen isteğe bağlı kısa bir rehber.',
          );
    return Semantics(
      key: Key('dashboard-food-guide-step-$step'),
      container: true,
      child: AnimatedSwitcher(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 1 : 370,
        ),
        child: FirstUseContextCoachmark(
          key: ValueKey(step),
          title: title,
          message: message,
          step: step + 1,
          stepCount: 2,
          icon: second ? Icons.search_rounded : Icons.celebration_rounded,
          accent: second
              ? const Color(0xFF9ACBFF)
              : const Color(0xFF95F5E1),
          onAction: saving ? null : onNext,
          actionLabel: second
              ? _copy(
                  context,
                  en: 'Open Food Log',
                  ar: 'فتح تسجيل الطعام',
                  fr: 'Ouvrir le journal',
                  es: 'Abrir el diario',
                  tr: 'Yemek kaydını aç',
                )
              : _copy(
                  context,
                  en: 'Next',
                  ar: 'التالي',
                  fr: 'Suivant',
                  es: 'Siguiente',
                  tr: 'İleri',
                ),
          onSkip: onSkip,
          skipKey: const Key('dashboard-guide-skip'),
          actionKey: const Key('dashboard-guide-next'),
        ),
      ),
    );
  }
}

class _StreakGuideStep extends StatelessWidget {
  const _StreakGuideStep({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return FirstUseContextCoachmark(
      key: const Key('dashboard-first-food-streak-guide'),
      title: ar ? 'أول يوم في رحلتك!' : 'Day one of your journey!',
      message: ar
          ? 'سجلّك بدأ بالفعل. تابع أيامك هنا بعد كل وجبة، دون خطوات إضافية أو اشتراك.'
          : 'Your streak begins here. Come back after each meal to follow your days.',
      step: 3,
      stepCount: 3,
      icon: Icons.calendar_month_rounded,
      accent: const Color(0xFFFBD583),
      onAction: onFinish,
      actionLabel: ar ? 'رائع، فهمت' : 'Got it',
      onSkip: onFinish,
      skipKey: const Key('dashboard-streak-guide-skip'),
      actionKey: const Key('dashboard-streak-guide-done'),
    );
  }
}
