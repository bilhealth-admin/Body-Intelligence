import '../core/global_platform_core.dart';
import 'wearables_platform.dart';

enum WearableVendor { appleWatch, wearOs, samsung, garmin, fitbit }

final class WearableAuthSession {
  WearableAuthSession({
    required this.providerId,
    required this.accessTokenRef,
    required this.refreshTokenRef,
    required DateTime expiresAt,
    required this.revoked,
  }) : expiresAt = expiresAt.toUtc();

  final String providerId;
  final String accessTokenRef;
  final String refreshTokenRef;
  final DateTime expiresAt;
  final bool revoked;
}

abstract interface class WearableCredentialBroker {
  Future<WearableAuthSession?> session(String providerId);
  Future<WearableAuthSession> refresh(WearableAuthSession session);
  Future<void> revoke(String providerId);
}

abstract interface class WearableRemoteApi {
  Future<Map<String, Object?>> fetch({
    required WearableVendor vendor,
    required String accessTokenRef,
    required String? cursor,
    required DateTime asOf,
  });
}

final class WearableProviderPolicy {
  const WearableProviderPolicy({
    required this.vendor,
    required this.priority,
    required this.maxAttempts,
    required this.minimumRateLimitRemaining,
    required this.mapping,
  });

  final WearableVendor vendor;
  final int priority;
  final int maxAttempts;
  final int minimumRateLimitRemaining;
  final Map<String, String> mapping;

  static WearableProviderPolicy forVendor(WearableVendor vendor) =>
      switch (vendor) {
        WearableVendor.appleWatch => const WearableProviderPolicy(
          vendor: WearableVendor.appleWatch,
          priority: 100,
          maxAttempts: 2,
          minimumRateLimitRemaining: 1,
          mapping: <String, String>{'calories': 'active_energy'},
        ),
        WearableVendor.wearOs => const WearableProviderPolicy(
          vendor: WearableVendor.wearOs,
          priority: 90,
          maxAttempts: 3,
          minimumRateLimitRemaining: 2,
          mapping: <String, String>{'calories': 'active_energy'},
        ),
        WearableVendor.samsung => const WearableProviderPolicy(
          vendor: WearableVendor.samsung,
          priority: 85,
          maxAttempts: 3,
          minimumRateLimitRemaining: 2,
          mapping: <String, String>{'blood_oxygen': 'oxygen'},
        ),
        WearableVendor.garmin => const WearableProviderPolicy(
          vendor: WearableVendor.garmin,
          priority: 80,
          maxAttempts: 4,
          minimumRateLimitRemaining: 5,
          mapping: <String, String>{'body_battery': 'recovery_score'},
        ),
        WearableVendor.fitbit => const WearableProviderPolicy(
          vendor: WearableVendor.fitbit,
          priority: 75,
          maxAttempts: 4,
          minimumRateLimitRemaining: 5,
          mapping: <String, String>{'minutes_fairly_active': 'active_minutes'},
        ),
      };
}

final class ProviderWearableAdapter implements WearableProvider {
  ProviderWearableAdapter({
    required this.vendor,
    required this.credentials,
    required this.api,
    required this.store,
    required this.audit,
    WearableProviderPolicy? policy,
  }) : policy = policy ?? WearableProviderPolicy.forVendor(vendor);

  final WearableVendor vendor;
  final WearableCredentialBroker credentials;
  final WearableRemoteApi api;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final WearableProviderPolicy policy;

  @override
  String get id => vendor.name;

  @override
  Future<Set<String>> capabilities() async => switch (vendor) {
    WearableVendor.appleWatch => <String>{
      'steps',
      'active_energy',
      'workout',
      'sleep',
      'heart_rate',
      'hrv',
      'oxygen',
    },
    WearableVendor.wearOs => <String>{
      'steps',
      'active_energy',
      'workout',
      'sleep',
      'heart_rate',
    },
    WearableVendor.samsung => <String>{
      'steps',
      'active_energy',
      'workout',
      'sleep',
      'heart_rate',
      'oxygen',
    },
    WearableVendor.garmin => <String>{
      'steps',
      'active_energy',
      'workout',
      'sleep',
      'heart_rate',
      'hrv',
      'oxygen',
      'respiratory_rate',
      'recovery_score',
    },
    WearableVendor.fitbit => <String>{
      'steps',
      'active_energy',
      'workout',
      'sleep',
      'heart_rate',
      'hrv',
      'oxygen',
      'active_minutes',
    },
  };

