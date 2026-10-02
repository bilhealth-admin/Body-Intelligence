import 'package:flutter/material.dart';
import '../../../app/localization/sapphire_copy.dart';
import 'community_sapphire.dart';

/// Branded first paint for Community entry.
///
/// The feed starts loading immediately behind this surface, while the caller
/// keeps the welcome visible for the same 2.2-second minimum used by AI Coach.
/// Refreshes after entry never re-show it. Back/messages remain reachable in
/// the parent bar.
class CommunityWelcome extends StatelessWidget {
  const CommunityWelcome({super.key});
  static const imageAsset =
      'assets/images/community/community_welcome_athletes.webp';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            key: const Key('community-welcome-loading'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: CommunitySapphire.navy,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.18,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ExcludeSemantics(
                              child: Image.asset(
                                imageAsset,
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, .55),
                                cacheWidth: 900,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFF203E68),
                                  child: Center(
                                    child: Icon(
                                      Icons.groups_rounded,
                                      size: 84,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [.55, 1],
                                  colors: [
                                    Colors.transparent,
                                    CommunitySapphire.navy,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                        child: Column(
                          children: [
                            Text(
                              sapphireText(context, 'welcome'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              sapphireText(context, 'together'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: const Color(0xFFE1EAFA)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  liveRegion: true,
                  label: sapphireText(context, 'loading'),
                  child: ExcludeSemantics(
                    child: TickerMode(
                      enabled: !MediaQuery.disableAnimationsOf(context),
                      child: const SizedBox(
                        width: 160,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  sapphireText(context, 'loading'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                ExcludeSemantics(
                  child: Container(
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
                                width: 110,
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
      // SliverToBoxAdapter supplies unbounded height; standalone entry surfaces
      // are bounded and must remain scrollable on small screens / large text.
      return constraints.hasBoundedHeight
          ? SingleChildScrollView(primary: false, child: content)
          : content;
    },
  );
}
