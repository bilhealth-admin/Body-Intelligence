import 'dart:math' as math;

import 'package:flutter/material.dart';

enum BilProgressTone { calories, carbs, fat, protein }

abstract final class BilProgressPalette {
  static Color color(BilProgressTone tone, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (tone) {
      BilProgressTone.calories =>
        dark ? const Color(0xFF8ABEF4) : const Color(0xFF003D8D),
      BilProgressTone.carbs =>
        dark ? const Color(0xFF63D5C4) : const Color(0xFF0B7D75),
      BilProgressTone.fat =>
        dark ? const Color(0xFFC795EE) : const Color(0xFF4A0562),
      BilProgressTone.protein =>
        dark ? const Color(0xFFFFC16F) : const Color(0xFFB56005),
    };
  }

  // Established nutrition roles, including the reference Home's older blue
  // macro variants. Other explicit colors retain their status/safety meaning.
  static Color resolve(Color? original, Brightness brightness) {
    final tone = switch (original?.toARGB32()) {
      0xFF0A8F88 ||
      0xFF1475E8 ||
      0xFF0BA5EC ||
      0xFF63D5C4 => BilProgressTone.carbs,
      0xFF6F1096 ||
      0xFF00A0D8 ||
      0xFFF79009 ||
      0xFFC795EE => BilProgressTone.fat,
      0xFFC56A00 ||
      0xFFFFAB32 ||
      0xFF0D5A9D ||
      0xFF7F56D9 ||
      0xFFFFC16F => BilProgressTone.protein,
      0xFF2768DA || 0xFF1D448B || null => BilProgressTone.calories,
      _ => null,
    };
    return tone == null ? original! : color(tone, brightness);
  }
}

/// Paints a static reference texture on the actual filled data region. The
/// original Material indicator owns layout, keys, values and Semantics. A null
/// value stays the original loading indicator; no ticker or task is added.
class BilStripedProgress extends StatelessWidget {
  const BilStripedProgress({
    super.key,
    required this.child,
    this.tone,
    this.nutritionColors = false,
  });

  final ProgressIndicator child;
  final BilProgressTone? tone;
  final bool nutritionColors;

  @override
  Widget build(BuildContext context) {
    final value = child.value;
    if (value == null || !value.isFinite || value <= 0) return child;
    final theme = Theme.of(context);
    final progressTheme = ProgressIndicatorTheme.of(context);
    final originalColor = child.valueColor?.value ?? child.color;
    final color = tone != null
        ? BilProgressPalette.color(tone!, theme.brightness)
        : nutritionColors
        ? BilProgressPalette.resolve(originalColor, theme.brightness)
        : originalColor ??
              BilProgressPalette.color(
                BilProgressTone.calories,
                theme.brightness,
              );
    final circle = child is CircularProgressIndicator
        ? child as CircularProgressIndicator
        : null;
    final painted = CustomPaint(
      foregroundPainter: _FilledStripes(
        value: value.clamp(0, 1).toDouble(),
        color: color,
        circular: circle != null,
        direction: Directionality.of(context),
        stroke: circle?.strokeWidth ?? progressTheme.strokeWidth ?? 4,
        strokeAlign: circle?.strokeAlign ?? progressTheme.strokeAlign ?? 0,
        cap: circle?.strokeCap ?? progressTheme.strokeCap ?? StrokeCap.butt,
        highContrast: MediaQuery.highContrastOf(context),
      ),
      child: child,
    );
    if (child is LinearProgressIndicator) {
      final bar = child as LinearProgressIndicator;
      return ClipRRect(
        borderRadius:
            bar.borderRadius ??
            progressTheme.borderRadius ??
            BorderRadius.circular(99),
        child: painted,
      );
    }
    return painted;
  }
}

abstract final class BilStripedProgressPaint {
  static void fill(
    Canvas canvas,
    Path shape,
    Rect bounds,
    Color color, {
    bool highContrast = false,
  }) {
    if (bounds.isEmpty || color.a <= 0) return;
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(bounds.inflate(1), Paint()..color = color);
    final stripe = Paint()
      ..color = color.computeLuminance() > .4
          ? Colors.black.withValues(alpha: color.a * (highContrast ? .65 : .28))
          : Colors.white.withValues(alpha: color.a * (highContrast ? 1 : .92))
      ..strokeWidth = highContrast ? 2.5 : 2;
    const spacing = 8.0;
    // The phase is anchored to the surface, never its changing filled length.
    final start = ((bounds.left - bounds.height) / spacing).floor() * spacing;
    for (var x = start; x <= bounds.right + bounds.height; x += spacing) {
      canvas.drawLine(
        Offset(x, bounds.bottom),
        Offset(x + bounds.height, bounds.top),
        stripe,
      );
    }
    canvas.restore();
  }

