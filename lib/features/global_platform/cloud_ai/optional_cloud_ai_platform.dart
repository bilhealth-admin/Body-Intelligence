import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/global_platform_core.dart';

final class CloudAiRequest {
  const CloudAiRequest({
    required this.id,
    required this.capability,
    required this.redactedPayload,
    required this.maxTokens,
    required this.timeout,
    this.requiredOutputKeys = const <String>{},
  });

  final String id, capability;
  final Map<String, Object?> redactedPayload;
  final int maxTokens;
  final Duration timeout;
  final Set<String> requiredOutputKeys;
}

final class CloudAiResponse {
  const CloudAiResponse({
    required this.providerId,
    required this.modelId,
    required this.output,
    required this.usageTokens,
    required this.provenance,
    required this.safe,
    this.structuredOutput,
  });

  final String providerId, modelId, output, provenance;
  final int usageTokens;
  final bool safe;
  final Map<String, Object?>? structuredOutput;
}

abstract interface class CloudAiProvider {
  String get id;
  Set<String> get capabilities;
  Future<CloudAiResponse> execute(CloudAiRequest request);
}

final class HttpCloudAiProvider implements CloudAiProvider {
  HttpCloudAiProvider({
    required this.id,
    required this.modelId,
    required this.endpoint,
    required this.capabilities,
    required this.tokenProvider,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  @override
  final String id;
  final String modelId;
  final Uri endpoint;
  @override
  final Set<String> capabilities;
  final Future<String?> Function() tokenProvider;
  final HttpClient _client;

  @override
  Future<CloudAiResponse> execute(CloudAiRequest request) async {
    final http = await _client.postUrl(endpoint).timeout(request.timeout);
    final token = await tokenProvider();
    if (token != null) {
      http.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    http.headers.contentType = ContentType.json;
    http.write(
      jsonEncode(<String, Object?>{
        'model': modelId,
        'capability': request.capability,
        'input': request.redactedPayload,
        'maxTokens': request.maxTokens,
        'requiredOutputKeys': request.requiredOutputKeys.toList()..sort(),
      }),
    );
    final response = await http.close().timeout(request.timeout);
    if (response.statusCode == 429) {
      throw StateError('rate-limited');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('cloud-ai-http-${response.statusCode}');
    }
    final body =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, Object?>;
    return CloudAiResponse(
      providerId: id,
      modelId: modelId,
      output: body['output'] as String? ?? '',
      usageTokens: (body['usageTokens'] as num? ?? 0).toInt(),
      provenance: '$id:$modelId:${request.id}',
      safe: body['safe'] == true,
      structuredOutput: body['structuredOutput'] is Map
          ? Map<String, Object?>.from(body['structuredOutput']! as Map)
          : null,
    );
  }
}

final class CloudAiRuntimePolicy {
  const CloudAiRuntimePolicy({
    this.maxAttemptsPerProvider = 2,
    this.circuitFailureThreshold = 3,
    this.maxPayloadDepth = 6,
  });

  final int maxAttemptsPerProvider;
  final int circuitFailureThreshold;
  final int maxPayloadDepth;
}

final class CloudAiRedactor {
  const CloudAiRedactor();

  static const Set<String> sensitiveKeys = <String>{
    'name',
    'email',
    'phone',
    'address',
    'nationalId',
    'medicalRecordNumber',
    'rawImage',
    'accessToken',
    'refreshToken',
  };

  Map<String, Object?> redact(Map<String, Object?> input, {int depth = 0}) {
    if (depth > 6) {
      throw StateError('cloud-ai-payload-too-deep');
    }
    final output = <String, Object?>{};
    for (final entry in input.entries) {
      if (sensitiveKeys.contains(entry.key)) {
        output[entry.key] = '[REDACTED]';
        continue;
      }
      output[entry.key] = _redactValue(entry.value, depth + 1);
    }
    return output;
  }

  Object? _redactValue(Object? value, int depth) {
    if (value is Map) {
      return redact(Map<String, Object?>.from(value), depth: depth);
    }
    if (value is List) {
      return <Object?>[for (final item in value) _redactValue(item, depth + 1)];
    }
    return value;
  }
}

final class OptionalCloudAiRuntime {
  OptionalCloudAiRuntime({
    required this.providers,
    required this.store,
    required this.audit,
    required this.monthlyTokenBudget,
    this.policy = const CloudAiRuntimePolicy(),
    this.redactor = const CloudAiRedactor(),
  });

  final List<CloudAiProvider> providers;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final int monthlyTokenBudget;
  final CloudAiRuntimePolicy policy;
  final CloudAiRedactor redactor;

  Future<CloudAiResponse?> run({
    required CloudAiRequest request,
    required GlobalConsentGrant consent,
    required bool localOnly,
    required DateTime at,
  }) async {
    if (localOnly || !consent.permits) {
      await _auditAbstention(
        request.id,
        at,
        localOnly ? 'local-only' : 'consent',
      );
      return null;
    }
    final existing = await store.get('cloud_ai_idempotency', request.id);
    if (existing != null) {
      return _responseFromMap(existing);
    }
    final month = _month(at);
    final spent =
        ((await store.get('cloud_ai_budget', month))?['tokens'] as num? ?? 0)
            .toInt();
    if (spent + request.maxTokens > monthlyTokenBudget) {
      await _auditAbstention(request.id, at, 'budget');
      return null;
    }
    final sanitized = redactor.redact(request.redactedPayload);
    final safeRequest = CloudAiRequest(
      id: request.id,
      capability: request.capability,
      redactedPayload: sanitized,
      maxTokens: request.maxTokens,
      timeout: request.timeout,
      requiredOutputKeys: request.requiredOutputKeys,
    );
    final candidates =
        providers
            .where(
              (provider) => provider.capabilities.contains(request.capability),
            )
            .toList()
          ..sort(
            (left, right) =>
                asyncScore(right.id).compareTo(asyncScore(left.id)),
          );
    for (final provider in candidates) {
      if (await _circuitOpen(provider.id)) {
        continue;
      }
      for (
        var attempt = 1;
        attempt <= policy.maxAttemptsPerProvider;
        attempt += 1
      ) {
        try {
          final response = await provider.execute(safeRequest);
          if (!_valid(response, request.requiredOutputKeys)) {
            await _recordFailure(provider.id);
            continue;
          }
          await _clearFailures(provider.id);
          await _recordSuccess(provider.id);
          await store.put('cloud_ai_budget', month, <String, Object?>{
            'tokens': spent + response.usageTokens,
          });
          final encoded = _responseToMap(response);
          await store.put('cloud_ai_idempotency', request.id, encoded);
          await audit.record(
            GlobalAuditEvent(
              action: 'cloud_ai.used',
              subjectId: request.id,
              at: at,
              metadata: <String, Object?>{
                'provider': provider.id,
                'tokens': response.usageTokens,
                'capability': request.capability,
                'attempt': attempt,
              },
            ),
          );
          return response;
        } catch (_) {
          await _recordFailure(provider.id);
        }
      }
    }
    await _auditAbstention(request.id, at, 'provider-exhausted');
    return null;
  }

  bool _valid(CloudAiResponse response, Set<String> requiredKeys) {
    if (!response.safe ||
        response.output.trim().isEmpty ||
        response.usageTokens < 0) {
      return false;
    }
    if (requiredKeys.isEmpty) {
      return true;
    }
    final structured = response.structuredOutput;
    return structured != null && requiredKeys.every(structured.containsKey);
  }

  int asyncScore(String providerId) {
    // Stable deterministic base score. Persisted successes/failures are used by
    // circuit breaking; alphabetical tiebreak keeps routing reproducible.
    return 100000 -
        providerId.codeUnits.fold<int>(0, (sum, value) => sum + value);
  }

  Future<bool> _circuitOpen(String providerId) async =>
      ((await store.get('cloud_ai_provider_health', providerId))?['failures']
                  as num? ??
              0)
          .toInt() >=
      policy.circuitFailureThreshold;

  Future<void> _recordFailure(String providerId) async {
    final current = await store.get('cloud_ai_provider_health', providerId);
    await store.put('cloud_ai_provider_health', providerId, <String, Object?>{
      'failures': ((current?['failures'] as num?)?.toInt() ?? 0) + 1,
      'successes': (current?['successes'] as num?)?.toInt() ?? 0,
    });
  }

  Future<void> _recordSuccess(String providerId) async {
    final current = await store.get('cloud_ai_provider_health', providerId);
    await store.put('cloud_ai_provider_health', providerId, <String, Object?>{
      'failures': 0,
      'successes': ((current?['successes'] as num?)?.toInt() ?? 0) + 1,
    });
  }

  Future<void> _clearFailures(String providerId) async {
    final current = await store.get('cloud_ai_provider_health', providerId);
    await store.put('cloud_ai_provider_health', providerId, <String, Object?>{
      'failures': 0,
      'successes': (current?['successes'] as num?)?.toInt() ?? 0,
    });
  }

  Future<void> _auditAbstention(String id, DateTime at, String reason) =>
      audit.record(
        GlobalAuditEvent(
          action: 'cloud_ai.abstained',
          subjectId: id,
          at: at,
          metadata: <String, Object?>{'reason': reason},
        ),
      );

  Map<String, Object?> _responseToMap(CloudAiResponse response) =>
      <String, Object?>{
        'providerId': response.providerId,
        'modelId': response.modelId,
        'output': response.output,
        'usageTokens': response.usageTokens,
        'provenance': response.provenance,
        'safe': response.safe,
        'structuredOutput': response.structuredOutput,
      };

  CloudAiResponse _responseFromMap(Map<String, Object?> map) => CloudAiResponse(
    providerId: map['providerId']! as String,
    modelId: map['modelId']! as String,
    output: map['output']! as String,
    usageTokens: (map['usageTokens']! as num).toInt(),
    provenance: map['provenance']! as String,
    safe: map['safe'] == true,
    structuredOutput: map['structuredOutput'] is Map
        ? Map<String, Object?>.from(map['structuredOutput']! as Map)
        : null,
  );

  String _month(DateTime value) =>
      '${value.toUtc().year}-${value.toUtc().month.toString().padLeft(2, '0')}';
}
