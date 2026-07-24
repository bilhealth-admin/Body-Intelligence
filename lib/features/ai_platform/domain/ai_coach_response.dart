import 'dart:collection';

enum AiCoachStatus { accepted, abstained, rejected }

final class AiCoachResponse {
  AiCoachResponse({
    required this.status,
    required DateTime generatedAt,
    required this.headline,
    required this.message,
    required this.actionId,
    required Iterable<String> evidenceIds,
    required Iterable<String> uncertaintyNotes,
    required Iterable<String> safetyNotes,
  }) : generatedAt = generatedAt.toUtc(),
       evidenceIds = UnmodifiableListView<String>(
         (evidenceIds
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ),
       uncertaintyNotes = UnmodifiableListView<String>(
         (uncertaintyNotes
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ),
       safetyNotes = UnmodifiableListView<String>(
         (safetyNotes
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       );

  final AiCoachStatus status;
  final DateTime generatedAt;
  final String headline;
  final String message;
  final String? actionId;
  final List<String> evidenceIds;
  final List<String> uncertaintyNotes;
  final List<String> safetyNotes;

  bool get canProceed => status == AiCoachStatus.accepted && actionId != null;
}