  @override
  Future<WearableSyncBatch> pull({
    required String? cursor,
    required DateTime asOf,
  }) async {
    final storedCursor = await store.get('wearable_cursor', id);
    final effectiveCursor = cursor ?? storedCursor?['value'] as String?;
    var session = await credentials.session(id);
    if (session == null || session.revoked) {
      throw StateError('wearable_auth_required:$id');
    }
    if (!session.expiresAt.isAfter(asOf.toUtc())) {
      session = await credentials.refresh(session);
    }

    Object? lastError;
    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      try {
        final raw = await api.fetch(
          vendor: vendor,
          accessTokenRef: session.accessTokenRef,
          cursor: effectiveCursor,
          asOf: asOf,
        );
        final remaining = (raw['rateLimitRemaining'] as num?)?.toInt();
        if (remaining != null && remaining < policy.minimumRateLimitRemaining) {
          throw StateError('wearable_rate_limited:$id:$remaining');
        }

        final signals = <GlobalHealthSignal>[];
        for (final item
            in raw['records'] as List<Object?>? ?? const <Object?>[]) {
          final row = Map<String, Object?>.from(item! as Map);
          final recordId = (row['recordId'] ?? row['id']) as String;
          final dedupKey = '$id:$recordId';
          if (await store.get('wearable_record_seen', dedupKey) != null) {
            continue;
          }
          final normalized = _normalize(row);
          final signal = GlobalHealthSignal.fromMap(<String, Object?>{
            ...normalized,
            'providerId': id,
            'sourceId': row['sourceId'] as String? ?? id,
            'recordId': recordId,
            'observedAt': row['observedAt'] as String,
            'confidence': (row['confidence'] as num? ?? .85).toDouble(),
            'deviceId': row['deviceId'] as String?,
            'timeZoneId': row['timeZoneId'] as String? ?? 'UTC',
            'attributes': <String, Object?>{'sourcePriority': policy.priority},
          });
          await store.put('wearable_record_seen', dedupKey, <String, Object?>{
            'observedAt': signal.provenance.observedAt.toIso8601String(),
            'attributes': <String, Object?>{'sourcePriority': policy.priority},
          });
          signals.add(signal);
        }

        for (final deletedId in List<String>.from(
          raw['deletedIds'] as List<Object?>? ?? const <Object?>[],
        )) {
          await store
              .put('wearable_tombstones', '$id:$deletedId', <String, Object?>{
                'providerId': id,
                'recordId': deletedId,
                'deletedAt': asOf.toUtc().toIso8601String(),
              });
          await store.remove('wearable_record_seen', '$id:$deletedId');
        }

        final nextCursor = raw['nextCursor'] as String?;
        if (nextCursor != null) {
          await store.put('wearable_cursor', id, <String, Object?>{
            'value': nextCursor,
            'updatedAt': asOf.toUtc().toIso8601String(),
          });
        }
        await store.put('wearable_provider_health', id, <String, Object?>{
          'lastSuccessAt': asOf.toUtc().toIso8601String(),
          'records': signals.length,
          'rateLimitRemaining': remaining,
          'attempt': attempt,
        });
        await audit.record(
          GlobalAuditEvent(
            action: 'wearable.sync.success',
            subjectId: id,
            at: asOf,
            metadata: <String, Object?>{
              'records': signals.length,
              'attempt': attempt,
            },
          ),
        );
        return WearableSyncBatch(
          signals: signals,
          deletedIds: List<String>.from(
            raw['deletedIds'] as List<Object?>? ?? const <Object?>[],
          ),
          nextCursor: nextCursor,
          hasMore: raw['hasMore'] == true,
        );
      } catch (error) {
        lastError = error;
        await store.put('wearable_provider_health', id, <String, Object?>{
          'lastFailureAt': asOf.toUtc().toIso8601String(),
          'error': error.runtimeType.toString(),
          'attempt': attempt,
          'retryable': attempt < policy.maxAttempts,
        });
        if (attempt < policy.maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 30 * attempt));
        }
      }
    }
    await audit.record(
      GlobalAuditEvent(
        action: 'wearable.sync.failed',
        subjectId: id,
        at: asOf,
        metadata: <String, Object?>{'error': lastError.runtimeType.toString()},
      ),
    );
    throw StateError('wearable_sync_failed:$id:${lastError.runtimeType}');
  }

  Map<String, Object?> _normalize(Map<String, Object?> row) {
    final rawKind = (row['kind'] ?? row['type']) as String;
    final kind = policy.mapping[rawKind] ?? rawKind;
    final value = (row['value'] as num).toDouble();
    final unit = row['unit'] as String;
    if (kind == 'distance' && unit == 'miles') {
      return <String, Object?>{
        'key': 'distance',
        'canonicalValue': value * 1.609344,
        'canonicalUnit': 'km',
      };
    }
    if (kind == 'weight' && unit == 'lb') {
      return <String, Object?>{
        'key': 'weight',
        'canonicalValue': value * 0.45359237,
        'canonicalUnit': 'kg',
      };
    }
    return <String, Object?>{
      'key': kind,
      'canonicalValue': value,
      'canonicalUnit': unit,
    };
  }

  @override
  Future<void> revoke() async {
    await credentials.revoke(id);
    await store.remove('wearable_cursor', id);
    await store.remove('wearable_provider_health', id);
    await audit.record(
      GlobalAuditEvent(
        action: 'wearable.revoked',
        subjectId: id,
        at: DateTime.now().toUtc(),
      ),
    );
  }
}

final class NativeWearableCredentialBroker implements WearableCredentialBroker {
  const NativeWearableCredentialBroker();

  @override
  Future<WearableAuthSession?> session(String providerId) async =>
      WearableAuthSession(
        providerId: providerId,
        accessTokenRef: 'native-platform-session',
        refreshTokenRef: 'native-platform-session',
        expiresAt: DateTime.utc(9999, 12, 31),
        revoked: false,
      );

  @override
  Future<WearableAuthSession> refresh(WearableAuthSession session) async =>
      session;

  @override
  Future<void> revoke(String providerId) async {}
}

final class WearableProviderCatalog {
  static List<ProviderWearableAdapter> production({
    required WearableCredentialBroker credentials,
    required WearableRemoteApi api,
    required GlobalDurableStore store,
    required GlobalAuditSink audit,
  }) => <ProviderWearableAdapter>[
    for (final vendor in <WearableVendor>[
      WearableVendor.appleWatch,
      WearableVendor.wearOs,
      WearableVendor.garmin,
      WearableVendor.fitbit,
    ])
      ProviderWearableAdapter(
        vendor: vendor,
        credentials: credentials,
        api: api,
        store: store,
        audit: audit,
      ),
  ];
}
