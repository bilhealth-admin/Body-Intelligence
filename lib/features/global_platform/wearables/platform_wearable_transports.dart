import 'dart:convert';

import 'package:flutter/services.dart';

import 'provider_specific_wearable_apis.dart';

final class PlatformAwareWearableTransport implements WearableHttpTransport {
  PlatformAwareWearableTransport({
    required this._remote,
    MethodChannel? appleChannel,
    MethodChannel? androidChannel,
  }) : _apple = appleChannel ?? const MethodChannel('bil/apple_health'),
       _android = androidChannel ?? const MethodChannel('bil/health_connect');

  final WearableHttpTransport _remote;
  final MethodChannel _apple;
  final MethodChannel _android;

  @override
  Future<WearableHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  }) async {
    if (uri.scheme != 'bil') {
      return _remote.send(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      );
    }
    final channel = switch (uri.host) {
      'healthkit' => _apple,
      'health-connect' => _android,
      _ => throw StateError('unsupported_wearable_platform:${uri.host}'),
    };
    final operation = uri.queryParameters['operation'];
    if (operation != 'anchoredRead' && operation != 'changes') {
      throw StateError('unsupported_wearable_operation:$operation');
    }
    final arguments = <String, Object?>{...uri.queryParameters};
    // Native bridges apply their complete supported-type registry when the
    // types key is absent. An empty list would explicitly request zero types.
    final payload = await channel.invokeMethod<Object?>(
      'readChanges',
      arguments,
    );
    final native = payload is Map
        ? Map<String, Object?>.from(payload.cast<Object?, Object?>())
        : <String, Object?>{
            'records': payload is List ? payload : const <Object?>[],
          };
    final response = <String, Object?>{
      'records': native['records'] is List
          ? native['records']!
          : const <Object?>[],
      'deletedIds': native['deletedIds'] is List
          ? native['deletedIds']!
          : const <Object?>[],
      if (native['nextAnchor'] != null) ...<String, Object?>{
        'anchor': native['nextAnchor'],
        'nextAnchor': native['nextAnchor'],
      },
      if (native['changeToken'] != null) 'changeToken': native['changeToken'],
      if (native['nextChangeToken'] != null)
        'changeToken': native['nextChangeToken'],
      'hasMore': native['hasMore'] == true,
    };
    return WearableHttpResponse(
      statusCode: 200,
      headers: const <String, String>{},
      body: Uint8List.fromList(utf8.encode(jsonEncode(response))),
    );
  }
}
