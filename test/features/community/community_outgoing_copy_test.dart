import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_outgoing_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sent has authored nonempty copy for every production locale', () {
    expect(
      CommunityOutgoingCopy.sentLabels.keys.toSet(),
      RuntimeCopy.supported,
    );
    for (final entry in CommunityOutgoingCopy.sentLabels.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      if (entry.key != 'en') {
        expect(entry.value, isNot('Sent'), reason: entry.key);
      }
    }
  });
}
