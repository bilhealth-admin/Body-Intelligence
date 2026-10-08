import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../services/community_owner_operation.dart';
import '../services/community_post_image_picker.dart';
import 'circle_management_gateway.dart';
import 'circle_operation_journal.dart';
import 'circle_management_models.dart';

part 'circle_management_controller_transactions.dart';
part 'circle_management_controller_media.dart';

/// State belongs to one captured visit, never to the currently signed-in user
/// by lookup. Every continuation checks the original gateway before publishing.
class CircleManagementController extends ChangeNotifier {
  CircleManagementController({
    required this.gateway,
    this.searchDebounce = const Duration(milliseconds: 350),
    this.ownsGateway = true,
    String Function()? requestIdFactory,
    CircleOperationJournal? operationJournal,
  }) : _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       _operationJournal =
           operationJournal ?? SharedPreferencesCircleOperationJournal() {
    gateway.addListener(_ownerChanged);
  }

  final CircleManagementGateway gateway;
  final Duration searchDebounce;
  final bool ownsGateway;
  final String Function() _requestIdFactory;
  final CircleOperationJournal _operationJournal;
  bool _disposed = false;
  bool _ownerInvalidated = false;
  Timer? _debounce;
  int _searchGeneration = 0;
  int _inviteGeneration = 0;
  int _circleGeneration = 0;
  int _capabilityGeneration = 0;
  String _query = '';
  bool _mine = false;
  String? _searchCursor;
  String? _inviteCursor;
  String? _inviteSlug;
  final Map<String, _CircleCommand> _commands = {};
  final Map<String, CircleOperationState> _states = {};
  final Map<String, Future<CircleOperationState>> _inFlight = {};
  // Coalesce identical first taps before the asynchronous durable-journal
  // restoration starts. _inFlight only protects requests after restoration.
  final Map<String, Future<CircleOperationState>> _pendingSubmissions = {};
  final Map<String, String> _pendingFingerprints = {};
  final Map<String, _CircleMediaWork> _media = {};
  Future<void>? _restoreFuture;
  bool _operationsRestored = false;
  Object? operationRecoveryError;

  CircleCapabilities? capabilities;
  bool capabilitiesLoading = false;
  Object? capabilitiesError;
  ManagedCommunityCircle? managedCircle;
  bool circleLoading = false;
  Object? circleError;
  List<ManagedCommunityCircle> searchRows = const [];
  bool searchLoading = false;
  Object? searchError;
  List<CircleInvitation> invites = const [];
  bool invitesLoading = false;
  Object? invitesError;

  bool get isCurrent => !_disposed && !_ownerInvalidated && gateway.isCurrent;
  bool get searchHasMore => _searchCursor != null;
  bool get invitesHasMore => _inviteCursor != null;
  String get searchQuery => _query;
  bool get searchMine => _mine;
  List<CircleOperationState> get operations =>
      List.unmodifiable(_states.values);
  CircleOperationState? operation(String key) => _states[key];
  bool mediaCleanupPending(String key) =>
      _media[key] != null &&
      !_media[key]!.cleanupComplete &&
      _states[key]?.receipt?.media?.status == 'cancelled';
  bool mediaCanResume(String key) =>
      _media[key]?.image != null &&
      _media[key]?.reservation != null &&
      _states[key]?.phase == CircleMutationPhase.awaitingUpload;
  bool mediaCanAcceptRetryImage(String key) =>
      _media[key]?.image == null &&
      _commands[key]?.operation == 'media_prepare' &&
      _commands[key]?.restoredReadbackOnly == true &&
      _states[key]?.phase == CircleMutationPhase.failed;

  Future<void> restorePendingOperations() async {
    if (_operationsRestored) return;
    final running = _restoreFuture;
    if (running != null) return running;
    final future = _restorePendingOperations();
    _restoreFuture = future;
    try {
      await future;
    } finally {
      if (identical(_restoreFuture, future)) _restoreFuture = null;
    }
  }

  Future<void> _restorePendingOperations() async {
    _check();
    operationRecoveryError = null;
    List<CircleOperationJournalEntry> entries;
    try {
      entries = await _operationJournal.load(gateway.ownerId);
      _check();
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } catch (error) {
      final failure = CircleOperationJournalUnavailable(error);
      operationRecoveryError = failure;
      _notify();
      throw failure;
    }
    for (final entry in entries) {
      _check();
      if (_commands.containsKey(entry.key)) continue;
      final command = _CircleCommand(
        key: entry.key,
        requestId: entry.requestId,
        operation: entry.operation,
        fingerprint: entry.fingerprint,
        target: entry.target,
        inviteId: entry.inviteId,
        mediaId: entry.mediaId,
        mediaKind: entry.mediaKind,
        mediaReservation: entry.mediaReservation,
        acknowledged: entry.acknowledged,
        restoredReadbackOnly: true,
        send: (_) async => throw const CircleReadbackPending(),
      );
      _commands[entry.key] = command;
      if (entry.operation.startsWith('media_') &&
          entry.target != null &&
          entry.mediaKind != null) {
        final work = _CircleMediaWork.recovered(entry.target!, entry.mediaKind!)
          ..reservation = entry.mediaReservation;
        if (entry.operation == 'media_finish') work.finishDispatched = true;
        if (entry.operation == 'media_cancel') work.cancelRequested = true;
        _media[entry.key] = work;
      }
      _states[entry.key] = CircleOperationState(
        key: entry.key,
        requestId: entry.requestId,
        operation: entry.operation,
        phase: CircleMutationPhase.readbackRequired,
        error: const CircleReadbackPending(),
      );
    }
    _operationsRestored = true;
    _notify();
    for (final entry in entries) {
      if (!isCurrent) return;
      final command = _commands[entry.key];
      if (command == null || _inFlight.containsKey(entry.key)) continue;
      await _singleFlight(entry.key, () => _readback(command));
    }
  }

