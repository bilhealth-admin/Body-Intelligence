import 'package:body_intelligence_log/features/community/presentation/community_comment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'comment expands downward and outside tap passes through $direction $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(390, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var outside = 0;
          var inside = 0;
          final text = List.filled(
            18,
            'A long comment with meaningful text.',
          ).join(' ');
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Directionality(
                    textDirection: direction,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          CommunityCommentCard(
                            identity: 'one',
                            source: text,
                            builder: (expanded, toggle) => Column(
                              children: [
                                const Text('Member'),
                                CommunityCommentText(
                                  identity: 'one',
                                  text: text,
                                  expanded: expanded,
                                  onToggle: toggle,
                                ),
                                TextButton(
                                  onPressed: () => inside++,
                                  child: const Text('Like'),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => outside++,
                            child: const Text('Outside'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final card = find.byKey(const ValueKey('community-comment-card-one'));
          final initial = tester.getRect(card);
          final arrow = find.byKey(const Key('community-comment-expand-one'));
          await tester.tap(arrow);
          await tester.pump();
          expect(tester.getTopLeft(card), initial.topLeft);
          expect(tester.getSize(card).height, greaterThan(initial.height));
          await tester.ensureVisible(find.text('Like'));
          await tester.tap(find.text('Like'));
          await tester.pump();
          expect(inside, 1);
          expect(
            tester
                .widget<SelectableText>(
                  find.byKey(const Key('community-comment-body-one')),
                )
                .data,
            text,
          );
          await tester.ensureVisible(find.text('Outside'));
          await tester.tap(find.text('Outside'));
          await tester.pump();
          expect(outside, 1);
          expect(tester.getSize(card).height, initial.height);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'short comments have no arrow, translated long text gains one, source update resets expansion',
    (tester) async {
      var source = 'Short';
      var displayed = source;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return CommunityCommentCard(
                  identity: 'same',
                  source: source,
                  builder: (expanded, toggle) => CommunityCommentText(
                    identity: 'same',
                    text: displayed,
                    expanded: expanded,
                    onToggle: toggle,
                  ),
                );
              },
            ),
          ),
        ),
      );
      final arrow = find.byKey(const Key('community-comment-expand-same'));
      expect(arrow, findsNothing);
      update(
        () => displayed = List.filled(30, 'Translated long text').join(' '),
      );
      await tester.pump();
      expect(arrow, findsOneWidget);
      await tester.tap(arrow);
      await tester.pump();
      expect(find.byType(SelectableText), findsOneWidget);
      update(() {
        source = 'Edited source';
      });
      await tester.pump();
      expect(find.byType(SelectableText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
