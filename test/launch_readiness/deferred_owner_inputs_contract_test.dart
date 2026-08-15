import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('external owner inputs remain explicit and fail closed', () {
    final json =
        jsonDecode(
              File(
                'docs/release/BIL_DEFERRED_OWNER_INPUTS.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final store = json['store'] as Map<String, dynamic>;
    for (final platform in ['google_play', 'apple_app_store']) {
      final values = store[platform] as Map<String, dynamic>;
      expect(values['premium_monthly_product_id'], isNull);
      expect(values['premium_annual_product_id'], isNull);
      expect(values['premium_ai_coach_monthly_product_id'], isNull);
      expect(values['premium_ai_coach_annual_product_id'], isNull);
      expect(values['ai_boost_product_id'], 'bil_ai_boost');
    }
    final admob = json['admob'] as Map<String, dynamic>;
    expect(admob['production_enabled'], isFalse);
    expect(admob['publisher_id'], isNull);
    expect(admob['android_app_id'], isNull);
    expect(admob['ios_app_id'], isNull);
    final analytics = json['analytics'] as Map<String, dynamic>;
    expect(analytics['production_sink_configured'], isFalse);
    expect(analytics['campaigns_authorized'], isFalse);
  });
}
