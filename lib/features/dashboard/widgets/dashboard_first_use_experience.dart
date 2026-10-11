import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/first_meal_milestone.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../providers/dashboard_provider.dart';
import 'first_meal_celebration.dart';
import 'first_use_context_coachmark.dart';
import '../../../shared/widgets/first_use_guide_anchor.dart';

final _firstFoodMilestoneStatusProvider = StreamProvider<String?>(
  (ref) => ref
      .watch(preferencesRepositoryProvider)
      .watch(firstMealCelebrationPreferenceKey),
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

  Future<void> _finish({required bool openFood, String? expectedScope}) async {
    if (expectedScope != null && widget.ownerScope != expectedScope) return;
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
    if (openFood) context.go('/daily-log?foodLog=1&guide=1&from=%2Fdashboard');
  }

  String _guideCopy(
    BuildContext context,
    String en,
    String ar,
    String fr,
    String es,
    String tr,
  ) => switch (Localizations.localeOf(context).languageCode) {
    'ar' => ar,
    'fr' => fr,
    'es' => es,
    'tr' => tr,
    _ => en,
  };

  @override
  Widget build(BuildContext context) {
    final meals = ref.watch(allMealsProvider);
    final firstFoodStatus = ref.watch(_firstFoodMilestoneStatusProvider);
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
    final guideScope = widget.ownerScope;
    final anchor = FirstUseGuideAnchor.maybeOf(context);
    if (needsGuide && anchor != null) {
      return FirstUseAnchoredGuide(
        anchor: anchor,
        onStart: () => _finish(openFood: true, expectedScope: guideScope),
        onSkip: () => _finish(openFood: false, expectedScope: guideScope),
        guide: FirstUseContextCoachmark(
          key: const Key('dashboard-food-guide-anchored'),
          title: _guideCopy(
            context,
            'Log your first meal!',
            'سجّل أول وجبة!',
            'Enregistrez votre premier repas !',
            '¡Registra tu primera comida!',
            'İlk öğününü kaydet!',
          ),
          message: _guideCopy(
            context,
            'Tap Add to begin. Find your food, choose the portion, then save your meal.',
            'اضغط زر الإضافة لنبدأ. ابحث عن طعامك، حدّد الكمية ثم احفظ وجبتك.',
            'Appuyez sur Ajouter. Recherchez votre aliment, choisissez la portion et confirmez.',
            'Pulsa Añadir. Busca tu alimento, elige la porción y confirma.',
            'Ekle’ye dokun. Yemeğini ara, porsiyonu seç ve onayla.',
          ),
          compact: true,
          pointerAlignment: Alignment.center,
          onSkip: () => _finish(openFood: false),
          skipKey: const Key('dashboard-guide-skip'),
          onAction: () => anchor.openMenu?.call(),
          actionLabel: _guideCopy(
            context,
            'Let’s begin',
            'لنبدأ',
            'Commençons',
            'Empecemos',
            'Başlayalım',
          ),
          actionKey: const Key('dashboard-guide-next'),
        ),
        child: widget.child,
      );
    }
    // Standalone surfaces without a shell anchor retain accessible inline guidance.
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
          accent: second ? const Color(0xFF9ACBFF) : const Color(0xFF95F5E1),
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
