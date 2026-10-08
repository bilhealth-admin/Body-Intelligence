part of 'circle_management_surfaces.dart';

class _CircleMediaForm extends StatefulWidget {
  const _CircleMediaForm({
    required this.controller,
    required this.isCurrent,
    required this.circle,
    required this.onChanged,
    this.imagePicker,
  });

  final CircleManagementController controller;
  final ValueGetter<bool> isCurrent;
  final CommunityCircle circle;
  final Future<void> Function() onChanged;
  final CommunityPostImagePickerContract? imagePicker;

  @override
  State<_CircleMediaForm> createState() => _CircleMediaFormState();
}

class _CircleMediaFormState extends State<_CircleMediaForm> {
  final _drafts = <CircleMediaKind, CommunityPostImageDraft>{};
  final _pickerErrors = <CircleMediaKind, bool>{};
  final _flowErrors = <CircleMediaKind, bool>{};
  CircleMediaKind? _picking;
  int _pickGeneration = 0;

  bool get _current =>
      mounted && widget.isCurrent() && widget.controller.isCurrent;

  @override
  void dispose() {
    _pickGeneration++;
    _drafts.clear();
    super.dispose();
  }

  Future<void> _pick(CircleMediaKind kind) async {
    if (!_current ||
        _picking != null ||
        widget.controller.capabilities?.canManageMedia != true) {
      return;
    }
    final key = CircleOperationKeys.media(widget.circle.slug, kind);
    final state = widget.controller.operation(key);
    if (state?.phase == CircleMutationPhase.failed &&
        !widget.controller.resetDefinitivelyFailedOperation(key)) {
      return;
    }
    final generation = ++_pickGeneration;
    setState(() {
      _picking = kind;
      _pickerErrors.remove(kind);
    });
    try {
      final image = await (widget.imagePicker ?? CommunityPostImagePicker())
          .pick();
      if (!_current || generation != _pickGeneration) return;
      if (image != null) setState(() => _drafts[kind] = image);
      // A cancelled system picker does not upload, clear a saved image, or
      // claim that an image was changed.
    } on Object {
      if (_current && generation == _pickGeneration) {
        setState(() => _pickerErrors[kind] = true);
      }
    } finally {
      if (_current && generation == _pickGeneration) {
        setState(() => _picking = null);
      }
    }
  }

  Future<void> _upload(CircleMediaKind kind) async {
    final image = _drafts[kind];
    final controller = widget.controller;
    final key = CircleOperationKeys.media(widget.circle.slug, kind);
    final state = controller.operation(key);
    final recoveredReservation =
        state?.phase == CircleMutationPhase.awaitingUpload &&
        !controller.mediaCanResume(key);
    if (!_current ||
        image == null ||
        (_operationPending(state) && !recoveredReservation)) {
      return;
    }
    await _runAction(kind, () {
      if (controller.operation(key)?.phase == CircleMutationPhase.failed &&
          !controller.mediaCanAcceptRetryImage(key)) {
        return controller.retryFailedMedia(key);
      }
      controller.resetSucceededOperation(key);
      return controller.uploadMedia(
        circleSlug: widget.circle.slug,
        kind: kind,
        image: image,
      );
    });
  }

