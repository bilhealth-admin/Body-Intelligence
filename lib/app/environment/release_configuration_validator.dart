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
  });

  final bool production;
  final String applicationId;
  final bool cloudEnabled;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String serverUrl;
  final bool paymentsEnabled;
  final bool storeConfigured;
}

class ReleaseConfigurationIssue {
  const ReleaseConfigurationIssue(this.code, this.message);

  final String code;
  final String message;
}

class ReleaseConfigurationValidator {
  const ReleaseConfigurationValidator._();

  static const approvedApplicationId =
      'com.bilhealth.bodyintelligencelog';

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

    return List.unmodifiable(issues);
  }

  static bool _isHttps(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
