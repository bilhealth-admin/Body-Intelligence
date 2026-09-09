import 'package:flutter/material.dart';

import '../domain/community_content_policy.dart';
import 'community_copy.dart';

/// A fail-closed, read-only summary of the server-authoritative Community
/// policy state. Reading Community content remains available; write entry
/// points use this notice to explain why publishing or messaging is locked.
class CommunityPolicyNotice extends StatelessWidget {
  const CommunityPolicyNotice({
    required this.state,
    required this.onReview,
    required this.onRetry,
    super.key,
  });

  final Future<CommunityPolicyState> state;
  final VoidCallback onReview;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<CommunityPolicyState>(
    future: state,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return _NoticeCard(
          key: const Key('community-policy-notice-loading'),
          icon: Icons.hourglass_top_rounded,
          title: communityText(
            context,
            'Checking Community policy…',
            'جارٍ التحقق من سياسة المجتمع…',
          ),
          body: communityText(
            context,
            'Posting and messages stay locked until verification finishes.',
            'يبقى النشر والرسائل مقفلين حتى اكتمال التحقق.',
          ),
          loading: true,
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return _NoticeCard(
          key: const Key('community-policy-notice-error'),
          icon: Icons.gpp_maybe_outlined,
          title: communityText(
            context,
            'Community policy could not be verified',
            'تعذر التحقق من سياسة المجتمع',
          ),
          body: communityText(
            context,
            'Posting and messages remain locked. Check your connection and retry.',
            'يبقى النشر والرسائل مقفلين. تحقق من الاتصال وأعد المحاولة.',
          ),
          actionLabel: communityText(context, 'Retry', 'إعادة المحاولة'),
          onAction: onRetry,
        );
      }

      final policyState = snapshot.data!;
      if (policyState.status == CommunityPolicyStatus.accepted &&
          policyState.permitsCommunityPublishing) {
        return const SizedBox.shrink();
      }
      if (policyState.status == CommunityPolicyStatus.unavailable) {
        return _NoticeCard(
          key: const Key('community-policy-notice-unavailable'),
          icon: Icons.policy_outlined,
          title: communityText(
            context,
            'Community publishing is unavailable',
            'النشر في المجتمع غير متاح',
          ),
          body: communityText(
            context,
            'No active production policy could be verified. No acceptance has been recorded.',
            'تعذر التحقق من سياسة إنتاج فعالة. لم تُسجّل أي موافقة.',
          ),
          actionLabel: communityText(context, 'Review safety', 'مراجعة الأمان'),
          onAction: onReview,
        );
      }

      final version = policyState.policy?.version;
      final acceptanceBody = version == null
          ? communityText(
              context,
              'Posting and messages stay locked until you accept the active version.',
              'يبقى النشر والرسائل مقفلين حتى توافق على النسخة الفعالة.',
            )
          : communityText(
              context,
              'Posting and messages stay locked until you accept {version}.',
              'يبقى النشر والرسائل مقفلين حتى توافق على {version}.',
            ).replaceAll('{version}', version);
      return _NoticeCard(
        key: const Key('community-policy-notice-acceptance-required'),
        icon: Icons.rule_folder_outlined,
        title: communityText(
          context,
          'Review the active Community policy',
          'راجع سياسة المجتمع الفعالة',
        ),
        body: acceptanceBody,
        actionLabel: communityText(context, 'Review policy', 'مراجعة السياسة'),
        onAction: onReview,
      );
    },
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(body),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
