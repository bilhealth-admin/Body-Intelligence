import 'package:flutter/material.dart';

import '../../app/theme/bil_semantic_icons.dart';

enum BilFeatureEntryKind { recipes, videos, sleep }

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
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _finished = true);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 220)
        : const Duration(milliseconds: 1080);
    _controller.forward();
  }

  @override
  void dispose() {
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
              builder: (context, _) {
                final value = _controller.value;
                final fade = value <= .72
                    ? 1.0
                    : (1 - ((value - .72) / .28)).clamp(0.0, 1.0);
                final scale = 1 + (.024 * value);
                return IgnorePointer(
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: scale,
                      child: _BilFeatureEntrySplash(kind: widget.kind),
                    ),
                  ),
                );
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
        glow: const Color(0xFFF0B45B),
        field: const Color(0xFF40240D),
      ),
      BilFeatureEntryKind.videos => (
        icon: BilSemanticIconKind.exercise,
        title: arabic ? 'فيديوهات BIL' : 'BIL Videos',
        subtitle: arabic
            ? 'تدريب مرئي واضح من مكتبتك الموثوقة'
            : 'Clear visual training from your trusted library',
        glow: const Color(0xFF64D8FF),
        field: const Color(0xFF12394E),
      ),
      BilFeatureEntryKind.sleep => (
        icon: BilSemanticIconKind.sleep,
        title: arabic ? 'ذكاء النوم' : 'Sleep Intelligence',
        subtitle: arabic
            ? 'افهم نومك من السجلات والقياسات الحقيقية'
            : 'Understand sleep from your real records and measurements',
        glow: const Color(0xFF9D91FF),
        field: const Color(0xFF29235B),
      ),
    };

    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Semantics(
        key: ValueKey('feature-entry-splash-${kind.name}'),
        container: true,
        label: data.title,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF030405),
            gradient: RadialGradient(
              center: const Alignment(0, -.18),
              radius: .9,
              colors: [data.field, const Color(0xFF030405)],
              stops: const [.02, 1],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 18,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            padding: const EdgeInsets.all(2.2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  data.glow.withValues(alpha: .98),
                                  const Color(0xFF7568FF),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: data.glow.withValues(alpha: .30),
                                  blurRadius: 36,
                                  spreadRadius: -8,
                                ),
                              ],
                            ),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0xFF071923),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: BilSemanticIconBadge(
                                  kind: data.icon,
                                  size: 60,
                                  iconSize: 29,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            data.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: arabic ? 1.28 : 1.12,
                                  letterSpacing: arabic ? 0 : -.35,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data.subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: const Color(0xFFC5D2E3),
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            width: 116,
                            child: LinearProgressIndicator(
                              value: .72,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(99),
                              color: data.glow,
                              backgroundColor: Colors.white.withValues(
                                alpha: .10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
