part of 'community_hub_page.dart';

extension _CommunityPostComposerReferenceSections
    on _CommunityPostComposerPageState {
  Widget _buildCommunityTitleField(BuildContext context, bool busy) =>
      TextField(
        key: const Key('community-composer-title'),
        controller: _title,
        enabled: !busy,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (value) {
          widget.draft.title = value;
          if (_submitError != null) setState(() => _submitError = null);
        },
        decoration: InputDecoration(
          labelText: communityText(context, 'Title', 'العنوان'),
          hintText: communityText(
            context,
            'Give this moment a clear title',
            'امنح هذه اللحظة عنوانًا واضحًا',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );

  List<Widget> _buildCommunityHashtagSection(
    BuildContext context,
    bool busy,
  ) => [
    const SizedBox(height: 16),
    Text(
      communityText(context, 'Hashtags — optional', 'الوسوم — اختياري'),
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 6),
    Text(
      communityText(
        context,
        'Add up to 10 searchable hashtags.',
        'أضف حتى 10 وسوم قابلة للبحث.',
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
    if (widget.draft.hashtags.isNotEmpty) ...[
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final hashtag in widget.draft.hashtags)
            InputChip(
              key: Key('community-composer-hashtag-' + hashtag),
              label: Text('#' + hashtag),
              onDeleted: busy
                  ? null
                  : () => setState(() {
                      widget.draft.hashtags.remove(hashtag);
                      _submitError = null;
                    }),
            ),
        ],
      ),
    ],
    const SizedBox(height: 8),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('community-composer-hashtag-input'),
            controller: _hashtagInput,
            enabled: !busy && widget.draft.hashtags.length < 10,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _CommunityPostComposerReferenceActions(this)._addHashtag(),
            decoration: InputDecoration(
              prefixText: '#',
              hintText: communityText(
                context,
                'healthyhabits',
                'عادات_صحية',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const Key('community-composer-hashtag-add'),
          tooltip: communityText(context, 'Add hashtag', 'إضافة وسم'),
          onPressed: busy || widget.draft.hashtags.length >= 10
              ? null
              : _addHashtag,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
  ];

  List<Widget> _buildCommunityCollaboratorSection(
    BuildContext context,
    bool busy,
  ) => [
    const SizedBox(height: 18),
    Text(
      communityText(
        context,
        'Collaboration — optional',
        'التعاون — اختياري',
      ),
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 6),
    Text(
      communityText(
        context,
        'Invite up to 3 Community members. Invitations are sent only after human approval, and a collaborator appears publicly only after accepting.',
        'ادعُ حتى 3 أعضاء من المجتمع. تُرسل الدعوات فقط بعد الاعتماد البشري، ولا يظهر المتعاون علنًا إلا بعد قبوله.',
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
    if (widget.draft.collaborators.isNotEmpty) ...[
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final collaborator in widget.draft.collaborators)
            InputChip(
              key: Key(
                'community-composer-selected-collaborator-' +
                    collaborator.userId,
              ),
              avatar: BilAccountAvatar(
                radius: 12,
                networkUrl: collaborator.avatarUrl,
              ),
              label: Text('@' + collaborator.handle),
              onDeleted: busy
                  ? null
                  : () => _CommunityPostComposerReferenceActions(this)._toggleCollaborator(
                    collaborator,
                  ),
            ),
        ],
      ),
    ],
    const SizedBox(height: 8),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('community-composer-collaborator-query'),
            controller: _collaboratorQuery,
            enabled: !busy && widget.draft.collaborators.length < 3,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _CommunityPostComposerReferenceActions(this)._searchCollaborators(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.group_add_outlined),
              hintText: communityText(
                context,
                'Search by name or @handle',
                'ابحث بالاسم أو @المعرّف',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const Key('community-composer-collaborator-search'),
          tooltip: communityText(
            context,
            'Search collaborators',
            'البحث عن متعاونين',
          ),
          onPressed:
              busy ||
                  _collaboratorSearching ||
                  widget.draft.collaborators.length >= 3
              ? null
              : _searchCollaborators,
          icon: _collaboratorSearching
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded),
        ),
      ],
    ),
    if (_collaboratorResults.isNotEmpty) ...[
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final collaborator in _collaboratorResults)
            FilterChip(
              key: Key(
                'community-composer-collaborator-' + collaborator.userId,
              ),
              selected: widget.draft.collaborators.any(
                (value) => value.userId == collaborator.userId,
              ),
              avatar: BilAccountAvatar(
                radius: 12,
                networkUrl: collaborator.avatarUrl,
              ),
              label: Text('@' + collaborator.handle),
              onSelected:
                  busy ||
                      (!widget.draft.collaborators.any(
                            (value) =>
                                value.userId == collaborator.userId,
                          ) &&
                          widget.draft.collaborators.length >= 3)
                  ? null
                  : (_) => _CommunityPostComposerReferenceActions(this)._toggleCollaborator(
                    collaborator,
                  ),
            ),
        ],
      ),
    ],
  ];
}
