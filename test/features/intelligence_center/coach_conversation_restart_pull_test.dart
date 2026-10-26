import 'dart:async';

import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_anchored_history.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_conversation_restart_pull.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _preview = Key('coach-new-conversation-pull-status');

class _Fixture {
  final controller = ScrollController();
  int calls = 0;
  bool enabled = true;
  String identity = 'conversation-one';
  int rows = 20;
  Completer<void>? held;

  Future<void> mount(WidgetTester tester, {bool arabic = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                height: 440,
                child: CoachConversationRestartPull(
                  controller: controller,
                  enabled: enabled,
                  conversationIdentity: identity,
                  label: arabic ? 'بدء محادثة جديدة' : 'Start new conversation',
                  onRestart: () async {
                    calls++;
                    await held?.future;
                  },
                  child: CoachAnchoredHistory(
                    controller: controller,
                    rowIds: List.generate(rows, (index) => 'row-$index'),
                    itemBuilder: (_, index) =>
                        SizedBox(height: 80, child: Text('Message $index')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<TestGesture> pull(WidgetTester tester, double amount) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CoachConversationRestartPull)),
    );
    await gesture.moveBy(Offset(0, -amount));
    await tester.pump();
    return gesture;
  }

  Future<void> close(WidgetTester tester) async {
    if (held != null && !held!.isCompleted) held!.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  }
}

void main() {
  for (final arabic in [false, true]) {
    testWidgets('short newest-edge pull previews Splash only Arabic=$arabic', (
      tester,
    ) async {
      final fixture = _Fixture();
      try {
        await fixture.mount(tester, arabic: arabic);
        final gesture = await fixture.pull(tester, 35);
        expect(find.byKey(_preview), findsOneWidget);
        expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
        expect(
          find.text(arabic ? 'بدء محادثة جديدة' : 'Start new conversation'),
          findsOneWidget,
        );
        expect(fixture.calls, 0);
        await gesture.up();
        await tester.pump();
        expect(find.byKey(_preview), findsNothing);
        expect(fixture.calls, 0);
      } finally {
        await fixture.close(tester);
      }
    });
  }

  testWidgets(
    'full extra pull restarts on release and runs once while saving',
    (tester) async {
      final fixture = _Fixture()..held = Completer<void>();
      try {
        await fixture.mount(tester);
        final gesture = await fixture.pull(tester, 145);
        expect(fixture.calls, 0);
        await gesture.up();
        await tester.pump();
        expect(fixture.calls, 1);
        expect(find.byKey(_preview), findsOneWidget);
        final second = await fixture.pull(tester, 145);
        await second.up();
        await tester.pump();
        expect(fixture.calls, 1);
        fixture.held!.complete();
        await tester.pump();
        expect(find.byKey(_preview), findsNothing);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets('reading older history cannot restart or show the preview', (
    tester,
  ) async {
    final fixture = _Fixture();
    try {
      await fixture.mount(tester);
      fixture.controller.jumpTo(800);
      await tester.pump();
      final gesture = await fixture.pull(tester, 150);
      expect(find.byKey(_preview), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fixture.calls, 0);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets('scrolling to the latest message does not count as extra pull', (
    tester,
  ) async {
    final fixture = _Fixture();
    try {
      await fixture.mount(tester);
      fixture.controller.jumpTo(100);
      await tester.pump();
      final arrival = await fixture.pull(tester, 140);
      await arrival.up();
      await tester.pumpAndSettle();
      expect(fixture.calls, 0);
      expect(find.byKey(_preview), findsNothing);
      expect(
        fixture.controller.offset,
        closeTo(fixture.controller.position.minScrollExtent, .1),
      );
      final extra = await fixture.pull(tester, 145);
      await extra.up();
      await tester.pump();
      expect(fixture.calls, 1);
    } finally {
      await fixture.close(tester);
    }
  });

  for (final operation in ['cancel', 'disable', 'identity', 'return', 'away']) {
    testWidgets('armed pull $operation leaves the current chat intact', (
      tester,
    ) async {
      final fixture = _Fixture();
      try {
        await fixture.mount(tester);
        final gesture = await fixture.pull(tester, 145);
        expect(find.byKey(_preview), findsOneWidget);
        switch (operation) {
          case 'cancel':
            await gesture.cancel();
          case 'disable':
            fixture.enabled = false;
            await fixture.mount(tester);
            await gesture.up();
          case 'identity':
            fixture.identity = 'conversation-two';
            await fixture.mount(tester);
            await gesture.up();
          case 'return':
            await gesture.moveBy(const Offset(0, 140));
            await gesture.up();
          case 'away':
            fixture.controller.jumpTo(500);
            await tester.pump();
            await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(fixture.calls, 0);
        expect(find.byKey(_preview), findsNothing);
      } finally {
        await fixture.close(tester);
      }
    });
  }

  testWidgets('jump and automatic scroll never restart the conversation', (
    tester,
  ) async {
    final fixture = _Fixture();
    try {
      await fixture.mount(tester);
      fixture.controller.jumpTo(500);
      await tester.pump();
      unawaited(
        fixture.controller.animateTo(
          fixture.controller.position.minScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
        ),
      );
      await tester.pumpAndSettle();
      expect(fixture.calls, 0);
      expect(find.byKey(_preview), findsNothing);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets('newest edge can be negative after appending an anchored reply', (
    tester,
  ) async {
    final fixture = _Fixture();
    try {
      await fixture.mount(tester);
      fixture.rows = 25;
      await fixture.mount(tester);
      expect(fixture.controller.position.minScrollExtent, lessThan(0));
      fixture.controller.jumpTo(fixture.controller.position.minScrollExtent);
      await tester.pump();
      final gesture = await fixture.pull(tester, 145);
      await gesture.up();
      await tester.pump();
      expect(fixture.calls, 1);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets('downward and horizontal drags do not arm a restart', (
    tester,
  ) async {
    final fixture = _Fixture();
    try {
      await fixture.mount(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CoachConversationRestartPull)),
      );
      await gesture.moveBy(const Offset(150, -15));
      await gesture.moveBy(const Offset(0, 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fixture.calls, 0);
      expect(find.byKey(_preview), findsNothing);
    } finally {
      await fixture.close(tester);
    }
  });
}
