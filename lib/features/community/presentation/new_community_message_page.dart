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
  _MessageOwnerVisit? _visit;

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
    _visit = _MessageOwnerVisit(repository, () => mounted, () {
      _debounce?.cancel();
      _searchGeneration++;
      _recipient = null;
      _subject.clear();
      _body.clear();
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
      await visit.run(() => visit.repository.sendMessage(recipient, envelope));
      if (mounted && visit.isCurrent) {
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/community/messages');
        }
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
      if (mounted && visit.isCurrent) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _MessagesCopy.of(context);
    final visit = _visit;
    if (visit != null && !visit.isCurrent) {
      return Scaffold(
        appBar: AppBar(
          leading: const CommunityReturnButton(),
          title: Text(copy.newMessage),
        ),
        body: const _MessageOwnerChanged(),
      );
    }
    if (_repository == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const CommunityReturnButton(),
          title: Text(copy.newMessage),
        ),
        body: _MessagesSignIn(copy: copy),
      );
    }
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(
          leading: AbsorbPointer(
            absorbing: _sending,
            child: const CommunityReturnButton(),
          ),
          title: Text(copy.newMessage),
          actions: [
            IconButton(
              key: const Key('community-message-send'),
              icon: const Icon(Icons.check_rounded),
              tooltip: copy.send,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (_sending) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  key: const Key('community-new-message-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    if (_policyState != null)
                      CommunityPolicyNotice(
                        state: _policyState!,
                        onReview: () => _reviewPolicy(),
                        onRetry: () => _refreshPolicyState(),
                      ),
                    if (_recipient == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: TextField(
                          key: const Key('community-message-recipient-search'),
                          controller: _recipientSearch,
                          autofocus: true,
                          enabled: !_sending,
                          onChanged: _search,
                          decoration: InputDecoration(
                            labelText: copy.to,
                            prefixIcon: const Icon(Icons.person_search_rounded),
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
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: ListTile(
                          leading: BilAccountAvatar(
                            radius: 20,
                            networkUrl: _recipient!['avatar_url'] as String?,
                          ),
                          title: Text(_recipient!['display_name'] as String),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: _sending
                                ? null
                                : () => setState(() => _recipient = null),
                          ),
                        ),
                      ),
                    if (_recipient == null)
                      SizedBox(
                        height: 180,
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          key: ObjectKey(visit),
                          future: _people,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return _PeopleSearchError(
                                copy: copy,
                                onRetry: () => _search(_recipientSearch.text),
                              );
                            }
                            return ListView(
                              primary: false,
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
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        key: const Key('community-message-subject'),
                        controller: _subject,
                        enabled: !_sending,
                        onChanged: (_) => _draftChanged(),
                        decoration: InputDecoration(
                          labelText: copy.subject,
                          counterText: '${_subject.text.runes.length}/120',
                          errorText: _subject.text.trim().runes.length > 120
                              ? _privateSubjectLimitText(context)
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TextField(
                        key: const Key('community-message-body'),
                        controller: _body,
                        enabled: !_sending,
                        onChanged: (_) => _draftChanged(),
                        minLines: 8,
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.all(16),
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
    );
  }
}
