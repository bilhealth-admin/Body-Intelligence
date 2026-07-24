import 'dart:collection';

enum HealthInsightSeverity { information, attention, blocked }

class HealthInsightEvidence {
  HealthInsightEvidence({
    required this.key,
    required this.statement,
    required this.provenance,
    required DateTime observedAt,
    required this.confidence,
  }) : observedAt = observedAt.toUtc(),
       assert(key != ''),
       assert(provenance != ''),
       assert(confidence >= 0 && confidence <= 1);

  final String key;
  final String statement;
  final String provenance;
  final DateTime observedAt;
  final double confidence;
}

class AutomatedHealthInsightSummary {
  AutomatedHealthInsightSummary({
    required DateTime generatedAt,
    required this.title,
    required this.body,
    required this.severity,
    required List<HealthInsightEvidence> evidence,
    required List<String> uncertaintyNotes,
    required this.safetyApproved,
    required this.isAbstained,
  }) : generatedAt = generatedAt.toUtc(),
       evidence = UnmodifiableListView(evidence),
       uncertaintyNotes = UnmodifiableListView(uncertaintyNotes);

  final DateTime generatedAt;
  final String title;
  final String body;
  final HealthInsightSeverity severity;
  final UnmodifiableListView<HealthInsightEvidence> evidence;
  final UnmodifiableListView<String> uncertaintyNotes;
  final bool safetyApproved;
  final bool isAbstained;
}
