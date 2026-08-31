/// The minimal, media-free six-month gym plan used by the wellness runtime.
final class GymSixMonthPlan {
  const GymSixMonthPlan({
    required this.sourcePath,
    required this.sourceContractId,
    required this.sourceSha256,
    required this.releaseManifestPath,
    required this.releaseManifestSha256,
    required this.months,
    required this.sessions,
    required this.warmups,
    required this.libraryPages,
    required this.exerciseIds,
  });

  final String sourcePath;
  final String sourceContractId;
  final String sourceSha256;
  final String releaseManifestPath;
  final String releaseManifestSha256;
  final List<GymPlanMonth> months;
  final List<GymPlanSession> sessions;
  final GymPlanWarmups warmups;
  final List<GymPlanLibraryPage> libraryPages;
  final List<String> exerciseIds;
}

final class GymPlanMonth {
  const GymPlanMonth({
    required this.month,
    required this.phase,
    required this.sessionIds,
  });

  final int month;
  final String phase;
  final List<String> sessionIds;
}

final class GymPlanSession {
  const GymPlanSession({required this.id, required this.exerciseIds});

  final String id;
  final List<String> exerciseIds;
}

final class GymPlanWarmups {
  const GymPlanWarmups({required this.exerciseIds, required this.groups});

  final List<String> exerciseIds;
  final List<GymPlanWarmupGroup> groups;
}

final class GymPlanWarmupGroup {
  const GymPlanWarmupGroup({required this.id, required this.exerciseIds});

  final String id;
  final List<String> exerciseIds;
}

final class GymPlanLibraryPage {
  const GymPlanLibraryPage({
    required this.id,
    required this.title,
    required this.kind,
    required this.description,
    required this.filters,
  });

  final String id;
  final String title;
  final String kind;
  final String description;
  final List<String> filters;
}
