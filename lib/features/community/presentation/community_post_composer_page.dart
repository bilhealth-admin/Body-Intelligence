part of 'community_hub_page.dart';

// Transient draft owned by the hub. Back navigation keeps the draft while the
// hub remains mounted; this does not claim persistence across process death.
class _CommunityComposerDraft {
  String body = '';
  CommunityPostImageDraft? image;
  final Set<String> topicSlugs = <String>{};
  String? circleSlug;
  bool pollEnabled = false;
  String pollQuestion = '';
  final List<String> pollOptions = <String>['', ''];
  bool pollAllowMultiple = false;
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
  late CommunityPostImageDraft? _selectedImage = widget.draft.image;
  late final Future<List<CommunityTopic>> _topics =
      widget.repository.loadCommunityTopics();
  late final Future<List<CommunityCircle>> _circles =
      widget.repository.loadCommunityCircles();
  bool _publishing = false;
  bool _selectingImage = false;
  bool _completed = false;
  TextDirection? _composerDirection;
  String? _composerError;
  String? _submitError;

  @override
  void dispose() {
    _composerFocus.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing || _selectingImage || _completed) return;
    final text = _composer.text.trim();
    if (text.isEmpty) {
      setState(
        () => _composerError = _selectedImage == null
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
      final image = _selectedImage;
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

      if (poll != null) {
        if (image == null) {
          await widget.repository.publishPostWithTopicsCircleAndPoll(
            text,
            topicSlugs: topicSlugs,
            circleSlug: circleSlug,
            poll: poll,
          );
        } else {
          await widget.repository.publishPostWithImageTopicsCircleAndPoll(
            text,
            image,
            topicSlugs: topicSlugs,
            circleSlug: circleSlug,
            poll: poll,
          );
        }
      } else if (image == null) {
        if (topicSlugs.isEmpty && circleSlug == null) {
          await widget.repository.publishPost(text);
        } else {
          await widget.repository.publishPostWithTopicsAndCircle(
            text,
            topicSlugs: topicSlugs,
            circleSlug: circleSlug,
          );
        }
      } else if (topicSlugs.isEmpty && circleSlug == null) {
        await widget.repository.publishPostWithImage(text, image);
      } else {
        await widget.repository.publishPostWithImageTopicsAndCircle(
          text,
          image,
          topicSlugs: topicSlugs,
          circleSlug: circleSlug,
        );
      }
      if (!mounted) return;
      widget.draft.body = '';
      widget.draft.image = null;
      widget.draft.topicSlugs.clear();
      widget.draft.circleSlug = null;
      widget.draft.pollEnabled = false;
      widget.draft.pollQuestion = '';
      widget.draft.pollOptions
        ..clear()
        ..addAll(const ['', '']);
      widget.draft.pollAllowMultiple = false;
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
          _selectedImage == null
              ? 'Could not publish now. Your text is kept so you can retry.'
              : 'Could not publish now. Your text and photo are kept so you can retry.',
          _selectedImage == null
              ? 'تعذر نشر المشاركة الآن. احتفظنا بالنص لتعيد المحاولة.'
              : 'تعذر النشر الآن. احتفظنا بالنص والصورة لتعيد المحاولة.',
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _pickImage() async {
    if (_publishing || _selectingImage || _completed) return;
    setState(() => _selectingImage = true);
    try {
      final image = await widget.imagePicker.pick();
      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
          widget.draft.image = image;
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

  @override
  Widget build(BuildContext context) {
    final busy = _publishing || _selectingImage || _completed;
    return PopScope<bool>(
      canPop: !_publishing || _completed,
      child: ScaffoldMessenger(
        child: Scaffold(
          key: const Key('community-post-editor-page'),
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(
              communityText(
                context,
                'Share an experience or win',
                'شارك تجربة أو إنجازًا',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('community-post-editor-scroll'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const Key('community-post-composer'),
                          controller: _composer,
                          focusNode: _composerFocus,
                          enabled: !busy,
                          maxLength: 1200,
                          minLines: 3,
                          maxLines: 8,
                          textDirection:
                              _composerDirection ?? Directionality.of(context),
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (value) {
                            widget.draft.body = value;
                            final direction =
                                BilWrittenLanguageResolver.directionFor(
                                  value,
                                  fallback: Directionality.of(context),
                                );
                            if (_composerError != null ||
                                _submitError != null ||
                                direction != _composerDirection) {
                              setState(() {
                                _composerDirection = direction;
                                _composerError = null;
                                _submitError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            alignLabelWithHint: true,
                            labelText: communityText(
                              context,
                              'Share an experience or win',
                              'شارك تجربة أو إنجازًا',
                            ),
                            helperText: communityText(
                              context,
                              'Do not share private health data you want to keep private.',
                              'لا تشارك بيانات صحية خاصة لا تريد ظهورها.',
                            ),
                            helperMaxLines: 3,
                            errorText: _composerError,
                            errorMaxLines: 3,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        if (_selectedImage case final image?) ...[
                          const SizedBox(height: 16),
                          _CommunityPostImagePreview(
                            image: image,
                            onRemove: busy
                                ? null
                                : () => setState(() {
                                    _selectedImage = null;
                                    widget.draft.image = null;
                                    _composerError = null;
                                  }),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          communityText(
                            context,
                            'Topics — choose up to 3',
                            'المواضيع — اختر حتى 3',
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<CommunityTopic>>(
                          future: _topics,
                          builder: (context, snapshot) {
                            final topics =
                                snapshot.data ?? const <CommunityTopic>[];
                            if (topics.isEmpty) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const LinearProgressIndicator();
                              }
                              return Text(
                                communityText(
                                  context,
                                  'Topics are unavailable right now. You can still publish.',
                                  'المواضيع غير متاحة الآن. لا يزال بإمكانك النشر.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final topic in topics)
                                  FilterChip(
                                    key: Key(
                                      'community-composer-topic-${topic.slug}',
                                    ),
                                    selected: widget.draft.topicSlugs.contains(
                                      topic.slug,
                                    ),
                                    avatar: Icon(
                                      CommunityTaxonomySheet.iconForSlug(
                                        topic.slug,
                                      ),
                                      size: 16,
                                    ),
                                    label: Text(
                                      CommunityTaxonomySheet.titleForSlug(
                                        context,
                                        topic.slug,
                                      ),
                                    ),
                                    onSelected: busy
                                        ? null
                                        : (selected) {
                                            setState(() {
                                              if (selected) {
                                                if (widget
                                                        .draft
                                                        .topicSlugs
                                                        .length <
                                                    3) {
                                                  widget.draft.topicSlugs.add(
                                                    topic.slug,
                                                  );
                                                }
                                              } else {
                                                widget.draft.topicSlugs.remove(
                                                  topic.slug,
                                                );
                                              }
                                            });
                                          },
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          communityText(
                            context,
                            'Circle — optional',
                            'الدائرة — اختياري',
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<CommunityCircle>>(
                          future: _circles,
                          builder: (context, snapshot) {
                            final circles = (snapshot.data ??
                                    const <CommunityCircle>[])
                                .where((circle) => circle.activeMember)
                                .toList(growable: false);
                            if (snapshot.connectionState !=
                                    ConnectionState.done &&
                                circles.isEmpty) {
                              return const LinearProgressIndicator();
                            }
                            if (circles.isEmpty) {
                              return Text(
                                communityText(
                                  context,
                                  'Join a Circle to post inside it.',
                                  'انضم إلى دائرة لتتمكن من النشر داخلها.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  key: const Key(
                                    'community-composer-circle-none',
                                  ),
                                  selected: widget.draft.circleSlug == null,
                                  label: Text(
                                    communityText(
                                      context,
                                      'No Circle',
                                      'بدون دائرة',
                                    ),
                                  ),
                                  onSelected: busy
                                      ? null
                                      : (_) => setState(
                                            () => widget.draft.circleSlug = null,
                                          ),
                                ),
                                for (final circle in circles)
                                  ChoiceChip(
                                    key: Key(
                                      'community-composer-circle-${circle.slug}',
                                    ),
                                    selected:
                                        widget.draft.circleSlug == circle.slug,
                                    avatar: Icon(
                                      _circleIcon(circle.slug),
                                      size: 16,
                                    ),
                                    label: Text(
                                      _circleTitle(context, circle.slug),
                                    ),
                                    onSelected: busy
                                        ? null
                                        : (selected) => setState(() {
                                              widget.draft.circleSlug =
                                                  selected ? circle.slug : null;
                                            }),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        SwitchListTile.adaptive(
                          key: const Key('community-composer-poll-toggle'),
                          contentPadding: EdgeInsets.zero,
                          value: widget.draft.pollEnabled,
                          onChanged: busy
                              ? null
                              : (value) => setState(() {
                                    widget.draft.pollEnabled = value;
                                  }),
                          title: Text(
                            communityText(
                              context,
                              'Add a poll',
                              'إضافة استطلاع',
                            ),
                          ),
                          subtitle: Text(
                            communityText(
                              context,
                              'Ask one question with 2–6 options.',
                              'اطرح سؤالًا واحدًا مع 2–6 خيارات.',
                            ),
                          ),
                        ),
                        if (widget.draft.pollEnabled) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key(
                              'community-composer-poll-question',
                            ),
                            initialValue: widget.draft.pollQuestion,
                            enabled: !busy,
                            maxLength: 200,
                            textCapitalization:
                                TextCapitalization.sentences,
                            onChanged: (value) {
                              widget.draft.pollQuestion = value;
                              if (_submitError != null) {
                                setState(() => _submitError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: communityText(
                                context,
                                'Poll question',
                                'سؤال الاستطلاع',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (var index = 0;
                              index < widget.draft.pollOptions.length;
                              index++) ...[
                            Row(
                              key: ValueKey(
                                'community-composer-poll-option-row-$index',
                              ),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: ValueKey(
                                      'community-composer-poll-option-$index',
                                    ),
                                    initialValue:
                                        widget.draft.pollOptions[index],
                                    enabled: !busy,
                                    maxLength: 100,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    onChanged: (value) {
                                      widget.draft.pollOptions[index] = value;
                                      if (_submitError != null) {
                                        setState(
                                          () => _submitError = null,
                                        );
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: communityText(
                                        context,
                                        'Option ${index + 1}',
                                        'الخيار ${index + 1}',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                if (widget.draft.pollOptions.length > 2) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    key: ValueKey(
                                      'community-composer-poll-remove-$index',
                                    ),
                                    tooltip: communityText(
                                      context,
                                      'Remove option',
                                      'إزالة الخيار',
                                    ),
                                    onPressed: busy
                                        ? null
                                        : () => setState(() {
                                              widget.draft.pollOptions
                                                  .removeAt(index);
                                            }),
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (widget.draft.pollOptions.length < 6)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                key: const Key(
                                  'community-composer-poll-add-option',
                                ),
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                          widget.draft.pollOptions.add('');
                                        }),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(
                                  communityText(
                                    context,
                                    'Add option',
                                    'إضافة خيار',
                                  ),
                                ),
                              ),
                            ),
                          SwitchListTile.adaptive(
                            key: const Key(
                              'community-composer-poll-multiple',
                            ),
                            contentPadding: EdgeInsets.zero,
                            value: widget.draft.pollAllowMultiple,
                            onChanged: busy
                                ? null
                                : (value) => setState(() {
                                      widget.draft.pollAllowMultiple = value;
                                    }),
                            title: Text(
                              communityText(
                                context,
                                'Allow multiple choices',
                                'السماح باختيار أكثر من خيار',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // The toolbar is outside the scroll content, so the image and
                // keyboard cannot push the Publish action out of the viewport.
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_submitError case final error?) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              key: const Key('community-post-submit-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        if (_publishing && _selectedImage != null) ...[
                          const LinearProgressIndicator(
                            key: Key('community-post-upload-progress'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('community-post-add-photo'),
                              onPressed: busy ? null : _pickImage,
                              icon: _selectingImage
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                              label: Text(
                                communityText(
                                  context,
                                  'Add photo',
                                  'إضافة صورة',
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              key: const Key('community-post-publish'),
                              onPressed: busy ? null : _publish,
                              icon: _publishing
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(
                                _publishing && _selectedImage != null
                                    ? communityText(
                                        context,
                                        'Uploading photo…',
                                        'جارٍ رفع الصورة…',
                                      )
                                    : communityText(context, 'Publish', 'نشر'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _CommunityPostImagePreview extends StatelessWidget {
  const _CommunityPostImagePreview({required this.image, this.onRemove});

  final CommunityPostImageDraft image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: communityText(context, 'Selected photo', 'الصورة المحددة'),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              image.bytes,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFE8EBF0),
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: IconButton.filledTonal(
                key: const Key('community-post-remove-photo'),
                onPressed: onRemove,
                tooltip: communityText(context, 'Remove photo', 'إزالة الصورة'),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
