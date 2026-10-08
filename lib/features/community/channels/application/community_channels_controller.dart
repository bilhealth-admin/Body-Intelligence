import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/community_channel_models.dart';
import '../domain/community_channels_repository.dart';

export '../domain/community_channel_models.dart';
export '../domain/community_channels_repository.dart';

part 'community_channels_activity.dart';

enum CommunityChannelConnectionState {
  unavailable,
  polling,
  connected,
  disconnected,
}

/// Coordinates one owner/repository/channel visit. The repository repeats the
/// fence immediately before transport dispatch; cancellation alone cannot do so.
final class CommunityChannelsController extends ChangeNotifier {
  CommunityChannelsController({
    required this.repository,
    this.channelId,
    CommunityChannelDraftStore? drafts,
    DateTime Function()? clock,
    String Function()? newMessageId,
  }) : _drafts = drafts ?? CommunityChannelDraftStore.process,
       _clock = clock ?? DateTime.now,
       _newMessageId = newMessageId ?? const Uuid().v4,
       ownerId = repository.currentOwnerId,
       visitGeneration = ++_nextVisit {
    var deliveredOwner = ownerId;
    _auth = repository.ownerChanges.listen((next) {
      final changed = next != deliveredOwner;
      deliveredOwner = next;
      if (changed || !isCurrent) _retire();
    }, onError: (Object _, StackTrace _) => _retire());
  }

  static int _nextVisit = 0;
  final CommunityChannelsRepository repository;
  final String? ownerId;
  final String? channelId;
  final int visitGeneration;
  final CommunityChannelDraftStore _drafts;
  final DateTime Function() _clock;
  final String Function() _newMessageId;
  StreamSubscription<String?>? _auth;
  StreamSubscription<CommunityChannelChange>? _changes;
  Timer? _poll;
  Timer? _presenceExpiry;
  bool _disposed = false;
  bool _retired = false;
  Completer<void>? _directoryDone;
  bool _refreshing = false;
  bool _refreshAgain = false;
  bool _presenceBusy = false;
  bool _reading = false;
  int _readToken = 0;
  int _readingEpoch = -1;
  int _presenceToken = 0;
  int _presenceEpoch = -1;
  int _visibilityEpoch = 0;
  int _contentEpoch = 0;
  int _accessEpoch = 0;
  int _watchEpoch = 0;
  int _mergeRevision = 0;
  final _messageRevisions = <String, int>{};
  final _countTimes = <String, DateTime>{};
  String? _directoryAfter;
  int? _olderBefore;
  int _newerAfter = 0;
  CommunityChannelPresence? _presence;
  DateTime? _presenceValidUntilLocal;

  List<CommunityChannel> channels = const [];
  List<CommunityChannelMessage> messages = const [];
  CommunityChannelCapabilities? capabilities;
  bool initialized = false;
  bool available = false;
  bool loadingDirectory = false;
  bool loadingMessages = false;
  bool loadingOlder = false;
  bool loadingNewer = false;
  bool sending = false;
  bool hasMoreChannels = false;
  bool hasOlder = false;
  bool hasNewer = false;
  bool foreground = false;
  Object? directoryError;
  Object? messagesError;
  Object? sendError;
  Object? readError;
  Object? presenceError;
  CommunityChannelConnectionState connectionState =
      CommunityChannelConnectionState.unavailable;

  bool get isCurrent {
    if (_disposed || _retired || ownerId == null) return false;
    try {
      return repository.currentOwnerId == ownerId;
    } on Object {
      return false;
    }
  }

  CommunityChannel? get channel {
    for (final row in channels) {
      if (row.id == channelId) return row;
    }
    return null;
  }

  bool get canSend =>
      isCurrent &&
      available &&
      channel?.enabled == true &&
      channel?.canSend == true;

  String get draftText => ownerId == null || channelId == null
      ? ''
      : _drafts.text(ownerId!, channelId!);

  CommunityChannelSendAttempt? get pendingSend =>
      ownerId == null || channelId == null
      ? null
      : _drafts.pending(ownerId!, channelId!);

  Set<String> get unreadIds => Set<String>.unmodifiable(
    messages
        .where((row) => !row.isRead && row.authorId != ownerId)
        .map((row) => row.id),
  );

  int? get onlineCount {
    final until = _presenceValidUntilLocal;
    if (!isCurrent ||
        !foreground ||
        channel?.canRead != true ||
        until == null ||
        !_clock().isBefore(until)) {
      return null;
    }
    return _presence?.onlineCount;
  }

  int get visibilityGeneration => _visibilityEpoch;

