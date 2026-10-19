part of 'community_post_moderation_page.dart';

extension _CommunityAiCoachReportReview on _CommunityPostModerationPageState {
  Future<void> _reviewAiCoachSafetyReport(
    AiCoachSafetyReport report,
    String decision,
  ) async {
    final visit = _visit;
    final repository = _repository;
    final key = 'ai-coach:${report.id}';
    if (visit == null ||
        repository == null ||
        !visit.isCurrent ||
        !report.isOpen ||
        _busyTargets.contains(key)) {
      return;
    }
    final decisionLabel = switch (decision) {
      'no_violation' => communityText(
        context,
        'No violation',
        'لا توجد مخالفة',
      ),
      'confirmed_safety_issue' => communityText(
        context,
        'Confirm safety issue',
        'تأكيد مشكلة سلامة',
      ),
      _ => null,
    };
    if (decisionLabel == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BilPearlMaterialAlertDialog(
        title: Text(
          communityText(
            context,
            'Review AI Coach report?',
            'مراجعة بلاغ AI Coach؟',
          ),
        ),
        content: Text(
          communityText(
            context,
            'This records "{decisionLabel}" and removes the submitted answer text from the review queue. The report reason and decision remain in the audit record.',
            'يسجل هذا «{decisionLabel}» ويزيل نص الإجابة المقدمة من قائمة المراجعة. ويبقى سبب البلاغ والقرار في سجل التدقيق.',
          ).replaceAll('{decisionLabel}', decisionLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(communityText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            key: const Key('ai-coach-safety-review-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(decisionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !visit.isCurrent) return;

    _updateModerationState(() => _busyTargets.add(key));
    final operationId = _aiCoachDecisionIds.putIfAbsent(
      report.id,
      () => const Uuid().v4(),
    );
    try {
      await visit.requireFreshModerator();
      final receipt = await visit.run(
        () => repository.reviewAiCoachSafetyReport(
          reportId: report.id,
          decision: decision,
          operationId: operationId,
        ),
      );
      if (receipt.reportId != report.id ||
          receipt.decision != decision ||
          receipt.status != 'reviewed') {
        throw const FormatException('ai_coach_safety_review_readback_mismatch');
      }
      if (!mounted || !visit.isCurrent) return;
      await _reloadAndReadback(visit);
      if (!mounted || !visit.isCurrent) return;
      _aiCoachDecisionIds.remove(report.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'AI Coach report reviewed.',
              'تمت مراجعة بلاغ AI Coach.',
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not record the AI Coach review. Retry the same decision.',
              'تعذر تسجيل مراجعة AI Coach. أعد المحاولة بالقرار نفسه.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && visit.isCurrent) {
        _updateModerationState(() => _busyTargets.remove(key));
      }
    }
  }
}
