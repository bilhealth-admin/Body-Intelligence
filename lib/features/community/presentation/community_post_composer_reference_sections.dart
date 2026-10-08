part of 'community_hub_page.dart';

extension _CommunityPostComposerReferenceSections
    on _CommunityPostComposerPageState {
  Widget _buildCommunityTitleField(BuildContext context, bool busy) =>
      _composerTextBox(
        key: const Key('community-composer-title-box'),
        minHeight: 57,
        child: TextField(
          key: const Key('community-composer-title'),
          controller: _title,
          enabled: !busy,
          maxLength: 120,
          style: TextStyle(fontSize: 14, color: CommunitySapphire.ink(context)),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) {
            widget.draft.title = value;
            if (_submitError != null) {
              _setComposerState(() => _submitError = null);
            }
          },
          decoration: _composerFieldDecoration(
            hint: communityText(
              context,
              'Add a title (optional)',
              'أضف عنوانًا (اختياري)',
            ),
          ),
        ),
      );

  Widget _buildCommunityReferenceOptions(BuildContext context, bool busy) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget section({
      required String id,
      required String actionKey,
      required IconData icon,
      required String title,
      required List<Widget> children,
      bool optional = true,
      Widget? selected,
      bool selectedOnNextLine = false,
    }) {
      final controller = _composerSections[id]!;
      return ExpansionTile(
        key: Key(actionKey),
        controller: controller,
        enabled: !busy,
        maintainState: true,
        minTileHeight: 48,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 9),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: const Color(0xFF0872FF),
        collapsedIconColor: const Color(0xFF0872FF),
        leading: Icon(icon, size: 22),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: title),
                  if (optional)
                    TextSpan(
                      text:
                          ' ${communityText(context, '(optional)', '(اختياري)')}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: CommunitySapphire.muted(context),
                      ),
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: CommunitySapphire.ink(context),
              ),
            ),
            if (selectedOnNextLine && selected != null) ...[
              const SizedBox(height: 4),
              selected,
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected != null && !selectedOnNextLine) ...[
              selected,
              const SizedBox(width: 5),
            ],
            Icon(
              controller.isExpanded
                  ? Icons.expand_more_rounded
                  : Icons.chevron_right_rounded,
              size: 20,
              color: CommunitySapphire.muted(context),
            ),
          ],
        ),
        onExpansionChanged: (expanded) {
          _setComposerState(() {
            if (id == 'poll' && expanded) widget.draft.pollEnabled = true;
          });
        },
        children: children,
      );
    }

    Widget divider() => Divider(
      height: 1,
      indent: 12,
      endIndent: 12,
      color: dark ? const Color(0xFF2A3B52) : const Color(0xFFEAF1FA),
    );
    return Container(
      key: const Key('community-composer-reference-action-rail'),
      decoration: BoxDecoration(
        color: CommunitySapphire.paper(context),
        border: Border.all(
          color: dark ? const Color(0xFF344965) : const Color(0xFFDCE9FA),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(
            id: 'poll',
            actionKey: 'community-composer-action-poll',
            icon: Icons.bar_chart_rounded,
            title: communityText(context, 'Add a poll', 'إضافة استطلاع'),
            selected: widget.draft.pollEnabled
                ? const Icon(Icons.check_circle_outline_rounded, size: 16)
                : null,
            children: [
              SizedBox(key: _pollAnchor),
              ..._CommunityPostComposerOptionFields(
                this,
              )._buildCommunityPollFields(context, busy),
            ],
          ),
          divider(),
          section(
            id: 'location',
            actionKey: 'community-composer-action-location',
            icon: Icons.location_on_rounded,
            title: communityText(context, 'Add location', 'إضافة موقع'),
            selected: widget.draft.locationLabel.trim().isNotEmpty
                ? const Icon(Icons.check_circle_outline_rounded, size: 16)
                : null,
            children: [
              SizedBox(key: _locationAnchor),
              ..._CommunityPostComposerOptionFields(
                this,
              )._buildCommunityLocationFields(context, busy),
            ],
          ),
          divider(),
          section(
            id: 'circles',
            actionKey: 'community-composer-action-circle',
            icon: Icons.groups_2_outlined,
            title: communityText(context, 'Choose circles', 'اختيار الدوائر'),
            optional: false,
            selectedOnNextLine:
                MediaQuery.textScalerOf(context).scale(1) >= 1.4,
            selected: widget.draft.circleSlug == null
                ? null
                : Container(
                    key: const Key('community-composer-selected-circle'),
                    constraints: const BoxConstraints(maxWidth: 116),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF203655)
                          : const Color(0xFFEDF5FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _circleTitle(context, widget.draft.circleSlug!),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? const Color(0xFF9AC2FF)
                            : const Color(0xFF0866FF),
                      ),
                    ),
                  ),
            children: [
              SizedBox(key: _circleAnchor),
              ..._CommunityPostComposerOptionFields(
                this,
              )._buildCommunityCirclesFields(context, busy),
              ..._CommunityPostComposerOptionFields(
                this,
              )._buildCommunityTopicsFields(context, busy),
            ],
          ),
          divider(),
          section(
            id: 'mentions',
            actionKey: 'community-composer-action-mentions',
            icon: Icons.person_outline_rounded,
            title: communityText(
              context,
              'Mention people',
              'الإشارة إلى أشخاص',
            ),
            children: [
              ..._CommunityPostComposerOptionFields(
                this,
              )._buildCommunityMentionsFields(context, busy),
              section(
                id: 'collaboration',
                actionKey: 'community-composer-action-collab',
                icon: Icons.group_add_outlined,
                title: communityText(
                  context,
                  'Collaboration — optional',
                  'التعاون — اختياري',
                ),
                optional: false,
                children: [
                  SizedBox(key: _collaborationAnchor),
                  ..._buildCommunityCollaboratorSection(context, busy),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _buildComposerMore(context, busy),
                  ),
                ],
              ),
            ],
          ),
          divider(),
          section(
            id: 'hashtags',
            actionKey: 'community-composer-action-hashtags',
            icon: Icons.tag_rounded,
            title: communityText(context, 'Add hashtags', 'إضافة وسوم'),
            children: _buildCommunityHashtagSection(context, busy),
          ),
          if (widget.draft.hashtags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final hashtag in widget.draft.hashtags)
                    InputChip(
                      key: Key('community-composer-hashtag-$hashtag'),
                      label: Text(
                        '#$hashtag',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: dark
                          ? const Color(0xFF203655)
                          : const Color(0xFFEDF5FF),
                      side: BorderSide.none,
                      onDeleted: busy
                          ? null
                          : () => _setComposerState(() {
                              widget.draft.hashtags.remove(hashtag);
                              _submitError = null;
                            }),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposerMore(BuildContext context, bool busy) =>
      PopupMenuButton<String>(
        key: const Key('community-composer-action-more'),
        enabled: !busy,
        tooltip: communityText(context, 'More', 'المزيد'),
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (value) {
          if (value == 'draft') _savePersistentDraft();
          if (value == 'photo') _pickImage();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'draft',
            child: Text(
              widget.draft.savedPersistently
                  ? communityText(context, 'Update draft', 'تحديث المسودة')
                  : communityText(context, 'Save draft', 'حفظ المسودة'),
            ),
          ),
          PopupMenuItem(
            value: 'photo',
            enabled: _selectedImages.length < 4,
            child: Text(communityText(context, 'Add photo', 'إضافة صورة')),
          ),
        ],
      );

  List<Widget> _buildCommunityHashtagSection(BuildContext context, bool busy) =>
      [
        Text(
          communityText(
            context,
            'Add up to 10 searchable hashtags.',
            'أضف حتى 10 وسوم قابلة للبحث.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
                onSubmitted: (_) => _addHashtag(),
                decoration: InputDecoration(
                  prefixText: '#',
                  hintText: 'progress',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
      communityText(context, 'Collaboration — optional', 'التعاون — اختياري'),
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
                'community-composer-selected-collaborator-${collaborator.userId}',
              ),
              avatar: BilAccountAvatar(
                radius: 12,
                networkUrl: collaborator.avatarUrl,
              ),
              label: Text('@${collaborator.handle}'),
              onDeleted: busy
                  ? null
                  : () => _CommunityPostComposerReferenceActions(
                      this,
                    )._toggleCollaborator(collaborator),
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
            onSubmitted: (_) => _CommunityPostComposerReferenceActions(
              this,
            )._searchCollaborators(),
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
                'community-composer-collaborator-${collaborator.userId}',
              ),
              selected: widget.draft.collaborators.any(
                (value) => value.userId == collaborator.userId,
              ),
              avatar: BilAccountAvatar(
                radius: 12,
                networkUrl: collaborator.avatarUrl,
              ),
              label: Text('@${collaborator.handle}'),
              onSelected:
                  busy ||
                      (!widget.draft.collaborators.any(
                            (value) => value.userId == collaborator.userId,
                          ) &&
                          widget.draft.collaborators.length >= 3)
                  ? null
                  : (_) => _CommunityPostComposerReferenceActions(
                      this,
                    )._toggleCollaborator(collaborator),
            ),
        ],
      ),
    ],
  ];
}