  CircleOperationJournalEntry _journalEntry(_CircleCommand command) =>
      CircleOperationJournalEntry(
        ownerId: gateway.ownerId,
        key: command.key,
        requestId: command.requestId,
        operation: command.operation,
        fingerprint: command.fingerprint,
        acknowledged: command.acknowledged,
        target: command.target,
        inviteId: command.inviteId,
        mediaId: command.mediaId,
        mediaKind: command.mediaKind,
        mediaReservation: command.mediaReservation,
      );

  Future<void> _persistCommand(_CircleCommand command) async {
    _check();
    try {
      await _operationJournal.upsert(gateway.ownerId, _journalEntry(command));
      _check();
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } catch (error) {
      throw CircleOperationJournalUnavailable(error);
    }
  }

  Future<void> _clearPersisted(String key) async {
    _check();
    try {
      await _operationJournal.remove(gateway.ownerId, key);
      _check();
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } catch (error) {
      throw CircleOperationJournalUnavailable(error);
    }
  }

  void _check() {
    if (!isCurrent) throw const CommunityOwnerOperationCancelled();
  }

  void _notify() {
    if (isCurrent) notifyListeners();
  }

  void _ownerChanged() {
    if (_disposed || gateway.isCurrent) return;
    _ownerInvalidated = true;
    _debounce?.cancel();
    _searchGeneration++;
    _inviteGeneration++;
    _circleGeneration++;
    _capabilityGeneration++;
    capabilities = null;
    managedCircle = null;
    searchRows = const [];
    invites = const [];
    _searchCursor = null;
    _inviteCursor = null;
    capabilitiesLoading = false;
    circleLoading = false;
    searchLoading = false;
    invitesLoading = false;
    capabilitiesError = null;
    circleError = null;
    searchError = null;
    invitesError = null;
    _commands.clear();
    _states.clear();
    _media.clear();
    notifyListeners();
  }

