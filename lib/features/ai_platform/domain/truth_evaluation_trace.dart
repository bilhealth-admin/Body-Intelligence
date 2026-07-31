import 'dart:collection';

import 'truth_assessment.dart';

/// Immutable provenance emitted by deterministic truth-rule composition.
///
/// The trace records what the local engine considered and what matched. It
/// performs no inference, persistence, network access, clock access, or user
/// state mutation.
final class TruthEvaluationTrace {
  TruthEvaluationTrace({
    required String propositionKey,
    required Iterable<String> consideredRuleKeys,
    required Iterable<String> matchedRuleKeys,
    required this.assessment,
  }) : propositionKey = _validatedText(propositionKey, 'propositionKey'),
       consideredRuleKeys = UnmodifiableListView<String>(
         _normalizedUnique(consideredRuleKeys, 'consideredRuleKeys'),
       ),
       matchedRuleKeys = UnmodifiableListView<String>(
         _normalizedUnique(matchedRuleKeys, 'matchedRuleKeys'),
       ) {
    final considered = this.consideredRuleKeys.toSet();
    for (final key in this.matchedRuleKeys) {
      if (!considered.contains(key)) {
        throw ArgumentError.value(
          key,
          'matchedRuleKeys',
          'matched rules must be included in considered rules',
        );
      }
    }
  }

  final String propositionKey;
  final List<String> consideredRuleKeys;
  final List<String> matchedRuleKeys;
  final TruthAssessment assessment;

  List<String> get unmatchedRuleKeys => UnmodifiableListView<String>(
    consideredRuleKeys
        .where((key) => !matchedRuleKeys.contains(key))
        .toList(growable: false),
  );

  static List<String> _normalizedUnique(Iterable<String> values, String field) {
    final normalized = values
        .map((value) => _validatedText(value, field))
        .toList(growable: false);
    final unique = normalized.toSet();
    if (unique.length != normalized.length) {
      throw ArgumentError.value(values, field, 'must contain unique keys');
    }
    return normalized..sort();
  }

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }
}
