import 'package:flutter/material.dart';

import '../../../../app/localization/bil_written_language_resolver.dart';
import '../../presentation/community_sapphire.dart';
import '../domain/community_channel_models.dart';
import 'community_channels_copy.dart';

class CommunityChannelMessageTile extends StatelessWidget {
  const CommunityChannelMessageTile({
    required this.message,
    required this.ownerId,
    required this.viewportMarker,
    super.key,
  });

  final CommunityChannelMessage message;
  final String ownerId;
  final Key viewportMarker;

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
    return Align(
      key: viewportMarker,
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: CommunityMessageBubble(
        mine: mine,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              author,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: ink),
              textDirection: BilWrittenLanguageResolver.directionFor(
                author,
                fallback: Directionality.of(context),
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              message.text,
              key: ValueKey('bil07-message-text-${message.id}'),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: ink),
              textDirection: BilWrittenLanguageResolver.directionFor(
                message.text,
                fallback: Directionality.of(context),
              ),
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
      ),
    );
  }
}
