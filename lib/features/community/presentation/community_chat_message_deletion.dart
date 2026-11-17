part of 'community_people_page.dart';

extension _CommunityChatMessageDeletion on _CommunityChatPageState {
  bool _canDeleteMessageForMe(CommunityMessage message) =>
      _current(_binding) &&
      ((message.senderId == _ownerId && message.recipientId == _peerId) ||
          (message.recipientId == _ownerId && message.senderId == _peerId));

  Widget _messageActionMenu(
    BuildContext context,
    CommunityMessage message, {
    required bool mine,
  }) => bilPearlPopupMenuButton<String>(
    key: Key('community-message-safety-${message.id}'),
    enabled: !_safetyBusy,
    iconColor: mine ? Colors.white : null,
    tooltip: communityText(context, 'Message actions', 'إجراءات الرسالة'),
    onSelected: (action) => action == 'delete'
        ? _deleteMessageForMe(message)
        : _messageSafety(message, action),
    itemBuilder: (_) => [
      PopupMenuItem(
        key: Key('community-message-delete-for-me-${message.id}'),
        value: 'delete',
        child: Text(_deleteForMeText(context)),
      ),
      if (!mine) ...[
        PopupMenuItem(
          value: 'report',
          child: Text(communityText(context, 'Report', 'إبلاغ')),
        ),
        PopupMenuItem(
          value: 'block',
          child: Text(communityText(context, 'Block member', 'حظر العضو')),
        ),
      ],
    ],
  );

  Future<bool> _confirmMessageDeletion(int binding) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    var decided = false;
    late final DialogRoute<bool> dialog;
    dialog = DialogRoute<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        void decide(bool remove) {
          if (decided) return;
          decided = true;
          if (!navigator.mounted || !dialog.isActive) return;
          if (!dialogContext.mounted ||
              !_current(binding) ||
              !dialog.isCurrent) {
            navigator.removeRoute<bool>(dialog, false);
            return;
          }
          navigator.pop<bool>(remove);
        }

        return BilPearlMaterialAlertDialog(
          key: const Key('community-message-delete-dialog'),
          scrollable: true,
          title: Text(
            _copy(
              context,
              'إزالة هذه الرسالة من رسائلك؟',
              'Remove this message from your mailbox?',
              'Retirer ce message de votre messagerie ?',
              '¿Eliminar este mensaje de tu buzón?',
              'Bu mesaj posta kutunuzdan kaldırılsın mı?',
            ),
          ),
          content: Text(
            _copy(
              context,
              'تُحذف نسختك فقط. يحتفظ الطرف الآخر بنسخته.',
              'Only your copy is removed. The other participant keeps their copy.',
              'Seule votre copie est supprimée. L’autre participant conserve la sienne.',
              'Solo se elimina tu copia. La otra persona conserva la suya.',
              'Yalnızca sizin kopyanız kaldırılır. Diğer katılımcı kendi kopyasını saklar.',
            ),
          ),
          actions: [
            TextButton(
              key: const Key('community-message-delete-cancel'),
              onPressed: () => decide(false),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              key: const Key('community-message-delete-confirm'),
              onPressed: () => decide(true),
              child: Text(_deleteForMeText(context)),
            ),
          ],
        );
      },
    );
    void cancelDialog() {
      decided = true;
      // Remove only this exact dialog after a visit/auth retirement, including
      // retirement during a widget rebuild. Never pop a replacement route.
      scheduleMicrotask(() {
        if (navigator.mounted && dialog.isActive) {
          navigator.removeRoute<bool>(dialog, false);
        }
      });
    }

    _cancelMessageDeletionDialog = cancelDialog;
    try {
      return await navigator.push<bool>(dialog) == true;
    } finally {
      if (identical(_cancelMessageDeletionDialog, cancelDialog)) {
        _cancelMessageDeletionDialog = null;
      }
    }
  }

  Future<void> _deleteMessageForMe(CommunityMessage message) async {
    final binding = _binding;
    if (_safetyBusy || !_canDeleteMessageForMe(message)) return;
    _setChatState(() => _safetyBusy = true);
    try {
      await _run(binding, () async {
        final confirmed = await _confirmMessageDeletion(binding);
        _check(binding);
        if (!confirmed || !_canDeleteMessageForMe(message)) return;
        await _repository!.deleteMessageForCurrentUser(message);
        _check(binding);
        if (!mounted) return;
        // This follows the confirmed actor/RLS readback, not an optimistic
        // mutation. Retire older head/page reads so they cannot restore it.
        _setChatState(() {
          _loadGeneration++;
          _rows = List.unmodifiable(_rows.where((row) => row.id != message.id));
          _observeMessagePresentation();
          _messages = Future.value(_rows);
        });
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                context,
                'أُزيلت الرسالة من رسائلك.',
                'Message removed from your mailbox.',
                'Message retiré de votre messagerie.',
                'Mensaje eliminado de tu buzón.',
                'Mesaj posta kutunuzdan kaldırıldı.',
              ),
            ),
          ),
        );
      });
    } on CommunityOwnerOperationCancelled {
      // Neither a deletion nor its feedback may cross an owner/peer/ABA visit.
    } on Object {
      if (mounted && _current(binding)) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
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

String _deleteForMeText(BuildContext context) => _copy(
  context,
  'حذف من رسائلي',
  'Delete for me',
  'Supprimer pour moi',
  'Eliminar para mí',
  'Benim için sil',
);
