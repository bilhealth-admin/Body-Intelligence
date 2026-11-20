import 'package:body_intelligence_log/shared/widgets/bil_pinned_header_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final height in [160.0, 220.0]) {
    testWidgets('long 3x heading preserves body space in ${height}px viewport', (
      tester,
    ) async {
      final bodyController = ScrollController();
      addTearDown(bodyController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(3),
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 320,
                height: height,
                child: BilPinnedHeaderBody(
                  header: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Conversation history and previously saved chats'),
                      Text(
                        'Every conversation is saved on this device. Review your conversations before choosing the one you want to open.',
                      ),
                    ],
                  ),
                  body: ListView.builder(
                    key: const Key('body'),
                    controller: bodyController,
                    itemCount: 40,
                    itemExtent: 80,
                    itemBuilder: (_, index) => Text('Conversation $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(const Key('bil-pinned-header-scroll'));
      final before = tester.getRect(header);
      expect(
        tester.getSize(find.byKey(const Key('body'))).height,
        greaterThanOrEqualTo(height * .4),
      );
      await tester.drag(find.byKey(const Key('body')), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(bodyController.offset, greaterThan(0));
      expect(tester.getRect(header), before);
      await tester.drag(header, const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(of: header, matching: find.byType(Scrollable)),
            )
            .position
            .pixels,
        greaterThan(0),
      );
      expect(tester.getRect(header), before);
      expect(tester.takeException(), isNull);
    });
  }
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('pinned heading remains visible at $direction scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 44, bottom: 34),
              ),
              child: Directionality(textDirection: direction, child: child!),
            ),
            home: Scaffold(
              body: SafeArea(
                child: BilPinnedHeaderBody(
                  header: const Padding(
                    key: Key('heading'),
                    padding: EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Conversations'),
                        Text('History is stored on this device.'),
                      ],
                    ),
                  ),
                  body: ListView.builder(
                    controller: controller,
                    itemCount: 40,
                    itemBuilder: (_, index) => SizedBox(
                      height: 80,
                      child: Text('Conversation $index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final before = tester.getRect(find.byKey(const Key('heading')));
        final headerScroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('bil-pinned-header-scroll')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(headerScroll.position.maxScrollExtent, 0);
        expect(headerScroll.position.pixels, 0);
        expect(before.top, greaterThanOrEqualTo(44));
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        expect(tester.getRect(find.byKey(const Key('heading'))), before);
        expect(find.text('Conversations').hitTestable(), findsOneWidget);
        expect(
          find.text('History is stored on this device.').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
