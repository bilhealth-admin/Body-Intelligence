import 'dart:convert';

import 'package:body_intelligence_log/features/intelligence_center/services/coach_cloud_payload_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud Coach payload replaces non-finite numbers with unavailable', () {
    final value = sanitizeCoachCloudObject(<Object?, Object?>{
      'valid': 72.5,
      'invalid': double.nan,
      'nested': <Object?>[double.infinity, -double.infinity, 3],
    });

    expect(value['valid'], 72.5);
    expect(value['invalid'], isNull);
    expect(value['nested'], <Object?>[null, null, 3]);
    expect(() => jsonEncode(value), returnsNormally);
  });

  test('cloud Coach payload bounds unsupported objects to null', () {
    final value = sanitizeCoachCloudObject(<Object?, Object?>{
      'when': DateTime.utc(2026, 8, 21),
      'unsupported': Object(),
    });

    expect(value['when'], '2026-08-21T00:00:00.000Z');
    expect(value['unsupported'], isNull);
  });
}
