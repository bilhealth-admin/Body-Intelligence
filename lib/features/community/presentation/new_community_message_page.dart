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

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _people = _repository!.searchProfiles('');
      return;
    }
    final client = _initializedCommunityClient();
    if (client?.auth.currentUser != null) {
      _repository = CommunityRepository(client!);
      _people = _repository!.searchProfiles('');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = _repository;
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (repository != null &&
        (_policyState == null || _policyLocale != locale)) {
      _policyLocale = locale;
      _policyState = repository.loadCommunityPolicyState(localeCode: locale);
    }
  }

  Future<CommunityPolicyState?> _refreshPolicyState() async {
    final repository = _repository;
    if (repository == null) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final future = repository.loadCommunityPolicyState(localeCode: locale);
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
    final repository = _repository;
    if (repository == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunitySafetyPage(repository: repository),
      ),
    );
    if (mounted) await _refreshPolicyState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recipientSearch.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _repository != null) {
        setState(() {
          _people = _repository!
              .searchProfiles(value)
              .then(
                (rows) => generation == _searchGeneration ? rows : const [],
              );
        });
      }
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final copy = _MessagesCopy.of(context);
    if (_repository == null ||
        _recipient == null ||
        _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.completeFields)));
      return;
    }
    setState(() => _sending = true);
    try {
      await _repository!.sendMessage(
        _recipient!['user_id'] as String,
        MessageBodyContract.compose(subject: _subject.text, body: _body.text),
      );
      if (mounted) context.pop();
    } on CommunityPolicyAccessException catch (error) {
      if (mounted) {
        await _refreshPolicyState();
        if (!mounted) return;
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
              onPressed: () => _reviewPolicy(),
            ),
          ),
        );
      }
    } on CommunityMembershipAccessException catch (error) {
      if (mounted) {
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
      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.sendFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _MessagesCopy.of(context);
    if (_repository == null) {
      return Scaffold(
        appBar: AppBar(title: Text(copy.newMessage)),
        body: _MessagesSignIn(copy: copy),
      );
    }
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _sending ? null : () => context.pop(),
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
                                        : () => setState(
                                            () => _recipient = person,
                                          ),
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
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(120),
                        ],
                        decoration: InputDecoration(
                          labelText: copy.subject,
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
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(4000),
                        ],
                        minLines: 8,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: copy.message,
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
