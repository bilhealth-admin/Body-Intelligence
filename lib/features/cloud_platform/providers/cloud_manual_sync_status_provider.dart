import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../services/cloud_manual_sync_service.dart';
import 'cloud_sync_providers.dart';

const cloudLastSuccessfulSyncPreferenceKey = 'cloud.lastSuccessfulSyncAtUtc';

String cloudLastSuccessfulSyncPreferenceKeyFor(String ownerId) =>
    '$cloudLastSuccessfulSyncPreferenceKey.$ownerId';

enum CloudManualSyncPhase { loading, never, idle, syncing, unavailable }

final class CloudManualSyncStatus {
  const CloudManualSyncStatus({required this.phase, this.lastSuccessfulSyncAt});

  const CloudManualSyncStatus.loading()
    : phase = CloudManualSyncPhase.loading,
      lastSuccessfulSyncAt = null;

  final CloudManualSyncPhase phase;
  final DateTime? lastSuccessfulSyncAt;

  bool get isSyncing => phase == CloudManualSyncPhase.syncing;
}

/// The one source of truth for manual cloud-sync presentation state.
///
/// A timestamp is persisted only when [CloudManualSyncService] returns the
/// real successful [CloudSyncReport.completedAt]. Failed attempts never write
/// or invent a time. The same state drives both More and Sharing & Privacy.
final cloudManualSyncStatusProvider =
    StateNotifierProvider.autoDispose<
      CloudManualSyncStatusController,
      CloudManualSyncStatus
    >((ref) {
      final ownerId = _activeCloudOwnerId();
      final controller = CloudManualSyncStatusController(
        preferences: ref.watch(preferencesRepositoryProvider),
        runSync: () => ref.read(cloudManualSyncServiceProvider).runOnce(),
        cloudAvailable: AppEnvironment.supabaseRuntimeReady && ownerId != null,
        ownerId: ownerId,
      );
      unawaited(controller.hydrate());
      return controller;
    });

String? _activeCloudOwnerId() {
  if (!AppEnvironment.supabaseRuntimeReady) return null;
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } on Object {
    return null;
  }
}

final class CloudManualSyncStatusController
    extends StateNotifier<CloudManualSyncStatus> {
  CloudManualSyncStatusController({
    required PreferencesRepository preferences,
    required Future<CloudManualSyncResult> Function() runSync,
    required bool cloudAvailable,
    required String? ownerId,
  }) : this._(preferences, runSync, cloudAvailable, ownerId);

  CloudManualSyncStatusController._(
    this._preferences,
    this._runSync,
    this._cloudAvailable,
    this._ownerId,
  ) : super(const CloudManualSyncStatus.loading());

  final PreferencesRepository _preferences;
  final Future<CloudManualSyncResult> Function() _runSync;
  final bool _cloudAvailable;
  final String? _ownerId;
  Future<void>? _hydration;

  Future<void> hydrate() => _hydration ??= _hydrate();

  Future<void> _hydrate() async {
    try {
      final ownerId = _ownerId;
      if (!_cloudAvailable || ownerId == null) {
        if (mounted) {
          state = const CloudManualSyncStatus(
            phase: CloudManualSyncPhase.unavailable,
          );
        }
        return;
      }
      final raw = await _preferences.get(
        cloudLastSuccessfulSyncPreferenceKeyFor(ownerId),
      );
      final parsed = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
      if (mounted) {
        state = CloudManualSyncStatus(
          phase: parsed == null
              ? CloudManualSyncPhase.never
              : CloudManualSyncPhase.idle,
          lastSuccessfulSyncAt: parsed,
        );
      }
    } on Object {
      if (mounted) {
        state = const CloudManualSyncStatus(
          phase: CloudManualSyncPhase.unavailable,
        );
      }
    }
  }

  Future<CloudManualSyncResult> runOnce() async {
    await hydrate();
    if (!mounted) {
      return const CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.unavailable,
      );
    }
    if (state.isSyncing) {
      return CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.unavailable,
        completedAt: null,
      );
    }
    final previous = state.lastSuccessfulSyncAt;
    state = CloudManualSyncStatus(
      phase: CloudManualSyncPhase.syncing,
      lastSuccessfulSyncAt: previous,
    );
    try {
      final result = await _runSync();
      final completedAt = result.completedAt?.toUtc();
      final ownerId = _ownerId;
      if (result.completed &&
          completedAt != null &&
          ownerId != null &&
          result.ownerId == ownerId) {
        await _preferences.set(
          cloudLastSuccessfulSyncPreferenceKeyFor(ownerId),
          completedAt.toIso8601String(),
        );
        if (mounted) {
          state = CloudManualSyncStatus(
            phase: CloudManualSyncPhase.idle,
            lastSuccessfulSyncAt: completedAt,
          );
        }
      } else {
        if (mounted) {
          state = CloudManualSyncStatus(
            phase: CloudManualSyncPhase.unavailable,
            lastSuccessfulSyncAt: previous,
          );
        }
      }
      return result;
    } on Object {
      if (mounted) {
        state = CloudManualSyncStatus(
          phase: CloudManualSyncPhase.unavailable,
          lastSuccessfulSyncAt: previous,
        );
      }
      rethrow;
    }
  }
}
