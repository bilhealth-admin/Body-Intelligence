import 'dart:convert';
import 'dart:typed_data';
import 'provider_wearable_adapters.dart';

final class WearableHttpResponse {
  const WearableHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;
}

abstract interface class WearableHttpTransport {
  Future<WearableHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  });
}

abstract base class ProviderHttpWearableApi implements WearableRemoteApi {
  ProviderHttpWearableApi(this.transport);
  final WearableHttpTransport transport;
  Uri endpoint(String? cursor, DateTime asOf);
  Map<String, String> headers(String accessTokenRef) => <String, String>{
    'authorization': 'Bearer $accessTokenRef',
    'accept': 'application/json',
  };
  Map<String, Object?> mapPayload(
    Map<String, Object?> payload,
    WearableHttpResponse response,
  );
  @override
  Future<Map<String, Object?>> fetch({
    required WearableVendor vendor,
    required String accessTokenRef,
    required String? cursor,
    required DateTime asOf,
  }) async {
    final response = await transport.send(
      method: 'GET',
      uri: endpoint(cursor, asOf),
      headers: headers(accessTokenRef),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('wearable_auth_rejected:${vendor.name}');
    }
    if (response.statusCode == 429) {
      throw StateError(
        'wearable_rate_limited:${vendor.name}:${response.headers['retry-after'] ?? 'unknown'}',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'wearable_provider_error:${vendor.name}:${response.statusCode}',
      );
    }
    final decoded = Map<String, Object?>.from(
      jsonDecode(utf8.decode(response.body)) as Map,
    );
    return mapPayload(decoded, response);
  }
}

final class GarminWearableApi extends ProviderHttpWearableApi {
  GarminWearableApi(
    super.transport, {
    this.base = 'https://apis.garmin.com/wellness-api/rest',
  });
  final String base;
  @override
  Uri endpoint(String? cursor, DateTime asOf) =>
      Uri.parse('$base/activities').replace(
        queryParameters: <String, String>{
          'cursor': ?cursor,
          'until': asOf.toUtc().toIso8601String(),
        },
      );
  @override
  Map<String, Object?> mapPayload(
    Map<String, Object?> p,
    WearableHttpResponse r,
  ) => <String, Object?>{
    'records': p['activities'] ?? const [],
    'deletedIds': p['deletedIds'] ?? const [],
    'nextCursor': p['next'] as String?,
    'hasMore': p['next'] != null,
    'rateLimitRemaining': int.tryParse(
      r.headers['x-ratelimit-remaining'] ?? '',
    ),
  };
}

final class FitbitWearableApi extends ProviderHttpWearableApi {
  FitbitWearableApi(
    super.transport, {
    this.base = 'https://api.fitbit.com/1/user/-',
  });
  final String base;
  @override
  Uri endpoint(String? cursor, DateTime asOf) =>
      Uri.parse('$base/activities/list.json').replace(
        queryParameters: <String, String>{
          'beforeDate': asOf.toUtc().toIso8601String(),
          'offset': ?cursor,
          'limit': '100',
          'sort': 'desc',
        },
      );
  @override
  Map<String, Object?> mapPayload(
    Map<String, Object?> p,
    WearableHttpResponse r,
  ) => <String, Object?>{
    'records': p['activities'] ?? const [],
    'deletedIds': p['deletedIds'] ?? const [],
    'nextCursor': (p['pagination'] as Map?)?['next'] as String?,
    'hasMore': (p['pagination'] as Map?)?['next'] != null,
    'rateLimitRemaining': int.tryParse(
      r.headers['fitbit-rate-limit-remaining'] ?? '',
    ),
  };
}

final class AppleWatchWearableApi extends ProviderHttpWearableApi {
  AppleWatchWearableApi(super.transport, {this.base = 'bil://healthkit'});
  final String base;
  @override
  Uri endpoint(String? cursor, DateTime asOf) => Uri.parse(base).replace(
    queryParameters: <String, String>{
      'operation': 'anchoredRead',
      'anchor': ?cursor,
      'asOf': asOf.toUtc().toIso8601String(),
    },
  );
  @override
  Map<String, Object?> mapPayload(
    Map<String, Object?> p,
    WearableHttpResponse r,
  ) => <String, Object?>{
    'records': p['records'] ?? const [],
    'deletedIds': p['deletedIds'] ?? const [],
    'nextCursor': (p['anchor'] ?? p['nextAnchor']) as String?,
    'hasMore': p['hasMore'] == true,
    'rateLimitRemaining': 999,
  };
}

final class WearOsWearableApi extends ProviderHttpWearableApi {
  WearOsWearableApi(super.transport, {this.base = 'bil://health-connect'});
  final String base;
  @override
  Uri endpoint(String? cursor, DateTime asOf) => Uri.parse(base).replace(
    queryParameters: <String, String>{
      'operation': 'changes',
      'token': ?cursor,
      'asOf': asOf.toUtc().toIso8601String(),
    },
  );
  @override
  Map<String, Object?> mapPayload(
    Map<String, Object?> p,
    WearableHttpResponse r,
  ) => <String, Object?>{
    'records': p['records'] ?? const [],
    'deletedIds': p['deletedIds'] ?? const [],
    'nextCursor': (p['changeToken'] ?? p['nextChangeToken']) as String?,
    'hasMore': p['hasMore'] == true,
    'rateLimitRemaining': 999,
  };
}
