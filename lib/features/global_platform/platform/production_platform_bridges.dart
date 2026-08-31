import 'dart:async';
import 'package:flutter/services.dart';
import '../core/global_platform_core.dart';

final class HealthPlatformBridge {
  HealthPlatformBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('bil/global_health');
  final MethodChannel _channel;
  Future<Map<String, bool>> permissions(Iterable<String> types) async =>
      Map<String, bool>.from(
        await _channel.invokeMapMethod<String, dynamic>('permissions', {
              'types': types.toList(),
            }) ??
            const {},
      );
  Future<List<GlobalHealthSignal>> changes({
    required String platform,
    String? anchor,
  }) async {
    final rows =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('readChanges', {
          'platform': platform,
          'anchor': anchor,
        }) ??
        const [];
    return rows
        .map(
          (row) => GlobalHealthSignal.fromMap(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> delete(String platformId) =>
      _channel.invokeMethod<void>('deleteRecord', {'id': platformId});
}

final class FitnessBluetoothBridge {
  FitnessBluetoothBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('bil/fitness_devices');
  final MethodChannel _channel;
  Future<List<Map<String, Object?>>> scan() async =>
      (await _channel.invokeListMethod<Map<dynamic, dynamic>>('scan') ??
              const [])
          .map((e) => Map<String, Object?>.from(e))
          .toList(growable: false);
  Future<Map<String, Object?>> read(String deviceId) async =>
      Map<String, Object?>.from(
        await _channel.invokeMapMethod<String, dynamic>('read', {
              'deviceId': deviceId,
            }) ??
            const {},
      );
}
