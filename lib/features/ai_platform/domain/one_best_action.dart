import 'dart:collection';

enum OneBestActionStatus { accepted, abstained, rejected }

final class OneBestActionCandidate {
  OneBestActionCandidate({
    required this.id,
    required this.title,
    required this.rationale,
    required this.expectedBenefit,
    required this.confidence,
    required this.burden,
    required this.safetyEligible,
    required Iterable<String> evidenceIds,
  }) : evidenceIds = UnmodifiableListView<String>(
         (evidenceIds
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (rationale.trim().isEmpty) {
      throw ArgumentError.value(rationale, 'rationale', 'must not be empty');
    }
    if (expectedBenefit < 0 || expectedBenefit > 1) {
      throw ArgumentError.value(
        expectedBenefit,
        'expectedBenefit',
        'must be in [0, 1]',
      );
    }
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError.value(confidence, 'confidence', 'must be in [0, 1]');
    }
    if (burden < 0 || burden > 1) {
      throw ArgumentError.value(burden, 'burden', 'must be in [0, 1]');
    }
  }

  final String id;
  final String title;
  final String rationale;
  final double expectedBenefit;
  final double confidence;
  final double burden;
  final bool safetyEligible;
  final List<String> evidenceIds;

  double get rankingScore => (expectedBenefit * confidence) - (burden * 0.25);
}

final class RankedActionCandidate {
  const RankedActionCandidate({
    required this.candidate,
    required this.rank,
    required this.score,
  });

  final OneBestActionCandidate candidate;
  final int rank;
  final double score;
}

final class OneBestActionResult {
  OneBestActionResult({
    required this.status,
    required DateTime asOf,
    required this.selected,
    required Iterable<RankedActionCandidate> rankedCandidates,
    required Iterable<String> reasons,
    required Iterable<String> integrityIssues,
  }) : asOf = asOf.toUtc(),
       rankedCandidates = UnmodifiableListView<RankedActionCandidate>(
         rankedCandidates.toList(growable: false),
       ),
       reasons = UnmodifiableListView<String>(
         (reasons.toSet().toList()..sort()),
       ),
       integrityIssues = UnmodifiableListView<String>(
         (integrityIssues.toSet().toList()..sort()),
       );

  final OneBestActionStatus status;
  final DateTime asOf;
  final OneBestActionCandidate? selected;
  final List<RankedActionCandidate> rankedCandidates;
  final List<String> reasons;
  final List<String> integrityIssues;

  bool get canProceed =>
      status == OneBestActionStatus.accepted &&
      selected != null &&
      integrityIssues.isEmpty;
}
