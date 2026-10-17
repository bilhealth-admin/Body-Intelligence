import '../../../../shared/widgets/bil_glass_press_feedback.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../app/localization/bil_written_language_resolver.dart';
import '../../../../shared/widgets/chat_history_viewport.dart';
import '../../../../shared/widgets/bil_pearl_alert_dialog.dart';
import '../../domain/community_text_policy.dart';
import '../../presentation/community_return_button.dart';
import '../../presentation/community_surface.dart';
import '../../presentation/community_visible_activity_scope.dart';
import '../application/community_channels_controller.dart';
import 'community_channel_activity.dart';
import 'community_channel_message_tile.dart';
import 'community_channels_copy.dart';

part 'community_channels_directory.dart';
part 'community_channel_transcript.dart';
part 'community_channel_composer.dart';

typedef CommunityChannelPolicyReview =
    Future<void> Function(BuildContext context, bool Function() isCurrent);

/// The existing Community entry gate must surround the route. This page does
/// not manufacture a live directory, enroll members, or accept any policy.
class CommunityChannelsPage extends StatelessWidget {
  const CommunityChannelsPage({
    required this.repository,
    this.drafts,
    this.onReviewPolicy,
    super.key,
  });

  final CommunityChannelsRepository repository;
  final CommunityChannelDraftStore? drafts;
  final CommunityChannelPolicyReview? onReviewPolicy;

  @override
  Widget build(BuildContext context) => _CommunityChannelsView(
    repository: repository,
    drafts: drafts,
    onReviewPolicy: onReviewPolicy,
  );
}

class CommunityChannelMessagesPage extends StatelessWidget {
  const CommunityChannelMessagesPage({
    required this.repository,
    required this.channelId,
    this.drafts,
    this.onReviewPolicy,
    super.key,
  });

  final CommunityChannelsRepository repository;
  final String channelId;
  final CommunityChannelDraftStore? drafts;
  final CommunityChannelPolicyReview? onReviewPolicy;

  @override
  Widget build(BuildContext context) => _CommunityChannelsView(
    repository: repository,
    channelId: channelId,
    drafts: drafts,
    onReviewPolicy: onReviewPolicy,
  );
}

class _CommunityChannelsView extends StatefulWidget {
  const _CommunityChannelsView({
    required this.repository,
    this.channelId,
    this.drafts,
    this.onReviewPolicy,
  });

  final CommunityChannelsRepository repository;
  final String? channelId;
  final CommunityChannelDraftStore? drafts;
  final CommunityChannelPolicyReview? onReviewPolicy;

  @override
  State<_CommunityChannelsView> createState() => _CommunityChannelsViewState();
}

class _CommunityChannelsViewState extends State<_CommunityChannelsView> {
  late CommunityChannelsController _controller;
  final _composer = TextEditingController();
  final _history = ScrollController(keepScrollOffset: false);
  int _binding = 0;
  int _readRetry = 0;
  bool _syncingComposer = false;
  bool _buildQueued = false;
  bool _partialRead = false;
  bool _disposed = false;

  CommunityChannelDraftStore get _drafts =>
      widget.drafts ?? CommunityChannelDraftStore.process;

  @override
  void initState() {
    super.initState();
    _composer.addListener(_edited);
    _bind();
  }

  void _bind() {
    _binding++;
    _readRetry = 0;
    _partialRead = false;
    _controller = CommunityChannelsController(
      repository: widget.repository,
      channelId: widget.channelId,
      drafts: _drafts,
    );
    _controller.addListener(_changed);
    _syncComposer();
    unawaited(_controller.initialize());
  }

  void _syncComposer() {
    final text = _controller.isCurrent ? _controller.draftText : '';
    if (_composer.text == text) return;
    _syncingComposer = true;
    _composer.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _syncingComposer = false;
  }

  void _edited() {
    if (_syncingComposer || _disposed || !_controller.isCurrent) return;
    _controller.updateDraft(_composer.text);
    _changed();
  }

  void _changed() {
    if (!mounted || _disposed) return;
    _syncComposer();
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    if (_buildQueued) return;
    _buildQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildQueued = false;
      if (mounted && !_disposed) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _setChannelState(VoidCallback update) => setState(update);

  bool _current(CommunityChannelsController controller) =>
      mounted &&
      !_disposed &&
      identical(controller, _controller) &&
      controller.isCurrent;

  @override
  void didUpdateWidget(covariant _CommunityChannelsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.channelId != widget.channelId ||
        !identical(oldWidget.drafts, widget.drafts)) {
      _controller.removeListener(_changed);
      _controller.dispose();
      _bind();
    }
  }

