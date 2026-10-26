import 'package:flutter/material.dart';
import '../../../../shared/widgets/bil_conversation_presentation.dart';

import '../../../../app/localization/bil_written_language_resolver.dart';
import '../../presentation/community_sapphire.dart';
import '../domain/community_channel_models.dart';
import 'community_channels_copy.dart';

class CommunityChannelMessageTile extends StatelessWidget {
  const CommunityChannelMessageTile({
    required this.message,
    required this.ownerId,
    required this.viewportMarker,
    this.onSafety,
    this.presentation,
    this.visitIsCurrent,
    super.key,
  });

  final CommunityChannelMessage message;
  final String ownerId;
  final Key viewportMarker;
  final ValueChanged<CommunityChannelMessage>? onSafety;
  final BilConversationPresentation? presentation;
  final bool Function()? visitIsCurrent;

  @override
  Widget build(BuildContext context) {
    final mine = message.authorId == ownerId;
    final ink = mine ? Colors.white : CommunitySapphire.ink(context);
    final muted = mine ? Colors.white : CommunitySapphire.muted(context);
    final date = message.createdAt.toLocal();
    final dateLabel = MaterialLocalizations.of(context).formatShortDate(date);
    final timeLabel = TimeOfDay.fromDateTime(date).format(context);
    final author =
        message.authorDisplayName ??
        CommunityChannelsCopy.text(context, CommunityChannelsCopyKey.member);
    bool current() => visitIsCurrent?.call() ?? true;
    final direction = BilWrittenLanguageResolver.directionFor(
      message.text,
      fallback: Directionality.of(context),
    );
    final style =
        Theme.of(context).textTheme.bodyLarge?.copyWith(color: ink) ??
        TextStyle(fontSize: 16, color: ink);
    final fallback = SelectableText(
      message.text,
      key: ValueKey('bil07-message-text-${message.id}'),
      style: style,
      textDirection: direction,
    );
    final body = CommunityMessageBubble(
      mine: mine,
      nativeCanvas:
          presentation != null && !mine && BilConversationText.usesNativeText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            author,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ink),
            textDirection: BilWrittenLanguageResolver.directionFor(
              author,
              fallback: Directionality.of(context),
            ),
          ),
          const SizedBox(height: 4),
          if (presentation == null)
            fallback
          else
            BilConversationText(
              key: ValueKey('bil07-message-body-${message.id}'),
              text: message.text,
              mine: mine,
              direction: direction,
              style: style,
              visitIsCurrent: current,
              onPainted: (ready) {
                if (current()) presentation?.markPainted(message.id, ready);
              },
              fallback: fallback,
            ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                '$dateLabel · $timeLabel',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: muted),
              ),
              if (!mine && onSafety != null)
                IconButton(
                  key: ValueKey('bil07-message-safety-${message.id}'),
                  tooltip: CommunityChannelsCopy.text(
                    context,
                    CommunityChannelsCopyKey.messageSafety,
                  ),
                  onPressed: () => onSafety!(message),
                  icon: Icon(Icons.more_horiz_rounded, size: 19, color: muted),
                ),
              if (mine)
                Icon(
                  Icons.done_rounded,
                  size: 15,
                  color: muted,
                  semanticLabel: CommunityChannelsCopy.text(
                    context,
                    CommunityChannelsCopyKey.sent,
                  ),
                )
              else if (!message.isRead)
                Text(
                  CommunityChannelsCopy.text(
                    context,
                    CommunityChannelsCopyKey.unread,
                  ),
                  key: ValueKey('bil07-unread-${message.id}'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: muted),
                ),
            ],
          ),
        ],
      ),
    );
    Widget align(Widget child) => Align(
      key: viewportMarker,
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: child,
    );
    if (presentation == null) return align(body);
    return align(
      BilConversationArrival(
        id: message.id,
        presentation: presentation!,
        mine: mine,
        text: message.text,
        direction: direction,
        style: style,
        outgoingGradient: CommunitySapphire.messageGradient(context),
        visitIsCurrent: current,
        child: body,
      ),
    );
  }
}
