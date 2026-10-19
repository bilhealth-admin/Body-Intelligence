import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Finite guide-only particles; never captures or repeats the control's action.
class FirstUseGuideTapEffect extends StatefulWidget {
  const FirstUseGuideTapEffect({
    super.key,
    required this.target,
    required this.child,
    this.onActivated,
  });
  final Rect target;
  final Widget child;
  final VoidCallback? onActivated;
  @override
  State<FirstUseGuideTapEffect> createState() => _GuideTapEffectState();
}

class _GuideTapEffectState extends State<FirstUseGuideTapEffect> {
  Offset? down;
  int? pointer;
  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      if (widget.target.contains(event.localPosition) && pointer == null) {
        down = event.position;
        pointer = event.pointer;
      }
    },
    onPointerMove: (event) {
      if (event.pointer == pointer &&
          down != null &&
          (event.position - down!).distance > 12) {
        down = null;
      }
    },
    onPointerCancel: (event) {
      if (event.pointer == pointer) {
        down = null;
        pointer = null;
      }
    },
    onPointerUp: (event) {
      if (event.pointer != pointer) return;
      final valid = down != null && widget.target.contains(event.localPosition);
      down = null;
      pointer = null;
      if (!valid) return;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _showBurst(context, event.position);
      }
      widget.onActivated?.call();
    },
    child: widget.child,
  );
}

void _showBurst(BuildContext context, Offset globalPosition) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final box = overlay.context.findRenderObject()! as RenderBox;
  const extent = 96.0;
  final center = box.globalToLocal(globalPosition);
  final left = (center.dx - extent / 2)
      .clamp(0.0, math.max(0.0, box.size.width - extent))
      .toDouble();
  final top = (center.dy - extent / 2)
      .clamp(0.0, math.max(0.0, box.size.height - extent))
      .toDouble();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: left,
      top: top,
      width: extent,
      height: extent,
      child: const IgnorePointer(
        child: ExcludeSemantics(child: _TinyEmojiBurst()),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(milliseconds: 480), () {
    entry.remove();
    entry.dispose();
  });
}

class _TinyEmojiBurst extends StatelessWidget {
  const _TinyEmojiBurst();
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: const Key('first-use-tiny-emoji-burst'),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 420),
    builder: (_, value, _) => Opacity(
      opacity: (1 - value).clamp(0.0, 1.0),
      child: Stack(
        children: [
          for (var i = 0; i < 5; i++)
            Positioned(
              left: 36 + math.cos(i * math.pi * 2 / 5) * value * 28,
              top: 36 + math.sin(i * math.pi * 2 / 5) * value * 28,
              child: Transform.scale(
                scale: .65 + math.sin(value * math.pi) * .35,
                child: Text(
                  i.isEven ? '✨' : '🎉',
                  style: const TextStyle(
                    inherit: false,
                    decoration: TextDecoration.none,
                    height: 1,
                    fontSize: 20,
                    fontFamilyFallback: [
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                      'Noto Color Emoji',
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
