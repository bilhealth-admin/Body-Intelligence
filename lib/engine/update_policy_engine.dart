enum UpdateRequirement { none, optional, required, maintenance }

class UpdatePolicy {
  const UpdatePolicy({
    required this.latestVersion,
    required this.minimumVersion,
    required this.maintenance,
  });

  final String latestVersion;
  final String minimumVersion;
  final bool maintenance;
}

class UpdateDecision {
  const UpdateDecision(this.requirement, this.reason);
  final UpdateRequirement requirement;
  final String reason;
}

class UpdatePolicyEngine {
  const UpdatePolicyEngine._();

  static UpdateDecision evaluate({
    required String currentVersion,
    required UpdatePolicy policy,
  }) {
    if (policy.maintenance) {
      return const UpdateDecision(
        UpdateRequirement.maintenance,
        'Service maintenance is active. Local data access and export should remain available.',
      );
    }
    if (_compare(currentVersion, policy.minimumVersion) < 0) {
      return const UpdateDecision(
        UpdateRequirement.required,
        'This version is below the minimum supported security version.',
      );
    }
    if (_compare(currentVersion, policy.latestVersion) < 0) {
      return const UpdateDecision(
        UpdateRequirement.optional,
        'A newer version is available; the user may continue and be reminded later.',
      );
    }
    return const UpdateDecision(UpdateRequirement.none, 'The app is current.');
  }

  static int _compare(String left, String right) {
    List<int> parts(String value) => value
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final a = parts(left);
    final b = parts(right);
    for (var index = 0; index < 3; index++) {
      final difference =
          (index < a.length ? a[index] : 0) - (index < b.length ? b[index] : 0);
      if (difference != 0) return difference.sign;
    }
    return 0;
  }
}
