part of 'intelligence_center_page.dart';

extension _IntelligenceQueryRetry on _IntelligenceCenterPageState {
  Future<void> _retryFailedCoachRequest() async {
    final failed = failedRequest;
    if (failed == null || sending) return;
    if (!failed.cloudRequest.isCurrent) return;
    if (failed.cloudRequest.submitted &&
        !identical(checkedRefundedRequest, failed.cloudRequest)) {
      final generation = ++requestGeneration;
      _updateState(() => sending = true);
      final state = await failed.cloudRequest.reconcile();
      if (!mounted ||
          generation != requestGeneration ||
          !failed.cloudRequest.isCurrent ||
          !identical(failedRequest?.cloudRequest, failed.cloudRequest)) {
        return;
      }
      final text = switch (state) {
        CoachCloudRequestState.refunded => tr(
          'The previous request was refunded without using credits. Tap Retry request to send it again.',
          'أُعيد رصيد الطلب السابق دون استهلاك. اضغط «إعادة إرسال الطلب» لإرساله مجددًا.',
        ),
        CoachCloudRequestState.settled => tr(
          'This request completed, but its reply was not received. It will not be sent again.',
          'اكتمل هذا الطلب، لكن لم يصل رده. لن يُرسل مرة أخرى.',
        ),
        CoachCloudRequestState.pending => tr(
          'This request is still being processed. Check its status again shortly.',
          'ما زال هذا الطلب قيد المعالجة. تحقّق من حالته مجددًا بعد قليل.',
        ),
        _ => tr(
          'The request status could not be verified. It will not be sent again to avoid duplicate charges.',
          'تعذّر التحقق من حالة الطلب. لن يُرسل مرة أخرى لتجنب احتساب الرصيد مرتين.',
        ),
      };
      _updateState(() {
        checkedRefundedRequest = state == CoachCloudRequestState.refunded
            ? failed.cloudRequest
            : null;
        for (var i = 0; i < messages.length; i++) {
          if (retryableErrorMessageIds.contains(messages[i].id)) {
            messages[i] = messages[i].copyWith(text: text);
          }
        }
        sending = false;
        if (state == CoachCloudRequestState.settled) {
          failedRequest = null;
          retryableErrorMessageIds.clear();
          replyPhase = _CoachReplyPhase.idle;
        }
      });
      ref.invalidate(aiCoachCreditAccessProvider);
      ref
          .read(aiCoachUsageRefreshProvider.notifier)
          .requestAuthoritativeReload();
      unawaited(_saveConversation());
      return;
    }
    // A confirmed refund only changes the CTA. This path is reached on a
    // distinct explicit Retry request tap, never by the preceding status read.
    _updateState(() {
      checkedRefundedRequest = null;
      replyPhase = _CoachReplyPhase.idle;
      failedRequest = null;
    });
    await ask(
      inputChannel: failed.channel,
      detectedLanguageTag: failed.detectedLanguageTag,
      textOverride: failed.text,
      addUserMessage: false,
      autoSpeakReply: failed.autoSpeak,
      cloudRequest: failed.cloudRequest.submitted ? null : failed.cloudRequest,
    );
  }

  CoachCloudRequest _newCoachCloudRequest() {
    final epoch = conversationPersistenceEpoch;
    return CoachCloudRequest(
      requestId: 'coach-${const Uuid().v4()}',
      isCurrent: () =>
          _coachMessageVisitIsCurrent() &&
          conversationPersistenceEpoch == epoch,
    );
  }

  String? get _coachRetryLabel => failedRequest?.cloudRequest.submitted == true
      ? identical(checkedRefundedRequest, failedRequest!.cloudRequest)
            ? tr('Retry request', 'إعادة إرسال الطلب')
            : tr('Check request status', 'التحقق من حالة الطلب')
      : null;
}
