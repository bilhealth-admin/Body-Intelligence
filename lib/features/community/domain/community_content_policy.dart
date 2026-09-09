enum CommunityPolicyStatus { unavailable, acceptanceRequired, accepted }

final class CommunityContentPolicy {
  const CommunityContentPolicy._({
    required this.version,
    required this.documentUrl,
    this.localeCode,
    this.effectiveAt,
  });

  factory CommunityContentPolicy.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['version'];
    final rawDocumentUrl = json['document_url'];
    if (rawVersion is! String || rawDocumentUrl is! String) {
      throw const FormatException('Invalid Community policy payload');
    }

    final version = rawVersion.trim();
    final documentUrl = Uri.tryParse(rawDocumentUrl.trim());
    if (version.isEmpty ||
        version.length > 120 ||
        documentUrl == null ||
        documentUrl.scheme.toLowerCase() != 'https' ||
        documentUrl.host.isEmpty ||
        documentUrl.userInfo.isNotEmpty) {
      throw const FormatException('Invalid Community policy payload');
    }

    final rawLocaleCode = json['locale_code'];
    final localeCode =
        rawLocaleCode is String && rawLocaleCode.trim().isNotEmpty
        ? rawLocaleCode.trim()
        : null;
    final rawEffectiveAt = json['effective_at'];
    final effectiveAt = rawEffectiveAt is String
        ? DateTime.tryParse(rawEffectiveAt)?.toUtc()
        : null;
    if (rawEffectiveAt != null && effectiveAt == null) {
      throw const FormatException('Invalid Community policy payload');
    }

    return CommunityContentPolicy._(
      version: version,
      documentUrl: documentUrl,
      localeCode: localeCode,
      effectiveAt: effectiveAt,
    );
  }

  final String version;
  final Uri documentUrl;
  final String? localeCode;
  final DateTime? effectiveAt;
}

final class CommunityPolicyState {
  const CommunityPolicyState._({
    required this.status,
    this.policy,
    this.acceptedVersion,
  });

  const CommunityPolicyState.unavailable()
    : this._(status: CommunityPolicyStatus.unavailable);

  CommunityPolicyState.acceptanceRequired(CommunityContentPolicy policy)
    : this._(status: CommunityPolicyStatus.acceptanceRequired, policy: policy);

  factory CommunityPolicyState.accepted(
    CommunityContentPolicy policy, {
    required String acceptedVersion,
  }) {
    assert(acceptedVersion == policy.version);
    return CommunityPolicyState._(
      status: CommunityPolicyStatus.accepted,
      policy: policy,
      acceptedVersion: acceptedVersion,
    );
  }

  factory CommunityPolicyState.fromServerSnapshot(Map<String, dynamic> json) {
    final serverNow = DateTime.tryParse('${json['server_now']}')?.toUtc();
    final rawStatus = json['status'];
    if (serverNow == null || rawStatus is! String) {
      throw const FormatException('Invalid Community policy status payload');
    }
    if (rawStatus == 'unavailable') {
      return const CommunityPolicyState.unavailable();
    }
    if (rawStatus != 'accepted' && rawStatus != 'acceptance_required') {
      throw const FormatException('Invalid Community policy status payload');
    }

    final policy = CommunityContentPolicy.fromJson(json);
    final effectiveAt = policy.effectiveAt;
    final accepted = json['accepted'];
    if (effectiveAt == null ||
        effectiveAt.isAfter(serverNow) ||
        accepted is! bool ||
        accepted != (rawStatus == 'accepted')) {
      throw const FormatException('Invalid Community policy status payload');
    }

    if (!accepted) return CommunityPolicyState.acceptanceRequired(policy);
    final acceptedAt = DateTime.tryParse('${json['accepted_at']}')?.toUtc();
    if (acceptedAt == null || acceptedAt.isBefore(effectiveAt)) {
      throw const FormatException('Invalid Community policy status payload');
    }
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
  }

  final CommunityPolicyStatus status;
  final CommunityContentPolicy? policy;
  final String? acceptedVersion;

  bool get permitsCommunityPublishing =>
      status == CommunityPolicyStatus.accepted &&
      policy != null &&
      acceptedVersion == policy!.version;
}

enum CommunityPolicyAccessFailure {
  unavailable,
  acceptanceRequired,
  verificationFailed,
}

enum CommunityPolicyProtectedAction { publishing, messaging }

enum CommunityMembershipAccessFailure { suspended, relationshipBlocked }

final class CommunityPolicyAccessException implements Exception {
  const CommunityPolicyAccessException({
    required this.failure,
    this.policyVersion,
  });

  final CommunityPolicyAccessFailure failure;
  final String? policyVersion;

  String get code => switch (failure) {
    CommunityPolicyAccessFailure.unavailable => 'community_policy_unavailable',
    CommunityPolicyAccessFailure.acceptanceRequired =>
      'community_policy_acceptance_required',
    CommunityPolicyAccessFailure.verificationFailed =>
      'community_policy_verification_failed',
  };