  Future<void> _refresh(CommunityChannelsController controller) async {
    if (!_current(controller)) return;
    setState(() {
      _readRetry++;
      _partialRead = false;
    });
    await controller.refresh();
  }

  Future<Set<String>> _markSeen(
    CommunityChannelsController controller,
    List<String> ids,
  ) async {
    if (!_current(controller) || !controller.foreground) return {};
    final readGeneration = _readRetry;
    try {
      final confirmed = await controller.markSeen(ids);
      if (!_current(controller) ||
          !controller.foreground ||
          readGeneration != _readRetry) {
        return {};
      }
      final expected = ids.toSet();
      final readback = confirmed.intersection(expected);
      if (readback.length != expected.length) {
        setState(() => _partialRead = true);
      }
      return readback;
    } on Object {
      if (_current(controller) &&
          controller.foreground &&
          readGeneration == _readRetry) {
        setState(() => _partialRead = true);
      }
      return {};
    }
  }

  Future<void> _reviewPolicy(CommunityChannelsController controller) async {
    final review = widget.onReviewPolicy;
    if (review == null || !_current(controller)) return;
    try {
      await review(context, () => _current(controller));
      if (_current(controller)) await controller.refreshAccess();
    } on Object {
      if (!mounted || !_current(controller)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_copy(CommunityChannelsCopyKey.permissionsUnknown)),
        ),
      );
    }
    // Returning from a policy review never continues an earlier send attempt.
  }

  Future<void> _open(
    CommunityChannelsController controller,
    CommunityChannel channel,
  ) async {
    if (!_current(controller) || !channel.canRead) return;
    await pushCommunityPage<void>(
      context,
      CommunityChannelMessagesPage(
        repository: widget.repository,
        channelId: channel.id,
        drafts: _drafts,
        onReviewPolicy: widget.onReviewPolicy,
      ),
    );
    if (_current(controller)) await controller.loadDirectory();
  }

  /// The dialog never submits a message, report or block on appearance.
  /// Every request is an explicit user action owned by the current channel
  /// visit, with another owner check after the awaited system UI.
  Future<void> _messageSafety(
    CommunityChannelsController controller,
    CommunityChannelMessage message,
  ) async {
    final safety = widget.repository;
    final owner = controller.ownerId;
    final channel = controller.channelId;
    if (safety is! CommunityChannelSafetyRepository ||
        owner == null ||
        channel == null ||
        message.authorId == owner ||
        !_current(controller)) {
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BilPearlAlertDialog(
        title: Text(_copy(CommunityChannelsCopyKey.messageSafety)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('bil07-safety-report-option'),
              leading: const Icon(Icons.outlined_flag_rounded),
              title: Text(_copy(CommunityChannelsCopyKey.reportMessage)),
              onTap: () => Navigator.pop(dialogContext, 'report'),
            ),
            ListTile(
              key: const Key('bil07-safety-block-option'),
              leading: const Icon(Icons.person_off_outlined),
              title: Text(_copy(CommunityChannelsCopyKey.blockMember)),
              onTap: () => Navigator.pop(dialogContext, 'block'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_copy(CommunityChannelsCopyKey.cancel)),
          ),
        ],
      ),
    );
    if (!mounted || !_current(controller) || action == null) return;
    final scope = ChannelRequestScope(
      ownerId: owner,
      visitGeneration: controller.visitGeneration,
      isCurrentVisit: () => _current(controller),
    );
    try {
      if (action == 'report') {
        final reason = await _chooseChannelReportReason();
        if (reason == null || !_current(controller)) return;
        await safety.reportMessage(
          scope,
          channelId: channel,
          messageId: message.id,
          reason: reason,
        );
        if (!mounted || !_current(controller)) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_copy(CommunityChannelsCopyKey.reportSubmitted)),
        ));
      } else if (action == 'block') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => BilPearlAlertDialog(
            title: Text(_copy(CommunityChannelsCopyKey.blockMember)),
            content: Text(_copy(CommunityChannelsCopyKey.messageSafety)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_copy(CommunityChannelsCopyKey.cancel)),
              ),
              FilledButton(
                key: const Key('bil07-confirm-block'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_copy(CommunityChannelsCopyKey.confirm)),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted || !_current(controller)) return;
        await safety.blockMember(scope, message.authorId);
        if (!mounted || !_current(controller)) return;
        await _refresh(controller);
        if (!mounted || !_current(controller)) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_copy(CommunityChannelsCopyKey.blockConfirmed)),
        ));
      }
    } on Object {
      if (!mounted || !_current(controller)) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_copy(CommunityChannelsCopyKey.safetyUnavailable)),
      ));
    }
  }

  Future<String?> _chooseChannelReportReason() {
    String selected = 'spam';
    const options = <String, CommunityChannelsCopyKey>{
      'spam': CommunityChannelsCopyKey.reportSpam,
      'harassment': CommunityChannelsCopyKey.reportHarassment,
      'hate_speech': CommunityChannelsCopyKey.reportHate,
      'other': CommunityChannelsCopyKey.reportOther,
    };
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => BilPearlAlertDialog(
          title: Text(_copy(CommunityChannelsCopyKey.reportCategory)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in options.entries)
                ListTile(
                  key: Key('bil07-report-reason-${entry.key}'),
                  title: Text(_copy(entry.value)),
                  leading: Icon(
                    selected == entry.key
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                  ),
                  onTap: () => update(() => selected = entry.key),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_copy(CommunityChannelsCopyKey.cancel)),
            ),
            FilledButton(
              key: const Key('bil07-submit-report'),
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: Text(_copy(CommunityChannelsCopyKey.reportMessage)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(
    CommunityChannelsController controller, {
    bool retry = false,
  }) async {
    if (!_current(controller) || !controller.foreground) return;
    if (_history.hasClients && _history.position.hasContentDimensions) {
      _history.jumpTo(_history.position.minScrollExtent);
    }
    if (retry) {
      await controller.retrySend();
    } else {
      await controller.send();
    }
  }

  String _copy(
    CommunityChannelsCopyKey key, [
    Map<String, Object> values = const {},
  ]) => CommunityChannelsCopy.text(context, key, values);

  Object get _visitKey => (
    _controller.ownerId,
    widget.channelId,
    _binding,
    _controller.visitGeneration,
  );

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_changed);
    _controller.dispose();
    _composer.removeListener(_edited);
    _composer.dispose();
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return CommunitySurface(
      child: CommunityChannelActivity(
        key: ValueKey(('bil07-activity', _visitKey)),
        enabled: controller.isCurrent,
        onChanged: (active) {
          if (!_current(controller)) return;
          if (controller.foreground != active) {
            // Invalidate old scope callbacks on cover/resume without replacing
            // the history subtree or moving the user's scroll position.
            _readRetry++;
            _partialRead = false;
          }
          controller.setForeground(active);
        },
        child: Scaffold(
          key: const Key('bil07-channels-page'),
          appBar: AppBar(
            leading: const CommunityReturnButton(),
            title: Text(
              widget.channelId == null
                  ? _copy(CommunityChannelsCopyKey.publicChannels)
                  : controller.channel?.title ??
                        _copy(CommunityChannelsCopyKey.channels),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                key: const Key('bil07-refresh'),
                tooltip: _copy(CommunityChannelsCopyKey.refresh),
                onPressed: controller.isCurrent
                    ? () => _refresh(controller)
                    : null,
                icon: const BilGlassPressFeedback(
                  child: Icon(Icons.refresh_rounded),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: widget.channelId == null ? _directory() : _conversation(),
          ),
        ),
      ),
    );
  }

  Widget? _blockingState() {
    final controller = _controller;
    if (!controller.isCurrent) {
      return _empty(
        controller.ownerId == null
            ? CommunityChannelsCopyKey.signIn
            : CommunityChannelsCopyKey.ownerChanged,
      );
    }
    if (!controller.initialized) {
      return Center(
        child: CircularProgressIndicator(
          semanticsLabel: _copy(CommunityChannelsCopyKey.loading),
        ),
      );
    }
    if (!controller.available) {
      return _empty(
        CommunityChannelsCopyKey.channelUnavailable,
        onRetry: () => _refresh(controller),
      );
    }
    return null;
  }

  String _unreadLabel(int? count) => count == null
      ? _copy(CommunityChannelsCopyKey.unreadUnknown)
      : _copy(CommunityChannelsCopyKey.unreadCount, {'count': count});

  Widget _notice(
    CommunityChannelsCopyKey copyKey, {
    Key? key,
    Widget? action,
  }) => _ChannelNotice(key: key, text: _copy(copyKey), action: action);

  Widget _empty(CommunityChannelsCopyKey key, {VoidCallback? onRetry}) =>
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _notice(
            key,
            action: onRetry == null
                ? null
                : TextButton.icon(
                    key: const Key('bil07-empty-retry'),
                    onPressed: onRetry,
                    icon: const BilGlassPressFeedback(
                      child: Icon(Icons.refresh_rounded),
                    ),
                    label: Text(_copy(CommunityChannelsCopyKey.retry)),
                  ),
          ),
        ),
      );
}

class _ChannelNotice extends StatelessWidget {
  const _ChannelNotice({
    required this.text,
    this.action,
    this.detail,
    super.key,
  });

  final String text;
  final Widget? action;
  final Widget? detail;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(text), ?detail, ?action],
      ),
    ),
  );
}
