import 'dart:collection';

import 'ai_safety.dart';

final class AiSafetyPolicy {
  AiSafetyPolicy({
    required Iterable<AiSafetyRule> rules,
    this.requireAcceptedAction = true,
    this.abstainOnAdvisory = false,
  }) : rules = UnmodifiableListView<AiSafetyRule>(
         (rules.toList()..sort((left, right) => left.id.compareTo(right.id))),
       ) {
    final ids = rules.map((rule) => rule.id).toList(growable: false);
    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(ids, 'rules', 'rule ids must be unique');
    }
  }

  final List<AiSafetyRule> rules;
  final bool requireAcceptedAction;
  final bool abstainOnAdvisory;
}
