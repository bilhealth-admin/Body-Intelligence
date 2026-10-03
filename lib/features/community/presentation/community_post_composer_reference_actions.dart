part of 'community_hub_page.dart';

extension _CommunityPostComposerReferenceActions
    on _CommunityPostComposerPageState {
  Future<void> _captureVoiceInput() async {
    if (_publishing ||
        _savingDraft ||
        _voiceCapturing ||
        _selectingImage ||
        _completed) {
      return;
    }
    _setComposerState(() {
      _voiceCapturing = true;
      _submitError = null;
    });
    try {
      final transcript = await CommunityComposerVoiceInputService.platform()
          .capture(context);
      if (!mounted || transcript == null || transcript.isEmpty) return;

      final current = _composer.text.trim();
      final next = current.isEmpty ? transcript : '$current\n$transcript';
      if (next.length > 1200) {
        _setComposerState(
          () => _submitError = communityText(
            context,
            'The voice transcript would exceed the 1200-character post limit.',
            'سيؤدي النص الصوتي إلى تجاوز حد المنشور البالغ 1200 حرفًا.',
          ),
        );
        return;
      }

      _setComposerState(() {
        _composer.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        widget.draft.body = next;
        _composerDirection = BilWrittenLanguageResolver.directionFor(
          next,
          fallback: Directionality.of(context),
        );
        _composerError = null;
        _submitError = null;
      });
    } finally {
      if (mounted) _setComposerState(() => _voiceCapturing = false);
    }
  }

  String? _normalizeHashtag(String raw) {
    final normalized = raw
        .trim()
        .replaceFirst(RegExp(r'^#+'), '')
        .toLowerCase();
    if (normalized.isEmpty ||
        normalized.length > 40 ||
        normalized.contains(RegExp(r'[#\s\x00-\x1F\x7F]'))) {
      return null;
    }
    return normalized;
  }

  void _addHashtag() {
    if (_publishing || _savingDraft || _completed) return;
    final normalized = _normalizeHashtag(_hashtagInput.text);
    if (normalized == null) {
      _setComposerState(
        () => _submitError = communityText(
          context,
          'Use one hashtag without spaces, up to 40 characters.',
          'استخدم وسمًا واحدًا دون مسافات وبحد أقصى 40 حرفًا.',
        ),
      );
      return;
    }
    if (widget.draft.hashtags.contains(normalized)) {
      _hashtagInput.clear();
      return;
    }
    if (widget.draft.hashtags.length >= 10) {
      _setComposerState(
        () => _submitError = communityText(
          context,
          'You can add up to 10 hashtags.',
          'يمكنك إضافة حتى 10 وسوم.',
        ),
      );
      return;
    }
    _setComposerState(() {
      widget.draft.hashtags.add(normalized);
      _hashtagInput.clear();
      _submitError = null;
    });
  }

  Future<void> _searchCollaborators() async {
    if (_publishing ||
        _savingDraft ||
        _selectingImage ||
        _completed ||
        _collaboratorSearching) {
      return;
    }
    final query = _collaboratorQuery.text.trim();
    if (query.isEmpty) {
      _setComposerState(
        () => _collaboratorResults = const <CommunityMentionCandidate>[],
      );
      return;
    }
    _setComposerState(() => _collaboratorSearching = true);
    try {
      final results = await widget.repository.searchCommunityMentions(query);
      if (!mounted) return;
      _setComposerState(() => _collaboratorResults = results);
    } catch (_) {
      if (!mounted) return;
      _setComposerState(
        () => _collaboratorResults = const <CommunityMentionCandidate>[],
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not search collaborators right now.',
              'تعذر البحث عن متعاونين الآن.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) _setComposerState(() => _collaboratorSearching = false);
    }
  }

  void _toggleCollaborator(CommunityMentionCandidate candidate) {
    if (_publishing || _savingDraft || _completed) return;
    final index = widget.draft.collaborators.indexWhere(
      (value) => value.userId == candidate.userId,
    );
    _setComposerState(() {
      if (index >= 0) {
        widget.draft.collaborators.removeAt(index);
      } else if (widget.draft.collaborators.length < 3) {
        widget.draft.collaborators.add(candidate);
      }
      _submitError = null;
    });
  }

  bool get _hasDraftContent =>
      _title.text.trim().isNotEmpty ||
      _composer.text.trim().isNotEmpty ||
      _selectedImages.isNotEmpty ||
      widget.draft.topicSlugs.isNotEmpty ||
      widget.draft.circleSlug != null ||
      widget.draft.locationLabel.trim().isNotEmpty ||
      widget.draft.mentions.isNotEmpty ||
      widget.draft.collaborators.isNotEmpty ||
      widget.draft.hashtags.isNotEmpty ||
      widget.draft.pollEnabled;

  CommunityDraftSaveInput _currentDraftSaveInput(String draftId) =>
      CommunityDraftSaveInput(
        draftId: draftId,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        body: _composer.text,
        topicSlugs: widget.draft.topicSlugs.toList(growable: false),
        circleSlug: widget.draft.circleSlug,
        locationLabel: widget.draft.locationLabel.trim().isEmpty
            ? null
            : widget.draft.locationLabel.trim(),
        mentions: List<CommunityMentionCandidate>.unmodifiable(
          widget.draft.mentions,
        ),
        collaborators: List<CommunityMentionCandidate>.unmodifiable(
          widget.draft.collaborators,
        ),
        hashtags: List<String>.unmodifiable(widget.draft.hashtags),
        pollQuestion: widget.draft.pollEnabled
            ? widget.draft.pollQuestion
            : null,
        pollOptions: widget.draft.pollEnabled
            ? List<String>.unmodifiable(widget.draft.pollOptions)
            : const <String>[],
        pollAllowMultiple:
            widget.draft.pollEnabled && widget.draft.pollAllowMultiple,
      );

  Future<void> _savePersistentDraft() async {
    if (_publishing || _savingDraft || _selectingImage || _completed) {
      return;
    }
    if (!_hasDraftContent) {
      _setComposerState(
        () => _submitError = communityText(
          context,
          'Add something before saving a draft.',
          'أضف محتوى قبل حفظ المسودة.',
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    _setComposerState(() {
      _savingDraft = true;
      _submitError = null;
    });
    final draftId = widget.draft.persistentDraftId ?? const Uuid().v4();
    try {
      await widget.repository.saveMyCommunityDraft(
        input: _currentDraftSaveInput(draftId),
        images: List<CommunityPostImageDraft>.unmodifiable(_selectedImages),
      );
      if (!mounted) return;
      _setComposerState(() {
        widget.draft.persistentDraftId = draftId;
        widget.draft.savedPersistently = true;
        widget.draft.title = _title.text;
        widget.draft.body = _composer.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Draft saved securely.',
              'تم حفظ المسودة بأمان.',
            ),
          ),
        ),
      );
    } on CommunityPolicyAccessException catch (error) {
      if (!mounted) return;
      _setComposerState(
        () => _submitError = communityText(
          context,
          error.englishMessage(CommunityPolicyProtectedAction.publishing),
          error.arabicMessage(CommunityPolicyProtectedAction.publishing),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _setComposerState(
        () => _submitError = communityText(
          context,
          'Could not save this draft. Nothing was published.',
          'تعذر حفظ هذه المسودة. لم يتم نشر أي شيء.',
        ),
      );
    } finally {
      if (mounted) _setComposerState(() => _savingDraft = false);
    }
  }
}
