import 'dart:collection';

enum ClosureStatus { completed, notCompleted }

final class ClosureEvidence {
  const ClosureEvidence({
    required this.requirementId,
    required this.requirement,
    required this.productionFiles,
    required this.runtimePath,
    required this.behavioralTests,
    required this.systemTests,
    required this.regressionTests,
    required this.evidence,
    required this.securityReview,
    required this.failureRecoveryCoverage,
    required this.privacyCoverage,
    required this.provenanceCoverage,
    required this.decision,
    required this.status,
  });

  final String requirementId;
  final String requirement;
  final List<String> productionFiles;
  final String runtimePath;
  final List<String> behavioralTests;
  final List<String> systemTests;
  final List<String> regressionTests;
  final String evidence;
  final String securityReview;
  final String failureRecoveryCoverage;
  final String privacyCoverage;
  final String provenanceCoverage;
  final String decision;
  final ClosureStatus status;

  bool get hasCompleteProof =>
      productionFiles.isNotEmpty &&
      runtimePath.isNotEmpty &&
      behavioralTests.isNotEmpty &&
      systemTests.isNotEmpty &&
      regressionTests.isNotEmpty &&
      evidence.isNotEmpty &&
      securityReview.isNotEmpty &&
      failureRecoveryCoverage.isNotEmpty &&
      privacyCoverage.isNotEmpty &&
      provenanceCoverage.isNotEmpty &&
      decision.isNotEmpty;
}

final class GlobalClosureAudit {
  GlobalClosureAudit(Iterable<ClosureEvidence> evidence)
    : evidence = List<ClosureEvidence>.unmodifiable(evidence);

  final List<ClosureEvidence> evidence;

  bool get complete =>
      evidence.isNotEmpty &&
      evidence.every(
        (item) =>
            item.status == ClosureStatus.completed && item.hasCompleteProof,
      );

  Map<String, ClosureStatus> get byRequirement =>
      UnmodifiableMapView<String, ClosureStatus>(<String, ClosureStatus>{
        for (final item in evidence) item.requirementId: item.status,
      });

  List<ClosureEvidence> get unsupported => List<ClosureEvidence>.unmodifiable(
    evidence.where(
      (item) =>
          item.status != ClosureStatus.completed || !item.hasCompleteProof,
    ),
  );
}
