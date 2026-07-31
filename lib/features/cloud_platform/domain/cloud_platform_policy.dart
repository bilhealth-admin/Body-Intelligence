import 'dart:collection';

import 'cloud_sync_models.dart';

final class CloudSelectiveSyncPolicy {
  CloudSelectiveSyncPolicy({
    required Iterable<CloudEntityKind> enabledKinds,
    this.includeAiData = false,
    this.includeCoachData = false,
    this.includeCommunityData = false,
    this.includeFiles = false,
  }) : enabledKinds = UnmodifiableSetView(Set.of(enabledKinds));

  final Set<CloudEntityKind> enabledKinds;
  final bool includeAiData;
  final bool includeCoachData;
  final bool includeCommunityData;
  final bool includeFiles;

  bool allows(CloudEntityKind kind) {
    if (!enabledKinds.contains(kind)) return false;
    if (kind == CloudEntityKind.intelligenceOutput ||
        kind == CloudEntityKind.decisionMemory) {
      return includeAiData;
    }
    if (kind == CloudEntityKind.coach) return includeCoachData;
    if (kind == CloudEntityKind.community) return includeCommunityData;
    if (kind == CloudEntityKind.file) return includeFiles;
    return true;
  }
}

final class CloudPrivacyConsent {
  CloudPrivacyConsent({
    required this.ownerId,
    required this.policy,
    required DateTime grantedAt,
    DateTime? revokedAt,
    this.policyVersion = 1,
  }) : grantedAt = grantedAt.toUtc(),
       revokedAt = revokedAt?.toUtc(),
       assert(ownerId != ''),
       assert(policyVersion > 0);

  final String ownerId;
  final CloudSelectiveSyncPolicy policy;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final int policyVersion;

  bool get isActive => revokedAt == null;
}

final class CloudRetryPolicy {
  const CloudRetryPolicy({
    this.initialDelay = const Duration(seconds: 2),
    this.maximumDelay = const Duration(minutes: 15),
    this.maximumAttempts = 8,
  }) : assert(maximumAttempts > 0);

  final Duration initialDelay;
  final Duration maximumDelay;
  final int maximumAttempts;

  bool get hasValidDurations =>
      !initialDelay.isNegative && !maximumDelay.isNegative;

  void validate() {
    if (!hasValidDurations) {
      throw ArgumentError('Cloud retry delays must not be negative.');
    }
  }

  Duration delayForAttempt(int attempt) {
    validate();
    if (attempt <= 0) return Duration.zero;
    final multiplier = 1 << (attempt - 1).clamp(0, 20);
    final calculated = initialDelay * multiplier;
    return calculated > maximumDelay ? maximumDelay : calculated;
  }
}

final class CloudPlatformPolicy {
  const CloudPlatformPolicy({
    this.retry = const CloudRetryPolicy(),
    this.maxBatchSize = 100,
    this.tombstoneRetention = const Duration(days: 90),
    this.requireEncryption = true,
    this.localDatabaseRemainsAuthoritative = true,
  }) : assert(maxBatchSize > 0);

  final CloudRetryPolicy retry;
  final int maxBatchSize;
  final Duration tombstoneRetention;
  final bool requireEncryption;
  final bool localDatabaseRemainsAuthoritative;

  bool get hasValidRetention => !tombstoneRetention.isNegative;

  void validate() {
    retry.validate();
    if (!hasValidRetention) {
      throw ArgumentError('Cloud tombstone retention must not be negative.');
    }
  }
}
