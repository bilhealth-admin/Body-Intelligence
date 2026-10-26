part of 'community_people_page.dart';

extension _CommunityChatRendering on _CommunityChatPageState {
  Widget _buildChat(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CommunityReturnButton(
        fallbackLocation: '/community/messages',
      ),
      title: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            child: Icon(Icons.person_outline_rounded, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
    body: BilPearlBackdrop(
      child: _safetyBlocked
          ? Center(
              child: Text(
                communityText(context, 'Member blocked.', 'تم حظر العضو.'),
              ),
            )
          : _ownerCancelled
          ? Center(
              child: Text(
                communityText(
                  context,
                  'Your account changed. Return to Community to continue.',
                  'تغير الحساب. ارجع إلى المجتمع للمتابعة.',
                ),
                textAlign: TextAlign.center,
              ),
            )
          : _repository == null
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: BilPearlCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mark_chat_unread_outlined, size: 52),
                        const SizedBox(height: 16),
                        Text(
                          _copy(
                            context,
                            'سجّل الدخول لفتح الرسائل.',
                            'Sign in to open messages.',
                            'Connectez-vous pour ouvrir les messages.',
                            'Inicia sesión para abrir los mensajes.',
                            'Mesajları açmak için giriş yapın.',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _copy(
                            context,
                            'يبقى سجلك الصحي خاصًا. يظهر هنا فقط النص الذي ترسله.',
                            'Your health log stays private. Only the text you send appears here.',
                            'Votre journal de santé reste privé. Seul le texte que vous envoyez apparaît ici.',
                            'Tu registro de salud sigue siendo privado. Aquí solo aparece el texto que envías.',
                            'Sağlık kaydınız gizli kalır. Burada yalnızca gönderdiğiniz metin görünür.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: FutureBuilder<List<CommunityMessage>>(
                    key: ValueKey(_binding),
                    future: _messages,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done &&
                          !snapshot.hasData &&
                          _rows.isEmpty) {
                        return const Center(child: BilFeatureWelcomeStatus());
                      }
                      if (snapshot.hasError && _rows.isEmpty) {
                        return Center(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _setChatState(_reload),
                            icon: const BilNavigationFeedback(
                              child: Icon(Icons.refresh_rounded),
                            ),
                            label: Text(
                              _copy(
                                context,
                                'تعذر تحميل المحادثة. أعد المحاولة.',
                                'Could not load this chat. Try again.',
                                'Conversation indisponible. Réessayez.',
                                'No se pudo cargar el chat. Inténtalo de nuevo.',
                                'Sohbet yüklenemedi. Tekrar deneyin.',
                              ),
                            ),
                          ),
                        );
                      }
                      final rows = snapshot.data ?? _rows;
                      final binding = _binding;
                      final transcript = CommunityVisibleActivityScope(
                        ownerId: '${_ownerId}_${_peerId}_$binding',
                        retryKey: _readRetry,
                        enabled: _current(binding),
                        isRowPainted: _presentation.isPainted,
                        paintChanges: _presentation,
                        unreadIds: {
                          for (final message in rows)
                            if (message.recipientId == _ownerId &&
                                !message.isRead)
                              message.id,
                        },
                        onSeen: (ids) => _markSeen(binding, ids),
                        builder: (context, marker) => ChatHistoryViewport(
                          controller: _historyScroll,
                          latestMessageId: rows.isEmpty ? null : rows.last.id,
                          child: BilRefreshIndicator(
                            onRefresh: () async {
                              if (!_current(binding)) return;
                              _setChatState(() {
                                _readRetry++;
                                _reload();
                              });
                              try {
                                await _messages;
                              } on Object {
                                /* The retry state retains the transcript. */
                              }
                            },
                            child: ListView.builder(
                              key: const Key('community-message-history'),
                              controller: _historyScroll,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              findChildIndexCallback: (key) {
                                if (key is! ValueKey<String>) return null;
                                final position = rows.indexWhere(
                                  (message) => message.id == key.value,
                                );
                                return position < 0
                                    ? null
                                    : rows.length - 1 - position;
                              },
                              physics: const AlwaysScrollableScrollPhysics(),
                              reverse: true,
                              padding: const EdgeInsets.all(16),
                              itemCount: rows.length + (_hasOlder ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == rows.length) {
                                  return TextButton.icon(
                                    key: const Key('community-chat-load-older'),
                                    onPressed: _loadingOlder
                                        ? null
                                        : _loadOlder,
                                    icon: _loadingOlder
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: BilFeatureWelcomeStatus(),
                                          )
                                        : const Icon(Icons.history_rounded),
                                    label: Text(
                                      communityText(
                                        context,
                                        'Load older messages',
                                        'تحميل الرسائل الأقدم',
                                      ),
                                    ),
                                  );
                                }
                                final message = rows[rows.length - 1 - index];
                                final mine = message.senderId == _ownerId;
                                final direction =
                                    BilWrittenLanguageResolver.directionFor(
                                      message.body,
                                      fallback: Directionality.of(context),
                                    );
                                final messageStyle =
                                    Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(
                                      color: mine
                                          ? Colors.white
                                          : CommunitySapphire.ink(context),
                                    ) ??
                                    const TextStyle(fontSize: 16);
                                return KeyedSubtree(
                                  key: ValueKey(message.id),
                                  child: Align(
                                    key: marker(message.id),
                                    alignment: mine
                                        ? AlignmentDirectional.centerEnd
                                        : AlignmentDirectional.centerStart,
                                    child: BilConversationArrival(
                                      id: message.id,
                                      presentation: _presentation,
                                      mine: mine,
                                      text: message.body,
                                      direction: direction,
                                      style: messageStyle,
                                      outgoingGradient:
                                          CommunitySapphire.messageGradient(
                                            context,
                                          ),
                                      visitIsCurrent: () => _current(binding),
                                      child: CommunityMessageBubble(
                                        mine: mine,
                                        nativeCanvas:
                                            !mine &&
                                            BilConversationText.usesNativeText,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            BilConversationText(
                                              key: ValueKey(
                                                'community-message-body-${message.id}',
                                              ),
                                              text: message.body,
                                              mine: mine,
                                              direction: direction,
                                              style: messageStyle,
                                              visitIsCurrent: () =>
                                                  _current(binding),
                                              onPainted: (ready) {
                                                if (_current(binding)) {
                                                  _presentation.markPainted(
                                                    message.id,
                                                    ready,
                                                  );
                                                }
                                              },
                                              fallback: SelectableText(
                                                message.body,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      color: mine
                                                          ? Colors.white
                                                          : CommunitySapphire.ink(
                                                              context,
                                                            ),
                                                    ),
                                                textDirection:
                                                    BilWrittenLanguageResolver.directionFor(
                                                      message.body,
                                                      fallback:
                                                          Directionality.of(
                                                            context,
                                                          ),
                                                    ),
                                                key: ValueKey(
                                                  'community-message-text-${message.id}',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: [
                                                if (!mine)
                                                  bilPearlPopupMenuButton<
                                                    String
                                                  >(
                                                    key: Key(
                                                      'community-message-safety-${message.id}',
                                                    ),
                                                    enabled: !_safetyBusy,
                                                    tooltip: communityText(
                                                      context,
                                                      'Message actions',
                                                      'إجراءات الرسالة',
                                                    ),
                                                    onSelected: (action) =>
                                                        _messageSafety(
                                                          message,
                                                          action,
                                                        ),
                                                    itemBuilder: (_) => [
                                                      PopupMenuItem(
                                                        value: 'report',
                                                        child: Text(
                                                          communityText(
                                                            context,
                                                            'Report',
                                                            'إبلاغ',
                                                          ),
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'block',
                                                        child: Text(
                                                          communityText(
                                                            context,
                                                            'Block member',
                                                            'حظر العضو',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                Text(
                                                  TimeOfDay.fromDateTime(
                                                    message.createdAt.toLocal(),
                                                  ).format(context),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: mine
                                                            ? Colors.white
                                                            : CommunitySapphire.muted(
                                                                context,
                                                              ),
                                                      ),
                                                ),
                                                if (mine) ...[
                                                  Icon(
                                                    message.isRead
                                                        ? Icons.done_all_rounded
                                                        : Icons.done_rounded,
                                                    size: 15,
                                                    color: mine
                                                        ? Colors.white
                                                        : CommunitySapphire.muted(
                                                            context,
                                                          ),
                                                    semanticLabel:
                                                        message.isRead
                                                        ? _copy(
                                                            context,
                                                            'مقروءة',
                                                            'Read',
                                                            'Lu',
                                                            'Leído',
                                                            'Okundu',
                                                          )
                                                        : _copy(
                                                            context,
                                                            'مُرسلة',
                                                            'Sent',
                                                            'Envoyé',
                                                            'Enviado',
                                                            'Gönderildi',
                                                          ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                      return Column(
                        children: [
                          if (snapshot.hasError)
                            TextButton.icon(
                              key: const Key('community-chat-refresh-retry'),
                              onPressed: () => _setChatState(_reload),
                              icon: const BilNavigationFeedback(
                                child: Icon(Icons.refresh_rounded),
                              ),
                              label: Text(
                                _copy(
                                  context,
                                  'تعذر تحميل المحادثة. أعد المحاولة.',
                                  'Could not load this chat. Try again.',
                                  'Conversation indisponible. Réessayez.',
                                  'No se pudo cargar el chat. Inténtalo de nuevo.',
                                  'Sohbet yüklenemedi. Tekrar deneyin.',
                                ),
                              ),
                            ),
                          Expanded(
                            key: const ValueKey('community-chat-transcript'),
                            child: transcript,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: _chatComposerSurface(
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _composer,
                        builder: (context, value, _) => ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: _chatComposerMaxHeight(),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                fit: FlexFit.loose,
                                child: SingleChildScrollView(
                                  key: _composerAnchor,
                                  child: TextField(
                                    key: const Key(
                                      'community-message-composer',
                                    ),
                                    controller: _composer,
                                    minLines: 1,
                                    maxLines: 4,
                                    textDirection:
                                        _composerDirection ??
                                        Directionality.of(context),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    maxLength: 2000,
                                    maxLengthEnforcement:
                                        MaxLengthEnforcement.none,
                                    buildCounter:
                                        (
                                          context, {
                                          required currentLength,
                                          required isFocused,
                                          required maxLength,
                                        }) => null,
                                    onChanged: _updateComposerDirection,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: CommunitySapphire.ink(context),
                                          height: 1.45,
                                        ),
                                    decoration: InputDecoration(
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        14,
                                        6,
                                      ),
                                      hintText: _copy(
                                        context,
                                        'رسالة',
                                        'Message',
                                        'Message',
                                        'Mensaje',
                                        'Mesaj',
                                      ),
                                      errorText: value.text.runes.length > 2000
                                          ? _messageLimitText(context)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 6, 6),
                                child: Row(
                                  children: [
                                    bilPearlPopupMenuButton<String>(
                                      key: const Key('community-chat-emoji'),
                                      tooltip: communityText(
                                        context,
                                        'Add emoji',
                                        'إضافة إيموجي',
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                      ),
                                      icon: Icon(
                                        Icons.emoji_emotions_outlined,
                                        color: CommunitySapphire.muted(context),
                                      ),
                                      onOpened: () => _emojiBinding = _binding,
                                      onSelected: (emoji) {
                                        if (_emojiBinding != _binding ||
                                            !_current(_binding)) {
                                          return;
                                        }
                                        final text = _composer.text;
                                        final selection = _composer.selection;
                                        final start = selection.isValid
                                            ? selection.start
                                            : text.length;
                                        final end = selection.isValid
                                            ? selection.end
                                            : text.length;
                                        final next = text.replaceRange(
                                          start,
                                          end,
                                          emoji,
                                        );
                                        _composer.value = TextEditingValue(
                                          text: next,
                                          selection: TextSelection.collapsed(
                                            offset: start + emoji.length,
                                          ),
                                        );
                                        _updateComposerDirection(next);
                                      },
                                      itemBuilder: (_) =>
                                          ['👋', '👏', '💪', '🎉', '❤️', '😊']
                                              .map(
                                                (emoji) => PopupMenuItem(
                                                  value: emoji,
                                                  child: Text(
                                                    emoji,
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${value.text.runes.length}/2000',
                                        key: const Key(
                                          'community-chat-character-count',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: CommunitySapphire.muted(
                                                context,
                                              ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _chatSendButton(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );

  double _chatComposerMaxHeight() {
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        MediaQuery.paddingOf(context).top -
        kToolbarHeight -
        28;
    return (available * .65).clamp(0, 320).toDouble();
  }

  Widget _chatComposerSurface(Widget child) {
    final solid =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    const radius = BorderRadius.all(Radius.circular(24));
    if (solid) {
      return DecoratedBox(
        key: const Key('community-chat-composer-surface'),
        decoration: BilPearlFinish.panel(
          context,
          radius: radius,
          shadow: false,
        ),
        child: child,
      );
    }
    return BilFrostedPanel(
      key: const Key('community-chat-composer-surface'),
      radius: radius,
      child: child,
    );
  }

  Widget _chatSendButton() {
    final allowed = !_sending && _current(_binding);
    final busy = _sending && !_confirmingReplacement;
    const ink = CommunitySapphire.navy;
    final contrast = MediaQuery.highContrastOf(context);
    return DecoratedBox(
      key: const Key('community-chat-send-finish'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFECF3F8), Color(0xFFD7E4EF)],
        ),
        border: Border.all(
          color: contrast ? ink : const Color(0xFFBCCDDD),
          width: contrast ? 1.5 : .8,
        ),
        boxShadow: contrast
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x14223F58),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: IconButton(
        key: const Key('community-chat-send'),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          fixedSize: const Size.square(48),
          foregroundColor: ink,
          disabledForegroundColor: ink.withValues(alpha: .38),
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
          visualDensity: VisualDensity.standard,
        ),
        tooltip: _copy(
          context,
          'إرسال الرسالة',
          'Send message',
          'Envoyer le message',
          'Enviar mensaje',
          'Mesaj gönder',
        ),
        onPressed: allowed ? _send : null,
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: BilFeatureWelcomeStatus(color: ink),
              )
            : BilCrystalArrow(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 25,
                  color: allowed ? ink : ink.withValues(alpha: .38),
                ),
              ),
      ),
    );
  }
}
