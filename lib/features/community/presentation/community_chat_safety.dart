part of 'community_people_page.dart';

extension _CommunityChatSafety on _CommunityChatPageState {
  Future<void> _messageSafety(CommunityMessage message, String action) async {
    final binding = _binding;
    if (!_current(binding) ||
        _safetyBusy ||
        message.senderId == _ownerId ||
        message.senderId != _peerId ||
        message.recipientId != _ownerId ||
        !const {'report', 'block'}.contains(action)) {
      return;
    }
    _setChatState(() => _safetyBusy = true);
    var blocked = false;
    try {
      await _run(binding, () async {
        if (action == 'report') {
          final draft = await showCommunityReportSheet(
            context,
            target: CommunityReportTarget.message,
          );
          _check(binding);
          if (draft == null) return;
          await _repository!.report(
            targetKind: 'message',
            targetId: message.id,
            reason: draft.reason,
          );
          _check(binding);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                communityText(
                  context,
                  'Report sent for review.',
                  'تم إرسال البلاغ للمراجعة.',
                ),
              ),
            ),
          );
        } else {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => BilPearlMaterialAlertDialog(
              title: Text(
                communityText(context, 'Block this member?', 'حظر هذا العضو؟'),
              ),
              content: Text(
                communityText(
                  context,
                  'You will no longer see each other in Community or messages.',
                  'لن يتمكن أي منكما من رؤية الآخر في المجتمع أو الرسائل.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(communityText(context, 'Cancel', 'إلغاء')),
                ),
                FilledButton(
                  key: const Key('community-message-confirm-block'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(communityText(context, 'Block', 'حظر')),
                ),
              ],
            ),
          );
          _check(binding);
          if (confirmed != true) return;
          await _repository!.blockMember(message.senderId);
          _check(binding);
          blocked = true;
        }
      });
      if (blocked && _current(binding)) {
        _setChatState(() => _safetyBlocked = true);
        _retire();
      }
    } on CommunityOwnerOperationCancelled {
      // No action or feedback may cross an owner/conversation change.
    } catch (_) {
      if (mounted && _current(binding)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not complete that action safely. Try again.',
                'تعذر تنفيذ الإجراء بأمان. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (_current(binding)) _setChatState(() => _safetyBusy = false);
    }
  }
}
