import 'dart:collection';

enum PromptEnvelopeStatus { ready, abstained, rejected }

final class PromptEnvelope {
  PromptEnvelope({
    required this.status,
    required DateTime generatedAt,
    required this.systemInstruction,
    required this.userInstruction,
    required Iterable<String> contextLines,
    required Iterable<String> evidenceIds,
    required Iterable<String> safetyRequirements,
    required this.maximumOutputCharacters,
  }) : generatedAt = generatedAt.toUtc(),
       contextLines = UnmodifiableListView<String>(
         contextLines
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toList(growable: false),
       ),
       evidenceIds = UnmodifiableListView<String>(
         (evidenceIds
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ),
       safetyRequirements = UnmodifiableListView<String>(
         (safetyRequirements
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       );

  final PromptEnvelopeStatus status;
  final DateTime generatedAt;
  final String systemInstruction;
  final String userInstruction;
  final List<String> contextLines;
  final List<String> evidenceIds;
  final List<String> safetyRequirements;
  final int maximumOutputCharacters;

  bool get canDispatch => status == PromptEnvelopeStatus.ready;
}
