import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_media_locale_copy.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

final class _FakePostImagePicker implements CommunityPostImagePickerContract {
  const _FakePostImagePicker(this.image);

  final CommunityPostImageDraft? image;

  @override
  Future<CommunityPostImageDraft?> pick() async => image;
}

final class _PostImageRepository extends CommunityRepository {
  _PostImageRepository()
    : super(
        SupabaseClient(
          'https://community-images.invalid',
          'community-images-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  static const userId = '11111111-1111-4111-8111-111111111111';
  int imagePublishCalls = 0;
  String? publishedText;
  CommunityPostImageDraft? publishedImage;
  Completer<void>? publishBarrier;
  bool failPublish = false;
  bool includeImagePost = false;

  @override
  String get currentUserId => userId;

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async =>
      includeImagePost
      ? [
          CommunityPost(
            id: '22222222-2222-4222-8222-222222222222',
            authorId: userId,
            authorName: 'BIL QA Member',
            body: 'Post with a temporarily unavailable private photo',
            createdAt: DateTime.utc(2026, 8, 23),
            mediaObjectPath:
                '$userId/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.png',
            mediaMimeType: 'image/png',
            mediaBytes: 128,
            mediaWidth: 1600,
            mediaHeight: 900,
          ),
        ]
      : const [];

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => const [];

  @override
  Future<void> publishPost(String body) async {
    publishedText = body;
  }

  @override
  Future<void> publishPostWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async {
    imagePublishCalls++;
    publishedText = body;
    publishedImage = image;
    if (failPublish) throw StateError('injected publish failure');
    await publishBarrier?.future;
  }
}

Widget _app({
  required Locale locale,
  required CommunityRepository repository,
  required CommunityPostImagePickerContract picker,
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: CommunityHubPage(repository: repository, postImagePicker: picker),
);

CommunityPostImageDraft _testImage() {
  final source = img.Image(width: 8, height: 5)
    ..clear(img.ColorRgb8(30, 120, 190));
  return validateCommunityPostImage(Uint8List.fromList(img.encodePng(source)));
}

void main() {
  group('community post image validation', () {
    test('accepts decoded PNG and records bounded truthful metadata', () {
      final image = _testImage();
      expect(image.mimeType, 'image/png');
      expect(image.extension, 'png');
      expect(image.width, 8);
      expect(image.height, 5);
      expect(image.byteLength, lessThan(communityPostImageMaxBytes));
    });

    test('accepts truthful JPEG and WebP signatures', () {
      final source = img.Image(width: 6, height: 4)
        ..clear(img.ColorRgb8(80, 170, 70));
      final jpeg = validateCommunityPostImage(
        Uint8List.fromList(img.encodeJpg(source)),
      );
      final webp = validateCommunityPostImage(img.encodeWebP(source));
      expect((jpeg.mimeType, jpeg.extension), ('image/jpeg', 'jpg'));
      expect((webp.mimeType, webp.extension), ('image/webp', 'webp'));
    });

    test('rejects unsupported, corrupt, oversized, and unsafe dimensions', () {
      expect(
        () => validateCommunityPostImage(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(
          isA<CommunityPostImageException>().having(
            (error) => error.failure,
            'failure',
            CommunityPostImageFailure.unsupportedType,
          ),
        ),
      );
      expect(
        () => validateCommunityPostImage(
          Uint8List.fromList([
            0x89,
            0x50,
            0x4e,
            0x47,
            0x0d,
            0x0a,
            0x1a,
            0x0a,
            0,
            0,
          ]),
        ),
        throwsA(isA<CommunityPostImageException>()),
      );
      expect(
        () => validateCommunityPostImage(
          Uint8List(communityPostImageMaxBytes + 1),
        ),
        throwsA(
          isA<CommunityPostImageException>().having(
            (error) => error.failure,
            'failure',
            CommunityPostImageFailure.tooLarge,
          ),
        ),
      );
      final tooWide = img.Image(
        width: communityPostImageMaxDimension + 1,
        height: 1,
      );
      expect(
        () => validateCommunityPostImage(
          Uint8List.fromList(img.encodePng(tooWide)),
        ),
        throwsA(
          isA<CommunityPostImageException>().having(
            (error) => error.failure,
            'failure',
            CommunityPostImageFailure.invalidDimensions,
          ),
        ),
      );
    });
  });

  test('migration and repository keep private media owner-scoped', () {
    final migration = File(
      'supabase/migrations/20260823014911_community_post_images.sql',
    ).readAsStringSync();
    final repository = [
      'lib/features/community/data/community_repository.dart',
      'lib/features/community/data/community_post_cloud_store.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    for (final contract in <String>[
      "'community-post-images'",
      'false,',
      '5242880',
      "array['image/jpeg', 'image/png', 'image/webp']",
      'bil_community_posts_media_all_or_none',
      'bil_community_posts_media_owned_path',
      'owner_id = (select auth.uid()::text)',
      "(storage.foldername(name))[1] = (select auth.uid()::text)",
      "name ~ '^[0-9a-f]{8}-[0-9a-f]{4}",
      "'storage.object.sign'",
      "'storage.object.sign_many'",
      'community_post_image_delete_own',
    ]) {
      expect(migration, contains(contract), reason: contract);
    }
    expect(migration, isNot(contains("'storage.object.list'")));
    expect(migration, isNot(contains('service_role')));
    expect(migration, isNot(contains('for update\nto authenticated')));
    expect(repository, contains('createSignedUrlsResult'));
    expect(repository, contains('upsert: false'));
    expect(repository, contains("remove([path])"));
    expect(repository, isNot(contains('getPublicUrl')));
  });

  test('all Community photo copy is native across the 25 locales', () {
    expect(communityMediaLocaleCopy.length, 23);
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final english in communityMediaEnglishKeys) {
        final translated = communityTextForLanguage(
          tag,
          english,
          'نص عربي أصلي',
        );
        expect(translated.trim(), isNotEmpty, reason: '$tag: $english');
        if (tag != 'en') {
          expect(translated, isNot(english), reason: '$tag: $english');
        }
      }
    }
  });

  testWidgets(
    'photo draft previews, shows upload progress, and publishes once',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final image = _testImage();
      final repository = _PostImageRepository()
        ..publishBarrier = Completer<void>();
      await tester.pumpWidget(
        _app(
          locale: const Locale('en'),
          repository: repository,
          picker: _FakePostImagePicker(image),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('community-post-add-photo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-post-remove-photo')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('community-post-composer')),
        'A photo-backed community update',
      );
      await tester.tap(find.byKey(const Key('community-post-publish')));
      await tester.pump();

      expect(repository.imagePublishCalls, 1);
      expect(repository.publishedText, 'A photo-backed community update');
      expect(repository.publishedImage, same(image));
      expect(
        find.byKey(const Key('community-post-upload-progress')),
        findsOneWidget,
      );
      expect(find.text('A photo-backed community update'), findsOneWidget);

      repository.publishBarrier!.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-post-remove-photo')),
        findsNothing,
      );
      expect(find.text('A photo-backed community update'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed image publish retains both text and photo for retry', (
    tester,
  ) async {
    final image = _testImage();
    final repository = _PostImageRepository()..failPublish = true;
    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        repository: repository,
        picker: _FakePostImagePicker(image),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-post-add-photo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('community-post-composer')),
      'Keep this complete draft',
    );
    await tester.tap(find.byKey(const Key('community-post-publish')));
    await tester.pumpAndSettle();

    expect(find.text('Keep this complete draft'), findsOneWidget);
    expect(
      find.byKey(const Key('community-post-remove-photo')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Could not publish now. Your text and photo are kept so you can retry.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('private image signing failure renders a bounded safe fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _PostImageRepository()..includeImagePost = true;
    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        repository: repository,
        picker: const _FakePostImagePicker(null),
      ),
    );
    await tester.pumpAndSettle();
    final image = find.byKey(
      const Key('community-post-image-22222222-2222-4222-8222-222222222222'),
    );
    await tester.ensureVisible(image);
    await tester.pumpAndSettle();
    expect(image, findsOneWidget);
    expect(find.text('Photo unavailable'), findsOneWidget);
    final size = tester.getSize(image);
    expect(size.width, lessThanOrEqualTo(358));
    expect(size.height, lessThanOrEqualTo(size.width / 0.8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo affordance survives 25 locales at 390x844 and 160%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      await tester.pumpWidget(
        _app(
          locale: locale,
          repository: _PostImageRepository(),
          picker: const _FakePostImagePicker(null),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-post-add-photo')),
        findsOneWidget,
        reason: tag,
      );
      expect(tester.takeException(), isNull, reason: tag);
    }
  });
}
