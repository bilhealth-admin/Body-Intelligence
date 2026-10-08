part of 'community_channels_page.dart';

extension _CommunityChannelTranscript on _CommunityChannelsViewState {
  Widget _conversation() {
    final blocking = _blockingState();
    if (blocking != null) return blocking;
    final controller = _controller;
    final channel = controller.channel;
    final online = controller.onlineCount;
    if (channel == null) {
      if (controller.loadingDirectory) {
        return const Center(child: CircularProgressIndicator());
      }
      return _empty(
        controller.directoryError == null
            ? CommunityChannelsCopyKey.accessRestricted
            : CommunityChannelsCopyKey.directoryUnavailable,
        onRetry: () => _refresh(controller),
      );
    }
    if (!channel.canRead) {
      return _empty(
        CommunityChannelsCopyKey.accessRestricted,
        onRetry: () => _refresh(controller),
      );
    }
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  _unreadLabel(channel.unreadCount),
                  key: const Key('bil07-channel-unread'),
                ),
                Text(
                  online == null
                      ? _copy(CommunityChannelsCopyKey.onlineUnknown)
                      : _copy(CommunityChannelsCopyKey.onlineCount, {
                          'count': online,
                        }),
                  key: const Key('bil07-channel-online'),
                ),
              ],
            ),
          ),
          Expanded(child: _transcript(channel)),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .42),
            child: SingleChildScrollView(child: _composerBar(channel)),
          ),
        ],
      ),
    );
  }

  Widget _transcript(CommunityChannel channel) {
    final controller = _controller;
    final rows = controller.messages;
    final policyError =
        controller.sendError is ChannelFailure &&
        (controller.sendError! as ChannelFailure).kind ==
            ChannelFailureKind.policyRequired;
    final status = <Widget>[
      if (controller.pendingSend != null) _pendingAttempt(),
      if (controller.sendError != null &&
          (controller.pendingSend == null || policyError))
        _sendError(),
      if (controller.connectionState ==
          CommunityChannelConnectionState.disconnected)
        _notice(
          CommunityChannelsCopyKey.connectionOffline,
          key: const Key('bil07-disconnected'),
          action: TextButton.icon(
            key: const Key('bil07-reconnect'),
            onPressed: controller.reconnect,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_copy(CommunityChannelsCopyKey.reconnect)),
          ),
        ),
      if (_partialRead || controller.readError != null)
        _notice(
          CommunityChannelsCopyKey.readUnconfirmed,
          key: const Key('bil07-read-unconfirmed'),
          action: TextButton(
            key: const Key('bil07-retry-read'),
            onPressed: () {
              if (!_current(controller)) return;
              _setChannelState(() {
                _partialRead = false;
                _readRetry++;
              });
            },
            child: Text(_copy(CommunityChannelsCopyKey.retryRead)),
          ),
        ),
      if (controller.messagesError != null)
        _notice(
          CommunityChannelsCopyKey.historyUnavailable,
          action: TextButton(
            key: const Key('bil07-retry-messages'),
            onPressed: () => _refresh(controller),
            child: Text(_copy(CommunityChannelsCopyKey.retry)),
          ),
        ),
      if (!controller.canSend) _accessNotice(channel),
      if (controller.loadingMessages && rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (rows.isEmpty && controller.messagesError == null)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _copy(CommunityChannelsCopyKey.noMessages),
            textAlign: TextAlign.center,
          ),
        ),
      if (controller.hasNewer)
        TextButton.icon(
          key: const Key('bil07-load-newer'),
          onPressed: controller.loadingNewer ? null : controller.loadNewer,
          icon: const Icon(Icons.update_rounded),
          label: Text(_copy(CommunityChannelsCopyKey.loadNewer)),
        ),
    ];
    final scope = CommunityVisibleActivityScope(
      // The owner alone is insufficient for A→B→A or a channel/repository
      // replacement. Destroy markers, blocked IDs and pending dwell per visit.
      key: ValueKey(('bil07-visible', _visitKey)),
      ownerId:
          '${controller.ownerId}:${widget.channelId}:$_binding:'
          '${controller.visitGeneration}',
      enabled: controller.isCurrent && controller.foreground && channel.canRead,
      retryKey: _readRetry,
      unreadIds: controller.unreadIds,
      onSeen: (ids) => _markSeen(controller, ids),
      builder: (context, marker) => ChatHistoryViewport(
        key: ValueKey(('bil07-history', _visitKey)),
        controller: _history,
        latestMessageId: rows.isEmpty ? null : rows.last.id,
        child: RefreshIndicator(
          onRefresh: () => _refresh(controller),
          child: ListView.builder(
            key: const Key('bil07-message-history'),
            controller: _history,
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: rows.length + 1 + (controller.hasOlder ? 1 : 0),
            findChildIndexCallback: (key) {
              if (key is! ValueKey<String>) return null;
              final position = rows.indexWhere((row) => row.id == key.value);
              return position < 0 ? null : rows.length - position;
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  key: const Key('bil07-transcript-status'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...status,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _copy(CommunityChannelsCopyKey.publicScope),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              }
              if (index > rows.length) {
                return TextButton.icon(
                  key: const Key('bil07-load-older'),
                  onPressed: controller.loadingOlder
                      ? null
                      : controller.loadOlder,
                  icon: const Icon(Icons.history_rounded),
                  label: Text(_copy(CommunityChannelsCopyKey.loadOlder)),
                );
              }
              final message = rows[rows.length - index];
              return CommunityChannelMessageTile(
                key: ValueKey(message.id),
                message: message,
                ownerId: controller.ownerId!,
                viewportMarker: marker(message.id),
              );
            },
          ),
        ),
      ),
    );
    return scope;
  }
}
