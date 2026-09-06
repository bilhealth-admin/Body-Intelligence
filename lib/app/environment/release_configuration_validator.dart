class ReleaseConfiguration {
  const ReleaseConfiguration({
    required this.production,
    required this.applicationId,
    required this.cloudEnabled,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.serverUrl,
    required this.paymentsEnabled,
    required this.storeConfigured,
    this.platform = '',
    this.facebookRequired = false,
    this.facebookLoginEnabled = false,
    this.facebookLoginReady = false,
    this.pushEnabled = false,
    this.pushProviderReady = false,
    this.mobileIntegrityRequired = false,
    this.mobileIntegrityBackendReleaseId = '',
    this.playIntegrityProjectNumber = '',
    this.sourceCommit = '',
    this.auditedSourceCommit = '',
    this.freezeManifestSha256 = '',
    this.auditedFreezeManifestSha256 = '',
    this.stagingManifestComplete = false,
    this.candidateFrozenOrAccepted = false,
    this.unresolvedReviewCount,
    this.manifestReleaseVersion = '',
    this.manifestReleaseBuildNumber,
  });

  final bool production;
  final String applicationId;
  final bool cloudEnabled;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String serverUrl;
  final bool paymentsEnabled;
  final bool storeConfigured;
  final String platform;
  final bool facebookRequired;
  final bool facebookLoginEnabled;
  final bool facebookLoginReady;
  final bool pushEnabled;
  final bool pushProviderReady;
  final bool mobileIntegrityRequired;
  final String mobileIntegrityBackendReleaseId;
  final String playIntegrityProjectNumber;
  final String sourceCommit;
  final String auditedSourceCommit;
  final String freezeManifestSha256;
  final String auditedFreezeManifestSha256;
  final bool stagingManifestComplete;
  final bool candidateFrozenOrAccepted;
  final int? unresolvedReviewCount;
  final String manifestReleaseVersion;
  final int? manifestReleaseBuildNumber;
}

class ReleaseConfigurationIssue {
  const ReleaseConfigurationIssue(this.code, this.message);

  final String code;
  final String message;
}

class ReleaseConfigurationValidator {
  const ReleaseConfigurationValidator._();

  static const approvedApplicationId = 'com.bilhealth.bodyintelligencelog';

