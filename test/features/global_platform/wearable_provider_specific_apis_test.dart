import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_specific_wearable_apis.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_wearable_adapters.dart';

final class _Transport implements WearableHttpTransport {
  const _Transport(this.status, this.headers, this.payload);

  final int status;
  final Map<String, String> headers;
  final Map<String, Object?> payload;

  @override
  Future<WearableHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  }) async => WearableHttpResponse(
    statusCode: status,
    headers: this.headers,
    body: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
  );
}

void main() {
  test(
    'implemented provider APIs preserve cursors, deletes and rate limits',
    () async {
      final cases = <(WearableRemoteApi, WearableVendor, String)>[
        (
          GarminWearableApi(
            const _Transport(
              200,
              <String, String>{'x-ratelimit-remaining': '9'},
              <String, Object?>{
                'activities': <Object?>[],
                'deletedIds': <String>['g-deleted'],
                'next': 'g',
              },
            ),
          ),
          WearableVendor.garmin,
          'g',
        ),
        (
          FitbitWearableApi(
            const _Transport(
              200,
              <String, String>{'fitbit-rate-limit-remaining': '8'},
              <String, Object?>{
                'activities': <Object?>[],
                'deletedIds': <String>['f-deleted'],
                'pagination': <String, Object?>{'next': 'f'},
              },
            ),
          ),
          WearableVendor.fitbit,
          'f',
        ),
        (
          AppleWatchWearableApi(
            const _Transport(200, <String, String>{}, <String, Object?>{
              'records': <Object?>[],
              'deletedIds': <String>['a-deleted'],
              'anchor': 'a',
            }),
          ),
          WearableVendor.appleWatch,
          'a',
        ),
        (
          WearOsWearableApi(
            const _Transport(200, <String, String>{}, <String, Object?>{
              'records': <Object?>[],
              'deletedIds': <String>['w-deleted'],
              'changeToken': 'w',
            }),
          ),
          WearableVendor.wearOs,
          'w',
        ),
      ];

      for (final (api, vendor, expectedCursor) in cases) {
        final result = await api.fetch(
          vendor: vendor,
          accessTokenRef: 'token',
          cursor: null,
          asOf: DateTime.utc(2026),
        );
        expect(result['nextCursor'], expectedCursor);
        expect(result['deletedIds'], isNotEmpty);
      }
    },
  );

  test('Samsung is not represented by an unverified production API', () {
    expect(WearableProviderCatalog.production, isA<Function>());
  });

  test('provider errors are mapped', () async {
    expect(
      () =>
          GarminWearableApi(
            const _Transport(429, <String, String>{
              'retry-after': '30',
            }, <String, Object?>{}),
          ).fetch(
            vendor: WearableVendor.garmin,
            accessTokenRef: 'x',
            cursor: null,
            asOf: DateTime.utc(2026),
          ),
      throwsStateError,
    );
  });
}
