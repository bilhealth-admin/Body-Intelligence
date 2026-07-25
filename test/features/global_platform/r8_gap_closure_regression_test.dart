import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'R8 production gaps remain wired and no legacy constant readiness survives',
    () {
      final root = Directory('lib/features/global_platform');
      final source = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(source, contains('WearableProviderCatalog'));
      expect(source, contains('BleMedicalDeviceProvider'));
      expect(source, contains('WorldClassReportRuntime'));
      expect(source, contains('GlobalProductFlows'));
      expect(source, contains('GlobalTypedRepository'));
      expect(source, isNot(contains('capabilityCount = 11')));
    },
  );
}
