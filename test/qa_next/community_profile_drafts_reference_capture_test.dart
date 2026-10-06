import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../visual_closure/visual_evidence_font.dart';

part 'community_profile_drafts_reference_fixture.dart';
part 'community_profile_drafts_reference_helpers.dart';
part 'community_profile_drafts_memory_cases.dart';
part 'community_profile_drafts_pagination_cases.dart';

void main() {
  late List<CommunityPostImageDraft> photos;
  late List<CommunityPostImagePreview> previews;
  late List<int> avatar;
  late _ReferenceAuth auth;
  late _ReferenceRepository repository;
  setUpAll(() async {
    await loadVisualEvidenceFont();
    avatar = await File(_avatarAsset).readAsBytes();
    photos = [
      for (final path in _assets)
        validateCommunityPostImage(await File(path).readAsBytes()),
    ];
    previews = [
      for (final photo in photos)
        await createCommunityPostImagePreviewAsync(
          photo.bytes,
          expectedMimeType: photo.mimeType,
          expectedByteLength: photo.byteLength,
          expectedWidth: photo.width,
          expectedHeight: photo.height,
        ),
    ];
  });
  setUp(() async {
    auth = _ReferenceAuth();
    await auth.prepare();
    repository = _ReferenceRepository(
      auth.client,
      photos,
      previews,
      avatarBytes: avatar,
    );
  });
  tearDown(() async => auth.client.dispose());

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        final suffix = '$language-${dark ? 'dark' : 'light'}-${scale.toInt()}';
        _referenceTest('populated Profile and private Drafts $suffix', (
          tester,
        ) async {
          var mounted = await _mountReference(
            tester,
            repository,
            language: language,
            dark: dark,
            scale: scale,
          );
          final cover = tester.getRect(
            find.byKey(const Key('community-profile-cover-frame')),
          );
          final avatar = tester.getRect(
            find.byKey(const Key('community-profile-avatar-frame')),
          );
          expect(cover.height, closeTo(133.5, .2));
          expect(avatar.width, closeTo(108.5, .2));
          expect(avatar.height, closeTo(avatar.width, .001));
          expect(avatar.center.dy, closeTo(cover.bottom, .1));
          // The 48dp accessible toolbar is 4.6dp taller than the poster's
          // calibrated optical bar; record that difference rather than hide it.
          expect(cover.top, closeTo(43.4, 5));
          expect(
            tester.getRect(find.byKey(const Key('community-edit-profile'))).top,
            greaterThanOrEqualTo(cover.bottom),
          );
          final edit = find.byKey(const Key('community-edit-profile'));
          final editStyle = tester
              .widget<OutlinedButton>(edit)
              .style!
              .textStyle!
              .resolve({});
          expect(
            editStyle?.fontFamily,
            Theme.of(tester.element(edit)).textTheme.labelLarge?.fontFamily,
            reason: 'The profile action must preserve the user theme font.',
          );
          if (scale == 1) {
            expect(
              tester
                  .getTopLeft(
                    find.byKey(const Key('community-profile-display-name')),
                  )
                  .dy,
              closeTo(250.4, 4),
            );
          }
          expect(
            find.byKey(const Key('bil-reference-navigation')),
            findsOneWidget,
          );
          await _captureReference(
            tester,
            mounted.boundary,
            'profile-header-$suffix',
          );

          final actions = find.byKey(const Key('community-self-drafts'));
          await tester.scrollUntilVisible(
            actions,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(actions);
          await tester.pumpAndSettle();
          expect(tester.getSize(actions).height, greaterThanOrEqualTo(88.5));
          await _captureReference(
            tester,
            mounted.boundary,
            'profile-actions-$suffix',
          );
          final reviews = find.byKey(
            const Key('community-profile-tab-reviews'),
          );
          await tester.scrollUntilVisible(
            reviews,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await _tapReference(tester, reviews);
          expect(
            find.text(
              language == 'ar'
                  ? 'مراجعة معتمدة فعلية'
                  : 'A real approved review',
            ),
            findsOneWidget,
          );
          await _captureReference(
            tester,
            mounted.boundary,
            'profile-reviews-$suffix',
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          mounted = await _mountReference(
            tester,
            repository,
            drafts: true,
            language: language,
            dark: dark,
            scale: scale,
          );
          expect(
            find.text(language == 'ar' ? 'المسودات (2)' : 'Drafts (2)'),
            findsOneWidget,
          );
          for (var index = 0; index < 4; index++) {
            expect(
              find.byKey(
                Key('community-draft-photo-${repository.id(0)}-$index'),
              ),
              findsOneWidget,
            );
          }
          expect(
            find.textContaining(language == 'ar' ? 'بلا استطلاع' : 'No poll'),
            findsOneWidget,
          );
          await _captureReference(
            tester,
            mounted.boundary,
            'drafts-populated-$suffix',
          );
          await _tapReference(
            tester,
            find.byKey(const Key('community-drafts-select')),
          );
          await _tapReference(
            tester,
            find.byKey(Key('community-draft-${repository.id(0)}')),
          );
          expect(
            find.byKey(const Key('community-drafts-delete-selected')),
            findsOneWidget,
          );
          await _captureReference(
            tester,
            mounted.boundary,
            'drafts-selected-$suffix',
          );
          expect(repository.profileReads, 0);
          expect(repository.codeReads, 0);
          expect(repository.policies, 0);
          expect(repository.saves, 0);
          expect(auth.unexpectedRequests, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  _referenceTest(
    'cursor pagination preserves the scroll position and truthful final count',
    (tester) async {
      repository.totalDrafts = 25;
      await _mountReference(tester, repository, drafts: true);
      expect(find.text('Drafts (20+)'), findsOneWidget);
      expect(repository.listCalls.single.limit, 20);
      await _findMore(tester);
      final beforeOffset = tester
          .state<ScrollableState>(_draftScrollable)
          .position
          .pixels;
      await _tapReference(
        tester,
        find.byKey(const Key('community-drafts-load-more')),
      );
      expect(repository.listCalls, hasLength(2));
      expect(repository.listCalls.last.before, repository.draft(19).updatedAt);
      expect(repository.listCalls.last.beforeId, repository.id(19));
      expect(repository.listCalls.last.limit, 20);
      expect(find.text('Drafts (25)'), findsOneWidget);
      expect(
        tester.state<ScrollableState>(_draftScrollable).position.pixels,
        greaterThanOrEqualTo(beforeOffset - 1),
      );
      await tester.scrollUntilVisible(
        find.byKey(Key('community-draft-${repository.id(24)}')),
        400,
        scrollable: _draftScrollable,
      );
      expect(
        find.byKey(Key('community-draft-${repository.id(24)}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('community-drafts-load-more')), findsNothing);
      expect(repository.profileReads, 0);
    },
  );

  _referenceTest(
    'failed later page retains rows and retries exactly the same cursor',
    (tester) async {
      repository.totalDrafts = 25;
      repository.failNextPage = true;
      final mounted = await _mountReference(tester, repository, drafts: true);
      await _findMore(tester);
      await _tapReference(
        tester,
        find.byKey(const Key('community-drafts-load-more')),
      );
      expect(find.text('Drafts (20+)'), findsOneWidget);
      expect(find.text(repository.title(19)), findsOneWidget);
      final failed = repository.listCalls.last;
      await _captureReference(
        tester,
        mounted.boundary,
        'drafts-page-retry-en-light-1',
      );
      await _tapReference(
        tester,
        find.byKey(const Key('community-drafts-load-more')),
      );
      expect(repository.listCalls.last, failed);
      expect(find.text('Drafts (25)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  _referenceTest(
    'old pending page cannot append after repository replacement',
    (tester) async {
      repository.totalDrafts = 25;
      final pending = Completer<List<CommunityDraftSummary>>();
      repository.nextPage = pending;
      final mounted = await _mountReference(tester, repository, drafts: true);
      await _findMore(tester);
      await tester.tap(find.byKey(const Key('community-drafts-load-more')));
      await tester.pump();
      final replacement = _ReferenceRepository(auth.client, photos, previews)
        ..totalDrafts = 1;
      mounted.selection.value = replacement;
      await tester.pumpAndSettle();
      pending.complete(
        repository.page(
          before: repository.draft(19).updatedAt,
          beforeId: repository.id(19),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Drafts (1)'), findsOneWidget);
      expect(replacement.listCalls, hasLength(1));
      expect(find.text('Drafts (25)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  _referenceTest('queued actual ABA cancels a pending later page', (
    tester,
  ) async {
    repository.totalDrafts = 25;
    final pending = Completer<List<CommunityDraftSummary>>();
    repository.nextPage = pending;
    await _mountReference(tester, repository, drafts: true);
    await _findMore(tester);
    await tester.tap(find.byKey(const Key('community-drafts-load-more')));
    await tester.pump();
    await auth.roundTrip();
    await tester.pumpAndSettle();
    pending.complete(
      repository.page(
        before: repository.draft(19).updatedAt,
        beforeId: repository.id(19),
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.client.auth.currentUser!.id, _owner);
    expect(find.text('Drafts (20+)'), findsOneWidget);
    expect(find.text('Drafts (25)'), findsNothing);
    expect(
      repository.listCalls.where((call) => call.before != null),
      hasLength(1),
    );
  });

  _referenceTest(
    'queued previews stay bounded and cannot start after replacement',
    (tester) async {
      repository.totalDrafts = 30;
      final pending = Completer<void>();
      repository.previewPause = pending;
      final mounted = await _mountReference(tester, repository, drafts: true);
      await _findMore(tester);
      expect(repository.activePreviews, 2);
      expect(repository.peakPreviews, 2);
      expect(repository.previewStarts, hasLength(2));
      final replacement = _ReferenceRepository(auth.client, photos, previews)
        ..totalDrafts = 1;
      mounted.selection.value = replacement;
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(repository.previewStarts, hasLength(2));
      expect(repository.activePreviews, 0);
      expect(find.text('Drafts (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ar']) {
    _referenceTest(
      'one failed optional preview can retry without hiding the draft $language',
      (tester) async {
        repository.badPhotos.add(1);
        final mounted = await _mountReference(
          tester,
          repository,
          drafts: true,
          language: language,
        );
        final id = repository.id(0);
        expect(
          find.byKey(Key('community-draft-photo-placeholder-$id-1')),
          findsOneWidget,
        );
        for (final index in [0, 2, 3]) {
          expect(
            find.byKey(Key('community-draft-photo-$id-$index')),
            findsOneWidget,
          );
        }
        expect(find.byKey(Key('community-draft-continue-$id')), findsOneWidget);
        await _captureReference(
          tester,
          mounted.boundary,
          'drafts-photo-failure-$language-light-1',
        );
        repository.badPhotos.clear();
        await _tapReference(
          tester,
          find.byKey(Key('community-draft-preview-retry-$id')),
        );
        for (var index = 0; index < 4; index++) {
          expect(
            find.byKey(Key('community-draft-photo-$id-$index')),
            findsOneWidget,
          );
        }
        await _captureReference(
          tester,
          mounted.boundary,
          'drafts-photo-recovered-$language-light-1',
        );
        expect(repository.saves, 0);
        expect(repository.profileReads, 0);
      },
    );

    _referenceTest(
      'independent Drafts restores all four photos and saves the same private draft $language',
      (tester) async {
        final mounted = await _mountReference(
          tester,
          repository,
          drafts: true,
          language: language,
        );
        final id = repository.id(0);
        await _tapReference(
          tester,
          find.byKey(Key('community-draft-continue-$id')),
        );
        expect(repository.opened, [id]);
        final field = find.byKey(const Key('community-post-composer'));
        expect(
          tester.widget<TextField>(field).controller!.text,
          repository.body(0),
        );
        for (var index = 0; index < 4; index++) {
          expect(
            find.byKey(Key('community-selected-photo-$index')),
            findsOneWidget,
          );
        }
        await _captureReference(
          tester,
          mounted.boundary,
          'drafts-restored-editor-$language-light-1',
        );
        final edited =
            '${repository.body(0)} ${language == 'ar' ? 'وسأتابع هذه الخطوة غدًا.' : 'I will keep this habit tomorrow.'}';
        await tester.ensureVisible(field);
        await tester.enterText(field, edited);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await _captureReference(
          tester,
          mounted.boundary,
          'drafts-restored-keyboard-$language-light-1',
        );
        tester.view.resetViewInsets();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        repository.loseNextSaveReply = true;
        await _tapReference(
          tester,
          find.byKey(const Key('community-post-save-draft')),
        );
        expect(repository.saves, 1);
        expect(repository.saveInputs.single.draftId, id);
        expect(tester.widget<TextField>(field).controller!.text, edited);
        expect(repository.saveImages.single, photos);
        expect(
          repository.saveInputs.single.pollOptions,
          repository.draft(0).pollOptions,
        );
        await _captureReference(
          tester,
          mounted.boundary,
          'drafts-save-retry-$language-light-1',
        );
        await _tapReference(
          tester,
          find.byKey(const Key('community-post-save-draft')),
        );
        expect(repository.saves, 2);
        expect(repository.saveInputs.last.draftId, id);
        expect(repository.saveInputs.last.body, edited);
        expect(repository.saveImages.last, photos);
        expect(repository.savedBodies[id], edited);
        expect(repository.profileReads, 0);
        expect(repository.codeReads, 0);
        expect(repository.policies, 0);
        expect(repository.saves, 2);
        expect(auth.unexpectedRequests, 0);
      },
    );
  }

  _referenceTest(
    'failed draft metadata leaves summary and editor action reachable',
    (tester) async {
      repository.failNextPreview = true;
      final mounted = await _mountReference(tester, repository, drafts: true);
      final id = repository.id(0);
      expect(find.text(repository.title(0)), findsOneWidget);
      expect(
        find.byKey(Key('community-draft-preview-retry-$id')),
        findsOneWidget,
      );
      expect(find.byKey(Key('community-draft-continue-$id')), findsOneWidget);
      expect(repository.opened, isEmpty);
      await _captureReference(
        tester,
        mounted.boundary,
        'drafts-metadata-failure-en-light-1',
      );
      await _tapReference(
        tester,
        find.byKey(Key('community-draft-preview-retry-$id')),
      );
      expect(find.byKey(Key('community-draft-photo-$id-3')), findsOneWidget);
      expect(repository.opened, isEmpty);
      expect(repository.saves, 0);
      expect(auth.unexpectedRequests, 0);
    },
  );

  _referenceTest(
    'later metadata readback replaces stale summary text and saved time',
    (tester) async {
      repository.previewPause = Completer<void>();
      await _mountReference(tester, repository, drafts: true);
      final id = repository.id(0);
      final oldTitle = repository.title(0);
      expect(find.text(oldTitle), findsOneWidget);
      repository.savedTitles[id] = 'Updated privately on another device';
      repository.savedBodies[id] = 'The authoritative body changed as well.';
      repository.savedTimes[id] = DateTime.now().toUtc();
      repository.previewPause!.complete();
      await tester.pumpAndSettle();
      expect(find.text(oldTitle), findsNothing);
      expect(find.text(repository.title(0)), findsOneWidget);
      expect(find.text(repository.body(0)), findsOneWidget);
      expect(find.text('Saved just now'), findsOneWidget);
      expect(repository.listCalls, hasLength(1));
      expect(
        repository.previewStarts.where((value) => value.id == id),
        hasLength(1),
      );
      expect(repository.profileReads, 0);
      expect(repository.policies, 0);
      expect(repository.saves, 0);
    },
  );

  for (final language in ['en', 'ar']) {
    _referenceTest(
      'Profile and Drafts controls stay reachable at320dp and200percent $language',
      (tester) async {
        var mounted = await _mountReference(
          tester,
          repository,
          language: language,
          scale: 2,
          width: 320,
        );
        final draftsAction = find.byKey(const Key('community-self-drafts'));
        await tester.scrollUntilVisible(
          draftsAction,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(draftsAction);
        await tester.pumpAndSettle();
        expect(draftsAction.hitTestable(), findsOneWidget);
        await _captureReference(
          tester,
          mounted.boundary,
          'profile-actions-$language-light-2-320',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        mounted = await _mountReference(
          tester,
          repository,
          drafts: true,
          language: language,
          scale: 2,
          width: 320,
        );
        final title = find.text(
          language == 'ar' ? 'المسودات (2)' : 'Drafts (2)',
        );
        final titleBox = tester.getRect(title);
        final toolbarBox = tester.getRect(find.byType(AppBar));
        expect(titleBox.top, greaterThanOrEqualTo(toolbarBox.top));
        expect(titleBox.bottom, lessThanOrEqualTo(toolbarBox.bottom));
        final continuation = find.byKey(
          Key('community-draft-continue-${repository.id(0)}'),
        );
        await tester.scrollUntilVisible(
          continuation,
          250,
          scrollable: _draftScrollable,
        );
        await tester.ensureVisible(continuation);
        await tester.pumpAndSettle();
        expect(continuation.hitTestable(), findsOneWidget);
        await _captureReference(
          tester,
          mounted.boundary,
          'drafts-controls-$language-light-2-320',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  _referenceTest(
    'Profile Quick Add is the shared presenter and dismiss preserves the visit',
    (tester) async {
      await _mountReference(tester, repository);
      await _tapReference(tester, find.byKey(const Key('bil-reference-nav-2')));
      expect(find.byType(BilQuickAddSheet), findsOneWidget);
      expect(repository.saves, 0);
      expect(repository.profileReads, 0);
      Navigator.of(tester.element(find.byType(BilQuickAddSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community-profile-hero')), findsOneWidget);
      expect(find.byType(BilQuickAddSheet), findsNothing);
    },
  );
  _draftPreviewMemoryCases(() => repository);
  _profileDraftPaginationCases(() => repository);
}
