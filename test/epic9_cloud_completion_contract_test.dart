import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'support/read_push_dispatcher.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test(
    'community and push stay hidden until cloud credentials and flags exist',
    () {
      final environment = source('lib/app/environment/app_environment.dart');
      final settings = source('lib/features/settings/settings_page.dart');
      final dashboard = [
        'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
        'lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
      ].map(source).join('\n');
      expect(environment, contains("'BIL_COMMUNITY_ENABLED'"));
      expect(environment, contains("'BIL_PUSH_ENABLED'"));
      expect(environment, contains('defaultValue: false'));
      expect(environment, contains('cloudConfigured && communityEnabled'));
      expect(environment, contains('communityConfigured && pushEnabled'));
      expect(settings, contains('if (AppEnvironment.communityConfigured)'));
      expect(dashboard, contains('if (AppEnvironment.communityConfigured)'));
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
      const repositoryRoot = 'lib/features/community/data/';
      final repositoryEntry = source(
        '${repositoryRoot}community_repository.dart',
      );
      final repositoryParts = RegExp(
        r"^part '([^']+)';",
        multiLine: true,
      ).allMatches(repositoryEntry).map((match) => match.group(1)!).toList();
      expect(
        repositoryParts,
        containsAll(<String>[
          'community_repository_profile_moderation_mixin.dart',
          'community_repository_connections_messaging_mixin.dart',
        ]),
      );
      final repository = <String>[
        repositoryEntry,
        source(
          'lib/features/community/data/community_social_repository_mixin.dart',
        ),
        ...repositoryParts.map((part) => source('$repositoryRoot$part')),
      ].join('\n');
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
      final profileRepository = source(
        '${repositoryRoot}community_repository_profile_moderation_mixin.dart',
      );
      final profileWrite = profileRepository.substring(
        profileRepository.indexOf('Future<void> saveMyProfile('),
        profileRepository.indexOf('void invalidateCommunityModeratorStatus()'),
      );
      expect(profileWrite, contains('CommunityTextPolicy.enforceAll'));
      expect(
        profileWrite,
        contains("await _client.from('bil_public_profiles').upsert"),
      );
      expect(profileWrite, contains("'user_id': _user.id"));
      expect(profileWrite, contains("'profile_visibility': visibility.name"));
      expect(profileWrite, contains("onConflict: 'user_id'"));
      expect(
        profileWrite.indexOf('CommunityTextPolicy.enforceAll'),
        lessThan(
          profileWrite.indexOf(
            "await _client.from('bil_public_profiles').upsert",
          ),
        ),
      );
    },
  );

  test(
    'push infrastructure is opt-in generic on lock screen and deep-link capable',
    () {
      final service = source(
        'lib/features/notifications/services/community_push_service.dart',
      );
      final registrationCoordinator = source(
        'lib/features/notifications/presentation/community_push_registration_coordinator.dart',
      );
      const notificationDir = 'lib/features/notifications/presentation/';
      final notificationEntry = source(
        '${notificationDir}notification_settings_page.dart',
      );
      final settings = <String>[
        notificationEntry,
        for (final part in RegExp(
          r"^part '([^']+)';",
          multiLine: true,
        ).allMatches(notificationEntry))
          source('$notificationDir${part.group(1)!}'),
      ].join('\n');
      final dispatch = readPushDispatcherImplementation(
        'supabase/functions/community_push_dispatch.ts',
      );
      final androidBridge = source(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILPushProvider.kt',
      );
      final androidActivity = source(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt',
      );
      final androidFirebaseService = source(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFirebaseMessagingService.kt',
      );
      final androidGradle = source('android/app/build.gradle.kts');
      final googleServices = source('android/app/google-services.json');
      final android = source('android/app/src/main/AndroidManifest.xml');
      final ios = source('ios/Runner/Info.plist');
      final deepLinks = source(
        'lib/features/notifications/domain/community_deep_link.dart',
      );
      final router =
          (source('lib/app/router/app_router.dart') +
          source('lib/app/router/app_community_routes.dart'));
      final redirect = source('lib/app/router/app_route_redirect.dart');
      expect(service, contains('AppEnvironment.pushConfigured'));
      expect(service, contains('bil_disable_push_tokens'));
      expect(service, contains('refreshRegistrationIfEnabled'));
      expect(service, contains('bil_set_sensitive_push_previews'));
      expect(service, contains('FlutterTimezone.getLocalTimezone'));
      expect(settings, contains("Key('community-cloud-push')"));
      expect(settings, contains("Key('sensitive-lock-screen-preview')"));
      expect(dispatch, contains('You have a new private update.'));
      expect(dispatch, contains('sensitive_preview_allowed'));
      expect(dispatch, contains('deep_link'));
      expect(dispatch, contains('data: {'));
      expect(dispatch, contains('deep_link: event.deep_link'));
      expect(androidBridge, contains('BILPushProvider'));
      expect(androidBridge, contains('BILFirebasePushProvider'));
      expect(androidBridge, contains('firebase_cloud_messaging'));
      expect(androidBridge, contains('FirebaseMessaging.getInstance().token'));
      expect(
        androidBridge,
        contains('FirebaseMessaging.getInstance().deleteToken()'),
      );
      expect(androidBridge, contains('fun status(): Map<String, Any>'));
      expect(androidFirebaseService, contains('override fun onNewToken'));
      expect(
        androidFirebaseService,
        contains('override fun onMessageReceived'),
      );
      expect(androidFirebaseService, contains('isSafeDeepLink'));
      expect(registrationCoordinator, contains('AppLifecycleState.resumed'));
      expect(registrationCoordinator, contains('refreshRegistrationIfEnabled'));
      expect(androidGradle, contains('com.google.gms.google-services'));
      expect(androidGradle, contains('com.google.firebase:firebase-messaging'));
      expect(googleServices, contains('com.bilhealth.bodyintelligencelog'));
      expect(googleServices, contains('bil-health'));
      expect(androidActivity, contains('"providerStatus"'));
      expect(androidActivity, contains('"takeInitialPayload"'));
      expect(androidActivity, contains('override fun onNewIntent'));
      expect(
        service,
        contains(
          'bool get ready => configured && tokenRegistration && remoteTapRouting',
        ),
      );
      expect(service, contains('PushProviderCapability.unavailable()'));
      expect(service, contains('on MissingPluginException'));
      expect(service, contains('on PlatformException'));
      final enable = service.substring(
        service.indexOf('Future<void> setEnabled('),
        service.indexOf('/// Reconciles a durable provider token'),
      );
      expect(
        enable,
        contains('final capability = await _tokenProvider.capability();'),
      );
      expect(
        enable,
        contains(
          "if (!capability.ready) throw StateError('Push provider is not ready');",
        ),
      );
      expect(
        enable.indexOf('if (!capability.ready)'),
        lessThan(enable.indexOf('await _requestAndRegisterCurrentToken(')),
      );
      final resume = service.substring(
        service.indexOf('Future<void> refreshRegistrationIfEnabled('),
        service.indexOf(
          'Future<CommunityPushDeliveryCategories> syncDeliveryPreferences(',
        ),
      );
      final resumeSteps = <String>[
        'if (!isAvailable) return;',
        'if (user == null) return;',
        'if (await _registrationPolicyStore.isExplicitlyDisabled(user.id)) return;',
        'final capability = await _tokenProvider.capability();',
        'if (!capability.ready || !capability.permissionGranted) return;',
        'final token = await _tokenProvider.existingPermissionToken();',
        'if (token == null || token.isEmpty) return;',
        'await _registerToken(token, deliveryPreferences);',
      ];
      var previousStep = -1;
      for (final step in resumeSteps) {
        expect(resume, contains(step), reason: step);
        final position = resume.indexOf(step);
        expect(position, greaterThan(previousStep), reason: step);
        previousStep = position;
      }
      expect(resume, isNot(contains('_tokenProvider.requestToken(')));
      expect(android, contains('android:scheme="bil"'));
      expect(android, contains('.BILFirebaseMessagingService'));
      expect(android, contains('com.google.firebase.MESSAGING_EVENT'));
      expect(ios, contains('bil'));
      expect(deepLinks, contains("uri.scheme.toLowerCase() != 'bil'"));
      expect(deepLinks, contains("segments.first == 'community'"));
      expect(deepLinks, contains("return null"));
      expect(router, contains("part 'app_route_redirect.dart'"));
      expect(redirect, contains('CommunityDeepLink.routeFor'));
      expect(redirect, contains('!AppEnvironment.communityConfigured'));
    },
  );

  test('account deletion is privileged, Storage-first and fails closed', () {
    final entry = source('supabase/functions/account_data_deletion.ts');
    final worker = source(
      'supabase/functions/_shared/account_deletion_worker.ts',
    );
    final storage = source(
      'supabase/functions/_shared/account_deletion_storage.ts',
    );
    expect(entry, contains('handleAccountDeletion'));
    expect(worker, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(worker, contains('auth.admin.deleteUser'));
    expect(worker, contains('BIL_INTERNAL_DELETION_SECRET'));
    expect(worker, contains('status: "pending"'));
    expect(worker, contains('storage_cleanup_failed'));
    expect(worker, contains('deleteBilUserStorage'));
    expect(storage, contains('profile-avatars'));
    expect(storage, contains('community-post-images'));
    expect(storage, contains('bucket.remove(chunk)'));
    expect(storage, contains('storage_cleanup_incomplete'));
    expect(
      worker.indexOf('deleteBilUserStorage'),
      lessThan(worker.indexOf('auth.admin.deleteUser')),
    );
    expect(worker, isNot(contains('anonKey')));
  });

  test('edge functions exist in canonical deploy directories', () {
    // Release gates must inspect tracked production sources, not a missing
    // historical PowerShell artifact that was never part of this checkout.
    final gate = source('lib/app/environment/app_environment.dart');
    final dispatch = readPushDispatcherImplementation(
      'supabase/functions/community-push-dispatch/index.ts',
    );
    final deletion = source(
      'supabase/functions/account-data-deletion/index.ts',
    );
    expect(
      gate,
      contains(
        'useSupabase && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty',
      ),
    );
    expect(gate, contains('if (!cloudConfigured) return false'));
    expect(
      gate,
      contains('communityConfigured => cloudConfigured && communityEnabled'),
    );
    expect(
      gate,
      contains('communityConfigured && pushEnabled && pushProviderReady'),
    );
    expect(dispatch, contains('BIL_INTERNAL_DISPATCH_SECRET'));
    expect(deletion, contains('handleAccountDeletion'));
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
