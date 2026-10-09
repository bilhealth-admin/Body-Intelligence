import 'package:flutter/material.dart';

/// Render-only transcript text: selection/copy is user initiated, and time
/// comes from the saved message rather than from a timer or a new DateTime.now.
class CoachMessageText extends StatefulWidget {
  const CoachMessageText({
    required this.text,
    required this.createdAt,
    required this.textDirection,
    this.style,
    this.alignEnd = false,
    this.animateReveal = false,
    this.showTime = true,
    super.key,
  });

  final String text;
  final DateTime createdAt;
  final TextDirection textDirection;
  final TextStyle? style;
  final bool alignEnd;

  /// Only fresh BIL replies animate. Restored transcript rows stay complete,
  /// selectable, and immediately readable.
  final bool animateReveal;
  final bool showTime;

  @override
  State<CoachMessageText> createState() => _CoachMessageTextState();
}

class _CoachMessageTextState extends State<CoachMessageText>
    with SingleTickerProviderStateMixin {
  // Sliver lists recycle off-screen rows. A fresh widget for the same message
  // must not restart the reveal animation when the user browses history.
  static final _startedRevealKeys = <Object>{};
  AnimationController? _revealController;
  late List<String> _graphemes;
  final _visibleText = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _resetReveal();
  }

  @override
  void didUpdateWidget(covariant CoachMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.animateReveal != widget.animateReveal) {
      _resetReveal();
    }
  }

  void _resetReveal() {
    _revealController?.dispose();
    _revealController = null;
    _graphemes = widget.text.characters.toList(growable: false);
    final revealKey = widget.key;
    final animateReveal =
        widget.animateReveal &&
        (revealKey == null || _startedRevealKeys.add(revealKey));
    if (!animateReveal || _graphemes.length <= 8) {
      _visibleText.value = widget.text;
      return;
    }
    // Grapheme clusters keep Arabic combining marks and joined emoji intact. The answer already exists locally;
    // this is a short visual reveal, not a streamed or delayed response.
    // A 40ms single-rune cadence is deliberately conversational rather than
    // the previous near-instant burst, while still keeping a normal reply
    // readable without a long wait.
    const initialVisible = 8;
    final remaining = _graphemes.length - initialVisible;
    var visible = initialVisible;
    _visibleText.value = _graphemes.take(visible).join();
    final controller = AnimationController(
      vsync: this,
      // Short answers keep their conversational reveal. Very long answers
      // are already fully available, so cap the cosmetic reveal to avoid
      // keeping a multi-paragraph message in motion for minutes.
      duration: Duration(
        milliseconds: (remaining * 40).clamp(320, 2400).toInt(),
      ),
    );
    _revealController = controller;
    controller.addListener(() {
      if (!mounted) return;
      final nextVisible =
          initialVisible +
          (controller.value * remaining).floor().clamp(0, remaining);
      if (nextVisible == visible) return;
      visible = nextVisible;
      // Only the selectable text subtree rebuilds; no parent bubble,
      // reaction buttons or hidden full-text layout is dirtied per tick.
      _visibleText.value = _graphemes.take(visible).join();
    });
    controller.forward();
  }

  @override
  void dispose() {
    _revealController?.dispose();
    _visibleText.dispose();
    super.dispose();
  }

  TextStyle _messageStyle(BuildContext context) =>
      (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
        // The writing language can differ from the UI language.
        fontFamilyFallback: <String>[
          'BILArabic',
          ...?widget.style?.fontFamilyFallback,
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Text reveals must not grow the bubble on every tick. Reserve the
        // complete reply's typography from the first frame so its timestamp,
        // reactions, report button and Sources remain at a fixed offset.
        if (widget.animateReveal && _graphemes.length > 8)
          Stack(
            fit: StackFit.passthrough,
            children: [
              // Size with TextPainter, not a hidden Text/RichText widget.
              // An invisible duplicate was being matched as a second reply
              // by find.text and by some accessibility traversal paths.
              LayoutBuilder(
                builder: (context, constraints) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: widget.text,
                      style: _messageStyle(context),
                    ),
                    textDirection: widget.textDirection,
                    textScaler: MediaQuery.textScalerOf(context),
                    textHeightBehavior: DefaultTextStyle.of(
                      context,
                    ).textHeightBehavior,
                    locale: Localizations.maybeLocaleOf(context),
                  )..layout(maxWidth: constraints.maxWidth);
                  final height = painter.height;
                  final width = constraints.hasBoundedWidth
                      ? constraints.maxWidth
                      : painter.width;
                  painter.dispose();
                  return SizedBox(width: width, height: height);
                },
              ),
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _visibleText,
                    builder: (context, visible, _) => SelectableText(
                      visible,
                      textDirection: widget.textDirection,
                      style: _messageStyle(context),
                      semanticsLabel: widget.text,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          ValueListenableBuilder<String>(
            valueListenable: _visibleText,
            builder: (context, visible, _) => SelectableText(
              visible,
              textDirection: widget.textDirection,
              style: _messageStyle(context),
              semanticsLabel: widget.animateReveal ? widget.text : null,
            ),
          ),
        if (widget.showTime) ...[
          const SizedBox(height: 4),
          CoachMessageTime(createdAt: widget.createdAt),
        ],
      ],
    );
  }
}

class CoachMessageTime extends StatelessWidget {
  const CoachMessageTime({required this.createdAt, super.key});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final localTime = createdAt.toLocal();
    final time = TimeOfDay.fromDateTime(localTime).format(context);
    final date = MaterialLocalizations.of(context).formatFullDate(localTime);
    return Text(
      time,
      semanticsLabel: '$date, $time',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
