part of 'circle_management_controller.dart';

extension CircleManagementControllerMedia on CircleManagementController {
  Future<CircleOperationState> uploadMedia({
    required String circleSlug,
    required CircleMediaKind kind,
    required CommunityPostImageDraft image,
  }) async {
    await restorePendingOperations();
    _check();
    circleValidateSlug(circleSlug);
    final key = CircleOperationKeys.media(circleSlug, kind);
    final running = _inFlight[key];
    if (running != null) return running;
    // Keep an immutable byte snapshot matching the reviewed image through all
    // async phases; a caller cannot replace bytes after the permission check.
    final snapshot = CommunityPostImageDraft(
      bytes: Uint8List.fromList(image.bytes),
      mimeType: image.mimeType,
      extension: image.extension,
      width: image.width,
      height: image.height,
    );
    final candidate = _CircleCommand(
      key: key,
      requestId: _requestIdFactory(),
      operation: 'media_prepare',
      target: circleSlug,
      mediaKind: kind,
      fingerprint: circleOperationDigest([
        circleSlug,
        kind.name,
        image.mimeType,
        image.byteLength,
        image.width,
        image.height,
        circleOperationBytesDigest(snapshot.bytes),
      ]),
      send: (id) => gateway.prepareMedia(
        requestId: id,
        circleSlug: circleSlug,
        kind: kind,
        image: snapshot,
      ),
    );
    final previous = _commands[key];
    final state = _states[key];
    if (previous != null) {
      if (previous.operation == 'media_prepare' &&
          previous.fingerprint != candidate.fingerprint) {
        throw const CircleReadbackPending();
      }
      if (state?.phase == CircleMutationPhase.awaitingUpload) {
        final work = _media[key];
        if (work == null || work.reservation == null) {
          throw const CircleReadbackPending();
        }
        if (previous.fingerprint != candidate.fingerprint) {
          throw const CircleReadbackPending();
        }
        work.image = snapshot;
        return _singleFlight(key, () => _continueMedia(key, work));
      }
      if (state != null && state.phase != CircleMutationPhase.failed) {
        return state;
      }
    }
    final command = previous?.restoredReadbackOnly == true
        ? candidate.withRequestIdentity(
            previous!.requestId,
            acknowledged: previous.acknowledged,
          )
        : previous ?? candidate;
    final work = _CircleMediaWork(circleSlug, kind, snapshot);
    _media[key] = work;
    _commands[key] = command;
    return _singleFlight(key, () async {
      final prepared = await _execute(command);
      if (prepared.phase != CircleMutationPhase.awaitingUpload || !isCurrent) {
        return prepared;
      }
      return _continueMedia(key, work);
    });
  }

  /// Continues a confirmed reservation only after another explicit user action.
  /// retryReadback itself never sends bytes or issues a follow-on mutation.
  Future<CircleOperationState> resumeMedia(String operationKey) async {
    await restorePendingOperations();
    _check();
    final running = _inFlight[operationKey];
    if (running != null) return running;
    final work = _media[operationKey];
    final state = _states[operationKey];
    if (work == null ||
        work.image == null ||
        state?.phase != CircleMutationPhase.awaitingUpload) {
      throw const CircleReadbackPending();
    }
    return _singleFlight(
      operationKey,
      () => _continueMedia(operationKey, work),
    );
  }

  Future<CircleOperationState> retryFailedMedia(String operationKey) async {
    await restorePendingOperations();
    _check();
    final running = _inFlight[operationKey];
    if (running != null) return running;
    final work = _media[operationKey];
    final command = _commands[operationKey];
    final state = _states[operationKey];
    if (work == null || command == null || state == null) {
      throw ArgumentError.value(operationKey, 'operationKey');
    }
    if (state.needsReadback) return retryReadback(operationKey);
    if (state.phase != CircleMutationPhase.failed) return Future.value(state);
    final active = _reattachRestoredMediaDispatch(command, work);
    if (!identical(active, command)) _commands[operationKey] = active;
    return _singleFlight(operationKey, () async {
      if (active.operation == 'media_finish') work.finishDispatched = true;
      final result = await _execute(active);
      if (active.operation == 'media_finish' &&
          result.phase == CircleMutationPhase.failed &&
          (result.error is CirclePermissionDenied ||
              result.error is CircleManagementUnavailable)) {
        work.finishDispatched = false;
      }
      if (active.operation == 'media_prepare' &&
          result.phase == CircleMutationPhase.awaitingUpload &&
          isCurrent) {
        return _continueMedia(operationKey, work);
      }
      return result;
    });
  }

