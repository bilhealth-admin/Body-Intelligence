part of 'connected_health_provider.dart';

final class NativeConnectedHealthGateway
    implements
        ConnectedHealthGateway,
        ConnectedHealthDailyActivityGateway,
        ConnectedHealthStartupPermissionGateway {
  NativeConnectedHealthGateway(this._flows);

  final GlobalProductFlows _flows;

  @override
  Future<ConnectedHealthSnapshot?> requestStartupPermissions() async {
    if (!_isIos || _capability?.available != true) return null;
    final bridge = _bridge;
    if (bridge is! NativeHealthAuthorizationReviewBridge) return null;
    final types = connectedHealthReadTypesForPlatform(
      TargetPlatform.iOS,
    ).map((type) => type.name).toSet();
    final status = await (bridge as NativeHealthAuthorizationReviewBridge)
        .authorizationRequestStatus(types)
        .timeout(const Duration(seconds: 8));
    if (status != HealthAuthorizationRequestStatus.shouldRequest) return null;
    return requestPermissions();
  }

  @override
  Future<ConnectedHealthSnapshot> loadDailyActivity() async {
    final cached = await load();
    final source = _source;
    final bridge = _bridge;
    if (source == null ||
        _capability?.available != true ||
        bridge is! NativeHealthDailyTotalsBridge) {
      return cached;
    }
    final consent = await _flows.store.get('connected_health_consent', source);
    if (consent?['readRequested'] != true) return cached;
    try {
      final now = DateTime.now();
      final activity = nativeDailyActivitySignals(
        await (bridge as NativeHealthDailyTotalsBridge)
            .readDailyTotals(asOf: now)
            .timeout(const Duration(seconds: 8)),
        now,
      );
      const keys = {'steps', 'distance', 'activeEnergy'};
      final signals = <ConnectedHealthSignalView>[
        ...cached.signals.where((signal) => !keys.contains(signal.key)),
        ..._selectRepresentativeSignals(
          activity,
        ).map(ConnectedHealthSignalView.fromSignal),
      ];
      final steps = activity.where((signal) => signal.key == 'steps').toList();
      final stored = await _flows.store.get('connected_health_ui', 'snapshot');
      await _flows.store.put('connected_health_ui', 'snapshot', {
        ...?stored,
        'lastSyncAt': now.toUtc().toIso8601String(),
        'importedCount': cached.importedCount,
        'signals': [
          for (final raw in stored?['signals'] as List<Object?>? ?? const [])
            if (raw is Map && !keys.contains(raw['key'])) raw,
          ..._selectRepresentativeSignals(
            activity,
          ).map((signal) => signal.toMap()),
        ],
        'stepHistory': steps.map((signal) => signal.toMap()).toList(),
      });
      return cached.copyWith(
        status: signals.isEmpty && _isIos
            ? ConnectedHealthStatus.authorizationRequested
            : ConnectedHealthStatus.synchronized,
        signals: signals,
        stepHistory: steps.map(ConnectedHealthSignalView.fromSignal).toList(),
        deviceVerified:
            cached.deviceVerified || activity.any(_isEvidenceFromNativeBridge),
        lastSyncAt: now,
        clearFailure: true,
      );
    } on Object {
      return cached.copyWith(
        status: ConnectedHealthStatus.degraded,
        failureCode: 'daily_activity_refresh_failed_cache_preserved',
      );
    }
  }

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
  Future<ConnectedHealthSnapshot> load() async {
    final source = _source;
    final capability = _capability;
    if (source == null || capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }

    try {
      final availability = _bridge is NativeHealthCapabilityBridge
          ? await (_bridge as NativeHealthCapabilityBridge).availability()
          : const <String, Object?>{'available': true};
      if (availability['available'] != true) {
        final status = availability['status']?.toString();
        return ConnectedHealthSnapshot(
          status: status == '2'
              ? ConnectedHealthStatus.updateRequired
              : ConnectedHealthStatus.unavailable,
          platformSource: source,
          availableSources: const <String>[],
          signals: const <ConnectedHealthSignalView>[],
          importedCount: 0,
          lastSyncAt: null,
          failureCode: 'native_health_unavailable',
          availabilityStatus: status,
        );
      }
      final permissions = await _bridge.permissions();
      final consentState = await _flows.store.get(
        'connected_health_consent',
        source,
      );
      final stored = await _flows.store.get('connected_health_ui', 'snapshot');
      final signals = <ConnectedHealthSignalView>[];
      final stepHistory = <ConnectedHealthSignalView>[];
      final retainedSignalMaps = <Map<String, Object?>>[];
      final retainedStepHistoryMaps = <Map<String, Object?>>[];
      var hasVerifiedNativeEvidence = false;
      var removedLegacyClinicalSignal = false;
      for (final raw in stored?['signals'] as List<Object?>? ?? const []) {
        final signal = GlobalHealthSignal.fromMap(
          Map<String, Object?>.from(raw! as Map),
        );
        // Old preview/foreign-provider cache rows are not HealthKit evidence.
        // Ignore them for this source without deleting the underlying history.
        if (!_isEvidenceFromNativeBridge(signal)) continue;
        if (BilHealthScope.excludesKey(signal.key) ||
            await _isTombstoned(signal)) {
          removedLegacyClinicalSignal = true;
          continue;
        }
        retainedSignalMaps.add(signal.toMap());
        signals.add(ConnectedHealthSignalView.fromSignal(signal));
        hasVerifiedNativeEvidence =
            hasVerifiedNativeEvidence || _isEvidenceFromNativeBridge(signal);
      }
      for (final raw in stored?['stepHistory'] as List<Object?>? ?? const []) {
        if (raw is! Map) continue;
        try {
          final signal = GlobalHealthSignal.fromMap(
            Map<String, Object?>.from(raw),
          );
          if (signal.key != 'steps' ||
              !_isEvidenceFromNativeBridge(signal) ||
              signal.deleted ||
              await _isTombstoned(signal)) {
            continue;
          }
          retainedStepHistoryMaps.add(signal.toMap());
          stepHistory.add(ConnectedHealthSignalView.fromSignal(signal));
          hasVerifiedNativeEvidence = true;
        } on Object {
          // A corrupt projection must not hide the latest valid snapshot.
        }
      }
      if (stepHistory.isEmpty) {
        stepHistory.addAll(signals.where((signal) => signal.key == 'steps'));
      }
      if (removedLegacyClinicalSignal && stored != null) {
        await _flows.store
            .put('connected_health_ui', 'snapshot', <String, Object?>{
              ...stored,
              'signals': retainedSignalMaps,
              'stepHistory': retainedStepHistoryMaps,
              'importedCount': retainedSignalMaps.length,
            });
      }
      final explicitlyRequested = consentState?['readRequested'] == true;
      // HealthKit deliberately does not reveal whether read access was
      // granted or denied. authorizationStatus(for:) reports sharing/write
      // status, so an iOS request must remain indeterminate until records are
      // actually returned. Never present it as granted from that snapshot.
      final granted =
          explicitlyRequested &&
          !_isIos &&
          permissions.values.any((value) => value);
      final lastSyncRaw = stored?['lastSyncAt'] as String?;
      return ConnectedHealthSnapshot(
        status: _isIos && explicitlyRequested
            ? (signals.isNotEmpty || stepHistory.isNotEmpty
                  ? ConnectedHealthStatus.synchronized
                  : ConnectedHealthStatus.authorizationRequested)
            : granted
            ? (lastSyncRaw == null
                  ? ConnectedHealthStatus.ready
                  : ConnectedHealthStatus.synchronized)
            : ConnectedHealthStatus.permissionRequired,
        platformSource: source,
        availableSources: <String>[source],
        signals: signals,
        importedCount: stored?['importedCount'] as int? ?? signals.length,
        lastSyncAt: lastSyncRaw == null
            ? null
            : DateTime.parse(lastSyncRaw).toLocal(),
        failureCode: null,
        availabilityStatus: availability['status']?.toString(),
        deviceVerified: hasVerifiedNativeEvidence,
        stepHistory: List<ConnectedHealthSignalView>.unmodifiable(stepHistory),
      );
    } catch (_) {
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.degraded,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'native_health_status_unavailable',
      );
    }
  }

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async {
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
      final previousConsent = await _flows.store.get(
        'connected_health_consent',
        source,
      );
      await _flows.store
          .put('connected_health_consent', source, <String, Object?>{
            ...?previousConsent,
            'readRequested': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
      // A pre-consent probe can create an empty HealthKit anchor. Reset it
      // after the user completes consent so the first authorized foreground
      // sync reads existing Apple Watch history, not only future changes.
      if (previousConsent?['readRequested'] != true) {
        await _flows.store.remove('health_anchor', _bridge.id);
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
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.degraded,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'health_permission_request_failed',
      );
    }
  }

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async {
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    try {
      await _bridge.request(
        connectedHealthWriteTypeNamesForPlatform(defaultTargetPlatform),
        write: true,
      );
      final current =
          await _flows.store.get('connected_health_consent', source) ??
          <String, Object?>{};
      await _flows.store
          .put('connected_health_consent', source, <String, Object?>{
            ...current,
            'weightWriteRequested': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
      return load();
    } catch (_) {
      final cached = await load();
      return cached.copyWith(failureCode: 'health_write_permission_failed');
    }
  }

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async {
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    try {
      final result = _bridge is NativeHealthCapabilityBridge
          ? await (_bridge as NativeHealthCapabilityBridge).revokeAccess()
          : const <String, Object?>{'revoked': false};
      await _flows.store
          .put('connected_health_consent', source, <String, Object?>{
            'readRequested': false,
            'weightWriteRequested': false,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
      await _flows.store.put(
        'connected_health_ui',
        'snapshot',
        <String, Object?>{
          'importedCount': 0,
          'signals': <Object?>[],
          'stepHistory': <Object?>[],
        },
      );
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
  Future<ConnectedHealthSnapshot> synchronize() async {
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }

    final consentState = await _flows.store.get(
      'connected_health_consent',
      source,
    );
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

    try {
      final now = DateTime.now();
      if (_isIos && consentState?['historicalReadResetAt'] == null) {
        // Older builds could create a HealthKit anchor before the user
        // granted read access. Clear that one-time probe so existing Watch
        // records are included in the first authorized sync.
        await _flows.store.remove('health_anchor', _bridge.id);
        await _flows.store
            .put('connected_health_consent', source, <String, Object?>{
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
          ? await _flows.appleHealth.integration.synchronize(
              asOf: now,
              consent: consent,
              types: connectedHealthReadTypesForPlatform(defaultTargetPlatform),
            )
          : await _flows.healthConnect.integration.synchronize(
              asOf: now,
              consent: consent,
              types: connectedHealthReadTypesForPlatform(defaultTargetPlatform),
            );
      final persistedRows = await _flows.store.list('health_signals');
      final persisted = <GlobalHealthSignal>[];
      for (final row in persistedRows) {
        try {
          final signal = GlobalHealthSignal.fromMap(row);
          if (BilHealthScope.excludesKey(signal.key) ||
              await _isTombstoned(signal)) {
            await _flows.store.remove('health_signals', signal.identity);
            await _flows.store.remove('health_seen', signal.identity);
            continue;
          }
          persisted.add(signal);
        } on Object {
          // A corrupt local row is ignored; valid evidence remains available.
        }
      }
      final normalizedPersisted = aggregateConnectedSleepSignals(persisted);
      final graph = await BilGlobalHealthEvidenceGraphEngine(
        memory: SourceReliabilityMemory(store: _flows.store),
      ).build(normalizedPersisted);
      final ordered = graph.selectedSignals.toList()
        ..sort(
          (a, b) => b.provenance.observedAt.compareTo(a.provenance.observedAt),
        );
      final dailyBridge = _bridge;
      final nativeTotals = dailyBridge is NativeHealthDailyTotalsBridge
          ? nativeDailyActivitySignals(
              await (dailyBridge as NativeHealthDailyTotalsBridge)
                  .readDailyTotals(asOf: now),
              now,
            )
          : null;
      final selected = _selectRepresentativeSignals([
        for (final signal in ordered)
          if (nativeTotals == null ||
              !const {'steps', 'distance', 'activeEnergy'}.contains(signal.key))
            signal,
        ...?nativeTotals,
      ]);
      final stepHistorySignals = nativeTotals == null
          ? aggregateConnectedStepSignals(graph.selectedSignals)
          : nativeTotals.where((signal) => signal.key == 'steps').toList();
      final hasVerifiedNativeEvidence = selected.any(
        _isEvidenceFromNativeBridge,
      );
      await _flows.store
          .put('connected_health_evidence', 'latest', <String, Object?>{
            'selectedIds': graph.nodes
                .where((node) => node.selected)
                .map((node) => node.id)
                .toList(),
            'conflictCount': graph.conflicts.length,
            'confidence': graph.confidence,
            'updatedAt': now.toUtc().toIso8601String(),
          });
      await _flows.store.put(
        'connected_health_ui',
        'snapshot',
        <String, Object?>{
          'lastSyncAt': now.toUtc().toIso8601String(),
          'importedCount': records.length,
          'signals': <Map<String, Object?>>[
            for (final signal in selected) signal.toMap(),
          ],
          'stepHistory': <Map<String, Object?>>[
            for (final signal in stepHistorySignals) signal.toMap(),
          ],
        },
      );
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
      );
    } catch (_) {
      final cached = await load();
      return cached.copyWith(
        status: ConnectedHealthStatus.degraded,
        failureCode: 'health_sync_failed_offline_cache_preserved',
      );
    }
  }
}
