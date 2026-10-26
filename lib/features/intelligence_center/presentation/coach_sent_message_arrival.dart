import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A local presentation transition for one already accepted user turn.
/// The actual row keeps its layout and semantics. A noninteractive canvas
/// travels from the existing composer bounds to that row; no second message,
/// request, selectable text or tappable control is created.
class CoachSentMessageArrival extends StatefulWidget {
  const CoachSentMessageArrival({
    super.key,
    required this.origin,
    required this.text,
    required this.direction,
    required this.style,
    required this.visitIsCurrent,
    required this.onFinished,
    required this.child,
    this.backgroundGradient,
  });
  final Rect? origin;
  final String text;
  final TextDirection direction;
  final TextStyle style;
  final bool Function() visitIsCurrent;
  final VoidCallback onFinished;
  final Widget child;
  final Gradient? backgroundGradient;

  @override
  State<CoachSentMessageArrival> createState() =>
      _CoachSentMessageArrivalState();
}

class _CoachSentMessageArrivalState extends State<CoachSentMessageArrival>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _portal = OverlayPortalController();
  final _target = GlobalKey();
  late final AnimationController _motion;
  bool _started = false;
  bool _flying = false;
  bool _finished = false;

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

  @override
  void initState() {
    super.initState();
    _motion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _started = true;
      if (_flying) {
        _finish();
      } else if (!_finished) {
        _finished = true;
        widget.onFinished();
      }
      return;
    }
    if (_started || widget.origin == null || !widget.visitIsCurrent()) return;
    _started = true;
    _flying = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.visitIsCurrent() || _reduceMotion) {
        if (mounted) _finish();
        return;
      }
      final rect = _targetBounds();
      if (rect == null || !rect.overlaps(_transcriptBounds())) {
        _finish();
        return;
      }
      _portal.show();
      _motion.forward();
    });
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted && _reduceMotion) _finish();
  }

  Rect? _targetBounds() {
    final render = _target.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    return render.localToGlobal(Offset.zero) & render.size;
  }

  Rect _transcriptBounds() {
    final render = _target.currentContext?.findRenderObject();
    final viewport = RenderAbstractViewport.maybeOf(render);
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    if (viewport == null || !viewport.attached) return screen;
    return MatrixUtils.transformRect(
      viewport.getTransformTo(null),
      viewport.paintBounds,
    ).intersect(screen);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _motion.stop();
    _portal.hide();
    if (mounted) setState(() => _flying = false);
    widget.onFinished();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    if (!_finished) widget.onFinished();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (context) => AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final target = _targetBounds();
        if (target == null ||
            widget.origin == null ||
            !widget.visitIsCurrent()) {
          return const SizedBox.shrink();
        }
        final transcript = _transcriptBounds();
        if (!target.overlaps(transcript)) return const SizedBox.shrink();
        final overlay = Overlay.of(context).context.findRenderObject();
        final offset = overlay is RenderBox
            ? overlay.localToGlobal(Offset.zero)
            : Offset.zero;
        final rect = Rect.lerp(
          widget.origin,
          target,
          Curves.easeOutCubic.transform(_motion.value),
        )!.shift(-offset);
        // A response or a history scroll can move the accepted row above the
        // transcript while this presentation-only transition is still active.
        // Keep its paint below the header and above navigation/keyboard, while
        // allowing the draft to begin at the unchanged composer rectangle.
        final clip = Rect.fromLTRB(
          transcript.left,
          transcript.top,
          transcript.right,
          widget.origin!.bottom > transcript.bottom
              ? widget.origin!.bottom
              : transcript.bottom,
        ).intersect(Offset.zero & MediaQuery.sizeOf(context)).shift(-offset);
        return Positioned.fromRect(
          rect: clip,
          child: ClipRect(
            key: const ValueKey('coach-sent-message-flight-clip'),
            child: Stack(
              children: [
                Positioned.fromRect(
                  key: const ValueKey('coach-sent-message-flight'),
                  rect: rect.shift(-clip.topLeft),
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: _SentDraftPainter(
                          text: widget.text,
                          direction: widget.direction,
                          style: widget.style,
                          scale: MediaQuery.textScalerOf(context),
                          scheme: Theme.of(context).colorScheme,
                          backgroundGradient: widget.backgroundGradient,
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
    child: Opacity(
      opacity: _flying ? 0 : 1,
      alwaysIncludeSemantics: true,
      child: KeyedSubtree(key: _target, child: widget.child),
    ),
  );
}

class _SentDraftPainter extends CustomPainter {
  const _SentDraftPainter({
    required this.text,
    required this.direction,
    required this.style,
    required this.scale,
    required this.scheme,
    this.backgroundGradient,
  });
  final String text;
  final TextDirection direction;
  final TextStyle style;
  final TextScaler scale;
  final ColorScheme scheme;
  final Gradient? backgroundGradient;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRRect(
      shape,
      Paint()
        ..shader =
            (backgroundGradient ??
                    LinearGradient(
                      colors: [
                        scheme.primaryContainer,
                        scheme.primaryContainer.withValues(alpha: .84),
                      ],
                    ))
                .createShader(rect, textDirection: direction),
    );
    if (size.width > 32) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scale,
      )..layout(maxWidth: size.width - 32);
      painter.paint(canvas, const Offset(16, 11));
      painter.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SentDraftPainter old) =>
      old.text != text ||
      old.direction != direction ||
      old.style != style ||
      old.scale != scale ||
      old.scheme != scheme ||
      old.backgroundGradient != backgroundGradient;
}
