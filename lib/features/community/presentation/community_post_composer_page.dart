part of 'community_hub_page.dart';

// The in-memory editor state can be promoted to a server-persistent draft.
// Back navigation still preserves unsaved edits while the hub remains mounted.
class _CommunityComposerDraft {
  String? persistentDraftId;
  bool savedPersistently = false;
  String title = '';
  String body = '';
  final List<CommunityPostImageDraft> images = <CommunityPostImageDraft>[];
  final Set<String> topicSlugs = <String>{};
  String? circleSlug;
  bool pollEnabled = false;
  String pollQuestion = '';
  final List<String> pollOptions = <String>['', ''];
  bool pollAllowMultiple = false;
  String locationLabel = '';
  final List<CommunityMentionCandidate> mentions =
      <CommunityMentionCandidate>[];
  final List<CommunityMentionCandidate> collaborators =
      <CommunityMentionCandidate>[];
  final List<String> hashtags = <String>[];

  factory _CommunityComposerDraft.fromPersistent(
    CommunityPersistentDraft draft,
    List<CommunityPostImageDraft> images,
  ) {
    final value = _CommunityComposerDraft();
    value.persistentDraftId = draft.draftId;
    value.savedPersistently = true;
    value.title = draft.title ?? '';
    value.body = draft.body;
    value.images.addAll(images);
    value.topicSlugs.addAll(draft.topicSlugs);
    value.circleSlug = draft.circleSlug;
    value.pollEnabled =
        draft.pollQuestion != null || draft.pollOptions.isNotEmpty;
    value.pollQuestion = draft.pollQuestion ?? '';
    value.pollOptions
      ..clear()
      ..addAll(draft.pollOptions);
    while (value.pollOptions.length < 2) {
      value.pollOptions.add('');
    }
    value.pollAllowMultiple = draft.pollAllowMultiple;
    value.locationLabel = draft.locationLabel ?? '';
    value.mentions.addAll(draft.mentions);
    value.collaborators.addAll(draft.collaborators);
    value.hashtags.addAll(draft.hashtags);
    return value;
  }

  _CommunityComposerDraft();
}

class _CommunityPostComposerPage extends StatefulWidget {
  const _CommunityPostComposerPage({
    required this.repository,
    required this.imagePicker,
    required this.draft,
    this.ownerIsCurrent,
    this.fromEarn = false,
  });
  final CommunityRepository repository;
  final CommunityPostImagePickerContract imagePicker;
  final _CommunityComposerDraft draft;
  final ValueGetter<bool>? ownerIsCurrent;
  final bool fromEarn;

  @override
  State<_CommunityPostComposerPage> createState() =>
      _CommunityPostComposerPageState();
}

