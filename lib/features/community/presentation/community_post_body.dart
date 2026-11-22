import 'package:flutter/material.dart';

import '../../../app/localization/bil_written_language_resolver.dart';
import 'community_copy.dart';

/// A two-line reading preview with its disclosure beside the final line.
/// The parent may share expansion with metadata and translation controls.
class CommunityPostBody extends StatefulWidget {
  const CommunityPostBody({
    super.key,
    required this.postId,
    required this.body,
    this.expanded,
    this.onExpandedChanged,
    this.alwaysExpandable = false,
  });

  final String postId;
  final String body;
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;
  final bool alwaysExpandable;

  @override
  State<CommunityPostBody> createState() => _CommunityPostBodyState();
}

class _CommunityPostBodyState extends State<CommunityPostBody> {
  bool _expanded = false;
  bool get _isExpanded => widget.expanded ?? _expanded;

  @override
  void didUpdateWidget(covariant CommunityPostBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId || oldWidget.body != widget.body) {
      _expanded = false;
    }
  }

  void _toggle() {
    final next = !_isExpanded;
    if (widget.expanded == null) setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
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
        maxLines: 2,
      )..layout(maxWidth: constraints.maxWidth);
      final expandable = widget.alwaysExpandable || painter.didExceedMaxLines;
      painter.dispose();
      final body = _isExpanded
          ? SelectableText(
              widget.body,
              key: ValueKey('community-post-body-${widget.postId}'),
              textDirection: direction,
              scrollPhysics: const NeverScrollableScrollPhysics(),
              style: style,
            )
          : Text(
              widget.body,
              key: ValueKey('community-post-body-${widget.postId}'),
              textDirection: direction,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            );
      if (!expandable) return body;
      final toggle = TextButton(
        key: ValueKey('community-post-expand-${widget.postId}'),
        onPressed: _toggle,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 44),
          textStyle: Theme.of(context).textTheme.bodyMedium,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _isExpanded
                    ? communityText(context, 'Show less', 'عرض أقل')
                    : communityText(context, 'Show more', 'عرض المزيد'),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              _isExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 16,
            ),
          ],
        ),
      );
      // At large accessibility sizes the action gets its own full-width line
      // rather than narrowing the author's text or reducing the system scale.
      final inline =
          !_isExpanded &&
          constraints.maxWidth >= 240 &&
          MediaQuery.textScalerOf(context).scale(14) <= 21;
      return inline
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: body),
                const SizedBox(width: 4),
                toggle,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                Align(alignment: AlignmentDirectional.centerEnd, child: toggle),
              ],
            );
    },
  );
}
