import '../domain/ai_context.dart';

/// Pure integrity validation for assembled AI Context.
final class AiContextIntegrityValidator {
  const AiContextIntegrityValidator();

  List<String> validate<T>(AiContext<T> context) {
    final issues = <String>[];
    final keys = <String>{};
    for (final item in context.provenance) {
      if (!keys.add(item.contextKey)) {
        issues.add('duplicate_provenance:${item.contextKey}');
      }
    }
    if (context.bodySnapshot != null &&
        context.bodySnapshot!.asOf.isAfter(context.asOf)) {
      issues.add('body_snapshot_after_context_as_of');
    }
    if (context.bodyTrends != null &&
        context.bodyTrends!.asOf.isAfter(context.asOf)) {
      issues.add('body_trends_after_context_as_of');
    }
    for (final history in context.decisionHistory) {
      if (history.record.createdAt.isAfter(context.asOf)) {
        issues.add('future_decision_memory:${history.record.id}');
      }
    }
    return List<String>.unmodifiable(issues..sort());
  }
}
