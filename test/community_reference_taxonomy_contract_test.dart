import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community exposes the reference taxonomy without invented counts', () {
    final source = File(
      'lib/features/community/presentation/community_taxonomy_sheet.dart',
    ).readAsStringSync();
    for (final topic in [
      'Getting Started',
      'Health and Weight Loss',
      'Food and Nutrition',
      'Recipes',
      'Fitness and Exercise',
      'Sleep, Mindfulness and Wellness',
      'Maintaining Weight',
      'Gaining Weight and Muscle',
      'Feature Suggestions',
      'Tech Support',
    ]) {
      expect(source, contains("'$topic'"), reason: topic);
    }
    expect(source, contains("'Quick links'"));
    expect(source, contains("'Popular tags'"));
    expect(
      source,
      contains(
        'Counts are shown only when real community analytics are available.',
      ),
    );
    expect(source, isNot(contains('memberCount')));
    expect(source, isNot(contains('postCount')));
  });

  test(
    'friend discovery exposes safe contacts and live BIL search methods',
    () {
      final source = File(
        'lib/features/community/presentation/community_people_page.dart',
      ).readAsStringSync();
      expect(source, contains("Key('community-add-from-contacts')"));
      expect(source, contains('No permission was requested.'));
      expect(source, contains("Key('community-add-by-bil-name')"));
      expect(source, contains('_searchFocus.requestFocus()'));
      expect(source, contains('_repository!.searchProfiles'));
    },
  );
}
