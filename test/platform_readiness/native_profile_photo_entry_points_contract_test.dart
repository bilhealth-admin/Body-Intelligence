import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile profile-photo entry points use the native gallery service', () {
    final dashboard = File(
      'lib/features/dashboard/dashboard_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/profile/services/profile_photo_service.dart',
    ).readAsStringSync();

    expect(dashboard, contains('profilePhotoServiceProvider'));
    expect(dashboard, contains('.chooseAndSave()'));
    expect(dashboard, isNot(contains('openFile(acceptedTypeGroups:')));
    expect(service, contains('TargetPlatform.iOS'));
    expect(service, contains('TargetPlatform.android'));
    expect(service, contains('image_picker.ImageSource.gallery'));
  });
}
