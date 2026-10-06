import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_creation.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/domain/community_post_context.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../visual_closure/visual_evidence_font.dart';

part 'community_composer_reference_capture_fixture.dart';
part 'community_composer_reference_capture_helpers.dart';

void main() {
  late List<CommunityPostImageDraft> photos;
  late _ComposerReferenceAuth auth;
  late _ComposerReferenceRepository repository;
  setUpAll(() async {
    await loadVisualEvidenceFont();
    photos = [
      for (final path in _photoAssets)
        validateCommunityPostImage(await File(path).readAsBytes()),
    ];
  });
  setUp(() async {
    // Auth HTTP, process/font loading and disposal belong to the real runner.
    auth = _ComposerReferenceAuth();
    await auth.signIn(_other);
    await auth.signIn(_owner);
    repository = _ComposerReferenceRepository(auth.client, photos);
  });
  tearDown(() async => auth.client.dispose());

  test('creation controls have authored copy in all 25 release locales', () {
    expect(
      CommunityCreationRuntimeCopy.rows.keys.toSet(),
      BilLocalePolicy.productionTags.toSet(),
    );
    for (final tag in BilLocalePolicy.productionTags) {
      final row = CommunityCreationRuntimeCopy.rows[tag]!;
      expect(row, hasLength(CommunityCreationRuntimeCopy.sources.length));
      for (var index = 0; index < row.length; index++) {
        expect(row[index].trim(), isNotEmpty, reason: '$tag:$index');
        expect(
          CommunityCreationRuntimeCopy.resolve(
            CommunityCreationRuntimeCopy.sources[index],
            tag,
          ),
          row[index],
        );
      }
    }
    expect(
      CommunityCreationRuntimeCopy.resolve('Create a Post', 'ar'),
      'إنشاء منشور',
    );
    expect(
      CommunityCreationRuntimeCopy.resolve('Create a Post', 'en'),
      'Create a Post',
    );
    expect(
      CommunityCreationRuntimeCopy.resolve('Unregistered copy', 'en'),
      isNull,
    );
  });

  testWidgets(
    'reference order retains four selected photos, full poll and same id after uncertain draft save',
    (tester) async {
      final picker = _FixturePicker(photos);
      final boundary = await _mountComposer(tester, repository, picker: picker);
      await _tapComposer(tester, 'community-create-post');
      await _captureComposer(tester, boundary, 'composer-empty-en-light-1');
      final titleBox = tester.getRect(
        find.byKey(const Key('community-composer-title-box')),
      );
      final bodyBox = tester.getRect(
        find.byKey(const Key('community-composer-body-box')),
      );
      final mediaBox = tester.getRect(
        find.byKey(const Key('community-post-selected-images')),
      );
      expect(titleBox.left, closeTo(16, 1));
      expect(titleBox.width, closeTo(382, 2));
      expect(titleBox.height, inInclusiveRange(54, 60));
      expect(bodyBox.height, inInclusiveRange(147, 154));
      expect(titleBox.bottom, lessThan(bodyBox.top));
      expect(bodyBox.bottom, lessThan(mediaBox.top));
      expect(mediaBox.height, closeTo(100, 1));
      final saveBox = tester.getRect(
        find.byKey(const Key('community-post-save-draft')),
      );
      final publishBox = tester.getRect(
        find.byKey(const Key('community-post-publish')),
      );
      expect(saveBox.right, lessThan(publishBox.left));
      expect(publishBox.height, greaterThan(saveBox.height));
      expect(saveBox.bottom, closeTo(publishBox.bottom, 1));

      await _enterComposer(
        tester,
        'community-composer-title',
        'A small win for today',
      );
      await _enterComposer(tester, 'community-post-composer', _bodyEn);
      for (var index = 0; index < 4; index++) {
        await _tapComposer(tester, 'community-post-add-photo');
        expect(
          find.byKey(Key('community-selected-photo-$index')),
          findsOneWidget,
        );
        if (index == 2) {
          await _scrollComposerTop(tester);
          await _captureComposer(
            tester,
            boundary,
            'composer-three-photos-add-en-light-1',
          );
        }
      }
      expect(picker.calls, 4);
      await tester.drag(
        find.byKey(const Key('community-post-selected-images')),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      final add = tester.widget<OutlinedButton>(
        find.byKey(const Key('community-post-add-photo')),
      );
      expect(
        add.onPressed,
        isNull,
        reason: 'Four photos is the real server limit.',
      );
      await _tapComposer(tester, 'community-composer-action-poll');
      await _enterComposer(tester, 'community-composer-poll-question', _pollEn);
      await _enterComposer(
        tester,
        'community-composer-poll-option-0',
        'A walk outdoors',
      );
      await _enterComposer(
        tester,
        'community-composer-poll-option-1',
        'A balanced meal',
      );
      await _tapComposer(tester, 'community-composer-action-poll');
      await _tapComposer(tester, 'community-composer-action-location');
      await _enterComposer(tester, 'community-composer-location', 'Melbourne');
      await _tapComposer(tester, 'community-composer-action-location');
      await _tapComposer(tester, 'community-composer-action-circle');
      await _tapComposer(tester, 'community-composer-circle-healthy-eating');
      await _tapComposer(tester, 'community-composer-topic-success-stories');
      await _tapComposer(tester, 'community-composer-action-circle');
      await _tapComposer(tester, 'community-composer-action-hashtags');
      await _enterComposer(
        tester,
        'community-composer-hashtag-input',
        'healthyhabits',
      );
      await _tapComposer(tester, 'community-composer-hashtag-add');
      await _tapComposer(tester, 'community-composer-action-hashtags');
      await _scrollComposerTop(tester);
      await tester.drag(
        find.byKey(const Key('community-post-selected-images')),
        const Offset(800, 0),
      );
      await tester.pumpAndSettle();
      await _captureComposer(tester, boundary, 'composer-populated-en-light-1');
      final profileReads = repository.profileReads;
      final codeReads = repository.codeReads;
      repository.loseNextSaveResponse = true;
      await _tapComposer(tester, 'community-post-save-draft');
      expect(repository.saveAttempts, hasLength(1));
      final first = repository.saveAttempts.single;
      expect(first.body, _bodyEn);
      expect(first.pollQuestion, _pollEn);
      expect(first.pollOptions, ['A walk outdoors', 'A balanced meal']);
      expect(first.circleSlug, 'healthy-eating');
      expect(first.topicSlugs, ['success-stories']);
      expect(first.hashtags, ['healthyhabits']);
      expect(repository.drafts[first.draftId]!.images, photos);
      expect(_composerBody(tester), _bodyEn);
      await _captureComposer(
        tester,
        boundary,
        'composer-draft-save-retry-en-light-1',
      );
      await _tapComposer(tester, 'community-post-save-draft');
      expect(repository.saveAttempts, hasLength(2));
      expect(repository.saveAttempts.last.draftId, first.draftId);
      expect(
        repository.drafts,
        hasLength(1),
        reason: 'A lost response must not create a second private draft.',
      );
      expect(repository.profileReads, profileReads);
      expect(repository.codeReads, codeReads);
      expect(repository.publishCalls, 0);
      expect(repository.acceptedPolicies, 0);

      final retainedSelection = tester
          .widget<TextField>(find.byKey(const Key('community-post-composer')))
          .controller!
          .selection;
      await _tapComposer(tester, 'community-composer-open-drafts');
      expect(find.byKey(const Key('community-drafts-page')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_composerBody(tester), _bodyEn);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('community-post-composer')))
            .controller!
            .selection,
        retainedSelection,
      );
      expect(
        repository.saveAttempts,
        hasLength(2),
        reason: 'Visiting Drafts does not implicitly save or publish.',
      );
      expect(repository.profileReads, profileReads);
      expect(repository.codeReads, codeReads);
      expect(find.text('Drafts (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmountComposer(tester);
    },
  );

  testWidgets(
    'older draft count cannot overwrite the count from a newer Drafts visit',
    (tester) async {
      final oldCount = Completer<List<CommunityDraftSummary>>();
      repository.nextList = oldCount;
      await _mountComposer(tester, repository);
      await _tapComposer(tester, 'community-create-post');
      expect(find.text('Drafts (0)'), findsNothing);
      repository.drafts[_restoredId] = (
        input: _savedInput('en'),
        images: photos,
      );
      await _enterComposer(
        tester,
        'community-post-composer',
        'Unsaved retained body',
      );
      await _tapComposer(tester, 'community-composer-open-drafts');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Drafts (1)'), findsOneWidget);
      oldCount.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('Drafts (1)'), findsOneWidget);
      expect(_composerBody(tester), 'Unsaved retained body');
      expect(repository.saveAttempts, isEmpty);
      expect(repository.publishAttempts, isEmpty);
      expect(tester.takeException(), isNull);
      await _unmountComposer(tester);
    },
  );

  testWidgets(
    'queued A B A invalidates outstanding draft count and the old editor',
    (tester) async {
      final oldCount = Completer<List<CommunityDraftSummary>>();
      repository.nextList = oldCount;
      await _mountComposer(tester, repository);
      await _tapComposer(tester, 'community-create-post');
      await _enterComposer(
        tester,
        'community-post-composer',
        'Owner A private text',
      );
      final delivered = <({String? eventOwner, String? currentOwner})>[];
      final observation = auth.client.auth.onAuthStateChange.listen((state) {
        delivered.add((
          eventOwner: state.session?.user.id,
          currentOwner: auth.client.auth.currentUser?.id,
        ));
      });
      // Cancel outside the widget fake clock; the SDK stream returns a real-zone Future.
      addTearDown(observation.cancel);
      await auth.roundTrip();
      await tester.pump();
      expect(delivered, contains((eventOwner: _other, currentOwner: _owner)));
      oldCount.complete([
        CommunityDraftSummary(
          draftId: _restoredId,
          title: 'Old owner',
          body: 'Private',
          updatedAt: DateTime.utc(2026, 10, 6),
          mediaCount: 0,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-composer-open-drafts')),
        findsNothing,
      );
      expect(find.text('Drafts (1)'), findsNothing);
      expect(repository.saveAttempts, isEmpty);
      expect(repository.publishAttempts, isEmpty);
      expect(repository.readOwners, everyElement(_owner));
      expect(tester.takeException(), isNull);
      await _unmountComposer(tester);
    },
  );

  for (final language in ['en', 'ar']) {
    testWidgets(
      'full Unicode overflow remains visible at 200% with zero save or publish $language',
      (tester) async {
        repository.drafts[_restoredId] = (
          input: _savedInput(language),
          images: photos,
        );
        final boundary = await _mountComposer(
          tester,
          repository,
          language: language,
          scale: 2,
          drafts: true,
        );
        await _tapComposer(tester, 'community-draft-continue-$_restoredId');
        final overflow =
            '${List.filled(1198, language == 'ar' ? 'ش' : 'a').join()}👩‍💻';
        expect(overflow.runes.length, 1201);
        await _enterComposer(tester, 'community-post-composer', overflow);
        await _tapComposer(tester, 'community-post-save-draft');
        await _tapComposer(tester, 'community-post-publish');
        expect(_composerBody(tester), overflow);
        expect(repository.saveAttempts, isEmpty);
        expect(repository.publishAttempts, isEmpty);
        expect(repository.profileReads, 0);
        expect(repository.codeReads, 0);
        final field = tester.widget<TextField>(
          find.byKey(const Key('community-post-composer')),
        );
        final error = language == 'ar'
            ? 'اجعل النص في حدود 1200 حرف. احتفظنا بالنص كاملًا.'
            : 'Keep the text within 1200 characters. Your text is kept.';
        expect(field.decoration!.errorText, error);
        await tester.ensureVisible(find.text(error));
        await tester.pumpAndSettle();
        await _captureComposer(
          tester,
          boundary,
          'composer-validation-retention-$language-light-2',
        );
        expect(tester.takeException(), isNull);
        await _unmountComposer(tester);
      },
    );
  }

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'actual restored four-photo poll $language dark=$dark scale=$scale with retry and keyboard reflow',
          (tester) async {
            repository.drafts[_restoredId] = (
              input: _savedInput(language),
              images: photos,
            );
            final boundary = await _mountComposer(
              tester,
              repository,
              language: language,
              dark: dark,
              scale: scale,
              drafts: true,
            );
            await _tapComposer(tester, 'community-draft-continue-$_restoredId');
            final expected = _savedInput(language);
            expect(_composerBody(tester), expected.body);
            expect(repository.profileReads, 0);
            expect(repository.codeReads, 0);
            for (var index = 0; index < 4; index++) {
              expect(
                find.byKey(Key('community-selected-photo-$index')),
                findsOneWidget,
              );
            }
            expect(find.text('#healthyhabits'), findsOneWidget);
            expect(
              find.descendant(
                of: find.byKey(const Key('community-composer-selected-circle')),
                matching: find.text(
                  language == 'ar' ? 'الأكل الصحي' : 'Healthy Eating',
                ),
              ),
              findsOneWidget,
            );
            final suffix =
                '$language-${dark ? 'dark' : 'light'}-${scale.toInt()}';
            await _captureComposer(
              tester,
              boundary,
              'composer-restored-$suffix',
            );
            await _tapComposer(tester, 'community-composer-action-poll');
            expect(find.text(expected.pollQuestion!), findsOneWidget);
            expect(find.text(expected.pollOptions.first), findsOneWidget);
            await _captureComposer(tester, boundary, 'composer-poll-$suffix');
            await _tapComposer(tester, 'community-composer-action-poll');
            await _enterComposer(
              tester,
              'community-post-composer',
              expected.body,
            );
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(_composerBody(tester), expected.body);
            expect(tester.takeException(), isNull);
            await _captureComposer(
              tester,
              boundary,
              'composer-keyboard-reflow-$suffix',
            );
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            repository.failNextPublish = true;
            await _tapComposer(tester, 'community-post-publish');
            expect(repository.publishAttempts, hasLength(1));
            expect(repository.publishedImages.single, photos);
            expect(repository.publishAttempts.single.body, expected.body);
            expect(
              repository.publishAttempts.single.pollOptions,
              expected.pollOptions,
            );
            expect(repository.publishAttempts.single.draftId, _restoredId);
            expect(_composerBody(tester), expected.body);
            await _captureComposer(
              tester,
              boundary,
              'composer-publish-retry-$suffix',
            );
            await _tapComposer(tester, 'community-post-publish');
            expect(repository.publishAttempts, hasLength(2));
            expect(repository.publishedImages.last, photos);
            expect(repository.publishAttempts.last.body, expected.body);
            expect(repository.publishAttempts.last.draftId, _restoredId);
            expect(
              repository.publishAttempts.last.pollQuestion,
              expected.pollQuestion,
            );
            expect(
              repository.publishAttempts.last.pollOptions,
              expected.pollOptions,
            );
            expect(repository.saveAttempts, isEmpty);
            expect(repository.acceptedPolicies, 0);
            expect(tester.takeException(), isNull);
            await _unmountComposer(tester);
          },
        );
      }
    }
  }
}
