import 'package:flutter/material.dart';

import 'community_copy.dart';

/// A prospective, conditional reward explanation; never a token balance.
/// Only moderation and its authoritative receipt can grant the reward.
class CommunityAiRewardNotice extends StatelessWidget {
  const CommunityAiRewardNotice({
    this.onCreate,
    this.showCreateAction = false,
    super.key,
  });

  final VoidCallback? onCreate;
  final bool showCreateAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('community-ai-reward-notice'),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              communityText(context, 'AI token reward', 'مكافأة توكنات AI'),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              communityText(
                context,
                'An eligible approved post may earn +5 AI tokens only when the server reward receipt confirms the grant. Approval alone does not guarantee a token award; daily limits may apply. AI tokens are not BIL Gold and cannot be cashed out. Opening or saving a draft earns nothing.',
                'قد يكسب المنشور المؤهل بعد اعتماده +5 توكنات AI فقط عندما يؤكد إيصال المكافأة من الخادم المنحة. الاعتماد وحده لا يضمن منح توكنات، وقد تنطبق حدود يومية. توكنات AI ليست BIL Gold ولا تُستبدل بنقود. فتح المسودة أو حفظها لا يمنح مكافأة.',
              ),
              style: TextStyle(color: scheme.onPrimaryContainer, height: 1.4),
            ),
            if (showCreateAction) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('community-earn-create-post'),
                  onPressed: onCreate,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    communityText(context, 'Create a Post', 'إنشاء منشور'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
