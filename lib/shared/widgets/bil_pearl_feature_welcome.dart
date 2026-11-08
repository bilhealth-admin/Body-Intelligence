import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../app/theme/bil_pearl_finish.dart';
import '../../app/theme/bil_flagship_tokens.dart';
import 'bil_splash_capsule_progress.dart';

/// The visual hold shared by internal feature entry surfaces. It never waits
/// for an asset, network request, authorization or first data page to finish.
const bilFeatureEntryDuration = Duration(milliseconds: 2200);

/// Matches the established Coach welcome title family. Other scripts retain
/// their platform fallback instead of being forced into a Latin-only font.
String? bilFeatureWelcomeDisplayFontFamily(Locale locale) =>
    switch (locale.languageCode.toLowerCase()) {
      'ar' || 'fa' || 'ur' => 'BILArabic',
      'en' ||
      'fr' ||
      'es' ||
      'tr' ||
      'de' ||
      'it' ||
      'pt' ||
      'id' ||
      'ms' ||
      'vi' ||
      'pl' ||
      'nl' => 'BILDisplay',
      _ => null,
    };

/// Opaque silver/pearl canvas: no destination pixels or text leak through.
/// Artwork is decorative; the actual feature title remains readable and
/// accessible in both themes. No pricing, entitlement or consent ownership.
class BilPearlFeatureWelcome extends StatelessWidget {
  const BilPearlFeatureWelcome({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artwork,
    this.artworkAspectRatio = 1,
    this.artworkWidth = 220,
    this.featherArtwork = true,
    this.statusLabel,
    this.leading,
    this.displayFontFamily,
  });

  final String title;
  final String subtitle;
  final Widget artwork;
  final double artworkAspectRatio;
  final double artworkWidth;
  final bool featherArtwork;
  final String? statusLabel;
  final Widget? leading;
  final String? displayFontFamily;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final ink = highContrast
        ? (dark ? Colors.white : Colors.black)
        : (dark ? BilPearlFinish.darkInk : BilPearlFinish.lightInk);
    final secondary = highContrast
        ? ink
        : (dark ? BilPearlFinish.darkSecondary : BilPearlFinish.lightSecondary);
    return DecoratedBox(
      key: const Key('bil-pearl-feature-canvas'),
      decoration: BoxDecoration(
        color: dark ? BilPearlFinish.darkCanvas : BilPearlFinish.lightSurface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, .52, 1],
          colors: dark
              ? const [Color(0xFF31414F), Color(0xFF141F2B), Color(0xFF23313C)]
              : const [Color(0xFFFDFEFF), Color(0xFFF1F4F7), Color(0xFFE3EAF0)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                key: const Key('bil-feature-welcome-scroll'),
                primary: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          leading == null ? 24 : 64,
                          28,
                          28,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(
                              child: SizedBox(
                                key: const Key('bil-feature-welcome-artwork'),
                                width: artworkWidth
                                    .clamp(
                                      0.0,
                                      (constraints.maxWidth - 56).clamp(
                                        0.0,
                                        double.infinity,
                                      ),
                                    )
                                    .toDouble(),
                                child: AspectRatio(
                                  aspectRatio: artworkAspectRatio,
                                  child: featherArtwork
                                      ? ShaderMask(
                                          blendMode: BlendMode.dstIn,
                                          shaderCallback: (bounds) =>
                                              const RadialGradient(
                                                radius: .5,
                                                colors: [
                                                  Colors.white,
                                                  Colors.white,
                                                  Colors.transparent,
                                                ],
                                                stops: [0, .58, 1],
                                              ).createShader(bounds),
                                          child: artwork,
                                        )
                                      : artwork,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              title,
                              key: const Key('bil-feature-welcome-title'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontFamily:
                                        displayFontFamily ??
                                        bilFeatureWelcomeDisplayFontFamily(
                                          Localizations.localeOf(context),
                                        ),
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              subtitle,
                              key: const Key('bil-feature-welcome-subtitle'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: secondary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 26),
                            BilFeatureWelcomeStatus(
                              color: highContrast
                                  ? ink
                                  : (dark
                                        ? const Color(0xFFBBC4CD)
                                        : const Color(0xFF697178)),
                              label: statusLabel,
                            ),
                            if (statusLabel != null) ...[
                              const SizedBox(height: 12),
                              ExcludeSemantics(
                                child: Text(
                                  statusLabel!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: secondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (leading != null)
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + 8,
              start: 12,
              child: leading!,
            ),
        ],
      ),
    );
  }
}

/// The startup capsule on every supported platform. The native
/// iOS reduceMotion flag is separate from MediaQuery.disableAnimations in the
/// pinned Flutter SDK, so changes to either must produce the static variant.
class BilFeatureWelcomeStatus extends StatefulWidget {
  const BilFeatureWelcomeStatus({super.key, this.color, this.label});
  final Color? color;
  final String? label;

  @override
  State<BilFeatureWelcomeStatus> createState() =>
      _BilFeatureWelcomeStatusState();
}

class _BilFeatureWelcomeStatusState extends State<BilFeatureWelcomeStatus>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _phase;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

  void _syncMotion() {
    if (_reduced) {
      _phase.stop(canceled: false);
      _phase.value = 0.72;
    } else if (!_phase.isAnimating) {
      // This repeats only while the real pending widget is mounted. No
      // percent, completion deadline or application state is inferred.
      _phase.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) {
      _syncMotion();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color =
        widget.color ??
        (MediaQuery.highContrastOf(context)
            ? (dark ? Colors.white : Colors.black)
            : (dark ? const Color(0xFF8CCFFF) : BilFlagshipTokens.navy800));
    final reduced = _reduced;
    return Semantics(
      liveRegion: true,
      label: widget.label,
      role: ui.SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 24,
          height: 24,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Preserve the former24x24 natural footprint, so an existing
              // adjacent waiting label keeps its exact position. Explicit
              // parent constraints still select compact or wide presentation.
              final width = constraints.constrainWidth(24);
              final height = constraints.constrainHeight(24);
              if (width <= 0 || height <= 0) return const SizedBox.shrink();
              final capsuleWidth = width.clamp(0.0, 112.0).toDouble();
              return SizedBox(
                width: width,
                height: height,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _phase,
                        builder: (context, _) => BilSplashCapsuleProgress(
                          key: Key(
                            reduced
                                ? 'bil-feature-welcome-static-status'
                                : 'bil-feature-welcome-progress',
                          ),
                          width: capsuleWidth,
                          progress: _phase.value,
                          reducedMotion: reduced,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
