import 'dart:async';

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

  @override
  State<CoachMessageText> createState() => _CoachMessageTextState();
}

class _CoachMessageTextState extends State<CoachMessageText> {
  Timer? _revealTimer;
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
    _revealTimer?.cancel();
    _runes = widget.text.runes.toList(growable: false);
    if (!widget.animateReveal || _runes.length <= 8) {
      _visibleText = widget.text;
      return;
    }
    // Runes keep Arabic and emoji intact. The answer already exists locally;
    // this is a short visual reveal, not a streamed or delayed response.
    var visible = 8;
    _visibleText = String.fromCharCodes(_runes.take(visible));
    _revealTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return timer.cancel();
      visible = visible + 5 > _runes.length ? _runes.length : visible + 5;
      setState(() {
        _visibleText = String.fromCharCodes(_runes.take(visible));
      });
      if (visible >= _runes.length) timer.cancel();
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localTime = widget.createdAt.toLocal();
    final time = TimeOfDay.fromDateTime(localTime).format(context);
    final date = MaterialLocalizations.of(context).formatFullDate(localTime);
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
        const SizedBox(height: 4),
        Text(
          time,
          semanticsLabel: '$date, $time',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
