import 'package:body_intelligence_log/features/community/presentation/community_post_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('feed preview expands and resets $direction $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final body = List.filled(
          15,
          direction == TextDirection.rtl
              ? 'نص منشور طويل لاختبار العرض الكامل'
              : 'A meaningful longer post to read.',
        ).join(' ');
        Future<void> mount(String id, String content) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 288,
                      child: CommunityPostBody(postId: id, body: content),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await mount('one', body);
        final text = find.byKey(const Key('community-post-body-one'));
        final arrow = find.byKey(const Key('community-post-expand-one'));
        final collapsed = tester.getSize(text).height;
        expect(tester.widget<Text>(text).maxLines, 3);
        expect(tester.widget<Text>(text).overflow, TextOverflow.ellipsis);
        expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
        await tester.tap(arrow);
        await tester.pump();
        expect(tester.widget<SelectableText>(text).data, body);
        expect(tester.getSize(text).height, greaterThan(collapsed));
        await tester.ensureVisible(arrow);
        await tester.tap(arrow);
        await tester.pump();
        expect(tester.getSize(text).height, closeTo(collapsed, .1));
        await tester.ensureVisible(arrow);
        await tester.tap(arrow);
        await tester.pump();
        await mount('one', 'Translation changed');
        expect(find.byType(SelectableText), findsNothing);
        expect(arrow, findsNothing);
        await mount('two', body);
        expect(
          find.byKey(const Key('community-post-expand-two')),
          findsOneWidget,
        );
        expect(find.byType(SelectableText), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('short but vertically overflowing text gets a show more arrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityPostBody(
            postId: 'lines',
            body: 'One\nTwo\nThree\nFour',
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('community-post-expand-lines')),
      findsOneWidget,
    );
  });
}
