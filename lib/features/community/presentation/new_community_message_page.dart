part of 'community_messages_page.dart';

class NewCommunityMessagePage extends StatefulWidget {
  const NewCommunityMessagePage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<NewCommunityMessagePage> createState() =>
      _NewCommunityMessagePageState();
}

class _NewCommunityMessagePageState extends State<NewCommunityMessagePage> {
  final _recipientSearch = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  CommunityRepository? _repository;
  Timer? _debounce;
  Future<List<Map<String, dynamic>>> _people = Future.value(const []);
  Future<CommunityPolicyState>? _policyState;
  String? _policyLocale;
  int _searchGeneration = 0;
  Map<String, dynamic>? _recipient;
  bool _sending = false;
  bool _confirmingReplacement = false;
  String? _sendRequestId, _sendRequestBody, _sendRequestRecipient;
  bool _removedDelivery = false;
  CommunityMessageOwnerVisit? _visit;

  @override
  void initState() {
    super.initState();
    _bind();
    _subject.addListener(_draftChanged);
    _body.addListener(_draftChanged);
  }

  void _draftChanged() {
    if (mounted && _visit?.isCurrent == true) setState(() {});
  }

  void _bind() {
    _visit = null;
    _repository = widget.repository;
    final client = _initializedCommunityClient();
    if (_repository == null && client?.auth.currentUser != null) {
      _repository = CommunityRepository(client!);
    }
    final repository = _repository;
    if (repository == null) return;
    _visit = CommunityMessageOwnerVisit(repository, () => mounted, () {
      _debounce?.cancel();
      _searchGeneration++;
      _recipient = null;
      _subject.clear();
      _body.clear();
      _sendRequestId = _sendRequestBody = _sendRequestRecipient = null;
      _removedDelivery = false;
      _recipientSearch.clear();
      _sending = false;
      if (mounted) setState(() {});
    });
    if (_visit!.isCurrent) {
      _people = _visit!.run(() => repository.searchProfiles(''));
    }
  }

