import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/first_meal_milestone.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../providers/dashboard_provider.dart';
import 'first_meal_celebration.dart';

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
      await preferences.set(key, 'dismissed');
    } catch (_) {
      // Skip always works for this visit when persistence is unavailable.
    }
    // A stale callback must never navigate a different signed-in owner.
    if (!mounted || !widget.ownerReady || widget.ownerScope != scope) return;
    setState(() => _saving = false);
    if (openFood) context.go('/daily-log?foodLog=1&from=%2Fdashboard');
  }

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = second
        ? const Color(0xFF193E83)
        : dark
        ? const Color(0xFF172B40)
        : Colors.white;
    final foreground = second || dark ? Colors.white : const Color(0xFF16233A);
    final title = second
        ? _copy(
            context,
            en: 'Search for your food',
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
            en: 'Search, check the amount, and confirm. Nothing is saved automatically.',
            ar: 'ابحث عن طعامك وراجع الكمية ثم أكّدها. لن يُحفظ شيء تلقائيًا.',
            fr: 'Recherchez, vérifiez la quantité, puis confirmez.',
            es: 'Busca, revisa la cantidad y confirma.',
            tr: 'Yemeği ara, miktarı kontrol et ve onayla.',
          )
        : _copy(
            context,
            en: 'We can guide you. Skip at any time to explore freely.',
            ar: 'يمكننا إرشادك خطوة بخطوة. تخطَّ متى أردت واستخدم التطبيق بحرية.',
            fr: 'Nous pouvons vous guider. Ignorez ces conseils à tout moment.',
            es: 'Podemos guiarte. Puedes omitir los consejos.',
            tr: 'Size yol gösterebiliriz. İpuçlarını atlayabilirsiniz.',
          );
    return Semantics(
      key: Key('dashboard-food-guide-step-$step'),
      container: true,
      label: '$title. $message',
      child: Material(
        color: background,
        elevation: 7,
        shadowColor: Colors.black.withValues(alpha: .20),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.celebration_rounded, size: 24, color: foreground),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                message,
                style: TextStyle(
                  color: foreground.withValues(alpha: .88),
                  fontSize: 13,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 12),
              OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                overflowSpacing: 8,
                children: [
                  TextButton.icon(
                    key: const Key('dashboard-guide-skip'),
                    onPressed: saving ? null : onSkip,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: foreground,
                    ),
                    label: Text(
                      _copy(
                        context,
                        en: 'Skip',
                        ar: 'تخطي',
                        fr: 'Ignorer',
                        es: 'Omitir',
                        tr: 'Atla',
                      ),
                      style: TextStyle(color: foreground),
                    ),
                  ),
                  FilledButton(
                    key: const Key('dashboard-guide-next'),
                    onPressed: saving ? null : onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: second
                          ? Colors.white
                          : const Color(0xFF235DDC),
                      foregroundColor: second
                          ? const Color(0xFF193E83)
                          : Colors.white,
                    ),
                    child: Text(
                      second
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
