import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum GlobalModule {
  appleHealth,
  healthConnect,
  wearables,
  medicalDevices,
  vision,
  cloudAi,
  plugins,
  reports,
  professional,
  commerce,
  globalization,
}

enum GlobalConsentState { unknown, denied, granted, withdrawn }

enum GlobalRuntimeStatus { ready, offline, degraded, consentRequired, blocked }

enum GlobalFailureKind {
  unavailable,
  unauthorized,
  timeout,
  invalidData,
  incompatible,
  revoked,
  exhausted,
}

final class GlobalConsentGrant {
  GlobalConsentGrant({
    required this.scope,
    required this.state,
    required DateTime updatedAt,
  }) : updatedAt = updatedAt.toUtc();
  final String scope;
  final GlobalConsentState state;
  final DateTime updatedAt;
  bool get permits => state == GlobalConsentState.granted;
}

final class GlobalFailure {
  const GlobalFailure({
    required this.module,
    required this.kind,
    required this.code,
    required this.retryable,
  });
  final GlobalModule module;
  final GlobalFailureKind kind;
  final String code;
  final bool retryable;
}

final class GlobalProvenance {
  GlobalProvenance({
    required this.providerId,
    required this.sourceId,
    required this.recordId,
    required DateTime observedAt,
    required this.confidence,
    this.deviceId,
    this.timeZoneId = 'UTC',
  }) : observedAt = observedAt.toUtc();
  final String providerId, sourceId, recordId, timeZoneId;
  final String? deviceId;
  final DateTime observedAt;
  final double confidence;

  Map<String, Object?> toMap() => <String, Object?>{
    'providerId': providerId,
    'sourceId': sourceId,
    'recordId': recordId,
    'observedAt': observedAt.toIso8601String(),
    'confidence': confidence,
    'deviceId': deviceId,
    'timeZoneId': timeZoneId,
  };
}

final class GlobalHealthSignal {
  GlobalHealthSignal({
    required this.key,
    required this.canonicalValue,
    required this.canonicalUnit,
    required this.provenance,
    this.deleted = false,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) : attributes = UnmodifiableMapView<String, Object?>(
         Map<String, Object?>.of(attributes),
       );
  factory GlobalHealthSignal.fromMap(Map<String, Object?> map) =>
      GlobalHealthSignal(
        key: map['key']! as String,
        canonicalValue: (map['canonicalValue']! as num).toDouble(),
        canonicalUnit: map['canonicalUnit']! as String,
        deleted: map['deleted'] == true,
        attributes: Map<String, Object?>.from(
          map['attributes'] as Map? ?? const <String, Object?>{},
        ),
        provenance: GlobalProvenance(
          providerId: map['providerId']! as String,
          sourceId: map['sourceId']! as String,
          recordId: map['recordId']! as String,
          observedAt: DateTime.parse(map['observedAt']! as String),
          confidence: (map['confidence']! as num).toDouble(),
          deviceId: map['deviceId'] as String?,
          timeZoneId: map['timeZoneId'] as String? ?? 'UTC',
        ),
      );
  final String key, canonicalUnit;
  final double canonicalValue;
  final GlobalProvenance provenance;
  final bool deleted;
  final Map<String, Object?> attributes;
  String get identity => '${provenance.providerId}:${provenance.recordId}:$key';
  Map<String, Object?> toMap() => <String, Object?>{
    'key': key,
    'canonicalValue': canonicalValue,
    'canonicalUnit': canonicalUnit,
    'deleted': deleted,
    'attributes': attributes,
    ...provenance.toMap(),
  };
}

final class GlobalAuditEvent {
  GlobalAuditEvent({
    required this.action,
    required this.subjectId,
    required DateTime at,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : at = at.toUtc(),
       metadata = UnmodifiableMapView<String, Object?>(
         Map<String, Object?>.of(metadata),
       );
  final String action, subjectId;
  final DateTime at;
  final Map<String, Object?> metadata;
}

abstract interface class GlobalDurableStore {
  Future<void> put(String bucket, String key, Map<String, Object?> value);
  Future<Map<String, Object?>?> get(String bucket, String key);
  Future<List<Map<String, Object?>>> list(String bucket);
  Future<void> remove(String bucket, String key);
  Future<void> clear(String bucket);
}

abstract interface class GlobalAuditSink {
  Future<void> record(GlobalAuditEvent event);
}

final class InMemoryGlobalStore implements GlobalDurableStore {
  final Map<String, Map<String, Map<String, Object?>>> _data =
      <String, Map<String, Map<String, Object?>>>{};
  @override
  Future<void> put(
    String bucket,
    String key,
    Map<String, Object?> value,
  ) async => (_data[bucket] ??= <String, Map<String, Object?>>{})[key] =
      Map<String, Object?>.of(value);
  @override
  Future<Map<String, Object?>?> get(String bucket, String key) async {
    final value = _data[bucket]?[key];
    return value == null ? null : Map<String, Object?>.of(value);
  }

  @override
  Future<List<Map<String, Object?>>> list(String bucket) async => [
    for (final value
        in (_data[bucket] ?? const <String, Map<String, Object?>>{}).values)
      Map<String, Object?>.of(value),
  ];
  @override
  Future<void> remove(String bucket, String key) async =>
      _data[bucket]?.remove(key);
  @override
  Future<void> clear(String bucket) async => _data.remove(bucket);
}

final class InMemoryGlobalAuditSink implements GlobalAuditSink {
  final List<GlobalAuditEvent> events = <GlobalAuditEvent>[];
  @override
  Future<void> record(GlobalAuditEvent event) async => events.add(event);
}

final class SecureFingerprint {
  static String ofBytes(List<int> bytes) => sha256.convert(bytes).toString();
  static String ofText(String value) => ofBytes(utf8.encode(value));
}

final class GlobalBinaryArtifact {
  const GlobalBinaryArtifact({
    required this.mimeType,
    required this.fileName,
    required this.bytes,
  });
  final String mimeType, fileName;
  final Uint8List bytes;
}
