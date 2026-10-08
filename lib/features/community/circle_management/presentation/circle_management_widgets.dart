part of 'circle_management_surfaces.dart';

bool _operationPending(CircleOperationState? state) =>
    state != null &&
    (state.phase == CircleMutationPhase.submitting ||
        state.phase == CircleMutationPhase.readingBack ||
        state.phase == CircleMutationPhase.readbackRequired ||
        state.phase == CircleMutationPhase.awaitingUpload);

bool _operationDefinitivelyRejected(CircleOperationState? state) =>
    state?.phase == CircleMutationPhase.failed &&
    (state?.error is CirclePermissionDenied ||
        state?.error is CircleManagementUnavailable ||
        state?.error is CommunityPostImageException);

class _ManagementNotice extends StatelessWidget {
  const _ManagementNotice({required this.text, this.action, super.key});

  final String text;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(liveRegion: true, child: Text(text)),
        if (action != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                circleManagementText(context, 'Retry', 'إعادة المحاولة'),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ManagementOwnerChanged extends StatelessWidget {
  const _ManagementOwnerChanged();

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('bil06-owner-changed'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        circleManagementText(
          context,
          'Your account or circle changed. Close this view and open it again.',
          'تغير الحساب أو الدائرة. أغلق هذه الشاشة وافتحها مجددًا.',
        ),
      ),
    ),
  );
}

class _OperationNotice extends StatefulWidget {
  const _OperationNotice({
    required this.controller,
    required this.operationKey,
    required this.isCurrent,
    required this.onChanged,
    required this.success,
    super.key,
  });

  final CircleManagementController controller;
  final String operationKey;
  final ValueGetter<bool> isCurrent;
  final Future<void> Function() onChanged;
  final String success;

  @override
  State<_OperationNotice> createState() => _OperationNoticeState();
}

class _OperationNoticeState extends State<_OperationNotice> {
  bool _running = false;
  bool _error = false;

  CircleManagementController get controller => widget.controller;
  String get operationKey => widget.operationKey;
  String get success => widget.success;
  bool get _current => mounted && widget.isCurrent() && controller.isCurrent;

  Future<void> _run(Future<CircleOperationState> Function() action) async {
    if (!_current || _running) return;
    setState(() {
      _running = true;
      _error = false;
    });
    try {
      final result = await controller.gateway.runForAttempt(
        isCurrentAttempt: () => _current,
        action: action,
      );
      if (_current && result.phase == CircleMutationPhase.succeeded) {
        await widget.onChanged();
      }
    } on Object {
      if (_current) setState(() => _error = true);
    } finally {
      if (_current) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.operation(operationKey);
    if (state == null) return const SizedBox.shrink();
    final text = switch (state.phase) {
      CircleMutationPhase.submitting => circleManagementText(
        context,
        'Sending your request…',
        'جارٍ إرسال طلبك…',
      ),
      CircleMutationPhase.readingBack => circleManagementText(
        context,
        'Checking the saved result…',
        'جارٍ التحقق من النتيجة المحفوظة…',
      ),
      CircleMutationPhase.readbackRequired => circleManagementText(
        context,
        'The result is not confirmed yet. Check the result before trying a new action; this will not send the request again.',
        'لم تتأكد النتيجة بعد. تحقق منها قبل تنفيذ إجراء جديد؛ لن يُعاد إرسال الطلب.',
      ),
      CircleMutationPhase.awaitingUpload =>
        controller.mediaCanResume(operationKey)
            ? circleManagementText(
                context,
                'The upload is reserved but the image has not been uploaded. Continue or cancel this upload.',
                'تم حجز عملية الرفع، لكن الصورة لم تُرفع. تابع الرفع أو ألغِه.',
              )
            : circleManagementText(
                context,
                'The upload reservation was recovered after reopening. Choose the same image to continue safely, or cancel the reservation.',
                'تمت استعادة حجز الرفع بعد إعادة فتح التطبيق. اختر الصورة نفسها للمتابعة بأمان، أو ألغِ الحجز.',
              ),
      CircleMutationPhase.failed => circleManagementText(
        context,
        'Could not confirm this action. Check your access, then retry the same request.',
        'تعذر تأكيد هذا الإجراء. تحقق من صلاحيتك ثم أعد محاولة الطلب نفسه.',
      ),
      CircleMutationPhase.succeeded => success,
      CircleMutationPhase.cancelled =>
        controller.mediaCleanupPending(operationKey)
            ? circleManagementText(
                context,
                'Upload cancelled. Temporary image cleanup is still pending. Retry cleanup before starting another upload.',
                'أُلغي الرفع. ما زال حذف الصورة المؤقتة قيد الانتظار. أعد محاولة الحذف قبل بدء رفع جديد.',
              )
            : state.error != null && state.operation.startsWith('media_')
            ? circleManagementText(
                context,
                'The image could not be uploaded. Cancellation was confirmed. You can choose the image again.',
                'تعذر رفع الصورة. تم التأكد من إلغاء العملية. يمكنك اختيار الصورة مجددًا.',
              )
            : circleManagementText(
                context,
                'This operation was cancelled.',
                'أُلغيت هذه العملية.',
              ),
    };
    return Column(
      key: Key('bil06-operation-$operationKey'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.phase == CircleMutationPhase.submitting ||
            state.phase == CircleMutationPhase.readingBack)
          const LinearProgressIndicator(),
        _ManagementNotice(text: text),
        if (_error) _ManagementNotice(text: _managementStepError(context)),
        if (state.phase == CircleMutationPhase.readbackRequired)
          OutlinedButton.icon(
            key: Key('bil06-readback-$operationKey'),
            onPressed: _running
                ? null
                : () => _run(() => controller.retryReadback(operationKey)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              circleManagementText(
                context,
                'Check result',
                'التحقق من النتيجة',
              ),
            ),
          ),
        if (state.phase == CircleMutationPhase.awaitingUpload &&
            controller.mediaCanResume(operationKey))
          OutlinedButton.icon(
            key: Key('bil06-resume-$operationKey'),
            onPressed: _running
                ? null
                : () => _run(() => controller.resumeMedia(operationKey)),
            icon: const Icon(Icons.upload_rounded),
            label: Text(
              circleManagementText(context, 'Continue upload', 'متابعة الرفع'),
            ),
          ),
        if (controller.mediaCleanupPending(operationKey))
          OutlinedButton.icon(
            key: Key('bil06-cleanup-$operationKey'),
            onPressed: _running
                ? null
                : () => _run(() => controller.retryReadback(operationKey)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              circleManagementText(
                context,
                'Retry cleanup',
                'إعادة محاولة الحذف',
              ),
            ),
          ),
      ],
    );
  }
}

