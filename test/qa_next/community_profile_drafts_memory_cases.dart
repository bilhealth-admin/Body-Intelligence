part of 'community_profile_drafts_reference_capture_test.dart';

void _draftPreviewMemoryCases(ValueGetter<_ReferenceRepository> repository) {
  _referenceTest(
    'cached four-photo drafts survive rebuild and revisit without fetching again',
    (tester) async {
      final source = repository()
        ..everyDraftHasFourPhotos = true
        ..totalDrafts = 20;
      await _mountReference(tester, source, drafts: true);
      final first = source.id(0);
      final oldTitle = source.title(0);
      final oldBody = source.body(0);
      source.savedTitles[first] = 'A later revision on another device';
      source.savedBodies[first] = 'A different authoritative body.';
      await tester.scrollUntilVisible(
        find.byKey(Key('community-draft-${source.id(5)}')),
        350,
        scrollable: _draftScrollable,
      );
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(_draftScrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await _tapReference(
        tester,
        find.byKey(const Key('community-drafts-select')),
      );
      expect(find.text(oldTitle), findsOneWidget);
      expect(find.text(oldBody), findsWidgets);
      expect(find.text(source.title(0)), findsNothing);
      expect(find.text(source.body(0)), findsNothing);
      expect(
        source.previewStarts.where((request) => request.id == first),
        hasLength(1),
      );
      expect(source.listCalls, hasLength(1));
      for (var index = 0; index < 4; index++) {
        final image = tester.widget<Image>(
          find.byKey(Key('community-draft-photo-$first-$index')),
        );
        final provider =
            (image.image as ResizeImage).imageProvider as MemoryImage;
        expect(provider.bytes.lengthInBytes, lessThanOrEqualTo(64 * 1024));
        expect(provider.bytes, source.previews[index].bytes);
      }
      expect(source.peakPreviews, lessThanOrEqualTo(2));
      expect(source.saves, 0);
    },
  );

  _referenceTest(
    'explicit refresh replaces the entire cached draft revision exactly once',
    (tester) async {
      final source = repository();
      await _mountReference(tester, source, drafts: true);
      final id = source.id(0);
      final previous = source.title(0);
      source.savedTitles[id] = 'An explicitly refreshed title';
      source.savedBodies[id] = 'The next complete private revision.';
      source.savedTimes[id] = DateTime.now().toUtc();
      final refreshing = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refreshing;
      await tester.pumpAndSettle();
      expect(find.text(previous), findsNothing);
      expect(find.text(source.title(0)), findsOneWidget);
      expect(find.text(source.body(0)), findsOneWidget);
      expect(find.text('Saved just now'), findsOneWidget);
      expect(source.listCalls, hasLength(2));
      expect(
        source.previewStarts.where((request) => request.id == id),
        hasLength(2),
      );
      for (var index = 0; index < 4; index++) {
        expect(
          find.byKey(Key('community-draft-photo-$id-$index')),
          findsOneWidget,
        );
      }
      expect(source.profileReads, 0);
      expect(source.policies, 0);
      expect(source.saves, 0);
    },
  );
}
