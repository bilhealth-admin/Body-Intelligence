import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coach greeting uses the local hour buckets', () {
    expect(coachGreetingKeyForHour(0), 'Good morning');
    expect(coachGreetingKeyForHour(11), 'Good morning');
    expect(coachGreetingKeyForHour(12), 'Good afternoon');
    expect(coachGreetingKeyForHour(15), 'Good afternoon');
    expect(coachGreetingKeyForHour(17), 'Good afternoon');
    expect(coachGreetingKeyForHour(18), 'Good evening');
    expect(coachGreetingKeyForHour(23), 'Good evening');
  });

  test('invalid hour cannot silently produce a wrong greeting', () {
    expect(() => coachGreetingKeyForHour(-1), throwsArgumentError);
    expect(() => coachGreetingKeyForHour(24), throwsArgumentError);
  });
}
