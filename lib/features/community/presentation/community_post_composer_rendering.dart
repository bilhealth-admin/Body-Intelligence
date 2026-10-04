part of 'community_hub_page.dart';

extension _CommunityPostComposerRendering on _CommunityPostComposerPageState {
  Widget buildCommunityPostComposer(BuildContext context) {
    final busy =
        _publishing ||
        _savingDraft ||
        _voiceCapturing ||
        _selectingImage ||
        _completed;
    return PopScope<bool>(
      canPop: (!_publishing && !_savingDraft) || _completed,
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
                        _CommunityPostComposerReferenceSections(
                          this,
                        )._buildCommunityTitleField(context, busy),
                        const SizedBox(height: 12),
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
                              _setComposerState(() {
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
                            suffixIcon: IconButton(
                              key: const Key('community-composer-voice-input'),
                              tooltip: communityText(
                                context,
                                'Voice input',
                                'إدخال صوتي',
                              ),
                              onPressed: busy
                                  ? null
                                  : () =>
                                        _CommunityPostComposerReferenceActions(
                                          this,
                                        )._captureVoiceInput(),
                              icon: _voiceCapturing
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.mic_none_rounded),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        ..._CommunityPostComposerReferenceSections(
                          this,
                        )._buildCommunityHashtagSection(context, busy),
                        if (_selectedImages.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 160,
                            child: ListView.separated(
                              key: const Key('community-post-selected-images'),
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) =>
                                  _CommunityPostImagePreview(
                                    index: index,
                                    image: _selectedImages[index],
                                    onRemove: busy
                                        ? null
                                        : () => _setComposerState(() {
                                            _selectedImages.removeAt(index);
                                            widget.draft.images
                                              ..clear()
                                              ..addAll(_selectedImages);
                                            _composerError = null;
                                          }),
                                  ),
                            ),
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
                                            _setComposerState(() {
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
                        SizedBox(key: _circleAnchor, height: 0),
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
                            final circles =
                                (snapshot.data ?? const <CommunityCircle>[])
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
                                      : (_) => _setComposerState(
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
                                        : (selected) => _setComposerState(() {
                                            widget.draft.circleSlug = selected
                                                ? circle.slug
                                                : null;
                                          }),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(key: _locationAnchor, height: 0),
                        Text(
                          communityText(
                            context,
                            'Location — optional',
                            'الموقع — اختياري',
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('community-composer-location'),
                          controller: _location,
                          enabled: !busy,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (value) {
                            widget.draft.locationLabel = value;
                            if (_submitError != null) {
                              _setComposerState(() => _submitError = null);
                            }
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            labelText: communityText(
                              context,
                              'City or place label',
                              'اسم المدينة أو المكان',
                            ),
                            helperText: communityText(
                              context,
                              'Optional text only. BIL does not request GPS for Community posts.',
                              'نص اختياري فقط. لا يطلب BIL موقع GPS لمنشورات المجتمع.',
                            ),
                            helperMaxLines: 2,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          communityText(
                            context,
                            'Mention people — optional',
                            'الإشارة إلى أشخاص — اختياري',
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          communityText(
                            context,
                            'Mention up to 10 discoverable Community members. They are notified only after the post is approved.',
                            'يمكنك الإشارة إلى 10 أعضاء ظاهرين كحد أقصى. لا يصلهم إشعار إلا بعد اعتماد المنشور.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (widget.draft.mentions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mention in widget.draft.mentions)
                                InputChip(
                                  key: Key(
                                    'community-composer-selected-mention-${mention.userId}',
                                  ),
                                  avatar: BilAccountAvatar(
                                    radius: 12,
                                    networkUrl: mention.avatarUrl,
                                  ),
                                  label: Text('@${mention.handle}'),
                                  onDeleted: busy
                                      ? null
                                      : () => _toggleMention(mention),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key(
                                  'community-composer-mention-query',
                                ),
                                controller: _mentionQuery,
                                enabled: !busy,
                                textDirection: TextDirection.ltr,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _searchMentions(),
                                decoration: InputDecoration(
                                  prefixText: '@',
                                  labelText: communityText(
                                    context,
                                    'Search handle',
                                    'البحث باسم المستخدم',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              key: const Key(
                                'community-composer-mention-search',
                              ),
                              tooltip: communityText(context, 'Search', 'بحث'),
                              onPressed: busy || _mentionSearching
                                  ? null
                                  : _searchMentions,
                              icon: _mentionSearching
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.search_rounded),
                            ),
                          ],
                        ),
                        if (_mentionResults.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mention in _mentionResults)
                                FilterChip(
                                  key: Key(
                                    'community-composer-mention-${mention.userId}',
                                  ),
                                  selected: widget.draft.mentions.any(
                                    (value) => value.userId == mention.userId,
                                  ),
                                  avatar: BilAccountAvatar(
                                    radius: 12,
                                    networkUrl: mention.avatarUrl,
                                  ),
                                  label: Text('@${mention.handle}'),
                                  onSelected:
                                      busy ||
                                          (!widget.draft.mentions.any(
                                                (value) =>
                                                    value.userId ==
                                                    mention.userId,
                                              ) &&
                                              widget.draft.mentions.length >=
                                                  10)
                                      ? null
                                      : (_) => _toggleMention(mention),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(key: _collaborationAnchor, height: 0),
                        ..._CommunityPostComposerReferenceSections(
                          this,
                        )._buildCommunityCollaboratorSection(context, busy),
                        const SizedBox(height: 8),
                        SizedBox(key: _pollAnchor, height: 0),
                        _CommunityComposerSwitchRow(
                          key: const Key('community-composer-poll-toggle'),
                          value: widget.draft.pollEnabled,
                          onChanged: busy
                              ? null
                              : (value) => _setComposerState(() {
                                  widget.draft.pollEnabled = value;
                                }),
                          title: communityText(
                            context,
                            'Add a poll',
                            'إضافة استطلاع',
                          ),
                          subtitle: communityText(
                            context,
                            'Ask one question with 2–6 options.',
                            'اطرح سؤالًا واحدًا مع 2–6 خيارات.',
                          ),
                        ),
                        if (widget.draft.pollEnabled) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('community-composer-poll-question'),
                            initialValue: widget.draft.pollQuestion,
                            enabled: !busy,
                            maxLength: 200,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (value) {
                              widget.draft.pollQuestion = value;
                              if (_submitError != null) {
                                _setComposerState(() => _submitError = null);
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
                          for (
                            var index = 0;
                            index < widget.draft.pollOptions.length;
                            index++
                          ) ...[
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
                                        _setComposerState(
                                          () => _submitError = null,
                                        );
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: communityText(
                                        context,
                                        'Option {index}',
                                        'الخيار {index}',
                                      ).replaceAll('{index}', '${index + 1}'),
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
                                        : () => _setComposerState(() {
                                            widget.draft.pollOptions.removeAt(
                                              index,
                                            );
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
                                    : () => _setComposerState(() {
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
                          _CommunityComposerSwitchRow(
                            key: const Key('community-composer-poll-multiple'),
                            value: widget.draft.pollAllowMultiple,
                            onChanged: busy
                                ? null
                                : (value) => _setComposerState(() {
                                    widget.draft.pollAllowMultiple = value;
                                  }),
                            title: communityText(
                              context,
                              'Allow multiple choices',
                              'السماح باختيار أكثر من خيار',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _CommunityPostComposerToolbar(
                  this,
                ).buildCommunityPostComposerToolbar(context, busy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