  static void arc(
    Canvas canvas,
    Rect rect,
    double start,
    double sweep,
    double stroke,
    Color color, {
    StrokeCap cap = StrokeCap.butt,
    bool highContrast = false,
  }) {
    if (!sweep.isFinite || sweep <= 0 || stroke <= 0) return;
    final outer = rect.inflate(stroke / 2);
    final inner = rect.deflate(stroke / 2);
    final shape = Path();
    if (sweep >= math.pi * 2 - .001) {
      shape.fillType = PathFillType.evenOdd;
      shape.addOval(outer);
      if (!inner.isEmpty) shape.addOval(inner);
    } else {
      shape.arcTo(outer, start, sweep, true);
      if (!inner.isEmpty) {
        shape.arcTo(inner, start + sweep, -sweep, false);
      } else {
        shape.lineTo(rect.center.dx, rect.center.dy);
      }
      shape.close();
      if (cap == StrokeCap.round) {
        for (final angle in [start, start + sweep]) {
          shape.addOval(
            Rect.fromCircle(
              center:
                  rect.center +
                  Offset(
                    math.cos(angle) * rect.width / 2,
                    math.sin(angle) * rect.height / 2,
                  ),
              radius: stroke / 2,
            ),
          );
        }
      }
    }
    fill(canvas, shape, outer, color, highContrast: highContrast);
  }
}

class _FilledStripes extends CustomPainter {
  const _FilledStripes({
    required this.value,
    required this.color,
    required this.circular,
    required this.direction,
    required this.stroke,
    required this.strokeAlign,
    required this.cap,
    required this.highContrast,
  });
  final double value;
  final Color color;
  final bool circular;
  final TextDirection direction;
  final double stroke;
  final double strokeAlign;
  final StrokeCap cap;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (circular) {
      final offset = -stroke / 2 * strokeAlign;
      BilStripedProgressPaint.arc(
        canvas,
        Rect.fromLTWH(
          offset,
          offset,
          size.width - offset * 2,
          size.height - offset * 2,
        ),
        -math.pi / 2,
        value * (math.pi * 2 - .001),
        stroke,
        color,
        cap: cap,
        highContrast: highContrast,
      );
    } else {
      final width = size.width * value;
      final rect = Rect.fromLTWH(
        direction == TextDirection.rtl ? size.width - width : 0,
        0,
        width,
        size.height,
      );
      // The Material fill is rectangular; rounding only the painted overlay
      // would leave triangles of its previous color at the progress endpoint.
      // The outer clip owns the track's rounded ends.
      final shape = Path()..addRect(rect);
      BilStripedProgressPaint.fill(
        canvas,
        shape,
        rect,
        color,
        highContrast: highContrast,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FilledStripes old) =>
      value != old.value ||
      color != old.color ||
      circular != old.circular ||
      direction != old.direction ||
      stroke != old.stroke ||
      strokeAlign != old.strokeAlign ||
      cap != old.cap ||
      highContrast != old.highContrast;
}

/// Texture for data fills that already own their extent, e.g. chart columns.
/// It does not compute a ratio or change the child's layout/semantics.
class BilStripedFill extends StatelessWidget {
  const BilStripedFill({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius = BorderRadius.zero,
  });
  final Widget child;
  final Color color;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: CustomPaint(
      foregroundPainter: _StripeFill(color, MediaQuery.highContrastOf(context)),
      child: child,
    ),
  );
}

class _StripeFill extends CustomPainter {
  const _StripeFill(this.color, this.highContrast);
  final Color color;
  final bool highContrast;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    BilStripedProgressPaint.fill(
      canvas,
      Path()..addRect(bounds),
      bounds,
      color,
      highContrast: highContrast,
    );
  }

  @override
  bool shouldRepaint(covariant _StripeFill old) =>
      color != old.color || highContrast != old.highContrast;
}