class _CommunityPostComposerPageState
    extends State<_CommunityPostComposerPage> {
  CommunityRepository? _composerRepository;
  String? _composerOwnerId;
  StreamSubscription<AuthState>? _composerAuth;
  int _composerBinding = 0;
  bool _composerOwnerCancelled = false;
  late final _title = TextEditingController(text: widget.draft.title);
  late final _composer = TextEditingController(text: widget.draft.body);
  final _composerFocus = FocusNode();
  final _circleAnchor = GlobalKey();
  final _locationAnchor = GlobalKey();
  final _collaborationAnchor = GlobalKey();
  final _pollAnchor = GlobalKey();
  final _composerSections = <String, ExpansibleController>{
    for (final section in [
      'poll',
      'location',
      'circles',
      'mentions',
      'collaboration',
      'hashtags',
    ])
      section: ExpansibleController(),
  };
  bool _openingDrafts = false;
  int? _draftCount;
  bool _draftCountCapped = false;
  int _draftCountGeneration = 0;
  int _draftVisitGeneration = 0;
  late final _location = TextEditingController(
    text: widget.draft.locationLabel,
  );
  final _hashtagInput = TextEditingController();
  final _mentionQuery = TextEditingController();
  final _collaboratorQuery = TextEditingController();
  late final List<CommunityPostImageDraft> _selectedImages =
      List<CommunityPostImageDraft>.from(widget.draft.images);
  late final Future<List<CommunityTopic>> _topics = widget.repository
      .loadCommunityTopics();
  late final Future<List<CommunityCircle>> _circles = widget.repository
      .loadCommunityCircles();
  bool _publishing = false;
  bool _savingDraft = false;
  bool _voiceCapturing = false;
  bool _selectingImage = false;
  bool _completed = false;
  bool _operationRecovery = false;
  TextDirection? _composerDirection;
  String? _composerError;
  String? _submitError;
  bool _mentionSearching = false;
  bool _collaboratorSearching = false;
  List<CommunityMentionCandidate> _mentionResults =
      const <CommunityMentionCandidate>[];
  List<CommunityMentionCandidate> _collaboratorResults =
      const <CommunityMentionCandidate>[];

  @override
  void initState() {
    super.initState();
    _bindComposerOwner();
    unawaited(_refreshComposerDraftCount());
  }

  @override
  void didUpdateWidget(covariant _CommunityPostComposerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.draft, widget.draft) ||
        !_sameComposerOwner) {
      _invalidateComposerOwner();
    }
  }

  @override
  void dispose() {
    _composerOwnerCancelled = true;
    _composerBinding++;
    _draftCountGeneration++;
    _draftVisitGeneration++;
    for (final controller in _composerSections.values) {
      controller.dispose();
    }
    unawaited(_composerAuth?.cancel());
    _composerFocus.dispose();
    _title.dispose();
    _composer.dispose();
    _location.dispose();
    _hashtagInput.dispose();
    _mentionQuery.dispose();
    _collaboratorQuery.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final owner = _composerOwnerId;
    if (!_checkComposerOwner() ||
        owner == null ||
        _publishing ||
        _savingDraft ||
        _voiceCapturing ||
        _selectingImage ||
        _openingDrafts ||
        _completed) {
      return;
    }
    final text = _composer.text.trim();
    if (text.isEmpty) {
      setState(
        () => _composerError = _selectedImages.isEmpty
            ? communityText(
                context,
                'Write your post before publishing.',
                'اكتب منشورك قبل النشر.',
              )
            : communityText(
                context,
                'Write a caption before publishing your photo.',
                'اكتب وصفًا قبل نشر الصورة.',
              ),
      );
      _composerFocus.requestFocus();
      return;
    }
    if (CommunityTextLimits.exceedsBodyLimit(text)) {
      setState(() => _composerError = communityBodyLimitText(context));
      _composerFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _composerError = null;
      _submitError = null;
      _publishing = true;
    });
    var startedPublication = false;
    try {
      final images = List<CommunityPostImageDraft>.unmodifiable(
        _selectedImages,
      );
      final topicSlugs = widget.draft.topicSlugs.toList(growable: false);
      final circleSlug = widget.draft.circleSlug;
      CommunityPollDraft? poll;
      if (widget.draft.pollEnabled) {
        try {
          poll = CommunityPollDraft(
            question: widget.draft.pollQuestion,
            options: widget.draft.pollOptions,
            allowMultiple: widget.draft.pollAllowMultiple,
          ).normalized();
        } on FormatException {
          if (!mounted) return;
          setState(
            () => _submitError = communityText(
              context,
              'Finish the poll: add a question and 2–6 different options.',
              'أكمل الاستطلاع: أضف سؤالًا و2–6 خيارات مختلفة.',
            ),
          );
          return;
        }
      }

      final locationLabel = widget.draft.locationLabel.trim();
      final mentions = List<CommunityMentionCandidate>.unmodifiable(
        widget.draft.mentions,
      );
      final collaborators = List<CommunityMentionCandidate>.unmodifiable(
        widget.draft.collaborators,
      );
      final hashtags = List<String>.unmodifiable(widget.draft.hashtags);
      final title = _title.text.trim();
      final persistentDraftId = widget.draft.savedPersistently
          ? widget.draft.persistentDraftId
          : null;
      final hasReferenceMetadata =
          title.isNotEmpty ||
          hashtags.isNotEmpty ||
          collaborators.isNotEmpty ||
          persistentDraftId != null;
      final hasPostContext =
          locationLabel.isNotEmpty ||
          mentions.isNotEmpty ||
          hasReferenceMetadata;

      if (!await _confirmCommunityEntry()) return;
      if (!mounted || !_checkComposerOwner()) return;
      startedPublication = true;
      await widget.repository.runForCommunityOwner(
        () async {
          if (hasPostContext) {
            await widget.repository.publishRichPost(
              text,
              images: images,
              topicSlugs: topicSlugs,
              circleSlug: circleSlug,
              poll: poll,
              locationLabel: locationLabel,
              mentions: mentions,
              title: title,
              hashtags: hashtags,
              collaborators: collaborators,
              persistentDraftId: persistentDraftId,
            );
          } else if (poll != null) {
            if (images.isEmpty) {
              await widget.repository.publishPostWithTopicsCircleAndPoll(
                text,
                topicSlugs: topicSlugs,
                circleSlug: circleSlug,
                poll: poll,
              );
            } else if (images.length == 1) {
              await widget.repository.publishPostWithImageTopicsCircleAndPoll(
                text,
                images.single,
                topicSlugs: topicSlugs,
                circleSlug: circleSlug,
                poll: poll,
              );
            } else {
              await widget.repository.publishPostWithImagesTopicsCircleAndPoll(
                text,
                images,
                topicSlugs: topicSlugs,
                circleSlug: circleSlug,
                poll: poll,
              );
            }
          } else if (images.isEmpty) {
            if (topicSlugs.isEmpty && circleSlug == null) {
              await widget.repository.publishPost(text);
            } else {
              await widget.repository.publishPostWithTopicsAndCircle(
                text,
                topicSlugs: topicSlugs,
                circleSlug: circleSlug,
              );
            }
          } else if (images.length == 1) {
            if (topicSlugs.isEmpty && circleSlug == null) {
              await widget.repository.publishPostWithImage(text, images.single);
            } else {
              await widget.repository.publishPostWithImageTopicsAndCircle(
                text,
                images.single,
                topicSlugs: topicSlugs,
                circleSlug: circleSlug,
              );
            }
          } else {
            await widget.repository.publishPostWithImagesTopicsAndCircle(
              text,
              images,
              topicSlugs: topicSlugs,
              circleSlug: circleSlug,
            );
          }
        },
        ownerId: owner,
        isCurrentOwner: () => _sameComposerOwner,
      );
      if (!mounted || !_checkComposerOwner()) return;
      widget.draft.persistentDraftId = null;
      widget.draft.savedPersistently = false;
      widget.draft.title = '';
      _title.clear();
      widget.draft.body = '';
      widget.draft.images.clear();
      _selectedImages.clear();
      widget.draft.topicSlugs.clear();
      widget.draft.circleSlug = null;
      widget.draft.pollEnabled = false;
      widget.draft.pollQuestion = '';
      widget.draft.pollOptions
        ..clear()
        ..addAll(const ['', '']);
      widget.draft.pollAllowMultiple = false;
      widget.draft.locationLabel = '';
      _location.clear();
      widget.draft.mentions.clear();
      widget.draft.collaborators.clear();
      widget.draft.hashtags.clear();
      _mentionResults = const <CommunityMentionCandidate>[];
      _collaboratorResults = const <CommunityMentionCandidate>[];
      _mentionQuery.clear();
      _collaboratorQuery.clear();
      _hashtagInput.clear();
      // Pop only after the request completes successfully. The hub owns refresh.
      // Re-enable route pop before the next frame; keep input locked until then.
      setState(() => _completed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sameComposerOwner) Navigator.of(context).pop(true);
      });
    } on CommunityPolicyAccessException catch (error) {
      if (!mounted || !_checkComposerOwner()) return;
      final message = communityText(
        context,
        error.englishMessage(CommunityPolicyProtectedAction.publishing),
        error.arabicMessage(CommunityPolicyProtectedAction.publishing),
      );
      setState(() => _submitError = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: communityText(context, 'Review policy', 'مراجعة السياسة'),
            onPressed: () {
              context.push('/community/safety');
            },
          ),
        ),
      );
    } on CommunityMembershipAccessException catch (error) {
      if (!mounted || !_checkComposerOwner()) return;
      final message = communityText(
        context,
        error.englishMessage(CommunityPolicyProtectedAction.publishing),
        error.arabicMessage(CommunityPolicyProtectedAction.publishing),
      );
      setState(() => _submitError = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on CommunityTextPolicyException catch (error) {
      if (!mounted || !_checkComposerOwner()) return;
      setState(
        () => _submitError = error.localizedMessage(
          Localizations.localeOf(context).toLanguageTag(),
        ),
      );
    } on CommunityPublishOperationConflict {
      if (!mounted || !_checkComposerOwner()) return;
      setState(() {
        _operationRecovery = true;
        _submitError = communityText(
          context,
          'A previous publishing attempt is still unresolved. Retry its original content or cancel the pending attempt before changing it.',
          'لم تُحسم محاولة النشر السابقة. أعد المحاولة بمحتواها الأصلي أو ألغِ المحاولة المعلّقة قبل تغييره.',
        );
      });
    } catch (_) {
      if (!mounted || !_checkComposerOwner()) return;
      if (startedPublication) {
        _operationRecovery =
            widget.repository.useServerIdempotentCommunityPublishing;
      }
      setState(
        () => _submitError = communityText(
          context,
          _selectedImages.isEmpty
              ? 'Could not publish now. Your text is kept so you can retry.'
              : 'Could not publish now. Your text and photo are kept so you can retry.',
          _selectedImages.isEmpty
              ? 'تعذر نشر المشاركة الآن. احتفظنا بالنص لتعيد المحاولة.'
              : 'تعذر النشر الآن. احتفظنا بالنص والصورة لتعيد المحاولة.',
        ),
      );
    } finally {
      if (mounted && _sameComposerOwner) setState(() => _publishing = false);
    }
  }

  Future<void> _cancelPendingPublish() async {
    final owner = _composerOwnerId;
    if (!_checkComposerOwner() ||
        owner == null ||
        _publishing ||
        !_operationRecovery) {
      return;
    }
    setState(() => _publishing = true);
    try {
      final cancelled = await widget.repository.runForCommunityOwner(
        widget.repository.cancelPendingPublishOperation,
        ownerId: owner,
        isCurrentOwner: () => _sameComposerOwner,
      );
      if (!mounted || !_checkComposerOwner()) return;
      setState(() {
        _operationRecovery = false;
        _submitError = cancelled
            ? null
            : communityText(
                context,
                'The previous attempt was already published. Check My posts before publishing again.',
                'نُشرت المحاولة السابقة بالفعل. تحقق من منشوراتي قبل النشر مجددًا.',
              );
      });
    } on CommunityPublishOperationUnavailable {
      if (!mounted || !_checkComposerOwner()) return;
      setState(() {
        _operationRecovery = false;
        _submitError = communityText(
          context,
          'The previous publishing operation completed, but its post is no longer available. This cancellation did not delete any media.',
          'اكتملت عملية النشر السابقة، لكن منشورها لم يعد متاحًا. لم يحذف هذا الإلغاء أي وسائط.',
        );
      });
    } catch (_) {
      if (!mounted || !_checkComposerOwner()) return;
      setState(
        () => _submitError = communityText(
          context,
          'Could not finish verifying cancellation. Retry before publishing again.',
          'تعذر إكمال التحقق من الإلغاء. أعد المحاولة قبل النشر مجددًا.',
        ),
      );
    } finally {
      if (mounted && _sameComposerOwner) setState(() => _publishing = false);
    }
  }

  Future<void> _pickImage() async {
    if (!_checkComposerOwner() ||
        _publishing ||
        _selectingImage ||
        _openingDrafts ||
        _completed ||
        _selectedImages.length >= 4) {
      return;
    }
    setState(() => _selectingImage = true);
    try {
      final image = await widget.imagePicker.pick();
      if (image != null && mounted && _checkComposerOwner()) {
        setState(() {
          _selectedImages.add(image);
          widget.draft.images
            ..clear()
            ..addAll(_selectedImages);
          _submitError = null;
        });
      }
    } on CommunityPostImageException catch (error) {
      if (!mounted || !_checkComposerOwner()) return;
      final (english, arabic) = switch (error.failure) {
        CommunityPostImageFailure.tooLarge => (
          'Photo too large. Choose an image up to 5 MB.',
          'الصورة كبيرة جدًا. اختر صورة بحجم لا يتجاوز 5 ميجابايت.',
        ),
        CommunityPostImageFailure.unsupportedType => (
          'Choose a JPEG, PNG, or WebP image.',
          'اختر صورة بصيغة JPEG أو PNG أو WebP.',
        ),
        CommunityPostImageFailure.invalidImage ||
        CommunityPostImageFailure.invalidDimensions => (
          'This photo could not be opened safely. Choose another photo.',
          'تعذر فتح هذه الصورة بأمان. اختر صورة أخرى.',
        ),
      };
      setState(() => _submitError = communityText(context, english, arabic));
    } on Object {
      if (!mounted || !_checkComposerOwner()) return;
      setState(
        () => _submitError = communityText(
          context,
          'Photo picker could not open. Try again.',
          'تعذر فتح اختيار الصور. حاول مجددًا.',
        ),
      );
    } finally {
      if (mounted && _sameComposerOwner) {
        setState(() => _selectingImage = false);
      }
    }
  }

  Future<void> _searchMentions() async {
    if (!_checkComposerOwner() ||
        _publishing ||
        _selectingImage ||
        _completed ||
        _mentionSearching) {
      return;
    }
    final query = _mentionQuery.text.trim();
    if (query.isEmpty) {
      setState(() => _mentionResults = const <CommunityMentionCandidate>[]);
      return;
    }

    setState(() => _mentionSearching = true);
    try {
      final results = await widget.repository.searchCommunityMentions(query);
      if (!mounted || !_checkComposerOwner()) return;
      setState(() => _mentionResults = results);
    } catch (_) {
      if (!mounted || !_checkComposerOwner()) return;
      setState(() => _mentionResults = const <CommunityMentionCandidate>[]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not search mentions right now.',
              'تعذر البحث عن الأشخاص للإشارة إليهم الآن.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && _sameComposerOwner) {
        setState(() => _mentionSearching = false);
      }
    }
  }

  void _toggleMention(CommunityMentionCandidate candidate) {
    if (!_checkComposerOwner() || _publishing || _completed) return;
    final index = widget.draft.mentions.indexWhere(
      (value) => value.userId == candidate.userId,
    );
    setState(() {
      if (index >= 0) {
        widget.draft.mentions.removeAt(index);
      } else if (widget.draft.mentions.length < 10) {
        widget.draft.mentions.add(candidate);
      }
      _submitError = null;
    });
  }

  void _setComposerState(VoidCallback callback) => setState(callback);

  @override
  Widget build(BuildContext context) => _sameComposerOwner
      ? buildCommunityPostComposer(context)
      : _buildComposerOwnerChanged(context);
}
