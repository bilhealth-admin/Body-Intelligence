import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

const _postId = '33333333-3333-4333-8333-333333333333';
const _memberId = '22222222-2222-4222-8222-222222222222';

void main() {
  test('reference composer migrations are RPC-only and forward bounded', () {
    final composer = File(
      'supabase/migrations/20261003211000_community_reference_composer_persistence_v1.sql',
    ).readAsStringSync().toLowerCase();
    final wip = File(
      'supabase/migrations/20261003211500_community_draft_work_in_progress_v1.sql',
    ).readAsStringSync().toLowerCase();
    final collaboration = File(
      'supabase/migrations/20261003212000_community_reference_collaboration_activity_v1.sql',
    ).readAsStringSync().toLowerCase();

    for (final required in const [
      'bil_community_post_hashtags_v1',
      'bil_community_post_collaborators_v1',
      'bil_community_post_drafts_v1',
      'bil_community_post_draft_media_v1',
      'bil_set_my_community_post_reference_metadata_v1',
      'bil_community_post_reference_metadata_v1',
      'bil_upsert_my_community_post_draft_v1',
      'bil_set_my_community_post_draft_media_v1',
      'bil_list_my_community_post_drafts_v1',
      'bil_get_my_community_post_draft_v1',
      'bil_delete_my_community_post_draft_v1',
      "set search_path=''",
      'revoke all on table',
      'grant execute',
      'community-post-images',
    ]) {
      expect(composer, contains(required), reason: required);
    }

    expect(wip, contains('bil_consume_my_community_post_draft_v1'));
    expect(wip, contains("moderation_status='pending'"));
    expect(wip, contains("visibility='community'"));

    for (final required in const [
      'collaboration_invite',
      'collaboration_accepted',
      'bil_post_collaboration_activity_v1',
      'bil_respond_community_collaboration_v1',
      'bil_activity_pair_allowed_v1',
      'bil_emit_community_activity_v2',
      "'duplicate',true",
    ]) {
      expect(collaboration, contains(required), reason: required);
    }

    expect(
      collaboration,
      contains("old.moderation_status is distinct from 'approved'"),
    );
    expect(collaboration, contains("new.moderation_status='approved'"));

    for (final sql in [composer, wip, collaboration]) {
      for (final forbidden in const [
        'weight',
        'waist',
        'body_fat',
        'health_log',
        'bil_subscriptions',
      ]) {
        expect(sql, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('post reference metadata parses title taxonomy and collaboration', () {
    final metadata = CommunityPostReferenceMetadata.fromJson({
      'post_id': _postId,
      'title': 'Community reference title',
      'hashtags': ['bilcommunity', 'nutrition'],
      'topics': [
        {
          'slug': 'nutrition',
          'title_copy_key': 'community_topic_nutrition',
          'post_count': 42,
        },
      ],
      'circle': {
        'slug': 'healthy-habits',
        'title_copy_key': 'community_circle_healthy_habits',
        'post_count': 11,
        'member_count': 9,
      },
      'collaborators': [
        {
          'user_id': _memberId,
          'handle': 'bil_member',
          'display_name': 'BIL Member',
          'avatar_url': null,
          'status': 'accepted',
        },
      ],
    });

    expect(metadata.postId, _postId);
    expect(metadata.title, 'Community reference title');
    expect(metadata.hashtags, ['bilcommunity', 'nutrition']);
    expect(metadata.topics.single.slug, 'nutrition');
    expect(metadata.topics.single.postCount, 42);
    expect(metadata.circle?.slug, 'healthy-habits');
    expect(metadata.circle?.memberCount, 9);
    expect(
      metadata.collaborators.single.status,
      CommunityCollaborationStatus.accepted,
    );
  });

  test('post reference metadata rejects unsafe hashtag payload', () {
    expect(
      () => CommunityPostReferenceMetadata.fromJson({
        'post_id': _postId,
        'title': null,
        'hashtags': ['bad hashtag'],
        'topics': const [],
        'circle': null,
        'collaborators': const [],
      }),
      throwsFormatException,
    );
  });

  test('collaboration activity kinds are typed by the Flutter client', () {
    expect(
      CommunityNotificationKind.fromWire('collaboration_invite'),
      CommunityNotificationKind.collaborationInvite,
    );
    expect(
      CommunityNotificationKind.fromWire('collaboration_accepted'),
      CommunityNotificationKind.collaborationAccepted,
    );
  });

  test('reference composer UI has real actions rather than inert controls', () {
    final rendering = File(
      'lib/features/community/presentation/community_post_composer_rendering.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/features/community/presentation/community_post_composer_reference_sections.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/community/presentation/community_post_composer_reference_actions.dart',
    ).readAsStringSync();
    final drafts = File(
      'lib/features/community/presentation/community_member_profile_drafts.dart',
    ).readAsStringSync();
    final notifications = File(
      'lib/features/community/presentation/community_notifications_page.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/community/presentation/community_post_detail_header.dart',
    ).readAsStringSync();

    expect(rendering, contains('community-composer-title'));
    expect(rendering, contains('community-composer-voice-input'));
    expect(sections, contains('community-composer-hashtag-input'));
    expect(sections, contains('community-composer-collaborator-query'));
    expect(actions, contains('saveMyCommunityDraft'));
    expect(actions, contains('_captureVoiceInput'));
    expect(drafts, contains('community-drafts-list'));
    expect(drafts, contains('loadMyCommunityDraft'));
    expect(drafts, contains('deleteMyCommunityDraft'));
    expect(notifications, contains('community-collab-accept-'));
    expect(notifications, contains('community-collab-decline-'));
    expect(notifications, contains('respondCommunityCollaboration'));
    expect(detail, contains('community-post-detail-follow'));
  });

  test('Community voice input stays on first-party device speech boundary', () {
    final source = File(
      'lib/features/community/services/community_composer_voice_input_service.dart',
    ).readAsStringSync();

    expect(source, contains('SpeechToText'));
    expect(source, contains('BilRuntimePermissionPolicy'));
    expect(source, contains('MealVoiceLocaleResolver.resolve'));
    expect(source, contains('community-voice-transcript'));
    expect(source, contains('community-use-voice-transcript'));
    expect(source, isNot(contains('SupabaseClient')));
    expect(source, isNot(contains('http.')));
    expect(source, isNot(contains('AI Voice')));
  });
}