String _managementStepError(BuildContext context) => circleManagementText(
  context,
  'Could not finish this step. Check the request status before continuing.',
  'تعذر إتمام هذه الخطوة. تحقق من حالة الطلب قبل المتابعة.',
);

String _accessLabel(BuildContext context, CommunityCircleAccess access) =>
    access == CommunityCircleAccess.public
    ? circleManagementText(context, 'Public', 'عامة')
    : circleManagementText(context, 'Private', 'خاصة');

String _joinLabel(BuildContext context, CommunityCircleJoinPolicy policy) =>
    switch (policy) {
      CommunityCircleJoinPolicy.open => circleManagementText(
        context,
        'Anyone eligible can join',
        'يمكن لكل مستخدم مستوفٍ للشروط الانضمام',
      ),
      CommunityCircleJoinPolicy.request => circleManagementText(
        context,
        'Join requests require approval',
        'طلبات الانضمام تحتاج إلى موافقة',
      ),
      CommunityCircleJoinPolicy.invite => circleManagementText(
        context,
        'Invitation required',
        'تحتاج إلى دعوة',
      ),
    };

/// Only a server-validated media reference supplies a network image. The
/// fallback explicitly describes missing/unavailable media, never a stock
/// photograph or a claimed circle cover.
class CircleVerifiedMedia extends StatelessWidget {
  const CircleVerifiedMedia({
    required this.media,
    required this.label,
    this.width,
    this.height = 144,
    this.radius = 12,
    this.fallback,
    super.key,
  });

  final CircleMediaReference? media;
  final String label;
  final double? width;
  final double height;
  final double radius;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    Widget unavailable() => Semantics(
      label:
          '$label: ${circleManagementText(context, 'Image unavailable', 'الصورة غير متاحة')}',
      child:
          fallback ??
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(12),
            child: Text(
              circleManagementText(
                context,
                'Image unavailable',
                'الصورة غير متاحة',
              ),
              textAlign: TextAlign.center,
            ),
          ),
    );
    final url = media?.signedUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null || url.isEmpty
            ? unavailable()
            : Image.network(
                url,
                fit: BoxFit.cover,
                semanticLabel: label,
                errorBuilder: (context, _, _) => unavailable(),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
              ),
      ),
    );
  }
}
