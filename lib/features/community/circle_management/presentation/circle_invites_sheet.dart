part of 'circle_management_surfaces.dart';

class _CircleInvitesForm extends StatefulWidget {
  const _CircleInvitesForm({
    required this.controller,
    required this.isCurrent,
    required this.onChanged,
    this.circle,
  });

  final CircleManagementController controller;
  final ValueGetter<bool> isCurrent;
  final Future<void> Function() onChanged;
  final CommunityCircle? circle;

  @override
  State<_CircleInvitesForm> createState() => _CircleInvitesFormState();
}

class _CircleInvitesFormState extends State<_CircleInvitesForm> {
  final _recipient = TextEditingController();
  final _sendForm = GlobalKey<FormState>();
  String? _reviewCode;
  String? _sendKey;
  String? _confirmingId;
  CircleInviteAction? _confirmingAction;
  bool _sending = false;
  bool _flowError = false;

  bool get _current =>
      mounted && widget.isCurrent() && widget.controller.isCurrent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) {
        unawaited(
          widget.controller.loadInvites(circleSlug: widget.circle?.slug),
        );
      }
    });
  }

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final circle = widget.circle;
    final code = _reviewCode;
    if (!_current || _sending || circle == null || code == null) return;
    setState(() {
      _sending = true;
      _flowError = false;
      _sendKey = CircleOperationKeys.inviteSend(circle.slug, code);
    });
    try {
      final result = await widget.controller.gateway.runForAttempt(
        isCurrentAttempt: () => _current,
        action: () => widget.controller.sendInvite(
          circleSlug: circle.slug,
          recipientCode: code,
        ),
      );
      if (_current && result.phase == CircleMutationPhase.succeeded) {
        await widget.onChanged();
        if (_current) {
          await widget.controller.loadInvites(circleSlug: circle.slug);
        }
      }
    } on Object {
      if (_current) setState(() => _flowError = true);
    } finally {
      if (_current) setState(() => _sending = false);
    }
  }

  Future<void> _act(CircleInvitation invite, CircleInviteAction action) async {
    if (!_current) return;
    final key = CircleOperationKeys.inviteAction(invite.id);
    if (_operationPending(widget.controller.operation(key))) return;
    setState(() => _flowError = false);
    try {
      final result = await widget.controller.gateway.runForAttempt(
        isCurrentAttempt: () => _current,
        action: () => widget.controller.actOnInvite(invite, action),
      );
      if (!_current) return;
      if (result.phase == CircleMutationPhase.succeeded) {
        setState(() {
          _confirmingId = null;
          _confirmingAction = null;
        });
        await widget.onChanged();
        if (_current) {
          await widget.controller.loadInvites(circleSlug: widget.circle?.slug);
        }
      }
    } on Object {
      if (_current) setState(() => _flowError = true);
    }
  }

  String _status(CircleInviteStatus status) => switch (status) {
    CircleInviteStatus.pending => circleManagementText(
      context,
      'Pending',
      'قيد الانتظار',
    ),
    CircleInviteStatus.accepted => circleManagementText(
      context,
      'Accepted',
      'مقبولة',
    ),
    CircleInviteStatus.declined => circleManagementText(
      context,
      'Declined',
      'مرفوضة',
    ),
    CircleInviteStatus.cancelled => circleManagementText(
      context,
      'Cancelled',
      'ملغاة',
    ),
    CircleInviteStatus.expired => circleManagementText(
      context,
      'Expired',
      'منتهية الصلاحية',
    ),
  };

  String _actionLabel(CircleInviteAction action) => switch (action) {
    CircleInviteAction.accept => circleManagementText(
      context,
      'Accept',
      'قبول',
    ),
    CircleInviteAction.decline => circleManagementText(
      context,
      'Decline',
      'رفض',
    ),
    CircleInviteAction.cancel => circleManagementText(
      context,
      'Cancel invitation',
      'إلغاء الدعوة',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final slug = widget.circle?.slug;
    final canSend = slug != null && controller.capabilities?.canInvite == true;
    final sendState = _sendKey == null ? null : controller.operation(_sendKey!);
    final sendLocked = _sending || _operationPending(sendState);
    final canRead = controller.capabilities?.canReadInvites == true;
    return ListView(
      key: const Key('bil06-invitations'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          circleManagementText(context, 'Invitations', 'الدعوات'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_flowError) _ManagementNotice(text: _managementStepError(context)),
        Text(
          circleManagementText(
            context,
            'Reading this list does not accept invitations. Accept joins the named circle; it does not follow a person.',
            'قراءة هذه القائمة لا تقبل الدعوات. القبول ينضم إلى الدائرة المحددة ولا يتابع أي شخص.',
          ),
        ),
        if (canSend) ...[
          const SizedBox(height: 16),
          Form(
            key: _sendForm,
            child: TextFormField(
              key: const Key('bil06-invite-recipient'),
              controller: _recipient,
              enabled: !sendLocked,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                labelText: circleManagementText(
                  context,
                  'Recipient BIL Code',
                  'رمز BIL للمستلم',
                ),
                helperText: circleManagementText(
                  context,
                  'Use the exact code shared by the recipient.',
                  'استخدم الرمز الذي شاركه المستلم نفسه.',
                ),
              ),
              onChanged: (_) => setState(() => _reviewCode = null),
              validator: (value) {
                try {
                  circleRecipientCode(value ?? '');
                  return null;
                } on ArgumentError {
                  return circleManagementText(
                    context,
                    'Enter a valid BIL Code.',
                    'أدخل رمز BIL صالحًا.',
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('bil06-invite-review'),
            onPressed: sendLocked
                ? null
                : () {
                    if (!_current ||
                        !(_sendForm.currentState?.validate() ?? false)) {
                      return;
                    }
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _reviewCode = circleRecipientCode(_recipient.text);
                      _sendKey = CircleOperationKeys.inviteSend(
                        slug,
                        _reviewCode!,
                      );
                    });
                  },
            child: Text(
              circleManagementText(
                context,
                'Review invitation',
                'مراجعة الدعوة',
              ),
            ),
          ),
          if (_reviewCode != null) ...[
            Text(
              circleManagementText(
                context,
                'Send an invitation to this BIL Code?',
                'هل تريد إرسال دعوة إلى رمز BIL هذا؟',
              ),
            ),
            SelectableText(
              _reviewCode!,
              key: const Key('bil06-invite-reviewed-code'),
            ),
            FilledButton(
              key: const Key('bil06-invite-send'),
              onPressed:
                  sendLocked ||
                      sendState?.phase == CircleMutationPhase.succeeded
                  ? null
                  : _send,
              child: Text(
                circleManagementText(
                  context,
                  'Send invitation',
                  'إرسال الدعوة',
                ),
              ),
            ),
          ],
        ],
        // Pending sends survive closing and reopening the sheet. Their only
        // retry is receipt readback, including when the form text was disposed.
        for (final operation in controller.operations)
          if (operation.key.startsWith('invite:send:') &&
              (slug == null || operation.key.startsWith('invite:send:$slug:')))
            _OperationNotice(
              key: Key('bil06-send-operation-notice-${operation.key}'),
              controller: controller,
              operationKey: operation.key,
              isCurrent: () => _current,
              onChanged: () async {
                if (!_current) return;
                await widget.onChanged();
                if (_current) await controller.loadInvites(circleSlug: slug);
              },
              success: circleManagementText(
                context,
                'Invitation saved and confirmed.',
                'تم حفظ الدعوة والتحقق منها.',
              ),
            ),
        const Divider(height: 28),
        if (!canRead)
          _ManagementNotice(
            text: circleManagementText(
              context,
              'Invitation access is unavailable.',
              'صلاحية الوصول إلى الدعوات غير متاحة.',
            ),
          ),
        if (controller.invitesLoading) const LinearProgressIndicator(),
        if (controller.invitesError != null)
          _ManagementNotice(
            key: const Key('bil06-invites-error'),
            text: circleManagementText(
              context,
              'Could not refresh invitations. Check again for their current state.',
              'تعذر تحديث الدعوات. تحقق مجددًا لمعرفة حالتها الحالية.',
            ),
            action: controller.invitesLoading || !canRead
                ? null
                : () => controller.loadInvites(circleSlug: slug),
          ),
        if (canRead &&
            !controller.invitesLoading &&
            controller.invitesError == null &&
            controller.invites.isEmpty)
          _ManagementNotice(
            text: circleManagementText(
              context,
              'No invitations are available.',
              'لا توجد دعوات متاحة.',
            ),
          ),
        if (canRead)
          for (final invite in controller.invites) _inviteRow(invite),
        if (canRead && controller.invitesHasMore)
          TextButton.icon(
            key: const Key('bil06-invites-more'),
            onPressed: controller.invitesLoading
                ? null
                : controller.loadMoreInvites,
            icon: const Icon(Icons.expand_more_rounded),
            label: Text(
              circleManagementText(
                context,
                'Load more invitations',
                'تحميل المزيد من الدعوات',
              ),
            ),
          ),
        TextButton.icon(
          key: const Key('bil06-invites-refresh'),
          onPressed: controller.invitesLoading || !canRead
              ? null
              : () => controller.loadInvites(circleSlug: slug),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            circleManagementText(
              context,
              'Refresh invitations',
              'تحديث الدعوات',
            ),
          ),
        ),
      ],
    );
  }

  Widget _inviteRow(CircleInvitation invite) {
    final controller = widget.controller;
    final key = CircleOperationKeys.inviteAction(invite.id);
    final operation = controller.operation(key);
    final record = operation?.receipt?.invite ?? invite;
    final received = record.inviteeId == controller.gateway.ownerId;
    final personName = received ? record.inviterName : record.inviteeName;
    final locked = _operationPending(operation);
    final action = _confirmingId == invite.id ? _confirmingAction : null;
    return Padding(
      key: Key('bil06-invite-${invite.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            record.circleName?.isNotEmpty == true
                ? record.circleName!
                : record.circleSlug,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            _status(record.status),
            key: Key('bil06-invite-status-${invite.id}'),
          ),
          Text(
            '${received ? circleManagementText(context, 'Invited by', 'الداعي') : circleManagementText(context, 'Recipient', 'المستلم')}: ${personName?.trim().isNotEmpty == true ? personName! : circleManagementText(context, 'Name unavailable', 'الاسم غير متاح')}',
            key: Key('bil06-invite-person-${invite.id}'),
          ),
          if (record.recipientCode != null)
            Text(
              '${circleManagementText(context, 'Recipient BIL Code', 'رمز BIL للمستلم')}: ${record.recipientCode}',
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final choice in CircleInviteAction.values)
                if (record.permits(choice, controller.gateway.ownerId))
                  OutlinedButton(
                    key: Key('bil06-invite-${choice.name}-${invite.id}'),
                    onPressed: locked
                        ? null
                        : () {
                            if (!_current) return;
                            setState(() {
                              _confirmingId = invite.id;
                              _confirmingAction = choice;
                            });
                          },
                    child: Text(_actionLabel(choice)),
                  ),
            ],
          ),
          if (action != null &&
              record.permits(action, controller.gateway.ownerId)) ...[
            Text(
              action == CircleInviteAction.accept
                  ? circleManagementText(
                      context,
                      'Accept this invitation and join this circle?',
                      'هل تريد قبول هذه الدعوة والانضمام إلى الدائرة؟',
                    )
                  : '${_actionLabel(action)}?',
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: Key('bil06-invite-confirm-${invite.id}'),
                  onPressed: locked ? null : () => _act(record, action),
                  child: Text(_actionLabel(action)),
                ),
                TextButton(
                  onPressed: locked
                      ? null
                      : () => setState(() {
                          _confirmingId = null;
                          _confirmingAction = null;
                        }),
                  child: Text(
                    circleManagementText(
                      context,
                      'Keep invitation unchanged',
                      'إبقاء الدعوة كما هي',
                    ),
                  ),
                ),
              ],
            ),
          ],
          _OperationNotice(
            key: Key('bil06-invite-operation-notice-$key'),
            controller: controller,
            operationKey: key,
            isCurrent: () => _current,
            onChanged: () async {
              if (!_current) return;
              await widget.onChanged();
              if (_current) {
                await controller.loadInvites(circleSlug: widget.circle?.slug);
              }
            },
            success: circleManagementText(
              context,
              'Invitation state confirmed.',
              'تم التحقق من حالة الدعوة.',
            ),
          ),
        ],
      ),
    );
  }
}
