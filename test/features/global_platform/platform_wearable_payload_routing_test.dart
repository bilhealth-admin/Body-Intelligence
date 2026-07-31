import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/platform_wearable_transports.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_specific_wearable_apis.dart';

final class _NeverRemote implements WearableHttpTransport {
  @override
  Future<WearableHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  }) => throw StateError('remote_not_expected');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native map payload preserves records deletions cursor and hasMore',
    () async {
      const channel = MethodChannel('test-health');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => <String, Object?>{
              'records': <Object?>[
                <String, Object?>{'id': 'r1'},
              ],
              'deletedIds': <Object?>['d1'],
              'nextAnchor': 'a2',
              'hasMore': true,
            },
          );
      final transport = PlatformAwareWearableTransport(
        remote: _NeverRemote(),
        appleChannel: channel,
      );
      final response = await transport.send(
        method: 'GET',
        uri: Uri.parse('bil://healthkit?operation=anchoredRead&anchor=a1'),
        headers: const {},
      );
      final text = String.fromCharCodes(response.body);
      expect(text, contains('r1'));
      expect(text, contains('d1'));
      expect(text, contains('a2'));
      expect(text, contains('true'));
    },
  );
}
