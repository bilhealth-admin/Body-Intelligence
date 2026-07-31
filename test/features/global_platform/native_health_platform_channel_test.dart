import 'package:body_intelligence_log/features/global_platform/platform/native_platform_bridges.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bil/apple_health');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'method channel serializes availability, anchors, deletions and provenance',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'availability') {
          return <String, Object?>{'available': true, 'platform': 'healthkit'};
        }
        if (call.method == 'permissions') {
          return <String, Object?>{'weight': true};
        }
        if (call.method == 'readChanges') {
          return <String, Object?>{
            'records': <Object?>[
              <String, Object?>{
                'id': 'r1',
                'type': 'weight',
                'value': 95.0,
                'unit': 'kg',
                'observedAt': '2026-07-24T00:00:00.000Z',
                'sourceId': 'com.apple.Health',
                'deviceId': 'watch',
                'confidence': 1.0,
                'timeZoneId': 'Africa/Cairo',
                'deleted': false,
              },
            ],
            'deletedIds': <String>['gone'],
            'nextAnchor': 'encoded-anchor',
            'hasMore': false,
          };
        }
        return null;
      });
      final bridge = MethodChannelHealthBridge(channelName: 'bil/apple_health');
      expect((await bridge.availability())['available'], isTrue);
      expect((await bridge.permissions())['weight'], isTrue);
      final page = await bridge.readChanges(
        anchor: null,
        asOf: DateTime.utc(2026, 7, 24),
        types: {'weight'},
      );
      expect(page.records.single.sourceId, 'com.apple.Health');
      expect(page.deletedIds, ['gone']);
      expect(page.nextAnchor, 'encoded-anchor');
      await bridge.enableBackgroundDelivery({'weight'});
      expect(
        calls.map((e) => e.method),
        containsAll(<String>[
          'availability',
          'permissions',
          'readChanges',
          'enableBackgroundDelivery',
        ]),
      );
    },
  );
}
