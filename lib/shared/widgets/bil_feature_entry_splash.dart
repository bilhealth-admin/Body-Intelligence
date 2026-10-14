import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/bil_semantic_icons.dart';
import 'bil_pearl_feature_welcome.dart';

enum BilFeatureEntryKind { recipes, videos, sleep, diet }

/// Bundled photos already displayed by the protected Dashboard Discover tiles.
/// They are reused as-is, with no catalog/network dependency or generated art.
const bilFeatureEntryArtworkAssets = <BilFeatureEntryKind, String>{
  BilFeatureEntryKind.recipes:
      'assets/images/flagship/bil_meal_discovery_v1.png',
  BilFeatureEntryKind.videos: 'assets/images/flagship/bil_movement_v1.png',
  BilFeatureEntryKind.sleep: 'assets/images/flagship/bil_sleep_insights_v2.png',
  BilFeatureEntryKind.diet:
      'assets/images/nutrition_plans/carb_cycling_lifestyle_v1.webp',
};

// Preserve the approved photos' native proportions inside the feather mask.
// A portrait contained inside a square mask leaves a straight interior edge;
// covering that square cuts the face. Neither changes the original photo.
const bilFeatureEntryArtworkAspectRatios = <BilFeatureEntryKind, double>{
  BilFeatureEntryKind.recipes: 1024 / 1536,
  BilFeatureEntryKind.videos: 1024 / 1536,
  BilFeatureEntryKind.sleep: 1,
  BilFeatureEntryKind.diet: 1280 / 854,
};

/// Short flagship transition shown by production entry routes only.
///
/// The destination remains mounted underneath so its first data load can start
/// immediately. Input and semantics remain blocked until the splash releases.
class BilFeatureEntrySplashGate extends StatefulWidget {
  const BilFeatureEntrySplashGate({
    super.key,
    required this.kind,
    required this.child,
  });

  final BilFeatureEntryKind kind;
  final Widget child;

  @override
  State<BilFeatureEntrySplashGate> createState() =>
      _BilFeatureEntrySplashGateState();
}

class _BilFeatureEntrySplashGateState extends State<BilFeatureEntrySplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _releaseTimer;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    // The fixed visual hold is independent of first ticker frame / rounding.
    // Data readiness and native reduceMotion never extend or shorten it.
    _releaseTimer = Timer(bilFeatureEntryDuration, () {
      if (mounted) setState(() => _finished = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.duration = bilFeatureEntryDuration;
    _controller.forward();
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(
          absorbing: !_finished,
          child: ExcludeSemantics(excluding: !_finished, child: widget.child),
        ),
        if (!_finished)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              child: _BilFeatureEntrySplash(kind: widget.kind),
              builder: (context, splash) {
                final reduceMotion =
                    MediaQuery.disableAnimationsOf(context) ||
                    View.of(
                      context,
                    ).platformDispatcher.accessibilityFeatures.reduceMotion;
                final value = _controller.value;
                final fade = reduceMotion || value <= .92
                    ? 1.0
                    : (1 - ((value - .92) / .08)).clamp(0.0, 1.0);
                // Let the welcome itself scroll at large font sizes. The
                // destination remains blocked by AbsorbPointer above.
                return Opacity(opacity: fade, child: splash);
              },
            ),
          ),
      ],
    );
  }
}

class _BilFeatureEntrySplash extends StatelessWidget {
  const _BilFeatureEntrySplash({required this.kind});

  final BilFeatureEntryKind kind;

  @override
  Widget build(BuildContext context) {
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final data = switch (kind) {
      BilFeatureEntryKind.recipes => (
        icon: BilSemanticIconKind.recipes,
        title: arabic ? 'وصفات BIL' : 'BIL Recipes',
        subtitle: arabic
            ? 'وصفات موثوقة، مرتبة لتصل لما يناسبك بسرعة'
            : 'Trusted recipes, organized for fast discovery',
      ),
      BilFeatureEntryKind.videos => (
        icon: BilSemanticIconKind.exercise,
        title: arabic ? 'فيديوهات BIL' : 'BIL Videos',
        subtitle: arabic
            ? 'تدريب مرئي واضح من مكتبتك الموثوقة'
            : 'Clear visual training from your trusted library',
      ),
      BilFeatureEntryKind.sleep => (
        icon: BilSemanticIconKind.sleep,
        title: arabic ? 'ذكاء النوم' : 'Sleep Intelligence',
        subtitle: arabic
            ? 'افهم نومك من السجلات والقياسات الحقيقية'
            : 'Understand sleep from your real records and measurements',
      ),
      BilFeatureEntryKind.diet => (
        icon: BilSemanticIconKind.nutrition,
        title: arabic ? 'المسارات الغذائية' : 'Nutrition pathways',
        subtitle: arabic
            ? 'قارن أولًا. تبقى أهدافك تحت اختيارك.'
            : 'Compare first. Your goals stay in your control.',
      ),
    };
    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Semantics(
        key: ValueKey('feature-entry-splash-${kind.name}'),
        container: true,
        child: BilPearlFeatureWelcome(
          title: data.title,
          subtitle: data.subtitle,
          statusLabel: arabic ? 'جارٍ التحضير…' : 'Preparing…',
          // Shared Community/Coach surface; fit each photo without a crop.
          artworkWidth:
              kind == BilFeatureEntryKind.recipes ||
                  kind == BilFeatureEntryKind.videos
              ? 220
              : 440,
          artworkAspectRatio: bilFeatureEntryArtworkAspectRatios[kind]!,
          artwork: Image.asset(
            bilFeatureEntryArtworkAssets[kind]!,
            key: ValueKey('feature-entry-artwork-${kind.name}'),
            fit: BoxFit.contain,
            alignment: Alignment.center,
            cacheWidth: 900,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Icon(
              BilSemanticIcons.spec(data.icon).icon,
              key: ValueKey('feature-entry-artwork-fallback-${kind.name}'),
              size: 84,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
