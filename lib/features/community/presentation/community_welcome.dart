import 'package:flutter/material.dart';
import '../../../app/localization/sapphire_copy.dart';
import 'community_sapphire.dart';

/// Local first paint, not a forced-delay splash. Existing feed content is never
/// covered during a refresh. Back/messages remain reachable in the parent bar.
class CommunityWelcome extends StatelessWidget {
  const CommunityWelcome({super.key});
  static const imageAsset =
      'assets/images/community/community_welcome_athletes.webp';
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        key: const Key('community-welcome-loading'),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: 1.65,
                child: ExcludeSemantics(
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.30),
                    cacheWidth: 700,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Center(
                        child: Icon(
                          Icons.groups_rounded,
                          size: 84,
                          color: CommunitySapphire.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              sapphireText(context, 'welcome'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              sapphireText(context, 'together'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              label: sapphireText(context, 'loading'),
              child: const SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              sapphireText(context, 'loading'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < 2; i++)
              ExcludeSemantics(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CommunitySapphire.paper(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 10,
                              width: 100,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: .5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
