import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/global_platform_core.dart';

enum VisionJobKind { meal, label, healthDocument }

enum VisionJobStatus {
  queued,
  running,
  reviewRequired,
  accepted,
  rejected,
  failed,
  deleted,
}

final class VisionFinding {
  const VisionFinding({
    required this.key,
    required this.value,
    required this.confidence,
    required this.provenance,
    this.rangeMin,
    this.rangeMax,
    this.page,
  });

  final String key, value, provenance;
  final double confidence;
  final double? rangeMin, rangeMax;
  final int? page;

  Map<String, Object?> toMap() => <String, Object?>{
    'key': key,
    'value': value,
    'confidence': confidence,
    'provenance': provenance,
    'rangeMin': rangeMin,
    'rangeMax': rangeMax,
    'page': page,
  };

  static VisionFinding fromMap(Map<String, Object?> map) => VisionFinding(
    key: map['key']! as String,
    value: map['value']! as String,
    confidence: (map['confidence']! as num).toDouble(),
    provenance: map['provenance']! as String,
    rangeMin: (map['rangeMin'] as num?)?.toDouble(),
    rangeMax: (map['rangeMax'] as num?)?.toDouble(),
    page: (map['page'] as num?)?.toInt(),
  );
}

final class VisionJob {
  VisionJob({
    required this.id,
    required this.kind,
    required this.status,
    required this.findings,
    required DateTime updatedAt,
    required this.attempts,
    required this.providerId,
    this.failureCode,
  }) : updatedAt = updatedAt.toUtc();

  final String id;
  final VisionJobKind kind;
  final VisionJobStatus status;
  final List<VisionFinding> findings;
  final DateTime updatedAt;
  final int attempts;
  final String providerId;
  final String? failureCode;
}

abstract interface class VisionProvider {
  String get id;
  Set<VisionJobKind> get capabilities;
  Future<List<VisionFinding>> analyze(
    VisionJobKind kind,
    List<int> bytes, {
    required String locale,
  });
}

final class HttpVisionProvider implements VisionProvider {
  HttpVisionProvider({
    required this.id,
    required this.endpoint,
    required this.tokenProvider,
    required this.capabilities,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  @override
  final String id;
  final Uri endpoint;
  final Future<String?> Function() tokenProvider;
  @override
  final Set<VisionJobKind> capabilities;
  final HttpClient _client;

  @override
  Future<List<VisionFinding>> analyze(
    VisionJobKind kind,
    List<int> bytes, {
    required String locale,
  }) async {
    if (!capabilities.contains(kind)) {
      throw StateError('provider-capability-mismatch');
    }
    final request = await _client.postUrl(endpoint);
    final token = await tokenProvider();
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, Object?>{
        'kind': kind.name,
        'locale': locale,
        'imageBase64': base64Encode(bytes),
      }),
    );
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('vision-http-${response.statusCode}');
    }
    final decoded =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, Object?>;
    return <VisionFinding>[
      for (final raw
          in decoded['findings'] as List<Object?>? ?? const <Object?>[])
        VisionFinding.fromMap(<String, Object?>{
          ...Map<String, Object?>.from(raw! as Map),
          'provenance': '$id:${(raw as Map)['fieldId'] ?? raw['key']}',
        }),
    ];
  }
}

final class VisionRuntimePolicy {
  const VisionRuntimePolicy({
    this.maxAttempts = 3,
    this.reviewThreshold = .82,
    this.minimumFindingConfidence = .35,
    this.circuitFailureThreshold = 3,
  });

  final int maxAttempts;
  final double reviewThreshold;
  final double minimumFindingConfidence;
  final int circuitFailureThreshold;
}

final class VisionRuntime {
  VisionRuntime({
    VisionProvider? provider,
    List<VisionProvider>? providers,
    required this.store,
    GlobalAuditSink? audit,
    this.policy = const VisionRuntimePolicy(),
  }) : providers = List<VisionProvider>.unmodifiable(
         providers ??
             (provider == null
                 ? const <VisionProvider>[]
                 : <VisionProvider>[provider]),
       ),
       audit = audit ?? InMemoryGlobalAuditSink();

