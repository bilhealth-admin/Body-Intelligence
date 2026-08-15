import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../shared/widgets/bil_wordmark.dart';
import 'onboarding_locale_copy.dart';

part 'welcome/welcome_screen.dart';
part 'body_canvas/body_setup_canvas.dart';
part 'body_canvas/body_setup_canvas_actions.dart';
part 'body_canvas/body_setup_desktop.dart';
part 'body_canvas/body_setup_compact.dart';
part 'body_canvas/body_editors.dart';
part 'shared/calibration_components.dart';

enum BilSex { male, female }

enum BilUnits { metric, imperial }

enum BilGoal { loseFat, maintain, buildMuscle }

enum BilActivity { low, light, moderate, high, veryHigh }

class BilOnboardingDraft {
  String name = '';
  DateTime? birthDate;
  BilSex sex = BilSex.male;
  BilUnits units = BilUnits.metric;
  BilGoal goal = BilGoal.loseFat;
  BilActivity activity = BilActivity.moderate;
  bool sexConfirmed = false;
  bool goalConfirmed = false;
  bool activityConfirmed = false;
  double? weight;
  double? height;
  double? waist;
  double? neck;
}

class BilInitialPlan {
  const BilInitialPlan({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.weeklyPace,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final double weeklyPace;
}

/// Production presentation layer for BIL Body Calibration.
///
/// The host remains responsible for the scientific calculation and persistence
/// through [calculatePlan] and [onComplete]. This widget owns presentation-only
/// draft state and never writes health data by itself.
class BilFlagshipOnboarding extends StatefulWidget {
  const BilFlagshipOnboarding({
    super.key,
    required this.calculatePlan,
    required this.onComplete,
    this.onSignIn,
    this.showWelcome = true,
    this.initialDraft,
    this.onExitToWelcome,
  });

  final Future<BilInitialPlan> Function(BilOnboardingDraft draft) calculatePlan;
  final Future<void> Function(BilOnboardingDraft draft, BilInitialPlan plan)
  onComplete;
  final VoidCallback? onSignIn;
  final bool showWelcome;
  final BilOnboardingDraft? initialDraft;
  final VoidCallback? onExitToWelcome;

  @override
  State<BilFlagshipOnboarding> createState() => _BilFlagshipOnboardingState();
}

class _BilFlagshipOnboardingState extends State<BilFlagshipOnboarding> {
  late final BilOnboardingDraft _draft;
  late final PageController _pageController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final source = widget.initialDraft;
    _draft = BilOnboardingDraft()
      ..name = source?.name ?? ''
      ..birthDate = source?.birthDate
      ..sex = source?.sex ?? BilSex.male
      ..units = source?.units ?? BilUnits.metric
      ..goal = source?.goal ?? BilGoal.loseFat
      ..activity = source?.activity ?? BilActivity.moderate
      ..sexConfirmed = source?.sexConfirmed ?? false
      ..goalConfirmed = source?.goalConfirmed ?? false
      ..activityConfirmed = source?.activityConfirmed ?? false
      ..weight = source?.weight
      ..height = source?.height
      ..waist = source?.waist
      ..neck = source?.neck;
    _pageController = PageController(initialPage: widget.showWelcome ? 0 : 1);
  }

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  bool get _isRtl => const {
    'ar',
    'fa',
    'ur',
  }.contains(Localizations.localeOf(context).languageCode.toLowerCase());

  String tr(String en, String ar) => onboardingText(context, en, ar);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToStage(int stage) async {
    await _pageController.animateToPage(
      stage,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _buildPlan() async {
    setState(() => _busy = true);
    try {
      final plan = await widget.calculatePlan(_draft);
      if (!mounted) return;
      await widget.onComplete(_draft, plan);
    } catch (error, stack) {
      debugPrint('BIL calibration plan failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'BIL could not calculate the initial plan. Please review the values and try again.',
              'تعذر على BIL حساب الخطة الأولية. راجع القيم ثم حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _BilColors.background,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          brightness: Brightness.light,
          primary: _BilColors.emerald,
          secondary: _BilColors.cyan,
          surface: _BilColors.surface,
        ),
      ),
      child: Scaffold(
        body: Directionality(
          textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Stack(
            children: [
              const Positioned.fill(child: _AmbientBackground()),
              SafeArea(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _V9PageMotion(
                      controller: _pageController,
                      index: 0,
                      child: _CalibrationWelcome(
                        isArabic: _isRtl,
                        onContinue: () => _goToStage(1),
                        onSkip: widget.onSignIn,
                      ),
                    ),
                    _V9PageMotion(
                      controller: _pageController,
                      index: 1,
                      child: _BodySetupCanvas(
                        draft: _draft,
                        isArabic: _isRtl,
                        busy: _busy,
                        onBack: widget.showWelcome
                            ? () => _goToStage(0)
                            : (widget.onExitToWelcome ??
                                  () => Navigator.maybePop(context)),
                        onChanged: () => setState(() {}),
                        onContinue: _buildPlan,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V9PageMotion extends StatelessWidget {
  const _V9PageMotion({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final page = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final delta = (page - index).clamp(-1.0, 1.0);
        final visibility = (1 - delta.abs()).clamp(0.0, 1.0);
        return Opacity(
          opacity: Curves.easeOutCubic.transform(visibility),
          child: Transform.translate(
            offset: Offset(delta * -34, 0),
            child: Transform.scale(
              scale: .985 + visibility * .015,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
