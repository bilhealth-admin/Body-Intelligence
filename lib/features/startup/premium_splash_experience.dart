import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const _bilSplashIdentityAsset = 'assets/branding/bil_splash_identity.png';
const bilSplashMotionAsset = 'assets/branding/bil_splash_motion.mp4';

/// The immutable MP4 contract: 60 frames at 30 fps.
const bilSplashMotionDuration = Duration(seconds: 2);

/// The deliberate Flutter identity window. Native Android is never delayed;
/// this begins only after Flutter has already painted its matching first frame.
const bilSplashMinimumDisplayDuration = Duration(milliseconds: 2300);

/// Bounds decoder/controller lifetime without participating in app routing.
/// StartupPage owns readiness and can therefore never wait on video playback.
const bilSplashPlaybackSafetyTimeout = bilSplashMinimumDisplayDuration;

/// Decoded before `runApp`, while Android is already showing the exact same
/// raster. RawImage can therefore paint Flutter's first frame without a flash.
ui.Image? bilPredecodedLaunchWordmark;

/// The exact BIL action blue shared by native Android and Flutter startup.
const bilLaunchBlue = Color(0xFF0877F9);

/// Presentation-only backdrop. Startup state and routing remain in StartupPage.
class PremiumSplashBackdrop extends StatelessWidget {
  const PremiumSplashBackdrop({this.animate = true, super.key});

  // Retained for compatibility with existing reduced-motion/golden harnesses.
  // The launch surface itself is deliberately motionless.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: ColoredBox(
        key: ValueKey('premium-splash-backdrop'),
        color: bilLaunchBlue,
      ),
    );
  }
}

/// The Flutter bootstrap frame. It uses one restrained capsule progress cue,
/// with no status copy, download state, or legacy spinner chrome.
class BilStartupLoadingSurface extends StatefulWidget {
  const BilStartupLoadingSurface({
    this.showSpinner = false,
    this.showLoadingLabel = false,
    super.key,
  });

  // Retained so existing call sites remain source-compatible. Both controls
  // are intentionally ignored by the 2026 seamless splash contract.
  final bool showSpinner;
  final bool showLoadingLabel;

  @override
  State<BilStartupLoadingSurface> createState() =>
      _BilStartupLoadingSurfaceState();
}

class _BilStartupLoadingSurfaceState extends State<BilStartupLoadingSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: bilSplashMinimumDisplayDuration,
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _progressController.stop(canceled: false);
      _progressController.value = 1;
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const PremiumSplashBackdrop(),
        const _SplashIdentity(),
        _PremiumSplashProgress(controller: _progressController),
      ],
    );
  }
}

class PremiumSplashExperience extends StatefulWidget {
  const PremiumSplashExperience({
    required this.controller,
    this.showSpinner = false,
    this.showLoadingLabel = false,
    this.showIdentity = true,
    super.key,
  });

  // Retained for source compatibility. StartupPage remains the sole owner of
  // readiness, routing, and minimum-display policy.
  final AnimationController controller;
  final bool showSpinner;
  final bool showLoadingLabel;
  final bool showIdentity;

  @override
  State<PremiumSplashExperience> createState() =>
      _PremiumSplashExperienceState();
}

class _PremiumSplashExperienceState extends State<PremiumSplashExperience> {
  VideoPlayerController? _videoController;
  Timer? _playbackSafetyTimer;
  bool _initializationScheduled = false;
  bool _videoInitialized = false;
  bool _videoHasDecodedFrame = false;

