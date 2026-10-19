import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/bil_pearl_finish.dart';
import 'bil_experience_presentation.dart';
import 'first_use_tap_celebration.dart';

/// Root-overlay geometry, with taps delivered to the real underlying control.
class FirstUseSpotlight extends StatelessWidget {
  const FirstUseSpotlight({
    super.key,
    required this.target,
    required this.guide,
    this.preferBelow = true,
    this.onTargetActivated,
  });
  final GlobalKey target;
  final Widget guide;
  final bool preferBelow;
  final VoidCallback? onTargetActivated;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: BilExperiencePresentation.occupied,
    builder: (context, occupied, _) {
      final route = ModalRoute.of(context);
      final animation = route?.animation;
      final box = target.currentContext?.findRenderObject();
      final overlay = Overlay.of(
        context,
        rootOverlay: true,
      ).context.findRenderObject();
      if (occupied ||
          box is! RenderBox ||
          !box.attached ||
          !box.hasSize ||
          overlay is! RenderBox ||
          !overlay.hasSize ||
          !(route?.isCurrent ?? true) ||
          (animation != null &&
              animation.status != AnimationStatus.completed)) {
        return const SizedBox.shrink();
      }
      final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
      // Dialogs remove inherited viewInsets after applying their own padding.
      // Placement still needs the root view's actual keyboard and safe areas.
      final media = MediaQueryData.fromView(View.of(context));
      final safe = Rect.fromLTRB(
        media.padding.left + 12,
        media.padding.top + 8,
        overlay.size.width - media.padding.right - 12,
        overlay.size.height -
            math.max(media.padding.bottom, media.viewInsets.bottom) -
            8,
      );
      if (safe.isEmpty || !rect.overlaps(safe)) return const SizedBox.shrink();
      final geometry = _GuideGeometry();
      Rect? containingPanel;
      target.currentContext?.visitAncestorElements((element) {
        if (element.widget is BilFrostedPanel) {
          final panel = element.findRenderObject();
          if (panel is RenderBox && panel.attached && panel.hasSize) {
            containingPanel =
                panel.localToGlobal(Offset.zero, ancestor: overlay) &
                panel.size;
          }
          return false;
        }
        return true;
      });
      final layout = _GuideLayout(
        rect: rect,
        safe: safe,
        preferBelow: preferBelow,
        geometry: geometry,
        containingPanel: containingPanel,
      );
      return FirstUseGuideTapEffect(
        target: rect,
        onActivated: onTargetActivated,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('first-use-spotlight-paint'),
                  painter: _GuidePainter(
                    rect,
                    geometry,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: layout,
                child: Material(
                  type: MaterialType.transparency,
                  child: FirstUseGuidePlacement(
                    below: layout.below,
                    pointerAlignment: Alignment.center,
                    child: guide,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _GuideGeometry {
  Rect? card;
}

class _GuideLayout extends SingleChildLayoutDelegate {
  _GuideLayout({
    required this.rect,
    required this.safe,
    required bool preferBelow,
    required this.geometry,
    Rect? containingPanel,
  }) {
    final above = math.max(0.0, rect.top - safe.top - 26);
    final under = math.max(0.0, safe.bottom - rect.bottom - 26);
    below = preferBelow
        ? under >= 180 || under >= above
        : above < 180 && under > above;
    available = below ? under : above;
    edge = below ? rect.bottom + 26 : rect.top - 26;
    if (containingPanel != null) {
      final outsideAbove = containingPanel.top - 16 - safe.top;
      final outsideBelow = safe.bottom - containingPanel.bottom - 16;
      if (outsideAbove >= 160 || outsideBelow >= 160) {
        below = preferBelow ? outsideBelow >= 160 : outsideAbove < 160;
        available = below ? outsideBelow : outsideAbove;
        edge = below ? containingPanel.bottom + 16 : containingPanel.top - 16;
      }
    }
  }
  final Rect rect, safe;
  final _GuideGeometry geometry;
  late bool below;
  late double available;
  late double edge;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(
        width: math.min(370, safe.width),
      ).copyWith(minHeight: 0, maxHeight: math.max(0, available));
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (rect.center.dx - childSize.width / 2)
        .clamp(safe.left, math.max(safe.left, safe.right - childSize.width))
        .toDouble();
    final top = below ? edge : edge - childSize.height;
    geometry.card = Offset(left, top) & childSize;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_GuideLayout old) => true;
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.target, this.geometry, this.color);
  final Rect target;
  final _GuideGeometry geometry;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final ring = target.inflate(6);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(ring),
      Paint()..color = const Color(0xFF777777).withValues(alpha: .34),
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawOval(ring, paint);
    final card = geometry.card;
    if (card == null) return;
    final below = card.top >= target.bottom;
    final from = Offset(ring.center.dx, below ? ring.bottom : ring.top);
    final end = Offset(
      target.center.dx.clamp(card.left + 20, card.right - 20),
      below ? card.top : card.bottom,
    );
    final middle = (from.dy + end.dy) / 2;
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, middle, end.dx, middle, end.dx, end.dy),
      paint,
    );
    canvas.drawCircle(end, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GuidePainter old) => true;
}

class FirstUseGuidePlacement extends InheritedWidget {
  const FirstUseGuidePlacement({
    super.key,
    required this.below,
    required this.pointerAlignment,
    required super.child,
  });
  final bool below;
  final Alignment pointerAlignment;
  static FirstUseGuidePlacement? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FirstUseGuidePlacement>();
  static bool belowOf(BuildContext context) => maybeOf(context)?.below ?? false;
  @override
  bool updateShouldNotify(FirstUseGuidePlacement old) =>
      below != old.below || pointerAlignment != old.pointerAlignment;
}
