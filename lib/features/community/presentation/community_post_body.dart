import 'package:flutter/material.dart';

import '../../../app/localization/bil_written_language_resolver.dart';
import 'community_copy.dart';

/// Feed preview measures actual wrapped lines, including translated content.
class CommunityPostBody extends StatefulWidget {
  const CommunityPostBody({
    super.key,
    required this.postId,
    required this.body,
  });

  final String postId;
  final String body;

  @override
  State<CommunityPostBody> createState() => _CommunityPostBodyState();
}

class _CommunityPostBodyState extends State<CommunityPostBody> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant CommunityPostBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId || oldWidget.body != widget.body) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final direction = BilWrittenLanguageResolver.directionFor(
        widget.body,
        fallback: Directionality.of(context),
      );
      final style = Theme.of(context).textTheme.bodyLarge;
      final painter = TextPainter(
        text: TextSpan(text: widget.body, style: style),
        textDirection: direction,
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 3,
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_expanded)
            SelectableText(
              widget.body,
              key: ValueKey('community-post-body-${widget.postId}'),
              textDirection: direction,
              style: style,
            )
          else
            Text(
              widget.body,
              key: ValueKey('community-post-body-${widget.postId}'),
              textDirection: direction,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          if (overflows)
            TextButton.icon(
              key: ValueKey('community-post-expand-${widget.postId}'),
              onPressed: () => setState(() => _expanded = !_expanded),
              iconAlignment: IconAlignment.end,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 19,
              ),
              label: Text(
                _expanded
                    ? communityText(context, 'Show less', 'عرض أقل')
                    : communityText(context, 'Show more', 'عرض المزيد'),
              ),
            ),
        ],
      );
    },
  );
}
