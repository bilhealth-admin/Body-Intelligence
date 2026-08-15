import 'package:flutter/services.dart';

import '../core/global_platform_core.dart';
import '../health_data/unified_health_data_integration.dart';

final class MethodChannelHealthBridge
    implements NativeHealthBridge, NativeHealthCapabilityBridge {
  MethodChannelHealthBridge({required String channelName})
    : _channel = MethodChannel(channelName);

  final MethodChannel _channel;

  @override
  String get id => _channel.name;

  @override
  Future<Map<String, Object?>> availability() async =>
      Map<String, Object?>.from(
        await _channel.invokeMapMethod<String, Object?>('availability') ??
            const <String, Object?>{},
      );

  @override
  Future<void> enableBackgroundDelivery(Set<String> types) async {
    await _channel.invokeMethod<void>(
      'enableBackgroundDelivery',
      <String, Object?>{'types': types.toList()..sort()},
    );
  }

  @override
  Future<Map<String, Object?>> revokeAccess() async =>
      Map<String, Object?>.from(
        await _channel.invokeMapMethod<String, Object?>('revokeAccess') ??
            const <String, Object?>{},
      );

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  @override
  Future<Map<String, bool>> permissions() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'permissions',
    );
    return <String, bool>{
      for (final entry in (result ?? const <String, Object?>{}).entries)
        entry.key: entry.value == true,
    };
  }

  @override
  Future<void> request(Set<String> types, {required bool write}) async {
    await _channel.invokeMethod<void>('requestPermissions', <String, Object?>{
      'types': types.toList()..sort(),
      'write': write,
    });
  }

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async {
    final raw = await _channel
        .invokeMapMethod<String, Object?>('readChanges', <String, Object?>{
          'anchor': anchor,
          'asOf': asOf.toUtc().toIso8601String(),
          'types': types.toList()..sort(),
        });
    final records = <NativeHealthRecord>[];
    for (final value
        in (raw?['records'] as List<Object?>? ?? const <Object?>[])) {
      final row = Map<String, Object?>.from(value! as Map);
      records.add(NativeHealthRecord.fromMap(row, providerId: id));
    }
    return NativeHealthPage(
      records: records,
      deletedIds: List<String>.from(
        raw?['deletedIds'] as List<Object?>? ?? const <Object?>[],
      ),
      nextAnchor: raw?['nextAnchor'] as String?,
      hasMore: raw?['hasMore'] == true,
    );
  }

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {
    await _channel.invokeMethod<void>('write', <String, Object?>{
      'signals': [for (final signal in signals) signal.toMap()],
    });
  }

  @override
  Future<void> delete(List<String> recordIds) async {
    await _channel.invokeMethod<void>('delete', <String, Object?>{
      'recordIds': recordIds,
    });
  }
}

final class MethodChannelWearableBridge {
  MethodChannelWearableBridge({
    required String providerId,
    required String channelName,
  }) : id = providerId,
       _channel = MethodChannel(channelName);

  final String id;
  final MethodChannel _channel;

  Future<Set<String>> capabilities() async => Set<String>.from(
    await _channel.invokeListMethod<String>('capabilities') ?? const <String>[],
  );

  Future<Map<String, Object?>> synchronize({
    String? cursor,
    required DateTime asOf,
  }) async => Map<String, Object?>.from(
    await _channel.invokeMapMethod<String, Object?>(
          'synchronize',
          <String, Object?>{
            'cursor': cursor,
            'asOf': asOf.toUtc().toIso8601String(),
          },
        ) ??
        const <String, Object?>{},
  );

  Future<void> revoke() => _channel.invokeMethod<void>('revoke');
}

final class MethodChannelMedicalDeviceBridge {
  MethodChannelMedicalDeviceBridge({required String channelName})
    : _channel = MethodChannel(channelName);
  final MethodChannel _channel;

  Future<List<Map<String, Object?>>> discover() async => [
    for (final row
        in await _channel.invokeListMethod<Object?>('discover') ??
            const <Object?>[])
      Map<String, Object?>.from(row! as Map),
  ];

  Future<List<Map<String, Object?>>> readBatch({
    required String deviceId,
    required DateTime asOf,
  }) async => [
    for (final row
        in await _channel.invokeListMethod<Object?>(
              'readBatch',
              <String, Object?>{
                'deviceId': deviceId,
                'asOf': asOf.toUtc().toIso8601String(),
              },
            ) ??
            const <Object?>[])
      Map<String, Object?>.from(row! as Map),
  ];
}
