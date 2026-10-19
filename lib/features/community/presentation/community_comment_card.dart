import 'package:flutter/material.dart';

import '../../../app/theme/bil_pearl_finish.dart';
import '../../../app/localization/bil_written_language_resolver.dart';
import 'community_copy.dart';

/// Outside taps only collapse presentation; they still reach their own target.
class CommunityCommentCard extends StatefulWidget {
  const CommunityCommentCard({
    super.key,
    required this.identity,
    required this.source,
    required this.builder,
  });
  final String identity;
  final String source;
  final Widget Function(bool expanded, VoidCallback toggle) builder;

  @override
  State<CommunityCommentCard> createState() => _CommunityCommentCardState();
}

class _CommunityCommentCardState extends State<CommunityCommentCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant CommunityCommentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.source != widget.source) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    onTapUpOutside: (_) {
      if (_expanded) setState(() => _expanded = false);
    },
    child: DecoratedBox(
      key: ValueKey('community-comment-card-${widget.identity}'),
      decoration: BilPearlFinish.panel(
        context,
        radius: BorderRadius.circular(20),
        shadow: false,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: widget.builder(
          _expanded,
          () => setState(() => _expanded = !_expanded),
        ),
      ),
    ),
  );
}

class CommunityCommentText extends StatelessWidget {
  const CommunityCommentText({
    super.key,
    required this.identity,
    required this.text,
    required this.expanded,
    required this.onToggle,
  });
  final String identity;
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final direction = BilWrittenLanguageResolver.directionFor(
        text,
        fallback: Directionality.of(context),
      );
      final style = DefaultTextStyle.of(context).style;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
        maxLines: 3,
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (overflows && !expanded)
            Text(
              text,
              key: Key('community-comment-body-$identity'),
              style: style,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textDirection: direction,
            )
          else
            SelectableText(
              text,
              key: Key('community-comment-body-$identity'),
              style: style,
              textDirection: direction,
            ),
          if (overflows)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: Key('community-comment-expand-$identity'),
                onPressed: onToggle,
                icon: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  communityText(
                    context,
                    expanded ? 'Show less' : 'Read more',
                    expanded ? 'عرض أقل' : 'قراءة المزيد',
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
