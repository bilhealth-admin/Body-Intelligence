import '../domain/truth_assessment.dart';
import '../domain/truth_proposition.dart';
import '../domain/truth_rule.dart';
import '../domain/truth_signal.dart';
import 'truth_engine.dart';

/// Composes typed deterministic rules into the existing Truth Engine boundary.
///
/// Composition is stable by rule key, rejects duplicate rules, and reports
/// proposition evidence requirements that were not satisfied by matched rules.
final class TruthRuleComposer {
  const TruthRuleComposer({this.truthEngine = const TruthEngine()});

  final TruthEngine truthEngine;

  TruthAssessment assess<T>({
    required TruthProposition<T> proposition,
    required T context,
    required Iterable<TruthRule<T>> rules,
  }) {
    final orderedRules = List<TruthRule<T>>.of(rules)
      ..sort((left, right) => left.key.compareTo(right.key));
    _requireUniqueRuleKeys(orderedRules);
    _requireMatchingProposition(proposition, orderedRules);

    final signals = <TruthSignal>[];
    for (final rule in orderedRules) {
      final signal = rule.evaluate(context);
      if (signal != null) {
        signals.add(signal);
      }
    }

    final evidenceKeys = signals
        .map((signal) => signal.evidence.key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    final missingEvidence =
        proposition.requiredEvidenceKeys
            .where((key) => !evidenceKeys.contains(key))
            .toList(growable: false)
          ..sort();

    return truthEngine.assess(
      signals: signals,
      missingEvidence: missingEvidence,
    );
  }

  void _requireUniqueRuleKeys<T>(List<TruthRule<T>> rules) {
    final seen = <String>{};
    for (final rule in rules) {
      if (!seen.add(rule.key)) {
        throw ArgumentError.value(
          rule.key,
          'rules',
          'rule keys must be unique',
        );
      }
    }
  }

  void _requireMatchingProposition<T>(
    TruthProposition<T> proposition,
    List<TruthRule<T>> rules,
  ) {
    for (final rule in rules) {
      if (rule.propositionKey != proposition.key) {
        throw ArgumentError.value(
          rule.propositionKey,
          'rules',
          'every rule must target proposition ${proposition.key}',
        );
      }
    }
  }
}