  _CircleCommand _reattachRestoredMediaDispatch(
    _CircleCommand command,
    _CircleMediaWork work,
  ) {
    if (!command.restoredReadbackOnly ||
        (command.operation != 'media_finish' &&
            command.operation != 'media_cancel')) {
      return command;
    }
    final reservation = work.reservation ?? command.mediaReservation;
    if (reservation == null ||
        reservation.status != 'reserved' ||
        reservation.ownerId != gateway.ownerId ||
        reservation.circleSlug != work.circleSlug ||
        reservation.kind != work.kind ||
        reservation.id != command.mediaId) {
      return command;
    }
    return _CircleCommand(
      key: command.key,
      requestId: command.requestId,
      operation: command.operation,
      fingerprint: command.fingerprint,
      target: command.target,
      mediaId: command.mediaId,
      mediaKind: command.mediaKind,
      mediaReservation: reservation,
      acknowledged: command.acknowledged,
      send: command.operation == 'media_finish'
          ? (id) => gateway.finishMedia(requestId: id, reservation: reservation)
          : (id) =>
                gateway.cancelMedia(requestId: id, reservation: reservation),
    );
  }

  Future<CircleOperationState> _continueMedia(
    String key,
    _CircleMediaWork work,
  ) async {
    final reservation = work.reservation;
    final image = work.image;
    if (reservation == null || image == null) {
      throw const CircleReadbackPending();
    }
    if (work.cancelRequested) return _cancelReserved(key, work);
    final previous = _commands[key]!;
    _state(
      previous,
      CircleMutationPhase.submitting,
      receipt: _states[key]?.receipt,
    );
    try {
      await gateway.uploadMedia(reservation, image);
      _check();
    } on CommunityOwnerOperationCancelled {
      return _cancelledAttempt(previous);
    } catch (error) {
      if (!isCurrent) return _cancelledAttempt(previous);
      // A byte transfer can have reached Storage even if its acknowledgement
      // was lost. Keep the real reservation; never retry an upsert implicitly.
      work.cancelRequested = true;
      final cancelled = await _cancelReserved(key, work);
      if (cancelled.phase == CircleMutationPhase.cancelled) {
        return _state(
          _commands[key]!,
          CircleMutationPhase.cancelled,
          receipt: cancelled.receipt,
          error: error,
        );
      }
      return cancelled;
    }
    if (work.cancelRequested) return _cancelReserved(key, work);
    work.finishDispatched = true;
    final finish = _CircleCommand(
      key: key,
      requestId: _requestIdFactory(),
      operation: 'media_finish',
      target: work.circleSlug,
      mediaId: reservation.id,
      mediaKind: work.kind,
      mediaReservation: reservation,
      fingerprint: circleOperationDigest(reservation.id),
      send: (id) =>
          gateway.finishMedia(requestId: id, reservation: reservation),
    );
    _commands[key] = finish;
    final result = await _execute(finish);
    if (result.phase == CircleMutationPhase.failed &&
        (result.error is CirclePermissionDenied ||
            result.error is CircleManagementUnavailable)) {
      // The gateway reports these typed failures only before the finish RPC.
      // A lost/uncertain reply keeps finishDispatched true; only a proven
      // pre-dispatch rejection leaves the real reserved upload cancellable.
      work.finishDispatched = false;
    }
    return result;
  }

  Future<CircleOperationState> cancelMedia(String operationKey) async {
    await restorePendingOperations();
    _check();
    final work = _media[operationKey];
    final command = _commands[operationKey];
    if (work == null || command == null) {
      throw ArgumentError.value(operationKey, 'operationKey');
    }
    // Finalize may already have committed. Cancellation then becomes a status
    // check; it cannot roll back or label a published image as cancelled.
    if (work.finishDispatched) return retryReadback(operationKey);
    work.cancelRequested = true;
    final running = _inFlight[operationKey];
    if (running != null) return running;
    if (_states[operationKey]?.needsReadback == true &&
        command.operation == 'media_cancel') {
      return retryReadback(operationKey);
    }
    if (work.reservation == null) return retryReadback(operationKey);
    return _singleFlight(
      operationKey,
      () => _cancelReserved(operationKey, work),
    );
  }

  Future<CircleOperationState> _cancelReserved(
    String key,
    _CircleMediaWork work,
  ) async {
    final reservation = work.reservation;
    if (reservation == null) throw const CircleReadbackPending();
    final existing = _commands[key];
    final command = existing?.operation == 'media_cancel'
        ? _reattachRestoredMediaDispatch(existing!, work)
        : _CircleCommand(
            key: key,
            requestId: _requestIdFactory(),
            operation: 'media_cancel',
            target: work.circleSlug,
            mediaId: reservation.id,
            mediaKind: work.kind,
            mediaReservation: reservation,
            fingerprint: circleOperationDigest(reservation.id),
            send: (id) =>
                gateway.cancelMedia(requestId: id, reservation: reservation),
          );
    _commands[key] = command;
    return _execute(command);
  }
}
