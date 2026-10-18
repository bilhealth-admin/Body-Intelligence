import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cosmetic waiting copy only: never claims a tool, search or data read ran.
/// Its complete text envelope is reserved, so phase changes cannot move history.
class CoachThinkingStatus extends StatefulWidget {
  const CoachThinkingStatus({super.key, required this.labels});

  final List<String> labels;

  @override
  State<CoachThinkingStatus> createState() => _CoachThinkingStatusState();
}

class _CoachThinkingStatusState extends State<CoachThinkingStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      height: 1.45,
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: LayoutBuilder(
            builder: (context, constraints) {
              var height = 0.0;
              for (final label in widget.labels) {
                final painter = TextPainter(
                  text: TextSpan(text: label, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  locale: Localizations.maybeLocaleOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                height = math.max(height, painter.height);
                painter.dispose();
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: height,
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) {
                    final phase = (_motion.value * widget.labels.length)
                        .floor()
                        .clamp(0, widget.labels.length - 1);
                    final text = AnimatedSwitcher(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 420),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [...previous, ?current],
                      ),
                      child: Text(
                        widget.labels[phase],
                        key: ValueKey(phase),
                        style: style,
                      ),
                    );
                    // Announce waiting once, not every cosmetic phase.
                    return Semantics(
                      liveRegion: true,
                      label: widget.labels.first,
                      child: ExcludeSemantics(
                        child: reduced
                            ? text
                            : ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => LinearGradient(
                                  begin: Alignment(
                                    -3 + (_motion.value * 6) % 6,
                                    0,
                                  ),
                                  end: Alignment(
                                    -1 + (_motion.value * 6) % 6,
                                    0,
                                  ),
                                  colors: [
                                    scheme.onSurfaceVariant,
                                    scheme.primary,
                                    scheme.onSurfaceVariant,
                                  ],
                                  stops: const [0, .5, 1],
                                ).createShader(bounds),
                                child: text,
                              ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
