import 'package:flutter/material.dart';

/// Render-only transcript text: selection/copy is user initiated, and time
/// comes from the saved message rather than from a timer or a new DateTime.now.
class CoachMessageText extends StatelessWidget {
  const CoachMessageText({
    required this.text,
    required this.createdAt,
    required this.textDirection,
    this.style,
    this.alignEnd = false,
    super.key,
  });

  final String text;
  final DateTime createdAt;
  final TextDirection textDirection;
  final TextStyle? style;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final localTime = createdAt.toLocal();
    final time = TimeOfDay.fromDateTime(localTime).format(context);
    final date = MaterialLocalizations.of(context).formatFullDate(localTime);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        SelectableText(text, textDirection: textDirection, style: style),
        const SizedBox(height: 4),
        Text(time, semanticsLabel: '$date, $time',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
      ],
    );
  }
}