  Future<void> _runAction(
    CircleMediaKind kind,
    Future<CircleOperationState> Function() action, {
    bool discardOnCancelled = false,
  }) async {
    if (!_current) return;
    setState(() => _flowErrors.remove(kind));
    try {
      final result = await widget.controller.gateway.runForAttempt(
        isCurrentAttempt: () => _current,
        action: action,
      );
      if (!_current) return;
      if (result.phase == CircleMutationPhase.succeeded) {
        setState(() => _drafts.remove(kind));
        await widget.onChanged();
      } else if (discardOnCancelled &&
          result.phase == CircleMutationPhase.cancelled) {
        setState(() => _drafts.remove(kind));
      }
    } on Object {
      if (_current) setState(() => _flowErrors[kind] = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final permitted = controller.capabilities?.canManageMedia == true;
    final managed = controller.managedCircle?.slug == widget.circle.slug
        ? controller.managedCircle
        : widget.circle is ManagedCommunityCircle
        ? widget.circle as ManagedCommunityCircle
        : null;
    return ListView(
      key: const Key('bil06-circle-media'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          circleManagementText(
            context,
            'Circle image and cover',
            'صورة الدائرة وغلافها',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          circleManagementText(
            context,
            'Choose an image you have permission to share. A selected preview stays on your device until you choose Upload. Images follow this circle’s access rules.',
            'اختر صورة تملك حق مشاركتها. تبقى معاينة الصورة المختارة على جهازك حتى تضغط رفع. تتبع الصور صلاحيات الوصول إلى هذه الدائرة.',
          ),
        ),
        if (!permitted)
          _ManagementNotice(
            text: circleManagementText(
              context,
              'Only an authorized circle manager can change images.',
              'يمكن لمدير الدائرة المخوّل فقط تغيير الصور.',
            ),
          ),
        if (controller.circleLoading) const LinearProgressIndicator(),
        if (controller.circleError != null)
          _ManagementNotice(
            text: circleManagementText(
              context,
              'Current circle images could not be verified.',
              'تعذر التحقق من صور الدائرة الحالية.',
            ),
            action: controller.circleLoading
                ? null
                : () => controller.loadCircle(widget.circle.slug),
          ),
        for (final kind in CircleMediaKind.values) ...[
          const Divider(height: 28),
          _mediaSlot(
            kind,
            kind == CircleMediaKind.avatar ? managed?.avatar : managed?.cover,
            permitted,
          ),
        ],
      ],
    );
  }

  Widget _mediaSlot(
    CircleMediaKind kind,
    CircleMediaReference? media,
    bool permitted,
  ) {
    final controller = widget.controller;
    final key = CircleOperationKeys.media(widget.circle.slug, kind);
    final state = controller.operation(key);
    final mutationPending = _operationPending(state);
    final recoveredReservation =
        state?.phase == CircleMutationPhase.awaitingUpload &&
        !controller.mediaCanResume(key);
    final locked =
        (mutationPending && !recoveredReservation) ||
        controller.mediaCleanupPending(key);
    final failedUncertain =
        state?.phase == CircleMutationPhase.failed &&
        !_operationDefinitivelyRejected(state) &&
        !controller.mediaCanAcceptRetryImage(key);
    final image = _drafts[kind];
    final label = kind == CircleMediaKind.avatar
        ? circleManagementText(context, 'Circle image', 'صورة الدائرة')
        : circleManagementText(context, 'Cover image', 'صورة الغلاف');
    return Column(
      key: Key('bil06-media-${kind.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        CircleVerifiedMedia(
          key: Key('bil06-saved-media-${kind.name}'),
          media: media,
          label: label,
        ),
        if (_pickerErrors[kind] == true)
          _ManagementNotice(
            key: Key('bil06-picker-error-${kind.name}'),
            text: circleManagementText(
              context,
              'Could not read that image. Choose a supported image and try again.',
              'تعذر قراءة هذه الصورة. اختر صورة مدعومة وحاول مجددًا.',
            ),
          ),
        if (_flowErrors[kind] == true)
          _ManagementNotice(text: _managementStepError(context)),
        if (image != null) ...[
          const SizedBox(height: 12),
          Text(
            state == null
                ? circleManagementText(
                    context,
                    'Selected preview — not uploaded',
                    'معاينة الصورة المختارة — لم تُرفع بعد',
                  )
                : circleManagementText(
                    context,
                    'Selected image preview',
                    'معاينة الصورة المختارة',
                  ),
          ),
          const SizedBox(height: 8),
          Image.memory(
            image.bytes,
            key: Key('bil06-selected-media-${kind.name}'),
            height: 144,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (context, _, _) => Text(
              circleManagementText(
                context,
                'Preview unavailable.',
                'المعاينة غير متاحة.',
              ),
            ),
          ),
        ],
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: Key('bil06-pick-media-${kind.name}'),
              onPressed:
                  !permitted || locked || failedUncertain || _picking != null
                  ? null
                  : () => _pick(kind),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _picking == kind
                    ? circleManagementText(
                        context,
                        'Choosing image…',
                        'جارٍ اختيار الصورة…',
                      )
                    : circleManagementText(
                        context,
                        'Choose image',
                        'اختيار صورة',
                      ),
              ),
            ),
            if (image != null) ...[
              FilledButton(
                key: Key('bil06-upload-media-${kind.name}'),
                onPressed: !permitted || locked ? null : () => _upload(kind),
                child: Text(circleManagementText(context, 'Upload', 'رفع')),
              ),
              TextButton(
                key: Key('bil06-discard-media-${kind.name}'),
                onPressed: locked
                    ? null
                    : () {
                        if (_current) setState(() => _drafts.remove(kind));
                      },
                child: Text(
                  circleManagementText(
                    context,
                    'Discard selection',
                    'إلغاء اختيار الصورة',
                  ),
                ),
              ),
            ],
            if (state?.phase == CircleMutationPhase.failed && image == null)
              OutlinedButton(
                key: Key('bil06-retry-upload-${kind.name}'),
                onPressed: !permitted
                    ? null
                    : () => _runAction(
                        kind,
                        () => controller.retryFailedMedia(key),
                      ),
                child: Text(
                  circleManagementText(
                    context,
                    'Retry the same upload request',
                    'إعادة محاولة طلب الرفع نفسه',
                  ),
                ),
              ),
            if (state != null && (mutationPending || failedUncertain))
              TextButton(
                key: Key('bil06-cancel-media-${kind.name}'),
                onPressed: () => _runAction(
                  kind,
                  () => controller.cancelMedia(key),
                  discardOnCancelled: true,
                ),
                child: Text(
                  circleManagementText(
                    context,
                    'Request upload cancellation',
                    'طلب إلغاء الرفع',
                  ),
                ),
              ),
          ],
        ),
        _OperationNotice(
          key: Key('bil06-media-operation-notice-$key'),
          controller: controller,
          operationKey: key,
          isCurrent: () => _current,
          onChanged: () async {
            if (!_current) return;
            if (controller.operation(key)?.phase ==
                CircleMutationPhase.succeeded) {
              setState(() => _drafts.remove(kind));
              await widget.onChanged();
            }
          },
          success: circleManagementText(
            context,
            'Image saved and confirmed.',
            'تم حفظ الصورة والتحقق منها.',
          ),
        ),
      ],
    );
  }
}
