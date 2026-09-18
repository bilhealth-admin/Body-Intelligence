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
  late List<int> _runes;
  late String _visibleText;

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
    _runes = widget.text.runes.toList(growable: false);
    final revealKey = widget.key;
    final animateReveal =
        widget.animateReveal &&
        (revealKey == null || _startedRevealKeys.add(revealKey));
    if (!animateReveal || _runes.length <= 8) {
      _visibleText = widget.text;
      return;
    }
    // Runes keep Arabic and emoji intact. The answer already exists locally;
    // this is a short visual reveal, not a streamed or delayed response.
    // A 40ms single-rune cadence is deliberately conversational rather than
    // the previous near-instant burst, while still keeping a normal reply
    // readable without a long wait.
    const initialVisible = 8;
    final remaining = _runes.length - initialVisible;
    var visible = initialVisible;
    _visibleText = String.fromCharCodes(_runes.take(visible));
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: remaining * 40),
    );
    _revealController = controller;
    controller.addListener(() {
      if (!mounted) return;
      final nextVisible =
          initialVisible +
          (controller.value * remaining).floor().clamp(0, remaining);
      if (nextVisible == visible) return;
      visible = nextVisible;
      setState(() {
        _visibleText = String.fromCharCodes(_runes.take(visible));
      });
    });
    controller.forward();
  }

  @override
  void dispose() {
    _revealController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        SelectableText(
          _visibleText,
          textDirection: widget.textDirection,
          style: widget.style,
          // Screen readers receive the complete answer while the visual layer
          // reveals it quickly.
          semanticsLabel: widget.animateReveal ? widget.text : null,
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
