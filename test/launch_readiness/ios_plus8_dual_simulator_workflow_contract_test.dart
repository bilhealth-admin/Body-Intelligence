import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String workflow;
  late String uiEntrypoint;
  late String uiDriver;
  late String watchdogDriver;
  late String backendOracle;
  late String runtimeProbe;
  late String scopeProbe;
  late String idbLock;

  setUpAll(() {
    workflow = File(
      '.github/workflows/bil_ios_plus8_dual_simulator_qa.yml',
    ).readAsStringSync();
    uiEntrypoint = File(
      'tool/release/ios_plus8_dual_simulator_ui.sh',
    ).readAsStringSync();
    uiDriver = <File>[
      File('tool/release/ios_plus8_dual_simulator_ui.sh'),
      ...Directory(
        'tool/release/ios_plus8_simulator_ui',
      ).listSync().whereType<File>().where((file) => file.path.endsWith('.sh')),
    ].map((file) => file.readAsStringSync()).join('\n');
    watchdogDriver = File(
      'tool/release/ios_plus8_reinstate_watchdog.sh',
    ).readAsStringSync();
    backendOracle = <File>[
      File('tool/release/ios_plus8_dual_account_canary.mjs'),
      ...Directory('tool/release/ios_plus8_canary')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.mjs')),
    ].map((file) => file.readAsStringSync()).join('\n');
    runtimeProbe = File(
      'tool/release/ios_plus8_canary_runtime_test.mjs',
    ).readAsStringSync();
    scopeProbe = File(
      'tool/release/ios_plus8_secret_scope_test.sh',
    ).readAsStringSync();
    idbLock = File(
      'tool/release/ios_plus8_idb_requirements.lock',
    ).readAsStringSync();
  });

  test('cloud simulator workflow is manual and fail-closed to +8', () {
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, isNot(contains('\n  push:')));
    expect(workflow, contains("[[ \"\$BUILD_NUMBER\" == '8' ]]"));
    expect(workflow, contains(r'^version:[[:space:]]+1\.0\.0\+8'));
    expect(workflow, contains('--build-number 8'));
    expect(workflow, contains('Build 7 must never be built or tested here'));
    expect(workflow, contains('BIL_PLUS8_AUDITED_SOURCE_SHA'));
    expect(workflow, contains('BIL_PLUS8_STAGING_MANIFEST_SHA256'));
    expect(
      workflow,
      contains('dart run tool/release/validate_release_configuration.dart'),
    );
    expect(workflow, contains('BIL_MOBILE_INTEGRITY_REQUIRED: true'));
    expect(workflow, contains('BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID'));
    expect(workflow, isNot(contains('allow_reviewer_five_token')));
    expect(uiDriver, contains('REVIEWER_APPROVAL_REWARD_TOKENS=0'));
  });

  test(
    'workflow creates independent iPhone owner and iPad reviewer sessions',
    () {
      expect(workflow, contains('IPHONE_UDID'));
      expect(workflow, contains('IPAD_UDID'));
      expect(workflow, contains('BIL-plus8-iPhone-'));
      expect(workflow, contains('BIL-plus8-iPad-'));
      expect(workflow, isNot(contains('deep-link, rotate')));
      expect(workflow, isNot(contains('idb ui rotate')));
      expect(workflow, contains('01-cold-launch.png'));
      expect(workflow, contains('03-relaunch.png'));
      expect(workflow, contains('IPAD_LANDSCAPE_WIDGET_CONTRACT=PASS'));
      expect(
        workflow,
        contains('IPAD_LANDSCAPE_SIMULATOR_RUNTIME=NOT_EXECUTED'),
      );
      expect(workflow, contains('fb-idb 1.1.7 has no supported rotation'));
      expect(workflow, contains('runner.log'));
    },
  );

  test('review credentials remain masked in one mode-0600 step scope', () {
    expect(workflow, contains('secrets.BIL_IOS_QA_OWNER_EMAIL'));
    expect(workflow, contains('secrets.BIL_IOS_QA_OWNER_PASSWORD'));
    expect(workflow, contains('secrets.BIL_SUPABASE_SERVICE_ROLE_KEY'));
    expect(workflow, contains('APP_STORE_CONNECT_PRIVATE_KEY_BASE64'));
    expect(workflow, isNot(contains('BIL_REVIEWER_EMAIL<<')));
    expect(workflow, isNot(contains('BIL_REVIEWER_PASSWORD<<')));
    expect(workflow, isNot(contains('process.env.GITHUB_ENV')));
    expect(uiDriver, contains('demoAccountName'));
    expect(uiDriver, contains('demoAccountPassword'));
    expect(uiDriver, contains('::add-mask::'));
    expect(uiDriver, contains('mode: 0o600'));
    expect(uiDriver, contains('chmod 600'));
    expect(uiDriver, isNot(contains('GITHUB_ENV')));
    expect(uiDriver, isNot(contains('set -x')));
    expect(workflow, isNot(contains('owner_email:')));
    expect(workflow, isNot(contains('reviewer_password:')));
    expect(uiEntrypoint, contains('unset OWNER_EMAIL OWNER_PASSWORD'));
    expect(uiDriver, contains('install_sanitized_apple_tool_wrappers'));
    expect(uiDriver, contains('-u BIL_SUPABASE_SERVICE_ROLE_KEY'));
    expect(uiDriver, contains('-u ASC_PRIVATE_KEY_BASE64'));
    expect(
      workflow,
      contains('bash tool/release/ios_plus8_secret_scope_test.sh'),
    );
    expect(scopeProbe, contains('IOS_PLUS8_APPLE_TOOL_SECRET_SCOPE=PASS'));
    final bootstrap = uiEntrypoint.indexOf('bootstrap');
    final credentialDelete = uiEntrypoint.lastIndexOf(
      'rm -f "\$REVIEW_CREDENTIALS"',
    );
    expect(bootstrap, greaterThan(0));
    expect(credentialDelete, greaterThan(bootstrap));
    expect(
      uiEntrypoint,
      contains('BIL_REVIEW_CREDENTIALS_PATH="\$REVIEW_CREDENTIALS"'),
    );
  });

  test(
    'runtime request uses the loaded anonymous key under injected fetch',
    () {
      expect(backendOracle, contains('apikey: supabaseConfig.anon'));
      expect(backendOracle, isNot(contains('apikey: config.anon')));
      expect(runtimeProbe, contains('globalThis.fetch = async'));
      expect(runtimeProbe, contains('runtime.supabaseConfig.anon'));
      expect(
        workflow,
        contains('node tool/release/ios_plus8_canary_runtime_test.mjs'),
      );
      final result = Process.runSync('node', <String>[
        'tool/release/ios_plus8_canary_runtime_test.mjs',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(
        result.stdout,
        contains('IOS_PLUS8_CANARY_RUNTIME_FETCH_INJECTION=PASS'),
      );
      expect(
        result.stdout,
        contains('IOS_PLUS8_ADMIN_USER_SCAN_CAP_FAIL_CLOSED=PASS'),
      );
    },
  );

  test('third-party workflow tools are commit or checksum locked', () {
    final actionReferences = RegExp(
      r'uses:\s+[^\s@]+@([^\s]+)',
    ).allMatches(workflow).map((match) => match.group(1)!).toList();
    expect(actionReferences, isNotEmpty);
    for (final reference in actionReferences) {
      expect(reference, matches(RegExp(r'^[0-9a-f]{40}$')));
    }
    expect(workflow, isNot(contains('brew install')));
    expect(
      workflow,
      contains(
        '3b72cc6a9a5b1a22a188205a84090d3a294347a846180efd755cf1a3c848e3e7',
      ),
    );
    expect(workflow, contains('--no-deps --require-hashes'));
    expect(workflow, contains('python-version: \'3.11.15\''));
    final requirements = idbLock
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'));
    expect(requirements.length, 10);
    for (final requirement in requirements) {
      expect(requirement, contains('https://files.pythonhosted.org/'));
      expect(requirement, matches(RegExp(r'#sha256=[0-9a-f]{64}$')));
    }
  });

  test('UI sequence and server oracle cover the two-account canary', () {
    for (final operation in <String>[
      'verify-friend-request',
      'verify-friend-accepted',
      'verify-reviewer-message',
      'verify-owner-message',
      'verify-individual-reset',
      'verify-target-notification',
      'verify-moderator-added',
      'verify-moderator-removed',
      'verify-approved-pending',
      'verify-approved',
      'verify-rejected-pending',
      'verify-rejected',
      'verify-block',
      'verify-blocked-message-denied',
      'verify-suspended',
      'verify-suspended-post-denied',
      'verify-reinstated',
      'create-restored-post',
      'verify-owner-protection',
    ]) {
      expect(uiDriver, contains(operation), reason: operation);
      expect(backendOracle, contains("'$operation'"), reason: operation);
    }
    expect(uiDriver, contains('login "\$IPHONE_UDID" "\$owner_email_secret"'));
    expect(uiDriver, contains('login "\$IPAD_UDID" "\$reviewer_email_secret"'));
    expect(uiDriver, contains("bil://community/chat/\$OWNER_ID"));
    expect(uiDriver, contains("bil://community/chat/\$REVIEWER_ID"));
    expect(backendOracle, contains('FRIENDSHIP_ID_SHA256='));
    expect(backendOracle, contains('MESSAGE_ID_SHA256='));
    expect(backendOracle, contains('POST_ID_SHA256='));
    expect(backendOracle, contains('CANARY_RUN_SHA256='));
    expect(backendOracle, contains('DISPOSABLE_ACCOUNT_SHA256='));
    expect(backendOracle, contains('INDIVIDUAL_RESET_ID_SHA256='));
    expect(backendOracle, contains('TARGET_NOTIFICATION_ID_SHA256='));
  });

  test(
    'owner authority, reviewer denial, and mutation boundaries are explicit',
    () {
      expect(uiDriver, contains("'Moderator access is required.'"));
      expect(uiDriver, contains("'BIL Administration'"));
      expect(uiDriver, contains("'Suspend Community access'"));
      expect(uiDriver, contains("'Restore access'"));
      expect(backendOracle, contains('reviewer_admin_denial_preflight_failed'));
      expect(backendOracle, contains('protected_administrator'));
      expect(
        backendOracle,
        contains('REVIEWER_ADMIN_AND_MODERATOR_DENIAL=PASS'),
      );
      expect(workflow, contains('PRODUCTION_WIDE_ADMIN_ACTIONS_NOT_RUN='));
      expect(backendOracle, isNot(contains("operation: 'global_reset'")));
      expect(uiDriver, contains('verify-individual-reset'));
      expect(uiDriver, contains('verify-target-notification'));
      expect(uiDriver, contains('verify-moderator-added'));
      expect(uiDriver, contains('verify-moderator-removed'));
      expect(backendOracle, contains('INDIVIDUAL_RESET_PLUS_2500=PASS'));
      expect(
        backendOracle,
        contains('TARGET_NOTIFICATION_EXACT_TEXT_AND_RECIPIENT=PASS'),
      );
      expect(backendOracle, contains('disposable.userId'));
      expect(
        backendOracle,
        isNot(contains('state.reviewer.userId && row?.reason')),
      );
      expect(uiDriver, contains('verify-rejected'));
      expect(uiDriver, contains('verify-approved'));
      expect(
        backendOracle,
        contains('OWNER_IPHONE_REVIEWER_POST_REJECTION_UI_AND_SERVER=PASS'),
      );
      expect(
        backendOracle,
        contains('OWNER_IPHONE_DISPOSABLE_POST_APPROVAL_UI_AND_SERVER=PASS'),
      );
      expect(
        backendOracle,
        isNot(
          contains('OWNER_IPHONE_REVIEWER_POST_APPROVAL_UI_AND_SERVER=PASS'),
        ),
      );
      expect(
        uiDriver,
        contains('has_markers "\$IPAD_UDID" "\$REJECTED_POST" \'Rejected\''),
      );
      expect(
        uiEntrypoint,
        contains('APPLE_REVIEWER_IPAD_REJECTED_POST_VISIBLE_UI=PASS'),
      );
      expect(backendOracle, contains('rewardDelta !== 5'));
      expect(backendOracle, contains('admin_user_scan_page_cap_reached'));
    },
  );

  test('backend restoration is fail-closed and precedes artifact creation', () {
    final cleanup = workflow.indexOf(
      'Restore and remove every backend canary artifact',
    );
    final privacyScan = workflow.indexOf(
      'Scan the upload set for private account data and bearer tokens',
    );
    final upload = workflow.indexOf('Upload +8 simulator evidence');
    expect(cleanup, greaterThan(0));
    expect(privacyScan, greaterThan(cleanup));
    expect(upload, greaterThan(privacyScan));
    expect(workflow, isNot(contains('set +e')));
    expect(uiDriver, isNot(contains('set +e')));
    expect(backendOracle, contains('// Reinstate first'));
    expect(
      backendOracle,
      contains('MESSAGE_TOMBSTONES_BOTH_PARTIES_THEN_HARD_DELETE=PASS'),
    );
    expect(
      backendOracle,
      contains('FRIENDSHIP_RESTORED_TO_ORIGINAL_NONE=PASS'),
    );
    expect(
      backendOracle,
      contains('BLOCK_ROWS_RESTORED_TO_ORIGINAL_NONE=PASS'),
    );
    expect(
      backendOracle,
      contains('REVIEWER_POST_SOFT_DELETE_THEN_HARD_DELETE=PASS'),
    );
    expect(backendOracle, contains('REVIEWER_NEVER_SUSPENDED=PASS'));
    expect(backendOracle, contains('REVIEWER_CREDIT_UNCHANGED=PASS'));
    expect(
      backendOracle,
      contains('DISPOSABLE_ACCOUNT_AND_PUBLIC_ROWS_DELETED=PASS'),
    );
    expect(
      backendOracle,
      contains('SERVICE_ROLE_EXACT_IDS_AND_MARKERS_ZERO_READBACK=PASS'),
    );
    expect(backendOracle, contains("serviceSelect('bil_messages'"));
    expect(backendOracle, contains("serviceSelect('bil_community_posts'"));
    expect(backendOracle, contains("serviceSelect('bil_friendships'"));
    expect(backendOracle, contains("serviceSelect('bil_blocks'"));
    expect(
      backendOracle,
      contains(
        r'and(requester_id.eq.${state.owner.userId},addressee_id.eq.${state.reviewer.userId})',
      ),
    );
    expect(
      backendOracle,
      contains('preexisting_friendship_must_not_be_overwritten'),
    );
    expect(
      backendOracle,
      contains('preexisting_block_must_not_be_overwritten'),
    );
    expect(backendOracle, contains('reviewer_was_already_suspended'));
  });

  test('artifact publication requires cleanup and privacy scan success', () {
    expect(
      workflow,
      contains(
        "if: always() && steps.cross_account_canary.outcome == 'success' && steps.backend_cleanup.outcome == 'success' && steps.privacy_scan.outcome == 'success'",
      ),
    );
    expect(workflow, contains('scan-evidence'));
    expect(backendOracle, contains('artifact_exact_private_value_detected'));
    expect(backendOracle, contains('artifact_jwt_detected'));
    expect(
      backendOracle,
      contains('AUTHENTICATED_RAW_UI_AND_LOGS_EXCLUDED=true'),
    );
    expect(uiDriver, contains('PRIVATE_UI_DIR="\$RUNNER_TEMP/bil-private-ui"'));
    expect(uiDriver, contains('AUTHENTICATED_RAW_SCREENSHOTS_UPLOADED=false'));
  });

  test('independent watchdog restores and deletes the exact disposable run', () {
    expect(workflow, contains('reinstate-watchdog:'));
    expect(workflow, contains('needs: dual-simulator-qa'));
    expect(
      workflow,
      contains('bash tool/release/ios_plus8_reinstate_watchdog.sh'),
    );
    expect(watchdogDriver, contains('unset OWNER_EMAIL OWNER_PASSWORD'));
    expect(watchdogDriver, contains('load_private_review_account'));
    expect(watchdogDriver, isNot(contains('GITHUB_ENV')));
    expect(backendOracle, contains('watchdog_multiple_exact_suspensions'));
    expect(backendOracle, contains('watchdog_reinstate_postcondition_failed'));
    expect(backendOracle, contains('watchdog_friend_pair_residue'));
    expect(backendOracle, contains('watchdog_message_residue'));
    expect(backendOracle, contains('watchdog_reviewer_post_residue'));
    expect(
      backendOracle,
      contains(
        'await cleanReviewerOwnerRun(owner, reviewerId, disposableMatches.length === 1)',
      ),
    );
    expect(
      backendOracle,
      isNot(contains('if (disposableMatches.length === 1)')),
    );
    expect(backendOracle, contains('INDEPENDENT_REINSTATE_WATCHDOG=PASS'));
    expect(
      backendOracle,
      contains('INDEPENDENT_REVIEWER_OWNER_RESIDUE_WATCHDOG=PASS'),
    );
    expect(
      backendOracle,
      contains('INDEPENDENT_DISPOSABLE_ACCOUNT_DELETE=PASS'),
    );
  });

  test(
    'security-sensitive canary is split into bounded single-purpose modules',
    () {
      final entry = File('tool/release/ios_plus8_dual_account_canary.mjs');
      final modules = Directory('tool/release/ios_plus8_canary')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.mjs'))
          .toList();
      expect(entry.readAsLinesSync().length, lessThanOrEqualTo(100));
      expect(
        modules.map((file) => file.uri.pathSegments.last),
        containsAll(<String>[
          'runtime.mjs',
          'setup.mjs',
          'community.mjs',
          'owner_admin.mjs',
          'disposable_account.mjs',
          'service_runtime.mjs',
          'cleanup_evidence.mjs',
          'evidence_io.mjs',
        ]),
      );
      for (final module in modules) {
        expect(
          module.readAsLinesSync().length,
          lessThanOrEqualTo(300),
          reason: module.path,
        );
      }
      expect(
        File(
          'tool/release/ios_plus8_dual_simulator_ui.sh',
        ).readAsLinesSync().length,
        lessThanOrEqualTo(120),
      );
      expect(
        File(
          'tool/release/ios_plus8_reinstate_watchdog.sh',
        ).readAsLinesSync().length,
        lessThanOrEqualTo(120),
      );
      for (final shell
          in Directory('tool/release/ios_plus8_simulator_ui')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.sh'))) {
        expect(shell.readAsLinesSync().length, lessThanOrEqualTo(300));
      }
    },
  );

  test('simulator evidence cannot be mistaken for signed-device evidence', () {
    expect(workflow, contains('SIMULATOR_BINARY=UNSIGNED_DEBUG_APP'));
    expect(workflow, contains('SIMULATOR_ATTEMPT_SCOPE='));
    expect(workflow, isNot(contains('SIMULATOR_PROVES=')));
    expect(workflow, contains('AUTHENTICATED_CANARY_RESULT='));
    expect(workflow, contains('SIMULATOR_INTEGRITY_BOUNDARY='));
    expect(workflow, contains('SIGNED_PHYSICAL_OR_TESTFLIGHT_STILL_REQUIRED='));
    expect(workflow, contains('Sign in with Apple credential sheet'));
    expect(workflow, contains('App Attest production assertion'));
    expect(workflow, contains('Facebook provider callback'));
    expect(workflow, contains('StoreKit purchase and restore'));
    expect(workflow, contains('APPLE_REVIEWER_POST_APPROVAL_EXCLUDED='));
    expect(workflow, contains('exhaustive signed UI absence is not claimed'));
    expect(workflow, contains('runs-on: ubuntu-24.04'));
    expect(workflow, contains('WATCHDOG_BOUNDARY='));
    expect(workflow, isNot(contains('flutter build ipa')));
    expect(workflow, isNot(contains('--upload-app')));
  });
}
