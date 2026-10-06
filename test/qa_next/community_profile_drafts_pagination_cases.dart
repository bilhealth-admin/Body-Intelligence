part of 'community_profile_drafts_reference_capture_test.dart';

void _profileDraftPaginationCases(
  ValueGetter<_ReferenceRepository> repository,
) {
  _referenceTest(
    'Profile badge50 projection does not cap independent Drafts at50',
    (tester) async {
      final source = repository()..totalDrafts = 55;
      await _mountReference(tester, source);
      final drafts = find.byKey(const Key('community-self-drafts'));
      await tester.scrollUntilVisible(
        drafts,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: drafts, matching: find.text('50+')),
        findsOneWidget,
      );
      expect(source.listCalls.single, (
        owner: _owner,
        before: null,
        beforeId: null,
        limit: 50,
      ));
      final profileReads = source.profileReads;
      await _tapReference(tester, drafts);
      expect(find.byKey(const Key('community-drafts-page')), findsOneWidget);
      expect(find.text('Drafts (20+)'), findsOneWidget);
      expect(source.listCalls.last.limit, 20);

      for (final lastIndex in [19, 39]) {
        await _findMore(tester);
        await _tapReference(
          tester,
          find.byKey(const Key('community-drafts-load-more')),
        );
        expect(source.listCalls.last, (
          owner: _owner,
          before: source.draft(lastIndex).updatedAt,
          beforeId: source.id(lastIndex),
          limit: 20,
        ));
        expect(
          find.text(lastIndex == 19 ? 'Drafts (40+)' : 'Drafts (55)'),
          findsOneWidget,
        );
      }
      await tester.scrollUntilVisible(
        find.byKey(Key('community-draft-${source.id(54)}')),
        400,
        scrollable: _draftScrollable,
      );
      expect(find.text(source.title(54)), findsOneWidget);
      expect(find.byKey(const Key('community-drafts-load-more')), findsNothing);
      expect(source.listCalls.map((call) => call.limit), [50, 20, 20, 20]);
      expect(source.profileReads, profileReads);
      expect(source.policies, 0);
      expect(source.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
