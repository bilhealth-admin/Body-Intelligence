import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('metrics and new rows cannot cancel a slow drag $platform', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var count = 30;
      var height = 360.0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SizedBox(
                  height: height,
                  child: ChatHistoryViewport(
                    controller: scroll,
                    latestMessageId: 'message-$count',
                    child: ListView.builder(
                      controller: scroll,
                      reverse: true,
                      itemCount: count,
                      itemExtent: 80,
                      itemBuilder: (context, index) => Text('message-$index'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ChatHistoryViewport)),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final before = scroll.offset;
      expect(before, inExclusiveRange(0, 72));
      rebuild(() {
        count++;
        height = 320;
      });
      await tester.pump();
      await tester.pump();
      expect(scroll.offset, closeTo(before, .5));
      expect(scroll.position.isScrollingNotifier.value, isTrue);
      for (var i = 0; i < 24; i++) {
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(100));
      final jump = find.byKey(const Key('chat-jump-to-latest'));
      expect(jump.hitTestable(), findsOneWidget);
      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(0, .5));
      rebuild(() => count++);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(0, .5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'latest end is stable and reading history is not forcibly interrupted',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final messages = List.generate(30, (index) => 'message-$index');
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SizedBox(
                  height: 360,
                  child: ChatHistoryViewport(
                    controller: scroll,
                    latestMessageId: messages.last,
                    child: ListView.builder(
                      key: const Key('test-history'),
                      controller: scroll,
                      reverse: true,
                      itemCount: messages.length,
                      itemExtent: 60,
                      itemBuilder: (context, index) =>
                          Text(messages[messages.length - 1 - index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(0, 0.5));
      await tester.drag(
        find.byKey(const Key('test-history')),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();
      final before = scroll.offset;
      expect(before, greaterThan(72));
      rebuild(() => messages.add('new-message'));
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(before, 0.5));
      final jump = find.byKey(const Key('chat-jump-to-latest'));
      expect(jump.hitTestable(), findsOneWidget);
      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(0, 0.5));
      expect(find.text('new-message'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('keyboard resize keeps latest end and composer reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: ChatHistoryViewport(
                  controller: scroll,
                  latestMessageId: 'latest',
                  child: ListView.builder(
                    controller: scroll,
                    reverse: true,
                    itemCount: 30,
                    itemExtent: 60,
                    itemBuilder: (context, index) =>
                        Text(index == 0 ? 'latest' : 'old-$index'),
                  ),
                ),
              ),
              const SafeArea(
                top: false,
                child: TextField(key: Key('composer')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(0, 0.5));
    expect(find.byKey(const Key('composer')).hitTestable(), findsOneWidget);
    expect(
      tester.getBottomRight(find.byKey(const Key('composer'))).dy,
      lessThanOrEqualTo(440),
    );
    expect(find.text('latest'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
