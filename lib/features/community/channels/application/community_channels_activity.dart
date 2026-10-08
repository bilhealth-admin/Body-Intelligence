part of 'community_channels_controller.dart';

extension _CommunityChannelsActivity on CommunityChannelsController {
  void _setForeground(bool value) {
    if (_disposed || value == foreground) return;
    foreground = value;
    _visibilityEpoch++;
    if (!value) {
      _stopActivity();
      _clearPresence();
    }
    // Safe when the route/lifecycle bridge runs during dependency updates.
    scheduleMicrotask(() {
      if (_disposed) return;
      _notify();
      if (value && foreground && isCurrent && available) {
        _startActivity();
        unawaited(refresh());
      }
    });
  }

  void _startActivity() {
    if (!isCurrent || !foreground || !available) return;
    final seconds = capabilities!.presenceHeartbeatSeconds;
    _poll ??= Timer.periodic(Duration(seconds: seconds), (_) {
      if (isCurrent && foreground) unawaited(refresh());
    });
    if (capabilities!.realtimeAvailable && _changes == null) {
      final scope = _scope(visible: true);
      final watchEpoch = ++_watchEpoch;
      _changes = repository
          .watchChanges(scope, channelId)
          .listen(
            (event) {
              if (!scope.isCurrent || watchEpoch != _watchEpoch) return;
              if (event == CommunityChannelChange.disconnected) {
                connectionState = CommunityChannelConnectionState.disconnected;
                _clearPresence();
                _notify();
              } else {
                if (event == CommunityChannelChange.connected) {
                  connectionState = CommunityChannelConnectionState.connected;
                }
                unawaited(refresh());
              }
            },
            onError: (Object _, StackTrace _) {
              if (!scope.isCurrent || watchEpoch != _watchEpoch) return;
              connectionState = CommunityChannelConnectionState.disconnected;
              _clearPresence();
              _notify();
            },
            onDone: () {
              if (!scope.isCurrent || watchEpoch != _watchEpoch) return;
              _changes = null;
              connectionState = CommunityChannelConnectionState.disconnected;
              _clearPresence();
              _notify();
            },
          );
    } else if (!capabilities!.realtimeAvailable) {
      connectionState = CommunityChannelConnectionState.polling;
    }
    if (channelId != null) unawaited(_refreshPresence());
  }

  Future<void> _refreshPresence() async {
    if (!isCurrent ||
        !foreground ||
        channel?.canRead != true ||
        (_presenceBusy && _presenceEpoch == _visibilityEpoch)) {
      return;
    }
    final token = ++_presenceToken;
    final visit = _scope(visible: true, channelAccess: true);
    final scope = ChannelRequestScope(
      ownerId: visit.ownerId,
      visitGeneration: visit.visitGeneration,
      isCurrentVisit: () => visit.isCurrent && token == _presenceToken,
    );
    _presenceEpoch = _visibilityEpoch;
    final startedAt = _clock();
    _presenceBusy = true;
    try {
      final value = await repository.loadPresence(
        scope,
        channelId!,
        heartbeat: channel!.membership == 'active',
        isForeground: () => scope.isCurrent,
      );
      scope.check();
      final validity = value.validUntil.difference(value.serverTime);
      _presence = value;
      // Use server-relative duration, conservatively including roundtrip time;
      // device clock skew cannot turn the server timestamp into a fresh count.
      _presenceValidUntilLocal = startedAt.add(validity);
      presenceError = null;
      _presenceExpiry?.cancel();
      final remaining = _presenceValidUntilLocal!.difference(_clock());
      if (remaining <= Duration.zero) {
        _clearPresence();
      } else {
        _presenceExpiry = Timer(remaining, () {
          if (!scope.isCurrent) return;
          _clearPresence();
          _notify();
        });
      }
      _notify();
    } on Object catch (error) {
      if (scope.isCurrent) {
        presenceError = error;
        _clearPresence();
        _notify();
      }
    } finally {
      if (token == _presenceToken) _presenceBusy = false;
    }
  }

  void _clearPresence() {
    _presenceToken++;
    _presenceBusy = false;
    _presence = null;
    _presenceValidUntilLocal = null;
    _presenceExpiry?.cancel();
    _presenceExpiry = null;
  }

  void _stopActivity() {
    _watchEpoch++;
    _poll?.cancel();
    _poll = null;
    unawaited(_changes?.cancel());
    _changes = null;
  }

  Future<void> _reconnect() async {
    if (!isCurrent || !foreground) return;
    _stopActivity();
    _clearPresence();
    _startActivity();
    await refresh();
  }
}
