import 'package:body_intelligence_log/features/community/services/contact_picker_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bil/contact_picker');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the native contact selected for an SMS invitation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pick');
          return <String, dynamic>{'name': ' Sam ', 'phone': ' +201234 '};
        });

    final contact = await const ContactPickerService().pick();

    expect(contact?.name, 'Sam');
    expect(contact?.phone, '+201234');
  });

  test(
    'rejects a contact without a phone instead of opening invalid SMS',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            return <String, dynamic>{'name': 'Name only', 'phone': '   '};
          });

      expect(await const ContactPickerService().pick(), isNull);
    },
  );
}
