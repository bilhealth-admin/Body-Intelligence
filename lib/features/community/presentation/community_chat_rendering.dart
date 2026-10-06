part of 'community_people_page.dart';

extension _CommunityChatRendering on _CommunityChatPageState {
  Widget _buildChat(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CommunityReturnButton(),
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
    body: _ownerCancelled
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
              child: Card(
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
                          'لا تظهر بياناتك الصحية داخل الرسائل.',
                          'Your health data is never shown in messages.',
                          'Vos données de santé ne figurent jamais dans les messages.',
                          'Tus datos de salud nunca aparecen en los mensajes.',
                          'Sağlık verileriniz mesajlarda gösterilmez.',
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
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError && _rows.isEmpty) {
                      return Center(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _setChatState(_reload),
                          icon: const Icon(Icons.refresh_rounded),
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
                        child: RefreshIndicator(
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
                                  onPressed: _loadingOlder ? null : _loadOlder,
                                  icon: _loadingOlder
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
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
                              return KeyedSubtree(
                                key: ValueKey(message.id),
                                child: Align(
                                  key: marker(message.id),
                                  alignment: mine
                                      ? AlignmentDirectional.centerEnd
                                      : AlignmentDirectional.centerStart,
                                  child: CommunityMessageBubble(
                                    mine: mine,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        SelectableText(
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
                                                fallback: Directionality.of(
                                                  context,
                                                ),
                                              ),
                                          key: ValueKey(
                                            'community-message-text-${message.id}',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
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
                                              const SizedBox(width: 4),
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
                                                semanticLabel: message.isRead
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
                            icon: const Icon(Icons.refresh_rounded),
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
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        tooltip: communityText(
                          context,
                          'Add emoji',
                          'إضافة إيموجي',
                        ),
                        icon: const Icon(Icons.emoji_emotions_outlined),
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
                          final next = text.replaceRange(start, end, emoji);
                          _composer.value = TextEditingValue(
                            text: next,
                            selection: TextSelection.collapsed(
                              offset: start + emoji.length,
                            ),
                          );
                          _updateComposerDirection(next);
                        },
                        itemBuilder: (_) => ['👋', '👏', '💪', '🎉', '❤️', '😊']
                            .map(
                              (emoji) => PopupMenuItem(
                                value: emoji,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      Expanded(
                        child: TextField(
                          key: const Key('community-message-composer'),
                          controller: _composer,
                          minLines: 1,
                          maxLines: 4,
                          textDirection:
                              _composerDirection ?? Directionality.of(context),
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 2000,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) => Text('${_composer.text.runes.length}/2000'),
                          onChanged: _updateComposerDirection,
                          decoration: InputDecoration(
                            hintText: _copy(
                              context,
                              'رسالة',
                              'Message',
                              'Message',
                              'Mensaje',
                              'Mesaj',
                            ),
                            errorText: _composer.text.runes.length > 2000
                                ? _messageLimitText(context)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: _copy(
                          context,
                          'إرسال الرسالة',
                          'Send message',
                          'Envoyer le message',
                          'Enviar mensaje',
                          'Mesaj gönder',
                        ),
                        onPressed: _sending || !_current(_binding)
                            ? null
                            : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}
