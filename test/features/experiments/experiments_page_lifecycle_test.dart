import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'experiments_fixture.dart';

void main() {
  experimentTestWidgets(
    'active experiment completion opens a valid 80 percent slider',
    (tester) async {
      final fixture = await pumpExperiments(tester, seedActive: true);
      await fixture.tap(tester, 'Record what happened');
      expect(tester.takeException(), isNull);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 80);
      expect(slider.min, 0);
      expect(slider.max, 100);
      expect((await fixture.real(fixture.repository.active))!.status, 'active');
      fixture.router.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
