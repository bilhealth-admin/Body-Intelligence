import '../domain/one_best_action.dart';

final class OneBestActionIntegrityValidator {
  const OneBestActionIntegrityValidator();

  List<String> validate(OneBestActionResult result) {
    final issues = <String>[];
    if (result.status == OneBestActionStatus.accepted) {
      if (result.selected == null) {
        issues.add('accepted result must expose one selected action');
      }
      if (result.rankedCandidates.isEmpty) {
        issues.add('accepted result must preserve ranked candidates');
      }
      if (result.selected != null &&
          result.rankedCandidates.every(
            (entry) => entry.candidate.id != result.selected!.id,
          )) {
        issues.add('selected action must exist in ranked candidates');
      }
    } else if (result.selected != null) {
      issues.add('non-accepted result must not expose a selected action');
    }
    for (var index = 0; index < result.rankedCandidates.length; index++) {
      final entry = result.rankedCandidates[index];
      if (entry.rank != index + 1) {
        issues.add('ranked candidates must use contiguous ranks');
        break;
      }
      if (entry.candidate.evidenceIds.isEmpty) {
        issues.add('ranked candidates must preserve evidence');
        break;
      }
      if (index > 0 && result.rankedCandidates[index - 1].score < entry.score) {
        issues.add('ranked candidates must be sorted descending');
        break;
      }
    }
    return issues..sort();
  }
}
