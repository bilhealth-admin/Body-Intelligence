import 'dart:io';

import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'paid pack install fails closed before download without verified access',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-wellness-access-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final manager = WellnessContentPackManager(
        packsDirectory: directory,
        entitlementLoader: () async => FreePlan.createState(),
      );

      await expectLater(
        manager.install(_paidPack),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('PRO access is required'),
          ),
        ),
      );
      expect(directory.listSync(), isEmpty);
    },
  );
}

final _paidPack = WellnessContentPack(
  id: 'bil-workouts-pro-v2',
  version: 1,
  type: WellnessContentType.workouts,
  title: 'Verified Pro workouts',
  description: 'Server-controlled licensed workout catalog.',
  locale: 'en',
  downloadUrl: Uri.parse('https://cdn.bilhealth.com/workouts/pro-v2.json'),
  sizeBytes: 128,
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  itemCount: 100,
  minimumAccess: WellnessContentAccess.pro,
  schemaVersion: 2,
  publisher: 'BIL Health',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts'),
  licenseName: 'BIL licensed content',
  licenseUrl: Uri.parse('https://bilhealth.com/licenses/workouts'),
);