  String englishMessage(CommunityPolicyProtectedAction action) => switch ((
    failure,
    action,
  )) {
    (
      CommunityPolicyAccessFailure.unavailable,
      CommunityPolicyProtectedAction.publishing,
    ) =>
      'Community publishing is locked because no active policy is available.',
    (
      CommunityPolicyAccessFailure.unavailable,
      CommunityPolicyProtectedAction.messaging,
    ) =>
      'Community messages are locked because no active policy is available.',
    (
      CommunityPolicyAccessFailure.acceptanceRequired,
      CommunityPolicyProtectedAction.publishing,
    ) =>
      'Review and accept the active Community policy before publishing.',
    (
      CommunityPolicyAccessFailure.acceptanceRequired,
      CommunityPolicyProtectedAction.messaging,
    ) =>
      'Review and accept the active Community policy before messaging.',
    (
      CommunityPolicyAccessFailure.verificationFailed,
      CommunityPolicyProtectedAction.publishing,
    ) =>
      'BIL could not verify your policy acceptance. Publishing remains locked.',
    (
      CommunityPolicyAccessFailure.verificationFailed,
      CommunityPolicyProtectedAction.messaging,
    ) =>
      'BIL could not verify your policy acceptance. Messaging remains locked.',
  };

  String arabicMessage(CommunityPolicyProtectedAction action) =>
      switch ((failure, action)) {
        (
          CommunityPolicyAccessFailure.unavailable,
          CommunityPolicyProtectedAction.publishing,
        ) =>
          'النشر في المجتمع مقفل لعدم توفر سياسة فعالة.',
        (
          CommunityPolicyAccessFailure.unavailable,
          CommunityPolicyProtectedAction.messaging,
        ) =>
          'رسائل المجتمع مقفلة لعدم توفر سياسة فعالة.',
        (
          CommunityPolicyAccessFailure.acceptanceRequired,
          CommunityPolicyProtectedAction.publishing,
        ) =>
          'راجع سياسة المجتمع الفعالة ووافق عليها قبل النشر.',
        (
          CommunityPolicyAccessFailure.acceptanceRequired,
          CommunityPolicyProtectedAction.messaging,
        ) =>
          'راجع سياسة المجتمع الفعالة ووافق عليها قبل المراسلة.',
        (
          CommunityPolicyAccessFailure.verificationFailed,
          CommunityPolicyProtectedAction.publishing,
        ) =>
          'تعذر على BIL التحقق من قبول السياسة. يظل النشر مقفلًا.',
        (
          CommunityPolicyAccessFailure.verificationFailed,
          CommunityPolicyProtectedAction.messaging,
        ) =>
          'تعذر على BIL التحقق من قبول السياسة. تظل المراسلة مقفلة.',
      };

  @override
  String toString() => policyVersion == null ? code : '$code:$policyVersion';
}

final class CommunityMembershipAccessException implements Exception {
  const CommunityMembershipAccessException({required this.failure});

  final CommunityMembershipAccessFailure failure;

  String get code => switch (failure) {
    CommunityMembershipAccessFailure.suspended => 'community_access_suspended',
    CommunityMembershipAccessFailure.relationshipBlocked =>
      'community_relationship_blocked',
  };

  String englishMessage(CommunityPolicyProtectedAction action) => switch ((
    failure,
    action,
  )) {
    (
      CommunityMembershipAccessFailure.suspended,
      CommunityPolicyProtectedAction.publishing,
    ) =>
      'Your Community access is suspended. Publishing remains locked.',
    (
      CommunityMembershipAccessFailure.suspended,
      CommunityPolicyProtectedAction.messaging,
    ) =>
      'Your Community access is suspended. Messaging remains locked.',
    (
      CommunityMembershipAccessFailure.relationshipBlocked,
      CommunityPolicyProtectedAction.publishing,
    ) =>
      'This Community action is unavailable because the relationship is blocked.',
    (
      CommunityMembershipAccessFailure.relationshipBlocked,
      CommunityPolicyProtectedAction.messaging,
    ) =>
      'Messaging is unavailable because the relationship is blocked.',
  };

  String arabicMessage(CommunityPolicyProtectedAction action) =>
      switch ((failure, action)) {
        (
          CommunityMembershipAccessFailure.suspended,
          CommunityPolicyProtectedAction.publishing,
        ) =>
          'تم إيقاف وصولك إلى المجتمع. يظل النشر مقفلًا.',
        (
          CommunityMembershipAccessFailure.suspended,
          CommunityPolicyProtectedAction.messaging,
        ) =>
          'تم إيقاف وصولك إلى المجتمع. تظل المراسلة مقفلة.',
        (
          CommunityMembershipAccessFailure.relationshipBlocked,
          CommunityPolicyProtectedAction.publishing,
        ) =>
          'هذا الإجراء غير متاح لأن العلاقة محظورة.',
        (
          CommunityMembershipAccessFailure.relationshipBlocked,
          CommunityPolicyProtectedAction.messaging,
        ) =>
          'المراسلة غير متاحة لأن العلاقة محظورة.',
      };

  @override
  String toString() => code;
}
