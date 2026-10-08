part of 'community_channels_page.dart';

extension _CommunityChannelComposer on _CommunityChannelsViewState {
  Widget _composerBar(CommunityChannel channel) {
    final controller = _controller;
    final length = _composer.text.runes.length;
    final limit = channel.maxTextCodePoints;
    final overLimit = length > limit;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('bil07-composer'),
              controller: _composer,
              enabled: controller.isCurrent,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textDirection: BilWrittenLanguageResolver.directionFor(
                _composer.text,
                fallback: Directionality.of(context),
              ),
              decoration: InputDecoration(
                labelText: _copy(CommunityChannelsCopyKey.message),
                counterText: '$length/$limit',
                errorText: overLimit
                    ? _copy(CommunityChannelsCopyKey.textLimit, {
                        'limit': limit,
                      })
                    : null,
                errorMaxLines: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: IconButton.filled(
              key: const Key('bil07-send'),
              tooltip: _copy(
                controller.sending
                    ? CommunityChannelsCopyKey.sending
                    : CommunityChannelsCopyKey.send,
              ),
              onPressed:
                  controller.canSend &&
                      controller.foreground &&
                      !controller.sending &&
                      controller.pendingSend == null &&
                      _composer.text.trim().isNotEmpty &&
                      !overLimit
                  ? () => _send(controller)
                  : null,
              icon: controller.sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessNotice(CommunityChannel channel) {
    final controller = _controller;
    final failure = controller.sendError;
    final policy =
        failure is ChannelFailure &&
        failure.kind == ChannelFailureKind.policyRequired;
    final key = !channel.enabled
        ? CommunityChannelsCopyKey.channelDisabled
        : channel.membership == 'banned'
        ? CommunityChannelsCopyKey.blocked
        : policy
        ? CommunityChannelsCopyKey.policyRequired
        : !channel.canSend
        ? CommunityChannelsCopyKey.readOnly
        : CommunityChannelsCopyKey.permissionsUnknown;
    return _notice(
      key,
      action: Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: _controller.refreshAccess,
            child: Text(_copy(CommunityChannelsCopyKey.refreshPermission)),
          ),
          if (widget.onReviewPolicy != null &&
              channel.enabled &&
              channel.membership != 'banned')
            TextButton(
              key: const Key('bil07-review-policy'),
              onPressed: () => _reviewPolicy(controller),
              child: Text(_copy(CommunityChannelsCopyKey.reviewPolicy)),
            ),
        ],
      ),
    );
  }

  Widget _sendError() {
    final controller = _controller;
    final error = controller.sendError;
    if (error is CommunityTextPolicyException) {
      return _ChannelNotice(
        text: error.localizedMessage(
          Localizations.localeOf(context).toLanguageTag(),
        ),
      );
    }
    final policy =
        error is ChannelFailure &&
        error.kind == ChannelFailureKind.policyRequired;
    return _notice(
      policy
          ? CommunityChannelsCopyKey.policyRequired
          : CommunityChannelsCopyKey.sendFailed,
      action: policy && widget.onReviewPolicy != null
          ? TextButton(
              key: const Key('bil07-review-send-policy'),
              onPressed: () => _reviewPolicy(controller),
              child: Text(_copy(CommunityChannelsCopyKey.reviewPolicy)),
            )
          : null,
    );
  }

  Widget _pendingAttempt() {
    final controller = _controller;
    final attempt = controller.pendingSend!;
    return _ChannelNotice(
      key: const Key('bil07-pending-attempt'),
      text: _copy(
        controller.sending
            ? CommunityChannelsCopyKey.sending
            : CommunityChannelsCopyKey.sendFailed,
      ),
      detail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            attempt.text,
            key: const Key('bil07-attempt-text'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textDirection: BilWrittenLanguageResolver.directionFor(
              attempt.text,
              fallback: Directionality.of(context),
            ),
          ),
          ExpansionTile(
            key: const Key('bil07-show-attempt'),
            title: Text(_copy(CommunityChannelsCopyKey.originalAttempt)),
            children: [
              SelectableText(
                attempt.text,
                textDirection: BilWrittenLanguageResolver.directionFor(
                  attempt.text,
                  fallback: Directionality.of(context),
                ),
              ),
            ],
          ),
          Text(_copy(CommunityChannelsCopyKey.retryOriginal)),
        ],
      ),
      action: TextButton.icon(
        key: const Key('bil07-retry-send'),
        onPressed:
            controller.sending || !controller.canSend || !controller.foreground
            ? null
            : () => _send(controller, retry: true),
        icon: const Icon(Icons.refresh_rounded),
        label: Text(_copy(CommunityChannelsCopyKey.retrySend)),
      ),
    );
  }
}
