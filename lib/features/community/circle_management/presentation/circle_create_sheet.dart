part of 'circle_management_surfaces.dart';

class _CircleCreateForm extends StatefulWidget {
  const _CircleCreateForm({
    required this.controller,
    required this.isCurrent,
    required this.onChanged,
  });

  final CircleManagementController controller;
  final ValueGetter<bool> isCurrent;
  final Future<void> Function() onChanged;

  @override
  State<_CircleCreateForm> createState() => _CircleCreateFormState();
}

class _CircleCreateFormState extends State<_CircleCreateForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _rules = TextEditingController();
  CommunityCircleAccess? _access;
  CommunityCircleJoinPolicy? _policy;
  CircleDraft? _review;
  bool _submitting = false;
  String? _validationError;
  bool _flowError = false;

  bool get _current =>
      mounted && widget.isCurrent() && widget.controller.isCurrent;

  @override
  void initState() {
    super.initState();
    final draft = widget.controller
        .operation(CircleOperationKeys.create)
        ?.draft;
    if (draft != null) {
      _name.text = draft.displayName;
      _description.text = draft.description;
      _rules.text = draft.rules;
      _access = draft.access;
      _policy = draft.joinPolicy;
      _review = draft;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _prepareReview() {
    if (!_current || !(_form.currentState?.validate() ?? false)) return;
    final access = _access;
    final policy = _policy;
    if (access == null || policy == null) return;
    final draft = CircleDraft(
      displayName: _name.text.trim(),
      description: _description.text.trim(),
      rules: _rules.text.trim(),
      access: access,
      joinPolicy: policy,
    );
    try {
      draft.validate();
    } on Object {
      setState(
        () => _validationError = circleManagementText(
          context,
          'Check the text and privacy choices before continuing.',
          'راجع النص واختيارات الخصوصية قبل المتابعة.',
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _review = draft;
      _validationError = null;
    });
  }

  Future<void> _submit() async {
    if (!_current || _submitting || _review == null) return;
    setState(() {
      _submitting = true;
      _flowError = false;
    });
    try {
      final result = await widget.controller.gateway.runForAttempt(
        isCurrentAttempt: () => _current,
        action: () => widget.controller.createCircle(_review!),
      );
      if (_current && result.phase == CircleMutationPhase.succeeded) {
        await widget.onChanged();
      }
    } on Object {
      if (_current) setState(() => _flowError = true);
    } finally {
      if (_current) setState(() => _submitting = false);
    }
  }

  String? _textLimit(String? value, int maximum, {bool required = false}) {
    final length = (value ?? '').trim().runes.length;
    if (required && length < 2) {
      return circleManagementText(
        context,
        'Enter a name of at least 2 characters.',
        'أدخل اسمًا من حرفين على الأقل.',
      );
    }
    if (length > maximum) {
      return circleManagementText(
        context,
        'Use at most $maximum characters.',
        'استخدم $maximum حرفًا كحد أقصى.',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final operation = controller.operation(CircleOperationKeys.create);
    final pending = _operationPending(operation) || _submitting;
    final succeeded = operation?.phase == CircleMutationPhase.succeeded;
    final permitted = controller.capabilities?.canCreate == true;
    final review = _review;
    return ListView(
      key: const Key('bil06-create-form'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          circleManagementText(context, 'Create a circle', 'إنشاء دائرة'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_validationError != null)
          _ManagementNotice(text: _validationError!),
        if (_flowError) _ManagementNotice(text: _managementStepError(context)),
        if (!permitted)
          _ManagementNotice(
            text: circleManagementText(
              context,
              'Your account does not have permission to create circles.',
              'لا يملك حسابك صلاحية إنشاء دوائر.',
            ),
          ),
        if (review == null && !succeeded)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('bil06-create-name'),
                  controller: _name,
                  enabled: !pending && permitted,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: circleManagementText(
                      context,
                      'Circle name',
                      'اسم الدائرة',
                    ),
                  ),
                  validator: (value) => _textLimit(value, 80, required: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('bil06-create-description'),
                  controller: _description,
                  enabled: !pending && permitted,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: circleManagementText(
                      context,
                      'Description',
                      'الوصف',
                    ),
                  ),
                  validator: (value) => _textLimit(value, 1000),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CommunityCircleAccess>(
                  key: const Key('bil06-create-privacy'),
                  initialValue: _access,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: circleManagementText(
                      context,
                      'Choose circle privacy',
                      'اختر خصوصية الدائرة',
                    ),
                  ),
                  items: [
                    for (final access in CommunityCircleAccess.values)
                      DropdownMenuItem(
                        value: access,
                        child: Text(_accessLabel(context, access)),
                      ),
                  ],
                  onChanged: pending || !permitted
                      ? null
                      : (value) {
                          if (!_current) return;
                          setState(() {
                            _access = value;
                            _policy = null;
                          });
                        },
                  validator: (value) => value == null
                      ? circleManagementText(
                          context,
                          'Choose privacy.',
                          'اختر الخصوصية.',
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  circleManagementText(
                    context,
                    'Public circles can appear in discovery. Private circles are visible only to people with access. Your selection does not accept Community policy for anyone.',
                    'قد تظهر الدوائر العامة في الاكتشاف. لا تظهر الدوائر الخاصة إلا لمن يملك صلاحية عرضها. لا يُعد اختيارك قبولًا لسياسة المجتمع نيابةً عن أي شخص.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CommunityCircleJoinPolicy>(
                  key: ValueKey(
                    'bil06-create-join-${_access?.name ?? 'unset'}',
                  ),
                  initialValue: _policy,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: circleManagementText(
                      context,
                      'How members join',
                      'طريقة الانضمام',
                    ),
                  ),
                  items: [
                    for (final policy in CommunityCircleJoinPolicy.values)
                      if (_access != CommunityCircleAccess.private ||
                          policy != CommunityCircleJoinPolicy.open)
                        DropdownMenuItem(
                          value: policy,
                          child: Text(_joinLabel(context, policy)),
                        ),
                  ],
                  onChanged: pending || !permitted || _access == null
                      ? null
                      : (value) {
                          if (_current) setState(() => _policy = value);
                        },
                  validator: (value) => value == null
                      ? circleManagementText(
                          context,
                          'Choose how members join.',
                          'اختر طريقة الانضمام.',
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('bil06-create-rules'),
                  controller: _rules,
                  enabled: !pending && permitted,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: circleManagementText(
                      context,
                      'Circle rules (optional)',
                      'قواعد الدائرة (اختياري)',
                    ),
                  ),
                  validator: (value) => _textLimit(value, 2000),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('bil06-create-review'),
                  onPressed: pending || !permitted ? null : _prepareReview,
                  child: Text(
                    circleManagementText(
                      context,
                      'Review circle',
                      'مراجعة الدائرة',
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (review != null && !succeeded) ...[
          Text(
            circleManagementText(
              context,
              'Review before creating',
              'المراجعة قبل الإنشاء',
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Text(review.displayName, key: const Key('bil06-create-review-name')),
          const SizedBox(height: 8),
          Text(
            review.description.isEmpty
                ? circleManagementText(
                    context,
                    'No description provided.',
                    'لم يُضَف وصف.',
                  )
                : review.description,
          ),
          const SizedBox(height: 8),
          Text(
            '${_accessLabel(context, review.access)} · ${_joinLabel(context, review.joinPolicy)}',
          ),
          const SizedBox(height: 8),
          Text(
            review.rules.isEmpty
                ? circleManagementText(
                    context,
                    'No additional circle rules provided.',
                    'لم تُضَف قواعد إضافية للدائرة.',
                  )
                : review.rules,
          ),
          const SizedBox(height: 12),
          Text(
            circleManagementText(
              context,
              'Creating this circle makes you its owner. Invitations are sent only when you explicitly choose a recipient and send one.',
              'إنشاء هذه الدائرة يجعلك مالكها. لا تُرسل الدعوات إلا عندما تختار مستلمًا وترسل الدعوة صراحةً.',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('bil06-create-submit'),
            onPressed: pending || !permitted ? null : _submit,
            child: Text(
              circleManagementText(
                context,
                'Create this circle',
                'إنشاء هذه الدائرة',
              ),
            ),
          ),
          TextButton(
            key: const Key('bil06-create-edit'),
            onPressed:
                pending ||
                    (operation != null &&
                        !_operationDefinitivelyRejected(operation))
                ? null
                : () {
                    if (!_current) return;
                    if (operation != null &&
                        !controller.resetDefinitivelyFailedOperation(
                          CircleOperationKeys.create,
                        )) {
                      return;
                    }
                    setState(() => _review = null);
                  },
            child: Text(
              circleManagementText(context, 'Edit details', 'تعديل التفاصيل'),
            ),
          ),
        ],
        _OperationNotice(
          key: const Key('bil06-create-operation-notice'),
          controller: controller,
          operationKey: CircleOperationKeys.create,
          isCurrent: () => _current,
          onChanged: widget.onChanged,
          success: circleManagementText(
            context,
            'Circle created and confirmed.',
            'تم إنشاء الدائرة والتحقق منها.',
          ),
        ),
        if (succeeded) ...[
          if (operation?.receipt?.circle?.displayName case final String name)
            Text(name, key: const Key('bil06-created-name')),
          TextButton(
            key: const Key('bil06-create-another'),
            onPressed: !permitted
                ? null
                : () {
                    if (!_current ||
                        !controller.resetSucceededOperation(
                          CircleOperationKeys.create,
                        )) {
                      return;
                    }
                    setState(() {
                      _name.clear();
                      _description.clear();
                      _rules.clear();
                      _access = null;
                      _policy = null;
                      _review = null;
                    });
                  },
            child: Text(
              circleManagementText(
                context,
                'Create another circle',
                'إنشاء دائرة أخرى',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
