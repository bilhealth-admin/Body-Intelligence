part of 'live_health_watch.dart';

/// At large accessibility scales only, keep the complete time in its existing
/// clock zone. The approved 1x text, colours, spacing and watch remain intact.
class _WatchTimeText extends StatelessWidget {
  const _WatchTimeText({required this.span, required this.style});

  final TextSpan span;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final requested = MediaQuery.textScalerOf(context);
    final fontSize = style.fontSize!;
    if (requested.scale(fontSize) <= fontSize) {
      // Keep the original paragraph configuration and painting at 1x.
      return Text.rich(
        span,
        key: const Key('watch-digital-time'),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: style,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final requested = MediaQuery.textScalerOf(context);
        var effective = requested;
        final fontSize = style.fontSize!;
        final requestedScale = requested.scale(fontSize) / fontSize;
        if (requestedScale > 1 && constraints.maxWidth.isFinite) {
          final painter = TextPainter(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.merge(style),
              children: [span],
            ),
            textDirection: TextDirection.ltr,
            textScaler: requested,
            locale: Localizations.maybeLocaleOf(context),
            maxLines: 1,
          )..layout();
          if (painter.width > constraints.maxWidth) {
            var lower = 1.0, upper = requestedScale;
            // Rich spans have different font sizes/letter spacing, so their
            // combined width is not a strictly proportional scalar ratio.
            for (var iteration = 0; iteration < 18; iteration++) {
              final candidate = (lower + upper) / 2;
              painter.textScaler = TextScaler.linear(candidate);
              painter.layout();
              if (painter.width <= constraints.maxWidth - .5) {
                lower = candidate;
              } else {
                upper = candidate;
              }
            }
            effective = TextScaler.linear(lower);
          }
          painter.dispose();
        }
        return Text.rich(
          span,
          key: const Key('watch-digital-time'),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          textScaler: effective,
          maxLines: 1,
          softWrap: false,
          style: style,
        );
      },
    );
  }
}
