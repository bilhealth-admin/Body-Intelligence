part of 'community_hub_page.dart';

// Transient draft owned by the hub. Back navigation keeps the draft while the
// hub remains mounted; this does not claim persistence across process death.
class _CommunityComposerDraft {
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
}

class _CommunityPostComposerPage extends StatefulWidget {
  const _CommunityPostComposerPage({
    required this.repository,
    required this.imagePicker,
    required this.draft,
  });
  final CommunityRepository repository;
  final CommunityPostImagePickerContract imagePicker;
  final _CommunityComposerDraft draft;

  @override
  State<_CommunityPostComposerPage> createState() =>
      _CommunityPostComposerPageState();
}

class _CommunityPostComposerPageState
    extends State<_CommunityPostComposerPage> {
  late final _composer = TextEditingController(text: widget.draft.body);
  final _composerFocus = FocusNode();
  late final _location = TextEditingController(
    text: widget.draft.locationLabel,
  );
  final _mentionQuery = TextEditingController();
  late final List<CommunityPostImageDraft> _selectedImages =
      List<CommunityPostImageDraft>.from(widget.draft.images);
  late final Future<List<CommunityTopic>> _topics = widget.repository
      .loadCommunityTopics();
  late final Future<List<CommunityCircle>> _circles = widget.repository
      .loadCommunityCircles();
  bool _publishing = false;
  bool _selectingImage = false;
  bool _completed = false;
  TextDirection? _composerDirection;
  String? _composerError;
  String? _submitError;
  bool _mentionSearching = false;
  List<CommunityMentionCandidate> _mentionResults =
      const <CommunityMentionCandidate>[];

  @override
  void dispose() {
    _composerFocus.dispose();
    _composer.dispose();
    _location.dispose();
    _mentionQuery.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing || _selectingImage || _completed) return;
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
    FocusScope.of(context).unfocus();
    setState(() {
      _composerError = null;
      _submitError = null;
      _publishing = true;
    });
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
      final hasPostContext = locationLabel.isNotEmpty || mentions.isNotEmpty;

      if (hasPostContext) {
        await widget.repository.publishRichPost(
          text,
          images: images,
          topicSlugs: topicSlugs,
          circleSlug: circleSlug,
          poll: poll,
          locationLabel: locationLabel,
          mentions: mentions,
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
      if (!mounted) return;
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
      _mentionResults = const <CommunityMentionCandidate>[];
      _mentionQuery.clear();
      // Pop only after the request completes successfully. The hub owns refresh.
      // Re-enable route pop before the next frame; keep input locked until then.
      setState(() => _completed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } on CommunityPolicyAccessException catch (error) {
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(
        () => _submitError = error.localizedMessage(
          Localizations.localeOf(context).toLanguageTag(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
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
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _pickImage() async {
    if (_publishing ||
        _selectingImage ||
        _completed ||
        _selectedImages.length >= 4) {
      return;
    }
    setState(() => _selectingImage = true);
    try {
      final image = await widget.imagePicker.pick();
      if (image != null && mounted) {
        setState(() {
          _selectedImages.add(image);
          widget.draft.images
            ..clear()
            ..addAll(_selectedImages);
          _submitError = null;
        });
      }
    } on CommunityPostImageException catch (error) {
      if (!mounted) return;
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
      if (!mounted) return;
      setState(
        () => _submitError = communityText(
          context,
          'Photo picker could not open. Try again.',
          'تعذر فتح اختيار الصور. حاول مجددًا.',
        ),
      );
    } finally {
      if (mounted) setState(() => _selectingImage = false);
    }
  }

  Future<void> _searchMentions() async {
    if (_publishing || _selectingImage || _completed || _mentionSearching) {
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
      if (!mounted) return;
      setState(() => _mentionResults = results);
    } catch (_) {
      if (!mounted) return;
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
      if (mounted) setState(() => _mentionSearching = false);
    }
  }

  void _toggleMention(CommunityMentionCandidate candidate) {
    if (_publishing || _completed) return;
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

  @override
  Widget build(BuildContext context) => buildCommunityPostComposer(context);
}