  final List<VisionProvider> providers;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final VisionRuntimePolicy policy;

  Future<VisionJob> submit({
    required String id,
    required VisionJobKind kind,
    required List<int> bytes,
    required DateTime at,
    required GlobalConsentGrant consent,
    String locale = 'en',
  }) async {
    if (!consent.permits) {
      throw StateError('vision-consent-required');
    }
    if (bytes.isEmpty) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'image/document bytes are required',
      );
    }
    final existing = await store.get('vision_jobs', id);
    if (existing != null && existing['status'] != VisionJobStatus.failed.name) {
      throw StateError('duplicate-vision-job');
    }
    await _persist(
      id: id,
      kind: kind,
      status: VisionJobStatus.queued,
      findings: const <VisionFinding>[],
      providerId: '',
      attempts: 0,
      at: at,
    );
    return _execute(id: id, kind: kind, bytes: bytes, at: at, locale: locale);
  }

  Future<VisionJob> _execute({
    required String id,
    required VisionJobKind kind,
    required List<int> bytes,
    required DateTime at,
    required String locale,
  }) async {
    final candidates = providers.where(
      (provider) => provider.capabilities.contains(kind),
    );
    Object? lastError;
    var attempt = 0;
    for (final provider in candidates) {
      if (await _circuitOpen(provider.id)) {
        continue;
      }
      while (attempt < policy.maxAttempts) {
        attempt += 1;
        await _persist(
          id: id,
          kind: kind,
          status: VisionJobStatus.running,
          findings: const <VisionFinding>[],
          providerId: provider.id,
          attempts: attempt,
          at: at,
        );
        try {
          final raw = await provider.analyze(kind, bytes, locale: locale);
          final findings = _validate(kind, raw);
          final status =
              findings.isEmpty ||
                  findings.any(
                    (finding) => finding.confidence < policy.reviewThreshold,
                  )
              ? VisionJobStatus.reviewRequired
              : VisionJobStatus.accepted;
          await _clearFailures(provider.id);
          await _persist(
            id: id,
            kind: kind,
            status: status,
            findings: findings,
            providerId: provider.id,
            attempts: attempt,
            at: at,
          );
          await audit.record(
            GlobalAuditEvent(
              action: 'vision.completed',
              subjectId: id,
              at: at,
              metadata: <String, Object?>{
                'status': status.name,
                'count': findings.length,
                'provider': provider.id,
                'attempts': attempt,
              },
            ),
          );
          return VisionJob(
            id: id,
            kind: kind,
            status: status,
            findings: findings,
            updatedAt: at,
            attempts: attempt,
            providerId: provider.id,
          );
        } catch (error) {
          lastError = error;
          await _recordFailure(provider.id);
        }
      }
    }
    final failureCode =
        lastError?.runtimeType.toString() ?? 'no-capable-provider';
    await _persist(
      id: id,
      kind: kind,
      status: VisionJobStatus.failed,
      findings: const <VisionFinding>[],
      providerId: '',
      attempts: attempt,
      at: at,
      failureCode: failureCode,
    );
    return VisionJob(
      id: id,
      kind: kind,
      status: VisionJobStatus.failed,
      findings: const <VisionFinding>[],
      updatedAt: at,
      attempts: attempt,
      providerId: '',
      failureCode: failureCode,
    );
  }

  List<VisionFinding> _validate(
    VisionJobKind kind,
    List<VisionFinding> findings,
  ) {
    final result = <VisionFinding>[];
    final identities = <String>{};
    for (final finding in findings) {
      if (!finding.confidence.isFinite ||
          finding.confidence < policy.minimumFindingConfidence ||
          finding.confidence > 1 ||
          finding.key.trim().isEmpty ||
          finding.value.trim().isEmpty ||
          !identities.add(
            '${finding.key}:${finding.value}:${finding.page ?? 0}',
          )) {
        continue;
      }
      if (kind == VisionJobKind.meal &&
          finding.rangeMin != null &&
          finding.rangeMax != null &&
          finding.rangeMin! > finding.rangeMax!) {
        continue;
      }
      result.add(finding);
    }
    return List<VisionFinding>.unmodifiable(result);
  }

  Future<void> review({
    required String id,
    required bool accept,
    required Map<String, String> corrections,
    required DateTime at,
  }) async {
    final existing = await store.get('vision_jobs', id);
    if (existing == null) {
      throw StateError('unknown-vision-job');
    }
    await store.put('vision_feedback', id, <String, Object?>{
      'accepted': accept,
      'corrections': corrections,
      'at': at.toUtc().toIso8601String(),
    });
    await store.put('vision_jobs', id, <String, Object?>{
      ...existing,
      'status': accept
          ? VisionJobStatus.accepted.name
          : VisionJobStatus.rejected.name,
      'updatedAt': at.toUtc().toIso8601String(),
    });
    await audit.record(
      GlobalAuditEvent(
        action: 'vision.reviewed',
        subjectId: id,
        at: at,
        metadata: <String, Object?>{
          'accepted': accept,
          'correctionCount': corrections.length,
        },
      ),
    );
  }

  Future<List<VisionJob>> pending() async => <VisionJob>[
    for (final map in await store.list('vision_jobs'))
      if (map['status'] == VisionJobStatus.queued.name ||
          map['status'] == VisionJobStatus.running.name ||
          map['status'] == VisionJobStatus.failed.name)
        _fromMap(map),
  ];

  Future<void> delete(String id, {DateTime? at}) async {
    await store.remove('vision_jobs', id);
    await store.remove('vision_feedback', id);
    await audit.record(
      GlobalAuditEvent(
        action: 'vision.deleted',
        subjectId: id,
        at: at ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> withdrawConsent() async {
    await store.clear('vision_jobs');
    await store.clear('vision_feedback');
  }

  Future<void> _persist({
    required String id,
    required VisionJobKind kind,
    required VisionJobStatus status,
    required List<VisionFinding> findings,
    required String providerId,
    required int attempts,
    required DateTime at,
    String? failureCode,
  }) => store.put('vision_jobs', id, <String, Object?>{
    'id': id,
    'kind': kind.name,
    'status': status.name,
    'findings': <Map<String, Object?>>[
      for (final finding in findings) finding.toMap(),
    ],
    'providerId': providerId,
    'attempts': attempts,
    'failureCode': failureCode,
    'updatedAt': at.toUtc().toIso8601String(),
  });

  VisionJob _fromMap(Map<String, Object?> map) => VisionJob(
    id: map['id']! as String,
    kind: VisionJobKind.values.byName(map['kind']! as String),
    status: VisionJobStatus.values.byName(map['status']! as String),
    findings: <VisionFinding>[
      for (final item in map['findings'] as List<Object?>? ?? const <Object?>[])
        VisionFinding.fromMap(Map<String, Object?>.from(item! as Map)),
    ],
    updatedAt: DateTime.parse(map['updatedAt']! as String),
    attempts: (map['attempts'] as num? ?? 0).toInt(),
    providerId: map['providerId'] as String? ?? '',
    failureCode: map['failureCode'] as String?,
  );

  Future<bool> _circuitOpen(String providerId) async =>
      ((await store.get('vision_provider_health', providerId))?['failures']
                  as num? ??
              0)
          .toInt() >=
      policy.circuitFailureThreshold;

  Future<void> _recordFailure(String providerId) async {
    final current = await store.get('vision_provider_health', providerId);
    await store.put('vision_provider_health', providerId, <String, Object?>{
      'failures': ((current?['failures'] as num?)?.toInt() ?? 0) + 1,
    });
  }

  Future<void> _clearFailures(String providerId) => store.put(
    'vision_provider_health',
    providerId,
    <String, Object?>{'failures': 0},
  );
}
