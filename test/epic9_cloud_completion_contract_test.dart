import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test(
    'community and push stay hidden until cloud credentials and flags exist',
    () {
      final environment = source('lib/app/environment/app_environment.dart');
      final settings = source('lib/features/settings/settings_page.dart');
      expect(environment, contains("'BIL_COMMUNITY_ENABLED'"));
      expect(environment, contains("'BIL_PUSH_ENABLED'"));
      expect(environment, contains('defaultValue: false'));
      expect(environment, contains('cloudConfigured && communityEnabled'));
      expect(environment, contains('communityConfigured && pushEnabled'));
      expect(settings, contains('if (AppEnvironment.communityConfigured)'));
    },
  );

  test(
    'cloud boundary enforces privacy abuse prevention moderation and deletion',
    () {
      final migration = source(
        'supabase/migrations/202608040002_bil_community_cloud_completion.sql',
      );
      for (final term in <String>[
        'bil_profiles_privacy_read',
        "profile_visibility in ('public','friends','private')",
        'bil_consume_rate_limit',
        'bil_require_community_policy',
        'bil_content_policies_active_read',
        'bil_list_open_community_reports',
        'bil_moderate_community_report',
        'bil_community_moderators',
        'bil_posts_audit',
        'bil_messages_audit',
        'bil_friendships_audit',
        'bil_request_account_deletion',
        'bil_push_outbox',
        'bil_register_push_token',
        'sensitive_preview_allowed=false',
      ]) {
        expect(migration, contains(term), reason: term);
      }
      expect(
        migration,
        contains("array['body', 'message', 'health', 'token']"),
      );
    },
  );

  test(
    'authenticated repository covers privacy social safety and moderation loops',
    () {
      final repository = source(
        'lib/features/community/data/community_repository.dart',
      );
      for (final method in <String>[
        'searchProfiles',
        'saveMyProfile',
        'requestFriend',
        'follow',
        'unfollow',
        'sendMessage',
        'deleteMessage',
        'report',
        'blockMember',
        'deletePost',
        'acceptContentPolicy',
        'loadOpenModerationReports',
        'moderateReport',
        'requestAccountDeletion',
      ]) {
        expect(repository, contains(method), reason: method);
      }
    },
  );

  test(
    'push infrastructure is opt-in generic on lock screen and deep-link capable',
    () {
      final service = source(
        'lib/features/notifications/services/community_push_service.dart',
      );
      final settings = source(
        'lib/features/notifications/presentation/notification_settings_page.dart',
      );
      final dispatch = source('supabase/functions/community_push_dispatch.ts');
      final androidBridge = source(
        'android/app/src/main/kotlin/com/kadem/bil/BILPushProvider.kt',
      );
      final android = source('android/app/src/main/AndroidManifest.xml');
      final ios = source('ios/Runner/Info.plist');
      final deepLinks = source(
        'lib/features/notifications/domain/community_deep_link.dart',
      );
      final router = source('lib/app/router/app_router.dart');
      expect(service, contains('AppEnvironment.pushConfigured'));
      expect(service, contains('bil_disable_push_tokens'));
      expect(service, contains('bil_set_sensitive_push_previews'));
      expect(service, contains('FlutterTimezone.getLocalTimezone'));
      expect(settings, contains("Key('community-cloud-push')"));
      expect(settings, contains("Key('sensitive-lock-screen-preview')"));
      expect(dispatch, contains('You have a new private update.'));
      expect(dispatch, contains('sensitive_preview_allowed'));
      expect(dispatch, contains('deep_link'));
      expect(androidBridge, contains('BILPushProvider'));
      expect(androidBridge, contains('push_provider_not_configured'));
      expect(android, contains('bil'));
      expect(android, contains('community'));
      expect(ios, contains('bil'));
      expect(deepLinks, contains("uri.scheme != 'bil'"));
      expect(deepLinks, contains("return null"));
      expect(router, contains('CommunityDeepLink.routeFor'));
      expect(router, contains('!AppEnvironment.communityConfigured'));
    },
  );

  test(
    'account deletion worker uses privileged auth deletion and no client secret',
    () {
      final worker = source('supabase/functions/account_data_deletion.ts');
      expect(worker, contains('SUPABASE_SERVICE_ROLE_KEY'));
      expect(worker, contains('auth.admin.deleteUser'));
      expect(worker, contains('BIL_INTERNAL_DELETION_SECRET'));
      expect(worker, contains("status: 'pending'"));
      expect(worker, contains('failed'));
      expect(worker, isNot(contains('anonKey')));
    },
  );

  test('edge functions exist in canonical deploy directories', () {
    final gate = source('artifacts/release/run_epic9_gate.ps1');
    final dispatch = source(
      'supabase/functions/community-push-dispatch/index.ts',
    );
    final deletion = source(
      'supabase/functions/account-data-deletion/index.ts',
    );
    expect(gate, contains('community-push-dispatch'));
    expect(gate, contains('account-data-deletion'));
    expect(gate, contains('index.ts'));
    expect(gate, contains('BLOCKED_CREDENTIALS_FEATURE_HIDDEN'));
    expect(dispatch, contains('BIL_INTERNAL_DISPATCH_SECRET'));
    expect(deletion, contains('BIL_INTERNAL_DELETION_SECRET'));
  });

  test(
    'credential-gated two-account integration evidence remains executable',
    () {
      final integration = source(
        'integration_test/epic9_two_account_cloud_test.dart',
      );
      expect(integration, contains('BIL_RUN_EPIC9_CLOUD_INTEGRATION'));
      expect(integration, contains('BIL_EPIC9_ACCOUNT_A_EMAIL'));
      expect(integration, contains('BIL_EPIC9_ACCOUNT_B_EMAIL'));
      expect(integration, contains('signInWithPassword'));
      expect(integration, contains('bil_request_friendship'));
      expect(integration, contains('bil_block_community_member'));
    },
  );
}
