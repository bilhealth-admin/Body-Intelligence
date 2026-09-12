import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/environment/release_configuration_validator.dart';
import 'package:body_intelligence_log/app/environment/release_manifest_metadata.dart';
import 'package:crypto/crypto.dart';

const _defaultManifest =
    'docs/release/BIL_ANDROID_V14_FROZEN_SOURCE_MANIFEST_2026-09-12.md';

bool _boolEnvironment(Map<String, String> environment, String name) {
  final value = environment[name]?.trim().toLowerCase();
  return switch (value) {
    'true' => true,
    'false' || null || '' => false,
    _ => throw FormatException('$name must be true or false.'),
  };
}

int? _optionalPositiveInt(Map<String, String> environment, String name) {
  final raw = environment[name]?.trim();
  if (raw == null || raw.isEmpty) return null;
  final value = int.tryParse(raw);
  if (value == null || value <= 0) {
    throw FormatException('$name must be a positive integer.');
  }
  return value;
}

Future<({String digest, ReleaseManifestMetadata metadata})> _readManifest(
  String path,
) async {
  final file = File(path);
  if (!await file.exists()) {
    return (digest: '', metadata: ReleaseManifestMetadata.parse(''));
  }
  final bytes = await file.readAsBytes();
  return (
    digest: sha256.convert(bytes).toString(),
    metadata: ReleaseManifestMetadata.parse(utf8.decode(bytes)),
  );
}

Future<void> main() async {
  final environment = Platform.environment;
  try {
    final manifestPath =
        environment['BIL_RELEASE_MANIFEST_PATH']?.trim() ?? _defaultManifest;
    final manifest = await _readManifest(manifestPath);
    final issues = ReleaseConfigurationValidator.validate(
      ReleaseConfiguration(
        production: _boolEnvironment(environment, 'BIL_RELEASE_PRODUCTION'),
        applicationId: environment['BIL_RELEASE_APPLICATION_ID']?.trim() ?? '',
        cloudEnabled: _boolEnvironment(environment, 'BIL_USE_SUPABASE'),
        supabaseUrl: environment['SUPABASE_URL']?.trim() ?? '',
        supabaseAnonKey: environment['SUPABASE_ANON_KEY']?.trim() ?? '',
        serverUrl: environment['BIL_RECEIPT_SERVER_URL']?.trim() ?? '',
        paymentsEnabled: _boolEnvironment(environment, 'BIL_PAYMENTS_ENABLED'),
        storeConfigured: _boolEnvironment(environment, 'BIL_STORE_CONFIGURED'),
        platform: environment['BIL_RELEASE_PLATFORM']?.trim() ?? '',
        facebookRequired: _boolEnvironment(
          environment,
          'BIL_FACEBOOK_REQUIRED',
        ),
        facebookLoginEnabled: _boolEnvironment(
          environment,
          'BIL_FACEBOOK_LOGIN_ENABLED',
        ),
        facebookLoginReady: _boolEnvironment(
          environment,
          'BIL_FACEBOOK_LOGIN_READY',
        ),
        pushEnabled: _boolEnvironment(environment, 'BIL_PUSH_ENABLED'),
        pushProviderReady: _boolEnvironment(
          environment,
          'BIL_PUSH_PROVIDER_READY',
        ),
        mobileIntegrityRequired: _boolEnvironment(
          environment,
          'BIL_MOBILE_INTEGRITY_REQUIRED',
        ),
        mobileIntegrityBackendReleaseId:
            environment['BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID']?.trim() ??
            '',
        playIntegrityProjectNumber:
            environment['BIL_PLAY_INTEGRITY_PROJECT_NUMBER']?.trim() ?? '',
        sourceCommit: environment['BIL_SOURCE_COMMIT']?.trim() ?? '',
        auditedSourceCommit:
            environment['BIL_AUDITED_SOURCE_COMMIT']?.trim() ?? '',
        freezeManifestSha256: manifest.digest,
        auditedFreezeManifestSha256:
            environment['BIL_AUDITED_FREEZE_MANIFEST_SHA256']?.trim() ?? '',
        stagingManifestComplete: manifest.metadata.stagingManifestComplete,
        candidateFrozenOrAccepted: manifest.metadata.candidateFrozenOrAccepted,
        unresolvedReviewCount: manifest.metadata.unresolvedReviewCount,
        manifestReleaseVersion: manifest.metadata.releaseVersion,
        manifestReleaseBuildNumber: manifest.metadata.releaseBuildNumber,
        expectedReleaseBuildNumber: _optionalPositiveInt(
          environment,
          'BIL_RELEASE_EXPECTED_BUILD_NUMBER',
        ),
      ),
    );

    if (issues.isNotEmpty) {
      stderr.writeln('RELEASE_CONFIGURATION_GATE=FAIL');
      for (final issue in issues) {
        stderr.writeln('${issue.code}: ${issue.message}');
      }
      exitCode = 78;
      return;
    }

    stdout.writeln('RELEASE_CONFIGURATION_GATE=PASS');
    stdout.writeln('AUDITED_SOURCE_COMMIT_GATE=PASS');
    stdout.writeln('AUDITED_FREEZE_MANIFEST_GATE=PASS');
    stdout.writeln('FROZEN_MANIFEST_CONTENT_GATE=PASS');
  } on FormatException catch (error) {
    stderr.writeln('RELEASE_CONFIGURATION_GATE=FAIL');
    stderr.writeln('invalid_boolean_configuration: ${error.message}');
    exitCode = 78;
  }
}