  static List<ReleaseConfigurationIssue> validate(
    ReleaseConfiguration configuration,
  ) {
    final issues = <ReleaseConfigurationIssue>[];
    final applicationId = configuration.applicationId.trim();

    if (applicationId.isEmpty || applicationId.startsWith('com.example')) {
      issues.add(
        const ReleaseConfigurationIssue(
          'invalid_application_id',
          'A permanent non-template application identifier is required.',
        ),
      );
    }

    if (configuration.production && applicationId != approvedApplicationId) {
      issues.add(
        const ReleaseConfigurationIssue(
          'unapproved_production_application_id',
          'Production requires the owner-approved BIL application identifier.',
        ),
      );
    }

    if (configuration.cloudEnabled) {
      if (!_isHttps(configuration.supabaseUrl)) {
        issues.add(
          const ReleaseConfigurationIssue(
            'invalid_supabase_url',
            'Enabled cloud configuration requires an HTTPS Supabase URL.',
          ),
        );
      }
      if (configuration.supabaseAnonKey.trim().isEmpty) {
        issues.add(
          const ReleaseConfigurationIssue(
            'missing_supabase_anon_key',
            'Enabled cloud configuration requires a public anonymous key.',
          ),
        );
      }
    }

    if (configuration.paymentsEnabled && !_isHttps(configuration.serverUrl)) {
      issues.add(
        const ReleaseConfigurationIssue(
          'payments_without_server',
          'Payments require an HTTPS server boundary for receipt validation.',
        ),
      );
    }

    if (configuration.production &&
        configuration.paymentsEnabled &&
        !configuration.storeConfigured) {
      issues.add(
        const ReleaseConfigurationIssue(
          'payments_without_store',
          'Production payments cannot be claimed before store activation.',
        ),
      );
    }

    if (configuration.facebookLoginReady &&
        !configuration.facebookLoginEnabled) {
      issues.add(
        const ReleaseConfigurationIssue(
          'facebook_ready_without_feature',
          'Facebook readiness cannot be true while the feature is disabled.',
        ),
      );
    }

    if (configuration.production &&
        configuration.facebookRequired &&
        (!configuration.facebookLoginEnabled ||
            !configuration.facebookLoginReady)) {
      issues.add(
        const ReleaseConfigurationIssue(
          'required_facebook_not_ready',
          'This production candidate requires both Facebook release gates.',
        ),
      );
    }

    if (configuration.pushEnabled != configuration.pushProviderReady) {
      issues.add(
        const ReleaseConfigurationIssue(
          'push_gate_mismatch',
          'Push feature and provider readiness must fail closed together.',
        ),
      );
    }

    if (configuration.production && !configuration.mobileIntegrityRequired) {
      issues.add(
        const ReleaseConfigurationIssue(
          'mobile_integrity_not_required',
          'Production must require the platform mobile-integrity boundary.',
        ),
      );
    }

    if (configuration.production &&
        configuration.mobileIntegrityBackendReleaseId.trim().isEmpty) {
      issues.add(
        const ReleaseConfigurationIssue(
          'missing_mobile_integrity_backend_release',
          'Production requires the reviewed backend integrity release binding.',
        ),
      );
    }

    final platform = configuration.platform.trim().toLowerCase();
    if (configuration.production &&
        platform != 'android' &&
        platform != 'ios') {
      issues.add(
        const ReleaseConfigurationIssue(
          'invalid_release_platform',
          'Production release validation requires android or ios.',
        ),
      );
    }
    if (configuration.production &&
        platform == 'android' &&
        !RegExp(
          r'^[1-9][0-9]+$',
        ).hasMatch(configuration.playIntegrityProjectNumber.trim())) {
      issues.add(
        const ReleaseConfigurationIssue(
          'invalid_play_integrity_project',
          'Android production requires its numeric Play-linked Cloud project.',
        ),
      );
    }

    if (configuration.production &&
        (!_isSha1(configuration.sourceCommit) ||
            !_isSha1(configuration.auditedSourceCommit) ||
            configuration.sourceCommit.toLowerCase() !=
                configuration.auditedSourceCommit.toLowerCase())) {
      issues.add(
        const ReleaseConfigurationIssue(
          'unaudited_source_commit',
          'The checked-out commit must equal the frozen audited commit.',
        ),
      );
    }

    if (configuration.production &&
        (!_isSha256(configuration.freezeManifestSha256) ||
            !_isSha256(configuration.auditedFreezeManifestSha256) ||
            configuration.freezeManifestSha256.toLowerCase() !=
                configuration.auditedFreezeManifestSha256.toLowerCase())) {
      issues.add(
        const ReleaseConfigurationIssue(
          'unapproved_freeze_manifest',
          'The release manifest digest must equal the audited digest.',
        ),
      );
    }

    if (configuration.production && !configuration.stagingManifestComplete) {
      issues.add(
        const ReleaseConfigurationIssue(
          'incomplete_release_manifest',
          'The release manifest must explicitly declare itself complete.',
        ),
      );
    }

    if (configuration.production && !configuration.candidateFrozenOrAccepted) {
      issues.add(
        const ReleaseConfigurationIssue(
          'release_candidate_not_accepted',
          'The release manifest must explicitly accept the frozen candidate.',
        ),
      );
    }

    if (configuration.production && configuration.unresolvedReviewCount != 0) {
      issues.add(
        const ReleaseConfigurationIssue(
          'unresolved_release_review_items',
          'The frozen release manifest must contain zero unresolved reviews.',
        ),
      );
    }

    if (configuration.production &&
        (configuration.manifestReleaseVersion != '1.0.0' ||
            configuration.manifestReleaseBuildNumber != 8)) {
      issues.add(
        const ReleaseConfigurationIssue(
          'wrong_frozen_release_version',
          'The accepted manifest must bind exactly version 1.0.0 build 8.',
        ),
      );
    }

    return List.unmodifiable(issues);
  }

  static bool _isHttps(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  static bool _isSha1(String value) =>
      RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(value.trim());

  static bool _isSha256(String value) =>
      RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value.trim());
}
