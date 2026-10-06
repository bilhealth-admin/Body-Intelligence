import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_coach_food_cards.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/localization/locale_fallback_closure.dart';

void main() {
  final rows =
      (jsonDecode(
                File(
                  'test/localization/fixtures/coach_food_card_copy_sources.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  test(
    'all native food card literal calls are present in the reviewed inventory',
    () {
      final source = File(
        'lib/features/intelligence_center/presentation/workspace/coach_food_card_copy.dart',
      ).readAsStringSync();
      expect(rows, hasLength(60));
      expect(coachLiteralRuntimeSources(source), {
        for (final row in rows) row['english'] as String,
      });
    },
  );

  test('food card bank has complete exact locale and placeholder coverage', () {
    expect(CoachFoodCardRuntimeCopy.balanced, isTrue);
    expect(
      CoachFoodCardRuntimeCopy.rows.keys.toSet(),
      BilLocalePolicy.productionTags.toSet(),
    );
    final placeholder = RegExp(r'\{[A-Za-z]+\}');
    Set<String> tokens(String value) => {
      for (final match in placeholder.allMatches(value)) match.group(0)!,
    };
    for (final row in CoachFoodCardRuntimeCopy.rows.entries) {
      for (
        var index = 0;
        index < CoachFoodCardRuntimeCopy.sources.length;
        index++
      ) {
        expect(
          tokens(row.value[index]),
          tokens(CoachFoodCardRuntimeCopy.sources[index]),
          reason: '${row.key}: ${CoachFoodCardRuntimeCopy.sources[index]}',
        );
      }
    }
    expect(
      CoachFoodCardRuntimeCopy.resolve('not a food copy key', 'en'),
      isNull,
    );
    expect(
      CoachFoodCardRuntimeCopy.resolve('Quantity confidence', 'pt_BR'),
      CoachFoodCardRuntimeCopy.resolve('Quantity confidence', 'pt-BR'),
    );
  });

  for (final tag in BilLocalePolicy.productionTags) {
    test(
      '$tag uses the authored food copy through the actual Coach locale helper',
      () {
        for (final row in rows) {
          final english = row['english'] as String;
          final arabic = row['arabic'] as String;
          final authored = CoachFoodCardRuntimeCopy.resolve(english, tag);
          final existing = RuntimeCopy.resolve(english, tag);
          final expected = tag == 'ar' ? arabic : existing ?? authored;
          expect(
            expected,
            isNotNull,
            reason: '$tag: $english has no authored source',
          );
          expect(
            intelligenceTextFor(tag, english, arabic),
            expected,
            reason: '$tag: $english',
          );
        }
        final confidenceLabels = {
          for (final english in [
            'Source confidence',
            'Identity confidence',
            'Quantity confidence',
          ])
            CoachFoodCardRuntimeCopy.resolve(english, tag),
        };
        expect(confidenceLabels, hasLength(3));
        expect(confidenceLabels, isNot(contains(null)));
      },
    );
  }
}
