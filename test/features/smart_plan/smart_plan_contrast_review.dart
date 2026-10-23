import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 1.4.3 uses the specified foreground and background, not antialiased
/// glyph histogram modes. Pearl gradients can make that histogram select two
/// background shades, especially for thin Arabic glyphs. Keep the real font,
/// retain AA thresholds, and measure every actual background pixel with only
/// the active text paint temporarily hidden. Restore all spans in finally.
/// https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
Future<List<String>> smartPlanTextContrastFailures(
  WidgetTester tester,
  Finder capture,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(capture);
  final original = <RenderParagraph, InlineSpan>{};
  final samples = <(RenderParagraph, List<TextStyle>, double)>[];
  final failures = <String>[];
  final visibleBounds = Offset.zero & boundary.size;
  for (final element in find.byType(RichText).hitTestable().evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final rect = MatrixUtils.transformRect(
      paragraph.getTransformTo(boundary),
      paragraph.paintBounds,
    );
    if (!rect.overlaps(visibleBounds)) continue;
    var disabled = false;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is ButtonStyleButton &&
          widget.onPressed == null &&
          widget.onLongPress == null) {
        disabled = true;
      }
      if (widget is DropdownButton && widget.onChanged == null) disabled = true;
      if (widget is IconButton && widget.onPressed == null) disabled = true;
      return !disabled;
    });
    if (disabled) continue;
    var opacity = 1.0;
    RenderObject? ancestor = paragraph.parent;
    while (ancestor != null && ancestor != boundary) {
      if (ancestor is RenderOpacity) opacity *= ancestor.opacity;
      if (ancestor is RenderAnimatedOpacity) opacity *= ancestor.opacity.value;
      ancestor = ancestor.parent;
    }
    if (opacity == 0) continue;
    final styles = <TextStyle>[];
    void collect(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final style = inherited.merge(span.style);
      if (span.text?.trim().isNotEmpty == true) styles.add(style);
      for (final child in span.children ?? const <InlineSpan>[]) {
        collect(child, style);
      }
    }

    collect(paragraph.text, DefaultTextStyle.of(element).style);
    original[paragraph] = paragraph.text;
    samples.add((paragraph, styles, opacity));
  }
  if (samples.isEmpty) return ['No visible text was actually reviewed'];
  InlineSpan hide(InlineSpan span) => span is TextSpan
      ? TextSpan(
          text: span.text,
          style: (span.style ?? const TextStyle()).copyWith(
            foreground: Paint()..color = Colors.transparent,
          ),
          children: span.children?.map(hide).toList(),
          locale: span.locale,
          semanticsLabel: span.semanticsLabel,
          spellOut: span.spellOut,
        )
      : span;
  try {
    for (final entry in original.entries) {
      entry.key.text = hide(entry.value);
    }
    await tester.pump();
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    if (data == null) throw StateError('No actual background pixels');
    final width = image!.width, height = image.height;
    for (final (paragraph, styles, opacity) in samples) {
      final rect = MatrixUtils.transformRect(
        paragraph.getTransformTo(boundary),
        paragraph.paintBounds,
      ).intersect(visibleBounds);
      for (final style in styles) {
        final foreground = style.foreground?.color ?? style.color;
        if (foreground == null || style.foreground?.shader != null) {
          failures.add(
            'Unresolved foreground: ${original[paragraph]!.toPlainText()}',
          );
          continue;
        }
        final ink = foreground.withValues(alpha: foreground.a * opacity);
        final icon = (style.fontFamily ?? '').contains('Icons');
        final large =
            (style.fontSize ?? 14) >= 24 ||
            ((style.fontSize ?? 14) >= 18.6667 &&
                (style.fontWeight?.value ?? 400) >= FontWeight.w700.value);
        final required = icon || large ? 3.0 : 4.5;
        var minimum = 21.0;
        for (
          var y = rect.top.ceil().clamp(0, height);
          y < rect.bottom.floor().clamp(0, height);
          y++
        ) {
          for (
            var x = rect.left.ceil().clamp(0, width);
            x < rect.right.floor().clamp(0, width);
            x++
          ) {
            final offset = (y * width + x) * 4;
            final background = Color.fromARGB(
              data.getUint8(offset + 3),
              data.getUint8(offset),
              data.getUint8(offset + 1),
              data.getUint8(offset + 2),
            );
            if (background.a != 1) {
              throw StateError('Unresolved transparent background');
            }
            final painted = Color.alphaBlend(
              ink,
              background,
            ).computeLuminance();
            final behind = background.computeLuminance();
            final ratio = painted >= behind
                ? (painted + .05) / (behind + .05)
                : (behind + .05) / (painted + .05);
            if (ratio < minimum) minimum = ratio;
          }
        }
        if (minimum < required) {
          failures.add(
            '${original[paragraph]!.toPlainText()}: ${minimum.toStringAsFixed(3)} < $required',
          );
        }
      }
    }
    image.dispose();
  } finally {
    for (final entry in original.entries) {
      entry.key.text = entry.value;
    }
    await tester.pump();
  }
  return failures;
}
