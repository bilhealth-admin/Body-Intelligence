part of 'connected_health_provider.dart';

final class NativeConnectedHealthGateway
    implements
        ConnectedHealthGateway,
        ConnectedHealthDailyActivityGateway,
        ConnectedHealthForegroundSyncGateway,
        ConnectedHealthCachedSnapshotGateway,
        ConnectedHealthStartupPermissionGateway,
        ConnectedHealthCancellableSyncGateway {
  NativeConnectedHealthGateway(
    this._flows, {
    String? ownerId,
    String Function()? currentOwnerId,
    DateTime Function()? foregroundNow,
  }) {
    _foregroundNow = foregroundNow ?? DateTime.now;
    final resolvedOwnerId = ownerId?.trim().isNotEmpty == true
        ? ownerId!.trim()
        : OwnerScopedHealthStore.localDeviceOwner;
    _store = OwnerScopedHealthStore(
      inner: _flows.store,
      ownerId: resolvedOwnerId,
      readCurrentOwnerId: currentOwnerId ?? () => resolvedOwnerId,
    );
    _appleHealthIntegration = UnifiedHealthDataRuntime(
      bridges: <NativeHealthBridge>[_flows.appleHealth.bridge],
      store: _store,
      audit: _flows.audit,
    );
    _healthConnectIntegration = UnifiedHealthDataRuntime(
      bridges: <NativeHealthBridge>[_flows.healthConnect.bridge],
      store: _store,
      audit: _flows.audit,
    );
  }

  final GlobalProductFlows _flows;
  late final OwnerScopedHealthStore _store;
  late final UnifiedHealthDataRuntime _appleHealthIntegration;
  late final UnifiedHealthDataRuntime _healthConnectIntegration;
  int _foregroundReadGeneration = 0;
  late final DateTime Function() _foregroundNow;

  @override
  Future<ConnectedHealthSnapshot?> requestStartupPermissions() async {
    // Apple Health authorization must be initiated by an explicit user action.
    // Keep this legacy startup seam fail-closed so a future dashboard caller
    // cannot present HealthKit permission during launch or passive refresh.
    return null;
  }

  @override
  Future<ConnectedHealthSnapshot> loadDailyActivity() =>
      _loadNativeDailyActivity(this);

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String? get _source => _isIos
      ? 'Apple Health'
      : _isAndroid
      ? 'Health Connect'
      : null;

  GlobalProductCapabilityState? get _capability => _isIos
      ? _flows.capabilities['appleWatch']
      : _isAndroid
      ? _flows.capabilities['wearOs']
      : null;

  @override
  Future<ConnectedHealthSnapshot> load() => _loadSnapshot(cachedOnly: false);

  @override
  Future<ConnectedHealthSnapshot> loadCachedSnapshot() =>
      _loadSnapshot(cachedOnly: true);

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async {
    if (!_store.isOwnerCurrent) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    try {
      final types = connectedHealthReadTypesForPlatform(
        defaultTargetPlatform,
      ).map((type) => type.name).toSet();
      final bridge = _bridge;
      final reviewInSettings =
          _isIos &&
          bridge is NativeHealthAuthorizationReviewBridge &&
          await (bridge as NativeHealthAuthorizationReviewBridge)
                  .authorizationRequestStatus(types)
                  .timeout(const Duration(seconds: 8)) ==
              HealthAuthorizationRequestStatus.unnecessary;
      if (!reviewInSettings) {
        await bridge.request(types, write: false);
      }
      final previousConsent = await _store.get(
        'connected_health_consent',
        source,
      );
      await _store.put('connected_health_consent', source, <String, Object?>{
        ...?previousConsent,
        'readRequested': true,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      // A pre-consent probe can create an empty HealthKit anchor. Reset it
      // after the user completes consent so the first authorized foreground
      // sync reads existing Apple Watch history, not only future changes.
      if (previousConsent?['readRequested'] != true) {
        await _store.remove('health_anchor', _bridge.id);
      }
      final loaded = await load();
      if (reviewInSettings) {
        return loaded.copyWith(
          failureCode: 'health_permissions_review_required',
        );
      }
      return !_isIos &&
              loaded.status == ConnectedHealthStatus.permissionRequired
          ? loaded.copyWith(
              status: ConnectedHealthStatus.permissionDenied,
              failureCode: 'health_permission_denied',
            )
          : loaded;
    } catch (_) {
      if (!_store.isOwnerCurrent) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      return (await loadCachedSnapshot()).copyWith(
        status: ConnectedHealthStatus.degraded,
        failureCode: 'health_permission_request_failed',
      );
    }
  }

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async {
    if (!_store.isOwnerCurrent) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    final writeTypes = connectedHealthWriteTypeNamesForPlatform(
      defaultTargetPlatform,
    );
    if (writeTypes.isEmpty) return load();
    try {
      await _bridge.request(writeTypes, write: true);
      final current =
          await _store.get('connected_health_consent', source) ??
          <String, Object?>{};
      await _store.put('connected_health_consent', source, <String, Object?>{
        ...current,
        'weightWriteRequested': true,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      return await load();
    } catch (_) {
      if (!_store.isOwnerCurrent) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      final cached = await load();
      return cached.copyWith(failureCode: 'health_write_permission_failed');
    }
  }

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async {
    if (!_store.isOwnerCurrent) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    try {
      final result = _bridge is NativeHealthCapabilityBridge
          ? await (_bridge as NativeHealthCapabilityBridge).revokeAccess()
          : const <String, Object?>{'revoked': false};
      if (!_store.isOwnerCurrent) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      await _store.put('connected_health_consent', source, <String, Object?>{
        'readRequested': false,
        'weightWriteRequested': false,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _store.put('connected_health_ui', 'snapshot', <String, Object?>{
        'importedCount': 0,
        'signals': <Object?>[],
        'stepHistory': <Object?>[],
      });
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.permissionRequired,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: result['revoked'] == true
            ? null
            : 'revoke_in_system_settings_required',
        deviceVerified: false,
      );
    } catch (_) {
      if (!_store.isOwnerCurrent) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      return (await load()).copyWith(failureCode: 'health_revoke_failed');
    }
  }

  @override
  Future<void> openSystemSettings() async {
    if (_bridge is NativeHealthCapabilityBridge) {
      await (_bridge as NativeHealthCapabilityBridge).openSettings();
    }
  }

  @override
  Future<void> cancelSynchronization() async {
    // Apple Health is the only platform changed by this fix. Bluetooth has its
    // own scan state machine and Android Health Connect retains its behavior.
    if (!_isIos) return;
    _foregroundReadGeneration++;
    final bridge = _bridge;
    try {
      if (bridge is NativeHealthLatestSignalsBridge) {
        await (bridge as NativeHealthLatestSignalsBridge).cancelLatestSignals();
      }
    } finally {
      if (bridge is NativeHealthCancellableReadBridge) {
        await (bridge as NativeHealthCancellableReadBridge).cancelReadChanges();
      }
    }
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() => _synchronize();

  @override
  Future<ConnectedHealthSnapshot> synchronizeWithForeground(
    void Function(ConnectedHealthSnapshot snapshot) onForeground,
  ) => _synchronize(onForeground: onForeground);

  Future<ConnectedHealthSnapshot> _synchronize({
    void Function(ConnectedHealthSnapshot snapshot)? onForeground,
  }) async {
    final generation = _foregroundReadGeneration;
    bool current() =>
        _store.isOwnerCurrent &&
        (!_isIos || generation == _foregroundReadGeneration);
    if (!_store.isOwnerCurrent) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }

    final consentState = await _store.get('connected_health_consent', source);
    if (consentState?['readRequested'] != true) {
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.permissionRequired,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'explicit_health_consent_required',
      );
    }

    // Keep a usable projection available while the full native import runs.
    // A successful HealthKit query can still legitimately return no records
    // (for example while the store is refreshing or access is indeterminate).
    // That result must never erase the last confirmed dashboard/watch values.
    var cached = _isIos ? await loadCachedSnapshot() : await load();
    var verifiedForeground = false;
    Future<bool> canContinue() async {
      if (!current()) return false;
      final consent = await _store.get('connected_health_consent', source);
      return current() && consent?['readRequested'] == true;
    }

    try {
      if (_isIos) {
        // Cancellation during the local preflight belongs to this operation;
        // a later helper must not adopt the next foreground generation.
        if (!await canContinue()) {
          return const ConnectedHealthSnapshot.unavailable();
        }
        cached = await _loadNativeDailyActivity(
          this,
          cachedPreflightOnly: true,
          onVerifiedSnapshot: (snapshot) {
            if (!current()) return;
            verifiedForeground = true;
            onForeground?.call(snapshot);
          },
        );
        if (!await canContinue()) {
          return const ConnectedHealthSnapshot.unavailable();
        }
      }
      final now = DateTime.now();
      if (_isIos && consentState?['historicalReadResetAt'] == null) {
        // Older builds could create a HealthKit anchor before the user
        // granted read access. Clear that one-time probe so existing Watch
        // records are included in the first authorized sync.
        await _store.remove('health_anchor', _bridge.id);
        if (!await canContinue()) {
          return const ConnectedHealthSnapshot.unavailable();
        }
        await _store.put('connected_health_consent', source, <String, Object?>{
          ...(consentState ?? const <String, Object?>{}),
          'historicalReadResetAt': now.toUtc().toIso8601String(),
        });
      }
      final consent = GlobalConsentGrant(
        scope: _isIos ? 'apple_health_read' : 'health_connect_read',
        state: GlobalConsentState.granted,
        updatedAt: now,
      );
      final records = _isIos
          ? await _appleHealthIntegration.synchronize(
              asOf: now,
              consent: consent,
              types: connectedHealthReadTypesForPlatform(defaultTargetPlatform),
              canContinue: canContinue,
            )
          : await _healthConnectIntegration.synchronize(
              asOf: now,
              consent: consent,
              types: connectedHealthReadTypesForPlatform(defaultTargetPlatform),
            );
      final persistedRows = await _store.list('health_signals');
      if (_isIos && !await canContinue()) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      final tombstones = await _loadTombstones();
      final persisted = <GlobalHealthSignal>[];
      var persistedRowsSinceUiYield = 0;
      for (final row in persistedRows) {
        persistedRowsSinceUiYield++;
        if (persistedRowsSinceUiYield >= 8) {
          persistedRowsSinceUiYield = 0;
          await Future<void>.delayed(Duration.zero);
        }
        try {
          final signal = GlobalHealthSignal.fromMap(row);
          if (BilHealthScope.excludesKey(signal.key) ||
              await _isTombstoned(signal, tombstones: tombstones)) {
            if (_isIos && !await canContinue()) {
              return const ConnectedHealthSnapshot.unavailable();
            }
            await _store.remove('health_signals', signal.identity);
            if (_isIos && !await canContinue()) {
              return const ConnectedHealthSnapshot.unavailable();
            }
            await _store.remove('health_seen', signal.identity);
            continue;
          }
          persisted.add(signal);
        } on Object {
          // A corrupt local row is ignored; valid evidence remains available.
        }
      }
      final normalizedPersisted = aggregateConnectedSleepSignals(persisted);
      // Parsing, aggregation and evidence reconciliation can still be sizeable
      // on the first Apple Health backfill. Hand an event turn back before the
      // graph walk so navigation and scrolling never wait behind it.
      await Future<void>.delayed(Duration.zero);
      final graph = await BilGlobalHealthEvidenceGraphEngine(
        memory: SourceReliabilityMemory(store: _store),
      ).build(normalizedPersisted);
      final ordered = graph.selectedSignals.toList()
        ..sort(
          (a, b) => b.provenance.observedAt.compareTo(a.provenance.observedAt),
        );
      final dailyBridge = _bridge;
      List<GlobalHealthSignal>? nativeTotals;
      if (dailyBridge is NativeHealthDailyTotalsBridge) {
        try {
          nativeTotals = nativeDailyActivitySignals(
            await (dailyBridge as NativeHealthDailyTotalsBridge)
                .readDailyTotals(asOf: now)
                .timeout(const Duration(seconds: 6)),
            now,
          );
        } on TimeoutException {
          // Daily aggregate reads are an optimization over the already
          // imported canonical records. A slow OS aggregate must not discard
          // a completed Health sync or replace fresh evidence with old cache.
          nativeTotals = null;
        }
      }
      final nativeTotalKeys =
          nativeTotals?.map((signal) => signal.key).toSet() ?? const <String>{};
      final selected = _selectRepresentativeSignals([
        // Re-read after import so explicit tombstones are honored. A missing
        // aggregate is not a deletion and must not roll a verified OS total
        // back to an older raw-record projection.
        for (final signal in await _retainedProjection(
          'signals',
          tombstones: tombstones,
        ))
          if (!nativeTotalKeys.contains(signal.key)) signal,
        for (final signal in ordered)
          if (!nativeTotalKeys.contains(signal.key)) signal,
        ...?nativeTotals,
      ]);
      final stepHistorySignals = nativeTotalKeys.contains('steps')
          ? nativeTotals!.where((signal) => signal.key == 'steps').toList()
          : preserveTrustedConnectedStepTotals(
              await _retainedProjection('stepHistory', tombstones: tombstones),
              aggregateConnectedStepSignals(graph.selectedSignals),
            );
      // Daily UI projection only; raw health_signals and live `selected`
      // remain untouched. Recompute from the complete retained native store,
      // not the old 500-row UI preview or a mean of previous daily means.
      final signalHistorySignals = await compute(
        projectConnectedDailyHistory,
        ConnectedDailyHistoryInput(
          samples: normalizedPersisted,
          selectedEvidence: graph.selectedSignals,
          nativeTotals: nativeTotals ?? const [],
          retained: await _retainedProjection(
            'signalHistory',
            tombstones: tombstones,
          ),
          asOf: now,
        ),
      );
      final hasVerifiedNativeEvidence = selected.any(
        _isEvidenceFromNativeBridge,
      );
      if (_isIos && !await canContinue()) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      if (selected.isEmpty &&
          (cached.signals.isNotEmpty || cached.stepHistory.isNotEmpty)) {
        return (await loadCachedSnapshot()).copyWith(
          status: ConnectedHealthStatus.degraded,
          failureCode: 'health_sync_empty_result_cache_preserved',
        );
      }
      await _store.put('connected_health_evidence', 'latest', <String, Object?>{
        'selectedIds': graph.nodes
            .where((node) => node.selected)
            .map((node) => node.id)
            .toList(),
        'conflictCount': graph.conflicts.length,
        'confidence': graph.confidence,
        'updatedAt': now.toUtc().toIso8601String(),
      });
      if (_isIos && !await canContinue()) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      await _store.put('connected_health_ui', 'snapshot', <String, Object?>{
        'lastSyncAt': now.toUtc().toIso8601String(),
        'importedCount': records.length,
        'signals': <Map<String, Object?>>[
          for (final signal in selected) signal.toMap(),
        ],
        'stepHistory': <Map<String, Object?>>[
          for (final signal in stepHistorySignals) signal.toMap(),
        ],
        'signalHistory': <Map<String, Object?>>[
          for (final signal in signalHistorySignals.take(1464)) signal.toMap(),
        ],
      });
      return ConnectedHealthSnapshot(
        // HealthKit intentionally makes read denial indistinguishable from an
        // empty store. Do not claim a connected/synchronized Apple source
        // until at least one native record provides affirmative evidence.
        status: connectedHealthStatusAfterSynchronization(
          platform: defaultTargetPlatform,
          hasVerifiedNativeEvidence: hasVerifiedNativeEvidence,
        ),
        platformSource: source,
        availableSources: <String>[source],
        signals: <ConnectedHealthSignalView>[
          for (final signal in selected)
            ConnectedHealthSignalView.fromSignal(signal),
        ],
        importedCount: records.length,
        lastSyncAt: now,
        failureCode: null,
        deviceVerified: hasVerifiedNativeEvidence,
        stepHistory: <ConnectedHealthSignalView>[
          for (final signal in stepHistorySignals)
            ConnectedHealthSignalView.fromSignal(signal),
        ],
        signalHistory: <ConnectedHealthSignalView>[
          for (final signal in signalHistorySignals.take(1464))
            ConnectedHealthSignalView.fromSignal(signal),
        ],
      );
    } catch (_) {
      if (!_store.isOwnerCurrent) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      if (_isIos && !await canContinue()) {
        return _store.isOwnerCurrent
            ? cached
            : const ConnectedHealthSnapshot.unavailable();
      }
      final retained = _isIos ? await loadCachedSnapshot() : await load();
      return retained.copyWith(
        status: ConnectedHealthStatus.degraded,
        failureCode: verifiedForeground
            ? 'health_history_sync_incomplete'
            : 'health_sync_failed_offline_cache_preserved',
      );
    }
  }
}