  Future<void> loadCapabilities() async {
    if (!isCurrent) return;
    final generation = ++_capabilityGeneration;
    capabilitiesLoading = true;
    capabilitiesError = null;
    capabilities = null;
    _debounce?.cancel();
    _searchGeneration++;
    searchRows = const [];
    _searchCursor = null;
    searchLoading = false;
    searchError = null;
    _inviteGeneration++;
    invites = const [];
    _inviteCursor = null;
    invitesLoading = false;
    _circleGeneration++;
    managedCircle = null;
    circleLoading = false;
    _notify();
    try {
      final value = await gateway.loadCapabilities();
      _check();
      if (generation == _capabilityGeneration) capabilities = value;
    } on CommunityOwnerOperationCancelled {
      return;
    } catch (error) {
      if (isCurrent && generation == _capabilityGeneration) {
        capabilitiesError = error;
      }
    } finally {
      if (isCurrent && generation == _capabilityGeneration) {
        capabilitiesLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadCircle(String slug) async {
    if (!isCurrent) return;
    final generation = ++_circleGeneration;
    circleLoading = true;
    circleError = null;
    managedCircle = null;
    _notify();
    try {
      final value = await gateway.readCircle(slug);
      _check();
      if (generation == _circleGeneration) managedCircle = value;
    } on CommunityOwnerOperationCancelled {
      return;
    } catch (error) {
      if (isCurrent && generation == _circleGeneration) circleError = error;
    } finally {
      if (isCurrent && generation == _circleGeneration) {
        circleLoading = false;
        _notify();
      }
    }
  }

  void setSearch(String query, {bool mine = false}) {
    if (!isCurrent) return;
    _query = query.trim();
    _mine = mine;
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    searchRows = const [];
    _searchCursor = null;
    searchError = null;
    searchLoading = false;
    try {
      circleText(_query, maximum: 100);
      if (capabilities?.canSearch == true) {
        searchLoading = true;
        _debounce = Timer(
          searchDebounce,
          () => unawaited(_loadSearch(generation)),
        );
      }
    } catch (error) {
      searchError = error;
    }
    _notify();
  }

  Future<void> refreshSearch() async {
    if (!isCurrent) return;
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    searchRows = const [];
    _searchCursor = null;
    await _loadSearch(generation);
  }

  Future<void> loadMore() async {
    if (!isCurrent || searchLoading || _searchCursor == null) return;
    await _loadSearch(_searchGeneration, cursor: _searchCursor);
  }

  Future<void> _loadSearch(int generation, {String? cursor}) async {
    if (!isCurrent || generation != _searchGeneration) return;
    if (capabilities?.canSearch != true) {
      searchLoading = false;
      searchError = const CircleManagementUnavailable();
      _notify();
      return;
    }
    final query = _query;
    final mine = _mine;
    searchLoading = true;
    searchError = null;
    _notify();
    try {
      final page = await gateway.search(
        query: query,
        mine: mine,
        afterSlug: cursor,
      );
      _check();
      if (generation != _searchGeneration || query != _query || mine != _mine) {
        return;
      }
      if (cursor != null && page.nextAfterSlug == cursor) {
        throw const FormatException('Circle search cursor did not advance');
      }
      final bySlug = <String, ManagedCommunityCircle>{
        if (cursor != null)
          for (final row in searchRows) row.slug: row,
        for (final row in page.circles) row.slug: row,
      };
      searchRows = List.unmodifiable(bySlug.values);
      _searchCursor = page.nextAfterSlug;
    } on CommunityOwnerOperationCancelled {
      return;
    } catch (error) {
      if (isCurrent && generation == _searchGeneration) searchError = error;
    } finally {
      if (isCurrent && generation == _searchGeneration) {
        searchLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadInvites({String? circleSlug}) async {
    if (!isCurrent) return;
    _inviteSlug = circleSlug ?? gateway.circleSlug;
    _inviteCursor = null;
    invites = const [];
    await _loadInvites(++_inviteGeneration);
  }

  Future<void> loadMoreInvites() async {
    if (!isCurrent || invitesLoading || _inviteCursor == null) return;
    await _loadInvites(_inviteGeneration, cursor: _inviteCursor);
  }

  Future<void> _loadInvites(int generation, {String? cursor}) async {
    if (!isCurrent || generation != _inviteGeneration) return;
    invitesLoading = true;
    invitesError = null;
    _notify();
    try {
      final page = await gateway.loadInvites(
        circleSlug: _inviteSlug,
        afterId: cursor,
      );
      _check();
      if (generation != _inviteGeneration) return;
      if (cursor != null && cursor == page.nextAfterId) {
        throw const FormatException('Circle invite cursor did not advance');
      }
      final byId = <String, CircleInvitation>{
        if (cursor != null)
          for (final row in invites) row.id: row,
        for (final row in page.invites) row.id: row,
      };
      invites = List.unmodifiable(byId.values);
      _inviteCursor = page.nextAfterId;
    } on CommunityOwnerOperationCancelled {
      return;
    } catch (error) {
      if (isCurrent && generation == _inviteGeneration) invitesError = error;
    } finally {
      if (isCurrent && generation == _inviteGeneration) {
        invitesLoading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounce?.cancel();
    _searchGeneration++;
    _inviteGeneration++;
    _circleGeneration++;
    _capabilityGeneration++;
    gateway.removeListener(_ownerChanged);
    if (ownsGateway) gateway.dispose();
    _commands.clear();
    _states.clear();
    _media.clear();
    super.dispose();
  }
}

class _CircleCommand {
  _CircleCommand({
    required this.key,
    required this.requestId,
    required this.operation,
    required this.fingerprint,
    required this.send,
    this.target,
    this.inviteId,
    this.draft,
    this.mediaId,
    this.mediaKind,
    this.mediaReservation,
    this.acknowledged = false,
    this.restoredReadbackOnly = false,
  });

  final String key;
  final String requestId;
  final String operation;
  final String fingerprint;
  final Future<CircleMutationReceipt> Function(String requestId) send;
  final String? target;
  final String? inviteId;
  final CircleDraft? draft;
  final String? mediaId;
  final CircleMediaKind? mediaKind;
  final CircleMediaReservation? mediaReservation;
  bool acknowledged;
  final bool restoredReadbackOnly;

  _CircleCommand withRequestIdentity(
    String value, {
    required bool acknowledged,
  }) => _CircleCommand(
    key: key,
    requestId: value,
    operation: operation,
    fingerprint: fingerprint,
    send: send,
    target: target,
    inviteId: inviteId,
    draft: draft,
    mediaId: mediaId,
    mediaKind: mediaKind,
    mediaReservation: mediaReservation,
    acknowledged: acknowledged,
  );
}

class _CircleMediaWork {
  _CircleMediaWork(this.circleSlug, this.kind, this.image);
  _CircleMediaWork.recovered(this.circleSlug, this.kind) : image = null;

  final String circleSlug;
  final CircleMediaKind kind;
  CommunityPostImageDraft? image;
  CircleMediaReservation? reservation;
  bool cancelRequested = false;
  bool finishDispatched = false;
  bool cleanupComplete = false;
}
