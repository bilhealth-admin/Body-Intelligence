import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

String _repositorySource() => [
  'lib/features/community/data/community_repository.dart',
  'lib/features/community/data/community_repository_discovery_mixin.dart',
  'lib/features/community/data/community_repository_profile_moderation_mixin.dart',
  'lib/features/community/data/community_repository_publishing_mixin.dart',
  'lib/features/community/data/community_repository_connections_messaging_mixin.dart',
].map((path) => File(path).readAsStringSync()).join('\n');

void main() {
  test('multi-image backend is ordered, owner-scoped, and storage-safe', () {
    final sql = File(
      'supabase/migrations/20261003103409_community_multi_image_foundation_v1.sql',
    ).readAsStringSync();

    expect(sql, contains('create table public.bil_community_post_media_v1'));
    expect(sql, contains('position smallint not null'));
    expect(sql, contains('position between 0 and 3'));
    expect(sql, contains('bil_set_my_community_post_media_v1'));
    expect(sql, contains('bil_community_post_media_v1'));
    expect(sql, contains('bil_my_community_post_media_paths_v1'));
    expect(sql, contains('bil_can_read_community_post_image_v2'));
    expect(sql, contains("p.moderation_status='pending'"));
    expect(sql, contains('public.bil_assert_community_publish_ready()'));
    expect(sql, contains('pg_catalog.jsonb_array_length(p_items)>4'));
    expect(sql, contains('owner_id=(select auth.uid())::text'));
    expect(sql, contains('delete from public.bil_community_post_media_v1'));
    expect(sql, contains('enable row level security'));
  });

  test('post model preserves an ordered four-photo collection', () {
    final media = [
      for (var index = 0; index < 4; index++)
        CommunityPostMedia.fromJson({
          'media_position': index,
          'object_path':
              '11111111-1111-4111-8111-111111111111/'
              '22222222-2222-4222-8222-222222222222/'
              '33333333-3333-4333-8333-33333333333$index.jpg',
          'mime_type': 'image/jpeg',
          'bytes': 120000,
          'width': 1200,
          'height': 800,
          'url': 'https://example.invalid/$index.jpg',
        }),
    ];

    final post = CommunityPost(
      id: '22222222-2222-4222-8222-222222222222',
      authorId: '11111111-1111-4111-8111-111111111111',
      body: 'Gallery',
      createdAt: DateTime.utc(2026, 10, 3),
      media: media,
    );

    expect(post.hasImage, isTrue);
    expect(post.mediaItems.length, 4);
    expect(post.mediaItems.map((item) => item.position), [0, 1, 2, 3]);
    expect(post.mediaAspectRatio, 1.5);
    expect(post.withSaved(true).mediaItems.length, 4);
  });

  test('client uploads and renders real ordered media instead of fake cards', () {
    final store = File(
      'lib/features/community/data/community_post_cloud_store.dart',
    ).readAsStringSync();
    final repository = _repositorySource();
    final composer = [
      'lib/features/community/presentation/community_post_composer_page.dart',
      'lib/features/community/presentation/community_post_composer_rendering.dart',
      'lib/features/community/presentation/community_post_composer_image_preview.dart',
      'lib/features/community/presentation/community_post_composer_toolbar.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final widgets = File(
      'lib/features/community/presentation/community_post_widgets.dart',
    ).readAsStringSync();

    expect(store, contains('CommunityPostMultiImagePublishingContract'));
    expect(store, contains('publishWithImagesReceipt'));
    expect(store, contains('bil_set_my_community_post_media_v1'));
    expect(store, contains('bil_community_post_media_v1'));
    expect(store, contains('bil_my_community_post_media_paths_v1'));
    expect(repository, contains('publishPostWithImagesTopicsAndCircle'));
    expect(repository, contains('publishPostWithImagesTopicsCircleAndPoll'));
    expect(composer, contains('community-post-selected-images'));
    expect(composer, contains('_selectedImages.length >= 4'));
    final gallery = File(
      'lib/features/community/presentation/community_post_gallery_page.dart',
    ).readAsStringSync();
    expect(widgets, contains('CommunityPostGalleryPage('));
    expect(gallery, contains('PageView.builder'));
    expect(gallery, contains('InteractiveViewer('));
    expect(gallery, contains('initialPage: widget.initialIndex'));
    expect(widgets, contains('gallery: media'));
    expect(widgets, contains('community-post-gallery-'));
  });
}