  @override
  void didUpdateWidget(covariant NewCommunityMessagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _visit?.dispose();
      _debounce?.cancel();
      _searchGeneration++;
      _subject.clear();
      _body.clear();
      _sendRequestId = _sendRequestBody = _sendRequestRecipient = null;
      _removedDelivery = false;
      _recipientSearch.clear();
      _recipient = null;
      _policyState = null;
      _policyLocale = null;
      _sending = false;
      _bind();
      _loadPolicy();
    }
  }

  void _loadPolicy() {
    final visit = _visit;
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (visit?.isCurrent == true &&
        (_policyState == null || _policyLocale != locale)) {
      _policyLocale = locale;
      _policyState = visit!.run(
        () => visit.repository.loadCommunityPolicyState(localeCode: locale),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPolicy();
  }

  Future<CommunityPolicyState?> _refreshPolicyState() async {
    final visit = _visit;
    if (visit?.isCurrent != true) return null;
    final repository = visit!.repository;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final future = visit.run(
      () => repository.loadCommunityPolicyState(localeCode: locale),
    );
    setState(() {
      _policyLocale = locale;
      _policyState = future;
    });
    try {
      return await future;
    } on Object {
      return null;
    }
  }

  Future<void> _reviewPolicy() async {
    final visit = _visit;
    if (visit?.isCurrent != true) return;
    final repository = _MessagePolicyRepository(visit!);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            visit.guard(CommunitySafetyPage(repository: repository)),
      ),
    );
    if (mounted && visit.isCurrent) await _refreshPolicyState();
  }

  @override
  void dispose() {
    _visit?.dispose();
    _debounce?.cancel();
    _subject.removeListener(_draftChanged);
    _body.removeListener(_draftChanged);
    _recipientSearch.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    final visit = _visit;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted && visit?.isCurrent == true) {
        setState(() {
          _people = visit!
              .run(() => visit.repository.searchProfiles(value))
              .then(
                (rows) => generation == _searchGeneration ? rows : const [],
              );
        });
      }
    });
  }

  Future<void> _send() async {
    final visit = _visit;
    if (_sending || visit == null || !visit.isCurrent) return;
    final copy = _MessagesCopy.of(context);
    if (_repository == null ||
        _recipient == null ||
        _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.completeFields)));
      return;
    }
    final envelope = MessageBodyContract.compose(
      subject: _subject.text,
      body: _body.text,
    );
    final subjectTooLong = _subject.text.trim().runes.length > 120;
    if (subjectTooLong || envelope.runes.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subjectTooLong
                ? _privateSubjectLimitText(context)
                : _privateMessageLimitText(context),
          ),
        ),
      );
      return;
    }
    final recipient = _recipient!['user_id'] as String;
    setState(() => _sending = true);
    try {
      if (_removedDelivery) {
        setState(() => _confirmingReplacement = true);
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => BilPearlMaterialAlertDialog(
            key: const Key('community-message-replacement-confirmation'),
            title: Text(copy.sendNewMessage),
            content: Text(copy.replacementBody),
            actions: [
              TextButton(
                key: const Key('community-message-replacement-cancel'),
                onPressed: () => Navigator.pop(context, false),
                child: Text(communityText(context, 'Cancel', 'إلغاء')),
              ),
              FilledButton(
                key: const Key('community-message-replacement-send'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(copy.sendNewMessage),
              ),
            ],
          ),
        );
        if (mounted && visit.isCurrent) {
          setState(() => _confirmingReplacement = false);
        }
        if (replace != true || !mounted || !visit.isCurrent) return;
        _sendRequestId = _sendRequestBody = _sendRequestRecipient = null;
        _removedDelivery = false;
      }
      if (_sendRequestId == null ||
          _sendRequestBody != envelope ||
          _sendRequestRecipient != recipient) {
        _sendRequestId = newCommunityMessageRequestId();
        _sendRequestBody = envelope;
        _sendRequestRecipient = recipient;
      }
      await visit.run(
        () => visit.repository.sendMessageOperation(
          recipient,
          envelope,
          requestId: _sendRequestId!,
        ),
      );
      if (mounted && visit.isCurrent) {
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/community/messages');
        }
      }
    } on CommunityMessageDeliveryRemoved {
      if (!mounted || !visit.isCurrent) return;
      setState(() => _removedDelivery = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.deliveryRemoved)));
    } on TimeoutException {
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Sending could not be confirmed yet. Your text is kept; retry checks the same request.',
              'لم يتأكد الإرسال بعد. النص محفوظ؛ إعادة المحاولة تتحقق من الطلب نفسه.',
            ),
          ),
        ),
      );
    } on CommunityMessageDeliveryUnavailable {
      if (mounted && visit.isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Sending is unavailable on this server. Your text is kept. Try again later.',
                'الإرسال غير متاح على هذا الخادم. احتفظنا بالنص؛ حاول لاحقًا.',
              ),
            ),
          ),
        );
      }
    } on CommunityPolicyAccessException catch (error) {
      if (mounted && visit.isCurrent) {
        await _refreshPolicyState();
        if (!mounted || !visit.isCurrent) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                error.englishMessage(CommunityPolicyProtectedAction.messaging),
                error.arabicMessage(CommunityPolicyProtectedAction.messaging),
              ),
            ),
            action: SnackBarAction(
              label: communityText(context, 'Review policy', 'مراجعة السياسة'),
              onPressed: () {
                if (visit.isCurrent) unawaited(_reviewPolicy());
              },
            ),
          ),
        );
      }
    } on CommunityMembershipAccessException catch (error) {
      if (mounted && visit.isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                error.englishMessage(CommunityPolicyProtectedAction.messaging),
                error.arabicMessage(CommunityPolicyProtectedAction.messaging),
              ),
            ),
          ),
        );
      }
    } on CommunityTextPolicyException catch (error) {
      if (mounted && visit.isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.localizedMessage(
                Localizations.localeOf(context).toLanguageTag(),
              ),
            ),
          ),
        );
      }
    } on Object {
      if (mounted && visit.isCurrent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.sendFailed)));
      }
    } finally {
      if (mounted && visit.isCurrent) {
        setState(() {
          _sending = false;
          _confirmingReplacement = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildMessagePage(context, constraints.maxWidth),
  );

  AppBar _messageHeader(
    BuildContext context,
    _MessagesCopy copy,
    double width, {
    bool sendAction = false,
  }) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.localeOf(context);
    final titleStyle =
        appBarTheme.titleTextStyle ??
        theme.textTheme.titleLarge!.copyWith(
          color: appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        );
    final spacing =
        appBarTheme.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
    final usableWidth =
        width -
        MediaQuery.paddingOf(context).left -
        MediaQuery.paddingOf(context).right;
    final sendStyle =
        theme.filledButtonTheme.style?.textStyle?.resolve(const {}) ??
        theme.textTheme.labelLarge;
    final sendMeasure = TextPainter(
      text: TextSpan(text: copy.send, style: sendStyle),
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
    )..layout();
    // Match the current icon, gap and horizontal button padding.
    final fullActionWidth = sendMeasure.width + 20 + 8 + 24;
    sendMeasure.dispose();
    final titleMeasure = TextPainter(
      text: TextSpan(text: copy.newMessage, style: titleStyle),
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
    )..layout();
    final fullTitleWidth = titleMeasure.width;
    final wideTitleWidth =
        usableWidth -
        56 -
        spacing * 2 -
        (sendAction ? fullActionWidth + 12 : 0);
    final compactAction = sendAction && fullTitleWidth > wideTitleWidth;
    final actionWidth = sendAction
        ? (compactAction ? 48 : fullActionWidth) + 12
        : 0.0;
    final titleWidth = usableWidth - 56 - spacing * 2 - actionWidth;
    titleMeasure.layout(maxWidth: titleWidth > 1 ? titleWidth : 1);
    final measuredHeight = titleMeasure.height + 16;
    titleMeasure.dispose();
    final baseHeight = appBarTheme.toolbarHeight ?? kToolbarHeight;
    final height = measuredHeight > baseHeight ? measuredHeight : baseHeight;
    return AppBar(
      toolbarHeight: height,
      leadingWidth: 56,
      titleSpacing: spacing,
      actionsPadding: EdgeInsets.zero,
      leading: AbsorbPointer(
        absorbing: sendAction && _sending,
        child: const CommunityReturnButton(),
      ),
      title: Text(
        copy.newMessage,
        key: const Key('community-new-message-title'),
        style: titleStyle,
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
      actions: !sendAction
          ? null
          : [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Tooltip(
                  message: copy.sendMessage,
                  child: compactAction
                      ? FilledButton.tonal(
                          key: const Key('community-message-send'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            fixedSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.standard,
                            shape: const CircleBorder(),
                          ),
                          onPressed: _sending ? null : _send,
                          child: const BilCrystalArrow(
                            extent: 36,
                            child: Icon(Icons.arrow_upward_rounded, size: 20),
                          ),
                        )
                      : FilledButton.tonalIcon(
                          key: const Key('community-message-send'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const BilCrystalArrow(
                            extent: 36,
                            child: Icon(Icons.arrow_upward_rounded, size: 20),
                          ),
                          label: Text(copy.send),
                          onPressed: _sending ? null : _send,
                        ),
                ),
              ),
            ],
    );
  }

  Widget _buildMessagePage(BuildContext context, double width) {
    final copy = _MessagesCopy.of(context);
    final visit = _visit;
    if (visit != null && !visit.isCurrent) {
      return Scaffold(
        appBar: _messageHeader(context, copy, width),
        body: const _MessageOwnerChanged(),
      );
    }
    if (_repository == null) {
      return Scaffold(
        appBar: _messageHeader(context, copy, width),
        body: _MessagesSignIn(copy: copy),
      );
    }
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: _messageHeader(context, copy, width, sendAction: true),
        body: BilPearlBackdrop(
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                if (_sending && !_confirmingReplacement)
                  const BilFeatureWelcomeStatus(),
                Expanded(
                  child: ListView(
                    key: const Key('community-new-message-scroll'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      if (_recipient == null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: TextField(
                            key: const Key(
                              'community-message-recipient-search',
                            ),
                            controller: _recipientSearch,
                            autofocus: true,
                            enabled: !_sending,
                            onChanged: _search,
                            decoration: InputDecoration(
                              labelText: copy.to,
                              prefixIcon: const Icon(
                                Icons.person_search_rounded,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                            ),
                          ),
                        )
                      else
                        BilPearlCard(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: ListTile(
                            leading: BilAccountAvatar(
                              radius: 20,
                              networkUrl: _recipient!['avatar_url'] as String?,
                            ),
                            title: Text(_recipient!['display_name'] as String),
                            trailing: IconButton(
                              key: const Key(
                                'community-message-recipient-clear',
                              ),
                              tooltip: communityText(
                                context,
                                'Change recipient',
                                'تغيير المستلم',
                              ),
                              icon: const Icon(Icons.close_rounded),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: _sending
                                  ? null
                                  : () => setState(() => _recipient = null),
                            ),
                          ),
                        ),
                      if (_recipient == null)
                        FutureBuilder<List<Map<String, dynamic>>>(
                          key: ObjectKey(visit),
                          future: _people,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                child: BilFeatureWelcomeStatus(),
                              );
                            }
                            if (snapshot.hasError) {
                              return _PeopleSearchError(
                                copy: copy,
                                onRetry: () => _search(_recipientSearch.text),
                              );
                            }
                            if (snapshot.data?.isEmpty ?? true) {
                              return const SizedBox(height: 8);
                            }
                            return BilPearlCard(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: ListView(
                                primary: false,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  for (final person
                                      in snapshot.data ??
                                          const <Map<String, dynamic>>[])
                                    ListTile(
                                      leading: BilAccountAvatar(
                                        radius: 20,
                                        networkUrl:
                                            person['avatar_url'] as String?,
                                      ),
                                      title: Text(
                                        person['display_name'] as String,
                                      ),
                                      onTap: _sending
                                          ? null
                                          : () {
                                              if (visit?.isCurrent == true) {
                                                setState(
                                                  () => _recipient = person,
                                                );
                                              }
                                            },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (_policyState != null)
                        _NewMessagePolicyLifetime(
                          key: ObjectKey(visit),
                          child: CommunityPolicyNotice(
                            state: _policyState!,
                            onReview: () => _reviewPolicy(),
                            onRetry: () => _refreshPolicyState(),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: BilPearlCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: TextField(
                                  key: const Key('community-message-subject'),
                                  controller: _subject,
                                  enabled: !_sending,
                                  onChanged: (_) => _draftChanged(),
                                  decoration: InputDecoration(
                                    labelText: copy.subject,
                                    counterText:
                                        '${_subject.text.runes.length}/120',
                                    errorText:
                                        _subject.text.trim().runes.length > 120
                                        ? _privateSubjectLimitText(context)
                                        : null,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: TextField(
                                  key: const Key('community-message-body'),
                                  controller: _body,
                                  enabled: !_sending,
                                  onChanged: (_) => _draftChanged(),
                                  minLines: 5,
                                  maxLines: null,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: InputDecoration(
                                    hintText: copy.message,
                                    counterText:
                                        '${MessageBodyContract.compose(subject: _subject.text, body: _body.text).runes.length}/2000',
                                    errorText:
                                        MessageBodyContract.compose(
                                              subject: _subject.text,
                                              body: _body.text,
                                            ).runes.length >
                                            2000
                                        ? _privateMessageLimitText(context)
                                        : null,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A reviewed policy Future must not be resubscribed solely because this form's
// first sliver scrolls outside the viewport. Keep this presentation lifetime
// within the existing owner visit; updates/retries still use the same notice.
class _NewMessagePolicyLifetime extends StatefulWidget {
  const _NewMessagePolicyLifetime({required this.child, super.key});
  final Widget child;

  @override
  State<_NewMessagePolicyLifetime> createState() =>
      _NewMessagePolicyLifetimeState();
}

class _NewMessagePolicyLifetimeState extends State<_NewMessagePolicyLifetime>
    with AutomaticKeepAliveClientMixin<_NewMessagePolicyLifetime> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
