import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reality runtime wires closed engines and safety gate', () {
    final s = File(
      'lib/features/ai_platform/services/local_intelligence_reality_runtime.dart',
    ).readAsStringSync();
    for (final token in [
      'BodyTwinEngine',
      'AiContextEngine',
      'TissueWaterNoiseEngine',
      'AdaptiveMetabolicForecastEngine',
      'OneBestActionEngine',
      'AiSafetyEngine',
      'AiCoachEngine',
      'AutomatedHealthInsightEngine',
      'ProprietaryBilIntelligenceEngine',
      'ScientificValidationEngine',
      'BilIntelligenceIntegrationEngine',
    ]) {
      expect(s, contains(token));
    }
    expect(s, contains('AiSafetyPolicy'));
  });
}
