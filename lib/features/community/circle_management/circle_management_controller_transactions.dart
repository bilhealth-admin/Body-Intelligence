part of 'circle_management_controller.dart';

extension CircleManagementControllerTransactions on CircleManagementController {
  Future<CircleOperationState> createCircle(CircleDraft draft) {
    draft.validate();
    return _submit(
      _CircleCommand(
        key: CircleOperationKeys.create,
        requestId: _requestIdFactory(),
        operation: 'create',
        fingerprint: circleOperationDigest(draft.toRpc()),
        draft: draft,
        send: (requestId) => gateway.create(requestId: requestId, draft: draft),
      ),
    );
  }

  Future<CircleOperationState> sendInvite({
    required String circleSlug,
    required String recipientCode,
  }) {
    circleValidateSlug(circleSlug);
    final code = circleRecipientCode(recipientCode);
    return _submit(
      _CircleCommand(
        key: CircleOperationKeys.inviteSend(circleSlug, code),
        requestId: _requestIdFactory(),
        operation: 'invite_send',
        fingerprint: circleOperationDigest([circleSlug, code]),
        target: circleSlug,
        send: (requestId) => gateway.sendInvite(
          requestId: requestId,
          circleSlug: circleSlug,
          recipientCode: code,
        ),
      ),
    );
  }

  Future<CircleOperationState> actOnInvite(
    CircleInvitation invite,
    CircleInviteAction action,
  ) => _submit(
    _CircleCommand(
      key: CircleOperationKeys.inviteAction(invite.id),
      requestId: _requestIdFactory(),
      operation: 'invite_${action.name}',
      fingerprint: circleOperationDigest([
        invite.id,
        invite.circleSlug,
        action.name,
      ]),
      target: invite.circleSlug,
      inviteId: invite.id,
      send: (requestId) => gateway.actOnInvite(
        requestId: requestId,
        invite: invite,
        action: action,
      ),
    ),
  );

  /// This explicit UI action is the only way to begin another completed
  /// create/upload. Uncertain or failed requests retain their identity.
  bool resetSucceededOperation(String key) {
    if (!isCurrent || _inFlight.containsKey(key) || mediaCleanupPending(key)) {
      return false;
    }
    final state = _states[key];
    if (state == null ||
        (state.phase != CircleMutationPhase.succeeded &&
            state.phase != CircleMutationPhase.cancelled)) {
      return false;
    }
    _commands.remove(key);
    _states.remove(key);
    _media.remove(key);
    _notify();
    return true;
  }

  bool resetDefinitivelyFailedOperation(String key) {
    if (!isCurrent || _inFlight.containsKey(key)) return false;
    final state = _states[key];
    final error = state?.error;
    if (state?.phase != CircleMutationPhase.failed ||
        !(error is CirclePermissionDenied ||
            error is CircleManagementUnavailable ||
            error is CommunityPostImageException)) {
      return false;
    }
    _commands.remove(key);
    _states.remove(key);
    _media.remove(key);
    _notify();
    return true;
  }

  Future<CircleOperationState> _submit(_CircleCommand candidate) {
    // Returning a Future from an `async` wrapper always changes its identity.
    // The same button double-tapped while loading the journal must share the
    // exact same durable request, including its pending Future.
    final pending = _pendingSubmissions[candidate.key];
    if (pending != null) {
      if (_pendingFingerprints[candidate.key] != candidate.fingerprint) {
        return Future.error(const CircleReadbackPending());
      }
      return pending;
    }
    final completer = Completer<CircleOperationState>();
    final submission = completer.future;
    _pendingSubmissions[candidate.key] = submission;
    _pendingFingerprints[candidate.key] = candidate.fingerprint;
    unawaited(() async {
      try {
        await restorePendingOperations();
        _check();
        final running = _inFlight[candidate.key];
        if (running != null) {
          completer.complete(await running);
          return;
        }
        final previous = _commands[candidate.key];
        final state = _states[candidate.key];
        if (previous != null) {
          if (previous.fingerprint != candidate.fingerprint) {
            throw const CircleReadbackPending();
          }
          if (state != null && state.phase != CircleMutationPhase.failed) {
            completer.complete(state);
            return;
          }
        }
        final command = previous?.restoredReadbackOnly == true
            ? candidate.withRequestIdentity(
                previous!.requestId,
                acknowledged: previous.acknowledged,
              )
            : previous ?? candidate;
        _commands[command.key] = command;
        completer.complete(
          await _singleFlight(command.key, () => _execute(command)),
        );
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        if (identical(_pendingSubmissions[candidate.key], submission)) {
          _pendingSubmissions.remove(candidate.key);
          _pendingFingerprints.remove(candidate.key);
        }
      }
    }());
    return submission;
  }

