import 'package:flutter_test/flutter_test.dart';

import '../../tool/visual_reference_manifest.dart' as reference_manifest;

void main() {
  test(
    'native health permission and help reference families stay distinct',
    () {
      for (var reference = 4988; reference <= 4991; reference++) {
        final mapping = reference_manifest.mappingFor(reference);
        expect(mapping.screen, 'privacy and health access');
        expect(mapping.route, '/connected-health');
        expect(
          mapping.capability,
          'platform health read/write permission selection',
        );
      }

      for (var reference = 4992; reference <= 4997; reference++) {
        final mapping = reference_manifest.mappingFor(reference);
        expect(mapping.screen, 'help');
        expect(mapping.route, '/help');
      }
    },
  );
}
