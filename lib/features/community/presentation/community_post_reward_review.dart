part of 'community_post_moderation_page.dart';

Future<String?> _reviewReason(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _ReviewReasonDialog(),
);

class _ReviewReasonDialog extends StatefulWidget {
  const _ReviewReasonDialog();
  @override
  State<_ReviewReasonDialog> createState() => _ReviewReasonDialogState();
}

class _ReviewReasonDialogState extends State<_ReviewReasonDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(
        communityText(context, 'Reason for this decision', 'سبب هذا القرار'),
      ),
      content: TextField(
        key: const Key('community-review-reason'),
        controller: controller,
        maxLength: 160,
        minLines: 2,
        maxLines: 5,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: communityText(
            context,
            'Explain the issue to the author',
            'وضّح المشكلة لصاحب المنشور',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(communityText(context, 'Cancel', 'إلغاء')),
        ),
        FilledButton(
          key: const Key('community-review-reason-confirm'),
          onPressed: valid
              ? () => Navigator.pop(context, controller.text.trim())
              : null,
          child: Text(communityText(context, 'Confirm', 'تأكيد')),
        ),
      ],
    );
  }
}

String _rewardStatusText(BuildContext context, String status) =>
    switch (status) {
      'not_requested' => communityText(
        context,
        'Published · reward not requested',
        'منشور · لم تُطلب مكافأة',
      ),
      'requested' => communityText(
        context,
        'Reward request awaiting an administrator',
        'طلب مكافأة بانتظار المسؤول',
      ),
      'executed' => communityText(
        context,
        'Reward executed',
        'تم تنفيذ المكافأة',
      ),
      'rejected' => communityText(
        context,
        'Reward request rejected',
        'رُفض طلب المكافأة',
      ),
      _ => communityText(
        context,
        'Reward not eligible under server policy',
        'المكافأة غير مستحقة وفق سياسة الخادم',
      ),
    };

class _RewardReviewCard extends StatelessWidget {
  const _RewardReviewCard({
    required this.review,
    required this.busy,
    required this.onRequest,
    required this.onApprove,
    required this.onReject,
  });
  final CommunityRewardReview review;
  final bool busy;
  final VoidCallback onRequest, onApprove, onReject;
  @override
  Widget build(BuildContext context) => Card(
    key: Key('community-reward-review-${review.snapshot.post.id}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            review.snapshot.post.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(_rewardStatusText(context, review.status)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (review.status == 'not_requested')
                FilledButton.tonal(
                  onPressed: busy ? null : onRequest,
                  key: Key(
                    'community-reward-request-${review.snapshot.post.id}',
                  ),
                  child: Text(
                    communityText(
                      context,
                      'Request eligible reward',
                      'طلب المكافأة المستحقة',
                    ),
                  ),
                ),
              if (review.status == 'requested' && review.canGrant) ...[
                FilledButton(
                  onPressed: busy ? null : onApprove,
                  key: Key(
                    'community-reward-approve-${review.snapshot.post.id}',
                  ),
                  child: Text(
                    communityText(context, 'Approve reward', 'اعتماد المكافأة'),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: Text(
                    communityText(context, 'Reject request', 'رفض الطلب'),
                  ),
                ),
              ],
              if (busy)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