  Future<CircleOperationState> _singleFlight(
    String key,
    Future<CircleOperationState> Function() action,
  ) {
    final running = _inFlight[key];
    if (running != null) return running;
    final completer = Completer<CircleOperationState>();
    _inFlight[key] = completer.future;
    unawaited(() async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _inFlight.remove(key);
      }
    }());
    return completer.future;
  }

  CircleOperationState _state(
    _CircleCommand command,
    CircleMutationPhase phase, {
    CircleMutationReceipt? receipt,
    Object? error,
  }) {
    final value = CircleOperationState(
      key: command.key,
      requestId: command.requestId,
      operation: command.operation,
      phase: phase,
      receipt: receipt,
      error: error,
      draft: command.draft,
    );
    if (isCurrent) {
      _states[command.key] = value;
      _notify();
    }
    return value;
  }

  CircleOperationState _cancelledAttempt(_CircleCommand command) => _state(
    command,
    isCurrent
        ? CircleMutationPhase.readbackRequired
        : CircleMutationPhase.cancelled,
    error: const CommunityOwnerOperationCancelled(),
  );

  Future<CircleOperationState> _execute(_CircleCommand command) async {
    _check();
    try {
      await _persistCommand(command);
    } on CommunityOwnerOperationCancelled {
      return _cancelledAttempt(command);
    } catch (error) {
      return _state(command, CircleMutationPhase.failed, error: error);
    }
    _state(command, CircleMutationPhase.submitting);
    Object? failure;
    try {
      final acknowledged = await command.send(command.requestId);
      _check();
      _validateReceipt(command, acknowledged);
      command.acknowledged = true;
      try {
        await _persistCommand(command);
      } on Object {
        // The request identity was already durably written before dispatch.
        // A failed acknowledgement-bit update cannot authorize a new ID.
      }
    } on CommunityOwnerOperationCancelled {
      return _cancelledAttempt(command);
    } on CirclePermissionDenied catch (error) {
      return _definitiveFailure(command, error);
    } on CircleManagementUnavailable catch (error) {
      return _definitiveFailure(command, error);
    } on CommunityPostImageException catch (error) {
      return _definitiveFailure(command, error);
    } catch (error) {
      failure = error;
    }
    if (!isCurrent) return _cancelledAttempt(command);
    return _readback(command, originalFailure: failure);
  }

  Future<CircleOperationState> _definitiveFailure(
    _CircleCommand command,
    Object error,
  ) async {
    try {
      await _clearPersisted(command.key);
    } on Object catch (persistenceError) {
      return _state(
        command,
        CircleMutationPhase.failed,
        error: persistenceError,
      );
    }
    return _state(command, CircleMutationPhase.failed, error: error);
  }

  Future<CircleOperationState> retryReadback(String operationKey) async {
    await restorePendingOperations();
    _check();
    final running = _inFlight[operationKey];
    if (running != null) return running;
    final command = _commands[operationKey];
    if (command == null) {
      throw ArgumentError.value(operationKey, 'operationKey');
    }
    return _singleFlight(operationKey, () => _readback(command));
  }

  Future<CircleOperationState> _readback(
    _CircleCommand command, {
    Object? originalFailure,
  }) async {
    _state(command, CircleMutationPhase.readingBack);
    try {
      final receipt = await gateway.readOperation(command.requestId);
      _check();
      if (receipt == null) {
        // A receipt was acknowledged: a missing read is not proof it failed.
        // When dispatch was uncertain and no receipt exists, an explicit retry
        // retains the SAME request ID and SQL serializes/replays that identity.
        return _state(
          command,
          command.acknowledged
              ? CircleMutationPhase.readbackRequired
              : CircleMutationPhase.failed,
          error: originalFailure ?? const CircleReadbackPending(),
        );
      }
      _validateReceipt(command, receipt);
      command.acknowledged = true;
      if (receipt.operation == 'media_prepare') {
        final reservation = receipt.media;
        if (reservation != null && reservation.status == 'reserved') {
          final work =
              _media[command.key] ??
              (command.target != null && command.mediaKind != null
                  ? _CircleMediaWork.recovered(
                      command.target!,
                      command.mediaKind!,
                    )
                  : null);
          if (work == null) {
            throw const FormatException('Circle upload identity unavailable');
          }
          _media[command.key] = work;
          work.reservation = reservation;
          return _state(
            command,
            CircleMutationPhase.awaitingUpload,
            receipt: receipt,
          );
        }
        // The immutable operation journal proves prepare committed. A missing,
        // published, cancelled or superseded current projection is historical
        // state, not a reason to replay the mutation or invent an upload.
        _applyReceipt(receipt);
        return _terminalState(
          command,
          CircleMutationPhase.succeeded,
          receipt: receipt,
        );
      }
      _applyReceipt(receipt);
      if (receipt.operation == 'media_cancel') {
        var work = _media[command.key];
        final currentMedia = receipt.media;
        if (work == null &&
            currentMedia != null &&
            command.target != null &&
            command.mediaKind != null) {
          work = _CircleMediaWork.recovered(command.target!, command.mediaKind!)
            ..reservation = currentMedia;
          _media[command.key] = work;
        }
        if (work != null &&
            currentMedia != null &&
            currentMedia.status == 'cancelled' &&
            !work.cleanupComplete) {
          try {
            // Readback never replays cancel SQL. After a committed cancellation,
            // it may remove only that immutable cancelled object.
            await gateway.removeCancelledMedia(currentMedia);
            _check();
            work.cleanupComplete = true;
          } on CommunityOwnerOperationCancelled {
            return _cancelledAttempt(command);
          } catch (error) {
            return _state(
              command,
              CircleMutationPhase.cancelled,
              receipt: receipt,
              error: error,
            );
          }
        }
      }
      return _terminalState(
        command,
        receipt.operation == 'media_cancel'
            ? CircleMutationPhase.cancelled
            : CircleMutationPhase.succeeded,
        receipt: receipt,
      );
    } on CommunityOwnerOperationCancelled {
      return _cancelledAttempt(command);
    } catch (error) {
      return _state(
        command,
        CircleMutationPhase.readbackRequired,
        error: error,
      );
    }
  }

  Future<CircleOperationState> _terminalState(
    _CircleCommand command,
    CircleMutationPhase phase, {
    required CircleMutationReceipt receipt,
  }) async {
    try {
      await _clearPersisted(command.key);
    } on CommunityOwnerOperationCancelled {
      return _cancelledAttempt(command);
    } catch (error) {
      return _state(
        command,
        CircleMutationPhase.readbackRequired,
        receipt: receipt,
        error: error,
      );
    }
    return _state(command, phase, receipt: receipt);
  }

  void _validateReceipt(_CircleCommand command, CircleMutationReceipt receipt) {
    if (receipt.ownerId != gateway.ownerId ||
        receipt.requestId != command.requestId ||
        receipt.operation != command.operation ||
        (command.target != null && receipt.circleSlug != command.target)) {
      throw const FormatException('Circle operation readback mismatch');
    }
    if (receipt.operation.startsWith('invite_')) {
      if (receipt.inviteId == null ||
          (command.inviteId != null && receipt.inviteId != command.inviteId)) {
        throw const FormatException('Circle invitation identity unavailable');
      }
      final expectedStatus = switch (receipt.operation) {
        'invite_accept' => CircleInviteStatus.accepted,
        'invite_decline' => CircleInviteStatus.declined,
        'invite_cancel' => CircleInviteStatus.cancelled,
        _ => null,
      };
      if (expectedStatus != null &&
          receipt.invite != null &&
          receipt.invite!.status != expectedStatus) {
        throw const FormatException('Circle invitation action not confirmed');
      }
    }
    if (receipt.operation.startsWith('media_')) {
      if (receipt.mediaId == null ||
          (command.mediaId != null && receipt.mediaId != command.mediaId)) {
        throw const FormatException(
          'Circle media operation identity unavailable',
        );
      }
      final media = receipt.media;
      if (media != null &&
          (media.ownerId != gateway.ownerId ||
              media.id != receipt.mediaId ||
              (command.mediaKind != null && media.kind != command.mediaKind))) {
        throw const FormatException('Circle media operation identity mismatch');
      }
    }
  }

  void _applyReceipt(CircleMutationReceipt receipt) {
    _check();
    if (receipt.circle != null) {
      final circle = receipt.circle!;
      if (gateway.circleSlug == null || gateway.circleSlug == circle.slug) {
        managedCircle = circle;
      }
      // Existing rows can be refreshed by an authoritative receipt. A newly
      // created private circle is never inserted into an unrelated search.
      searchRows = List.unmodifiable(
        searchRows.map((row) => row.slug == circle.slug ? circle : row),
      );
    }
    if (receipt.invite != null) {
      final invite = receipt.invite!;
      final byId = {for (final row in invites) row.id: row};
      if (_inviteSlug == null || _inviteSlug == invite.circleSlug) {
        byId[invite.id] = invite;
      }
      invites = List.unmodifiable(byId.values);
    }
  }
}
