import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest measurement outranks the onboarding profile weight', () {
    expect(
      resolveEffectiveCurrentWeight(
        latestMeasurement: 89.2,
        profileFallback: 90,
      ),
      89.2,
    );
  });

  test('profile weight remains the fallback without measurements', () {
    expect(
      resolveEffectiveCurrentWeight(
        latestMeasurement: null,
        profileFallback: 90,
      ),
      90,
    );
  });
}