  bool get _shouldPlayVideo =>
      widget.showIdentity &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVideoLifecycle();
  }

  @override
  void didUpdateWidget(covariant PremiumSplashExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showIdentity != widget.showIdentity) {
      _syncVideoLifecycle();
    }
  }

  void _syncVideoLifecycle() {
    if (_shouldPlayVideo) {
      _scheduleVideoInitialization();
    } else {
      _releaseVideo();
    }
  }

  void _scheduleVideoInitialization() {
    if (_initializationScheduled || _videoController != null) return;
    _initializationScheduled = true;
    _playbackSafetyTimer?.cancel();
    _playbackSafetyTimer = Timer(
      bilSplashPlaybackSafetyTimeout,
      _handlePlaybackSafetyTimeout,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializationScheduled = false;
      if (!mounted || !_shouldPlayVideo || _videoController != null) return;
      unawaited(_initializeVideo());
    });
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset(
      bilSplashMotionAsset,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
      viewType: VideoViewType.textureView,
    );
    _videoController = controller;
    controller.addListener(_handleVideoValue);

    try {
      await controller.initialize();
      if (_videoController != controller) return;
      if (!mounted || !_shouldPlayVideo) {
        _videoController = null;
        _releaseController(controller);
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (_videoController != controller) return;
      if (!mounted) {
        _videoController = null;
        _releaseController(controller);
        return;
      }
      setState(() => _videoInitialized = true);
      await controller.play();
    } on Object {
      if (_videoController != controller) return;
      _videoController = null;
      _playbackSafetyTimer?.cancel();
      _playbackSafetyTimer = null;
      if (mounted) {
        setState(() {
          _videoInitialized = false;
          _videoHasDecodedFrame = false;
        });
      }
      _releaseController(controller);
    }
  }

  void _handleVideoValue() {
    final controller = _videoController;
    if (controller == null ||
        _videoHasDecodedFrame ||
        !controller.value.isInitialized ||
        controller.value.position <= Duration.zero ||
        !mounted) {
      return;
    }
    // Keep the synchronous raster above the texture until playback position
    // proves that Android decoded a real frame. This masks texture black-up.
    setState(() => _videoHasDecodedFrame = true);
  }

  void _releaseController(VideoPlayerController controller) {
    controller.removeListener(_handleVideoValue);
    unawaited(controller.dispose());
  }

  void _handlePlaybackSafetyTimeout() {
    _playbackSafetyTimer = null;
    final controller = _videoController;
    if (controller == null) return;
    _videoController = null;
    if (mounted) {
      setState(() {
        _videoInitialized = false;
        _videoHasDecodedFrame = false;
      });
    } else {
      _videoInitialized = false;
      _videoHasDecodedFrame = false;
    }
    _releaseController(controller);
  }

  void _releaseVideo() {
    _playbackSafetyTimer?.cancel();
    _playbackSafetyTimer = null;
    final controller = _videoController;
    if (controller == null) return;
    _videoController = null;
    _videoInitialized = false;
    _videoHasDecodedFrame = false;
    _releaseController(controller);
  }

  @override
  void dispose() {
    _playbackSafetyTimer?.cancel();
    final controller = _videoController;
    _videoController = null;
    if (controller != null) _releaseController(controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoController = _videoController;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'BODY INTELLIGENCE LOG',
      image: true,
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PremiumSplashBackdrop(),
            if (widget.showIdentity &&
                _videoInitialized &&
                videoController != null)
              RepaintBoundary(
                key: const ValueKey('premium-splash-video'),
                child: _CoverSplashVideo(controller: videoController),
              ),
            if (widget.showIdentity)
              AnimatedOpacity(
                key: const ValueKey('premium-splash-first-frame-fallback'),
                opacity: _videoHasDecodedFrame ? 0 : 1,
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                child: const _SplashIdentity(),
              ),
            if (widget.showIdentity)
              _PremiumSplashProgress(controller: widget.controller),
          ],
        ),
      ),
    );
  }
}

class _PremiumSplashProgress extends StatelessWidget {
  const _PremiumSplashProgress({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth * 0.34)
              .clamp(112.0, 176.0)
              .toDouble();
          return Align(
            alignment: const Alignment(0, 0.24),
            child: RepaintBoundary(
              key: const ValueKey('premium-splash-progress'),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final timelineValue = reducedMotion
                      ? 0.72
                      : controller.value.clamp(0.0, 1.0);
                  final eased = Curves.easeInOutCubicEmphasized.transform(
                    timelineValue,
                  );
                  final fill = 0.12 + (0.88 * eased);
                  final highlightX = ((width + 38) * eased) - 38;
                  return SizedBox(
                    width: width,
                    height: 7,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Color(0x38FFFFFF)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: fill,
                              heightFactor: 1,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xA8FFFFFF),
                                      Color(0xD6FFFFFF),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!reducedMotion)
                            Transform.translate(
                              offset: Offset(highlightX, 0),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 38,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00FFFFFF),
                                          Color(0xB8FFFFFF),
                                          Color(0x00FFFFFF),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CoverSplashVideo extends StatelessWidget {
  const _CoverSplashVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.isEmpty) return const SizedBox.expand();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(size: size, child: VideoPlayer(controller)),
      ),
    );
  }
}

class _SplashIdentity extends StatelessWidget {
  const _SplashIdentity();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : constraints.biggest.shortestSide;
        final identity = bilPredecodedLaunchWordmark == null
            ? Image.asset(
                _bilSplashIdentityAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              )
            : RawImage(
                image: bilPredecodedLaunchWordmark,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              );
        return ClipRect(
          child: Center(
            child: SizedBox.square(
              key: const ValueKey('premium-splash-wordmark'),
              dimension: frameWidth,
              child: Transform.scale(scale: 1.4, child: identity),
            ),
          ),
        );
      },
    );
  }
}
