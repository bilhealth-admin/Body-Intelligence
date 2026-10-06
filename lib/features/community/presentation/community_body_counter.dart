import 'package:flutter/material.dart';

import '../domain/community_text_limits.dart';

/// A code-point counter; TextField's built-in counter counts grapheme clusters.
InputCounterWidgetBuilder communityBodyCounter(
  TextEditingController controller,
) => (context, {required currentLength, required isFocused, maxLength}) {
  final count = CommunityTextLimits.count(controller.text);
  final tooLong = count > CommunityTextLimits.bodyCodePointLimit;
  return Text(
    '$count / ${CommunityTextLimits.bodyCodePointLimit}',
    textDirection: TextDirection.ltr,
    style: tooLong
        ? TextStyle(color: Theme.of(context).colorScheme.error)
        : null,
  );
};