  ChannelRequestScope _scope({
    bool visible = false,
    bool channelAccess = false,
  }) {
    final visibility = _visibilityEpoch;
    final access = _accessEpoch;
    return ChannelRequestScope(
      ownerId: ownerId ?? '',
      visitGeneration: visitGeneration,
      isCurrentVisit: () =>
          isCurrent &&
          (!channelAccess ||
              (available &&
                  channel?.canRead == true &&
                  access == _accessEpoch)) &&
          (!visible || (foreground && visibility == _visibilityEpoch)),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (!isCurrent || initialized) return;
    loadingDirectory = true;
    _notify();
    try {
      final scope = _scope();
      final result = await repository.loadCapabilities(scope);
      scope.check();
      capabilities = result;
      available = true;
      directoryError = null;
    } on Object catch (error) {
      if (isCurrent) directoryError = error;
    } finally {
      if (isCurrent) {
        loadingDirectory = false;
        initialized = true;
        _notify();
      }
    }
    if (!isCurrent || !available) return;
    await refreshAccess();
    if (!isCurrent) return;
    if (channelId != null && channel?.canRead == true) {
      await _reconcileMessages();
    }
    if (foreground) _startActivity();
  }

  Future<void> loadDirectory({bool more = false}) async {
    if (!isCurrent || !available || (more && !hasMoreChannels)) return;
    if (loadingDirectory) {
      final active = _directoryDone;
      if (active == null) return;
      await active.future;
      if (isCurrent) await loadDirectory(more: more);
      return;
    }
    final done = Completer<void>();
    _directoryDone = done;
    loadingDirectory = true;
    directoryError = null;
    _notify();
    final after = more ? _directoryAfter : null;
    try {
      final scope = _scope();
      final page = await repository.loadDirectory(scope, afterId: after);
      scope.check();
      if (page.nextAfterId != null && page.nextAfterId == after) {
        throw const FormatException('Channel directory cursor did not advance');
      }
      final byId = <String, CommunityChannel>{
        if (more)
          for (final row in channels) row.id: row,
      };
      for (var row in page.channels) {
        final oldTime = _countTimes[row.id];
        final old = channels.where((value) => value.id == row.id).firstOrNull;
        if (oldTime != null &&
            page.serverTime.isBefore(oldTime) &&
            old != null) {
          row = row.withUnread(row.canRead ? old.unreadCount : null);
        } else {
          _countTimes[row.id] = page.serverTime;
        }
        byId[row.id] = row;
      }
      channels = List.unmodifiable(
        byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
      );
      _directoryAfter = page.nextAfterId;
      hasMoreChannels = page.nextAfterId != null;
    } on Object catch (error) {
      if (isCurrent) {
        directoryError = error;
        // Permission and count snapshots are unknown after a failed refresh.
        channels = const [];
        hasMoreChannels = false;
        _clearTranscript();
      }
    } finally {
      if (isCurrent) {
        loadingDirectory = false;
        _notify();
      }
      if (identical(_directoryDone, done)) _directoryDone = null;
      if (!done.isCompleted) done.complete();
    }
  }

  Future<void> refreshAccess() async {
    await loadDirectory();
    while (isCurrent &&
        channelId != null &&
        channel == null &&
        hasMoreChannels &&
        directoryError == null) {
      await loadDirectory(more: true);
    }
    if (!isCurrent) return;
    if (channelId != null && channel?.canRead != true) _clearTranscript();
    _notify();
  }

  Future<void> refresh() async {
    if (!isCurrent) return;
    if (!available) {
      initialized = false;
      await initialize();
      return;
    }
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        await refreshAccess();
        if (!isCurrent) return;
        if (channelId != null && channel?.canRead == true) {
          await _reconcileMessages();
          if (foreground) await _refreshPresence();
        }
      } while (_refreshAgain && isCurrent && foreground);
    } finally {
      _refreshing = false;
    }
  }

  /// Re-read the loaded range after reconnect/poll so a block or removed access
  /// can remove previously cached rows and profile projections. Newer sends
  /// arriving during this read are merged rather than replaced by an old page.
  Future<void> _reconcileMessages() async {
    final selected = channel;
    if (!isCurrent || selected == null || !selected.canRead) return;
    final scope = _scope(channelAccess: true);
    final epoch = ++_contentEpoch;
    final floor = messages.isEmpty ? null : messages.first.sequence;
    final target = selected.latestSequence;
    final mergeStart = _mergeRevision;
    loadingMessages = true;
    loadingOlder = false;
    loadingNewer = false;
    messagesError = null;
    _notify();
    try {
      final fresh = <CommunityChannelMessage>[];
      var after = floor == null ? null : floor - 1;
      CommunityChannelMessagePage? latestPage;
      do {
        final page = await repository.loadMessages(
          scope,
          selected.id,
          afterSequence: after,
        );
        scope.check();
        if (epoch != _contentEpoch) return;
        fresh.addAll(page.messages);
        latestPage = page;
        final next = page.nextAfterSequence;
        if (floor == null ||
            !page.hasMore ||
            (next != null && next >= target)) {
          break;
        }
        if (next == null || (after != null && next <= after)) {
          throw const FormatException(
            'Channel catch-up cursor did not advance',
          );
        }
        after = next;
      } while (isCurrent);
      scope.check();
      if (epoch != _contentEpoch) return;
      final concurrent = messages
          .where((row) => (_messageRevisions[row.id] ?? 0) > mergeStart)
          .toList();
      messages = const [];
      _merge([...fresh, ...concurrent]);
      if (floor == null) {
        _olderBefore = latestPage.nextBeforeSequence;
        hasOlder = latestPage.hasMore;
      }
      // A concurrent own send may sit beyond unseen foreign messages. Only
      // the fetched boundary certifies that an interval has been traversed.
      _newerAfter = latestPage.nextAfterSequence ?? after ?? 0;
      hasNewer = floor != null && latestPage.hasMore;
      readError = null;
    } on Object catch (error) {
      if (isCurrent && epoch == _contentEpoch) {
        messagesError = error;
        // A failed permission/visibility refresh cannot certify old content.
        messages = const [];
        _messageRevisions.clear();
        _clearPresence();
        _refreshDeniedAccess(error);
      }
    } finally {
      if (isCurrent && epoch == _contentEpoch) {
        loadingMessages = false;
        _notify();
      }
    }
  }

  Future<void> loadOlder() => _loadPage(older: true);
  Future<void> loadNewer() => _loadPage(older: false);

  Future<void> _loadPage({required bool older}) async {
    if (!isCurrent ||
        channel?.canRead != true ||
        loadingMessages ||
        (older && (!hasOlder || loadingOlder)) ||
        (!older && loadingNewer)) {
      return;
    }
    final scope = _scope(channelAccess: true);
    final epoch = _contentEpoch;
    if (older) {
      loadingOlder = true;
    } else {
      loadingNewer = true;
    }
    messagesError = null;
    _notify();
    final before = older ? _olderBefore : null;
    final after = older ? null : _newerAfter;
    try {
      final page = await repository.loadMessages(
        scope,
        channelId!,
        beforeSequence: before,
        afterSequence: after,
      );
      scope.check();
      if (epoch != _contentEpoch) return;
      if (page.hasMore &&
          (older
              ? page.nextBeforeSequence == null ||
                    (before != null && page.nextBeforeSequence! >= before)
              : page.nextAfterSequence == null ||
                    page.nextAfterSequence! <= after!)) {
        throw const FormatException('Channel page cursor did not advance');
      }
      _merge(page.messages);
      if (older) {
        _olderBefore = page.nextBeforeSequence;
        hasOlder = page.hasMore;
      } else {
        _newerAfter = page.nextAfterSequence ?? _newerAfter;
        hasNewer = page.hasMore;
      }
    } on Object catch (error) {
      if (isCurrent && epoch == _contentEpoch) {
        messagesError = error;
        _refreshDeniedAccess(error);
      }
    } finally {
      if (isCurrent && epoch == _contentEpoch) {
        if (older) {
          loadingOlder = false;
        } else {
          loadingNewer = false;
        }
        _notify();
      }
    }
  }

  void _merge(Iterable<CommunityChannelMessage> additions) {
    final byId = {for (final row in messages) row.id: row};
    final sequences = {for (final row in messages) row.sequence: row.id};
    for (var row in additions) {
      if (row.channelId != channelId ||
          row.sequence <= 0 ||
          (sequences[row.sequence] != null &&
              sequences[row.sequence] != row.id)) {
        throw const FormatException('Conflicting channel message identity');
      }
      final old = byId[row.id];
      if (old != null &&
          (old.sequence != row.sequence ||
              old.authorId != row.authorId ||
              old.text != row.text ||
              old.clientMessageId != row.clientMessageId)) {
        throw const FormatException('Channel message payload changed');
      }
      if (old?.isRead == true || row.authorId == ownerId) {
        row = row.confirmedRead();
      }
      byId[row.id] = row;
      sequences[row.sequence] = row.id;
      _messageRevisions[row.id] = ++_mergeRevision;
    }
    messages = List.unmodifiable(
      byId.values.toList()..sort((a, b) => a.sequence.compareTo(b.sequence)),
    );
  }

  void updateDraft(String text) {
    if (!isCurrent || ownerId == null || channelId == null) return;
    _drafts.update(ownerId!, channelId!, text);
    _notify();
  }

  Future<void> send() async {
    if (!isCurrent || sending) return;
    if (!canSend || pendingSend != null) {
      sendError = const ChannelFailure(ChannelFailureKind.denied);
      _notify();
      return;
    }
    try {
      CommunityChannelText.validate(
        draftText,
        maxCodePoints: channel!.maxTextCodePoints,
      );
      final attempt = CommunityChannelSendAttempt(
        ownerId: ownerId!,
        channelId: channelId!,
        clientMessageId: _newMessageId(),
        text: draftText,
        draftRevision: _drafts.revision(ownerId!, channelId!),
      );
      _drafts.begin(attempt);
      await _performSend(attempt);
    } on Object catch (error) {
      if (isCurrent) {
        sendError = error;
        _notify();
      }
    }
  }

  Future<void> retrySend() async {
    final attempt = pendingSend;
    if (!isCurrent || sending || attempt == null || !canSend) return;
    await _performSend(attempt);
  }

  Future<void> _performSend(CommunityChannelSendAttempt attempt) async {
    final scope = _scope(channelAccess: true);
    scope.check();
    sending = true;
    sendError = null;
    _notify();
    try {
      final row = await repository.send(scope, attempt);
      scope.check();
      if (row.channelId != attempt.channelId ||
          row.authorId != attempt.ownerId ||
          row.clientMessageId != attempt.clientMessageId ||
          row.text != attempt.text) {
        throw const FormatException('Channel send acknowledgement mismatch');
      }
      _merge([row]);
      _drafts.acknowledge(attempt);
      // Do not advance the paging cursor to a sent row: unseen messages may
      // have committed between the previous cursor and this acknowledgement.
      unawaited(loadNewer());
      unawaited(refreshAccess());
    } on Object catch (error) {
      if (isCurrent) sendError = error;
    } finally {
      if (isCurrent) {
        sending = false;
        _notify();
      }
    }
  }

  Future<Set<String>> markSeen(List<String> ids) async {
    if (!isCurrent ||
        !foreground ||
        channel?.canRead != true ||
        (_reading && _readingEpoch == _visibilityEpoch)) {
      return {};
    }
    final requested = ids
        .toSet()
        .intersection(unreadIds)
        .take(capabilities?.maxReceiptIds ?? 100)
        .toList(growable: false);
    if (requested.isEmpty) return {};
    final scope = _scope(visible: true, channelAccess: true);
    final epoch = _contentEpoch;
    final readToken = ++_readToken;
    _readingEpoch = _visibilityEpoch;
    _reading = true;
    readError = null;
    try {
      final readback = await repository.acknowledgeVisible(
        scope,
        channelId!,
        requested,
      );
      scope.check();
      if (epoch != _contentEpoch) return {};
      final confirmed = readback.confirmedIds.intersection(requested.toSet());
      messages = List.unmodifiable(
        messages.map(
          (row) => confirmed.contains(row.id) ? row.confirmedRead() : row,
        ),
      );
      for (final id in confirmed) {
        _messageRevisions[id] = ++_mergeRevision;
      }
      _applyUnread(readback.unreadCount, readback.serverTime);
      _notify();
      return confirmed;
    } on Object catch (error) {
      if (scope.isCurrent) {
        readError = error;
        _notify();
      }
      return {};
    } finally {
      if (readToken == _readToken) _reading = false;
    }
  }

  void _applyUnread(int count, DateTime serverTime) {
    final previous = _countTimes[channelId];
    if (previous != null && serverTime.isBefore(previous)) return;
    _countTimes[channelId!] = serverTime;
    channels = List.unmodifiable(
      channels.map((row) => row.id == channelId ? row.withUnread(count) : row),
    );
  }

  void setForeground(bool value) => _setForeground(value);

  Future<void> reconnect() => _reconnect();

  void _refreshDeniedAccess(Object error) {
    if (error is! ChannelFailure || error.kind != ChannelFailureKind.denied) {
      return;
    }
    channels = List.unmodifiable(channels.where((row) => row.id != channelId));
    _clearTranscript();
    _notify();
    unawaited(refreshAccess());
  }

  void _clearTranscript() {
    _contentEpoch++;
    _accessEpoch++;
    messages = const [];
    _messageRevisions.clear();
    _olderBefore = null;
    _newerAfter = 0;
    hasOlder = false;
    hasNewer = false;
    loadingMessages = false;
    loadingOlder = false;
    loadingNewer = false;
    _clearPresence();
  }

  void _retire() {
    if (_retired || _disposed) return;
    _retired = true;
    _visibilityEpoch++;
    _stopActivity();
    _clearTranscript();
    channels = const [];
    available = false;
    sending = false;
    loadingDirectory = false;
    connectionState = CommunityChannelConnectionState.unavailable;
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retired = true;
    _visibilityEpoch++;
    _stopActivity();
    _clearPresence();
    unawaited(_auth?.cancel());
    super.dispose();
  }
}
