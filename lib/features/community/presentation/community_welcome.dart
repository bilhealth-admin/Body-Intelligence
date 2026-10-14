import 'package:flutter/material.dart';

import '../../../app/localization/sapphire_copy.dart';
import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'community_return_button.dart';

/// One full-viewport welcome, while authorized member content starts loading
/// offstage. Refreshes never replay it; its caller owns the 2.2-second hold.
class CommunityWelcome extends StatelessWidget {
  const CommunityWelcome({super.key, this.showBack = false});

  final bool showBack;
  static const imageAsset =
      'assets/images/community/community_welcome_athletes.webp';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      height: constraints.hasBoundedHeight
          ? constraints.maxHeight
          : MediaQuery.sizeOf(context).height,
      child: BilPearlFeatureWelcome(
        key: const Key('community-welcome-loading'),
        title: sapphireText(context, 'welcome'),
        subtitle: sapphireText(context, 'together'),
        statusLabel: sapphireText(context, 'loading'),
        artworkWidth: 440,
        artworkAspectRatio: 1.05,
        leading: showBack ? const CommunityReturnButton() : null,
        artwork: Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          alignment: const Alignment(0, .55),
          cacheWidth: 900,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => Icon(
            Icons.groups_rounded,
            size: 84,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}
