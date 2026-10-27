import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_native_markdown.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_sent_message_arrival.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pending native surface still reaches actual composition', (
    tester,
  ) async {
    final probe = _NativeCompositionProbe();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 60,
          child: Opacity(opacity: 0, child: CustomPaint(painter: probe)),
        ),
      ),
    );
    expect(
      probe.paintCount,
      0,
      reason: 'The old zero-opacity gate skips paint.',
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CoachNativeMarkdownSurface(
          height: 60,
          ready: false,
          child: CustomPaint(painter: probe),
        ),
      ),
    );
    expect(
      probe.paintCount,
      greaterThan(0),
      reason: 'UIKit must be composed before SwiftUI can report real layout.',
    );
  });

  testWidgets('native surface accepts interaction only after readiness', (
    tester,
  ) async {
    var taps = 0;
    Widget surface(bool ready) => Directionality(
      textDirection: TextDirection.ltr,
      child: CoachNativeMarkdownSurface(
        height: 60,
        ready: ready,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const Text('Measured native content'),
        ),
      ),
    );
    await tester.pumpWidget(surface(false));
    await tester.tap(find.text('Measured native content'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpWidget(surface(true));
    await tester.tap(find.text('Measured native content'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  test(
    'production gesture factories construct the real UIKit render object',
    () {
      final factories = coachNativeMarkdownGestures();
      final renderer = RenderUiKitView(
        viewController: _RenderOnlyUiKitController(),
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: factories,
      );
      try {
        expect(factories.map((factory) => factory.type).toSet(), {
          LongPressGestureRecognizer,
          HorizontalDragGestureRecognizer,
        });
        // Vertical history scrolling remains with Flutter's existing viewport.
        renderer.updateGestureRecognizers(coachNativeMarkdownGestures());
      } finally {
        renderer.dispose();
      }
    },
  );

  test(
    'the old base-typed factories reproduce the native renderer assertion',
    () {
      expect(
        () => RenderUiKitView(
          viewController: _RenderOnlyUiKitController(),
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => LongPressGestureRecognizer(),
            ),
            Factory<OneSequenceGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
            ),
          },
        ),
        throwsAssertionError,
      );
    },
  );
  test('Markdown links are public HTTPS taps, never an action authority', () {
    expect(
      coachMarkdownPublicLink('https://www.cdc.gov/physical-activity/'),
      isNotNull,
    );
    for (final value in [
      'javascript:alert(1)',
      'data:text/html,test',
      'bil://delete-account',
      'file:///private/data',
      'https://127.0.0.1/private',
      'https://[::1]/',
      'https://10.0.0.1/',
      'https://host.local/',
      'https://host.local./',
      'https://localhost/',
      'https://u:p@example.com/',
      'https://example.com:8443/',
      'https://localhost.internal/',
      null,
      5,
    ]) {
      expect(coachMarkdownPublicLink(value), isNull, reason: '$value');
    }
  });

  testWidgets('a withdrawn owner cannot expose the renderer fallback', (
    tester,
  ) async {
    var current = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return CoachNativeMarkdown(
              text: 'Local owner fact',
              direction: TextDirection.ltr,
              style: const TextStyle(fontSize: 16),
              visitIsCurrent: () => current,
              fallback: const Text('Local owner fact'),
            );
          },
        ),
      ),
    );
    expect(find.text('Local owner fact'), findsOneWidget);
    update(() => current = false);
    await tester.pump();
    expect(find.text('Local owner fact'), findsNothing);
  });

  for (final rtl in [false, true]) {
    for (final dark in [false, true]) {
      for (final reduced in [false, true]) {
        testWidgets(
          'composer origin to accepted row RTL=$rtl dark=$dark reduced=$reduced',
          (tester) async {
            const origin = Rect.fromLTWH(30, 450, 300, 48);
            const target = Rect.fromLTWH(16, 80, 320, 140);
            final text = rtl ? 'رسالة محلية 60 kg' : 'A local message 60 kg';
            var finished = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: reduced),
                  child: child!,
                ),
                home: Scaffold(
                  body: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: target,
                        child: CoachSentMessageArrival(
                          origin: origin,
                          text: text,
                          direction: rtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: const TextStyle(fontSize: 16),
                          visitIsCurrent: () => true,
                          onFinished: () => finished++,
                          child: Text(text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pump();
            final flight = find.byKey(
              const ValueKey('coach-sent-message-flight'),
            );
            expect(
              find.text(text),
              findsOneWidget,
              reason: 'The visual flight creates no duplicate transcript row.',
            );
            if (reduced) {
              expect(flight, findsNothing);
              expect(finished, 1);
            } else {
              expect(flight, findsOneWidget);
              expect(tester.getRect(flight).top, closeTo(origin.top, .1));
              await tester.pump(const Duration(milliseconds: 110));
              final middle = tester.getRect(flight);
              expect(middle.top, inExclusiveRange(target.top, origin.top));
              expect(
                middle.width,
                inExclusiveRange(origin.width, target.width),
              );
              await tester.pump(const Duration(milliseconds: 170));
              expect(flight, findsNothing);
              expect(finished, 1);
            }
            expect(find.text(text), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            expect(
              finished,
              1,
              reason: 'Disposal must not complete the same flight twice.',
            );
          },
        );
      }
    }
  }

  testWidgets('leaving the conversation removes an in-flight draft overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachSentMessageArrival(
            origin: const Rect.fromLTWH(30, 400, 200, 40),
            text: 'Private local draft',
            direction: TextDirection.ltr,
            style: const TextStyle(fontSize: 16),
            visitIsCurrent: () => true,
            onFinished: () {},
            child: const Text('Private local draft'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('coach-sent-message-flight')),
      findsOneWidget,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Other screen'))),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('coach-sent-message-flight')),
      findsNothing,
    );
    expect(find.text('Private local draft'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an accepted row above the transcript cannot fly over the app bar',
    (tester) async {
      final scroll = ScrollController(initialScrollOffset: 100);
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 120, bottom: 100),
              child: ListView(
                controller: scroll,
                children: [
                  CoachSentMessageArrival(
                    origin: const Rect.fromLTWH(30, 510, 250, 48),
                    text: 'Accepted local turn',
                    direction: TextDirection.ltr,
                    style: const TextStyle(fontSize: 16),
                    visitIsCurrent: () => true,
                    onFinished: () => finished++,
                    child: const SizedBox(
                      height: 60,
                      child: Text('Accepted local turn'),
                    ),
                  ),
                  const SizedBox(height: 1600),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('coach-sent-message-flight')),
        findsNothing,
        reason: 'The retained offscreen row is outside the real viewport.',
      );
      expect(finished, 1);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Accepted local turn'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('coach-sent-message-flight')),
        findsNothing,
        reason: 'Returning to the preserved row does not replay the flight.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'flight clips to transcript and composer and vanishes when scrolled away',
    (tester) async {
      final scroll = ScrollController(initialScrollOffset: 30);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 120, bottom: 100),
              child: ListView(
                controller: scroll,
                children: [
                  CoachSentMessageArrival(
                    origin: const Rect.fromLTWH(30, 510, 250, 48),
                    text: 'Partly visible local turn',
                    direction: TextDirection.ltr,
                    style: const TextStyle(fontSize: 16),
                    visitIsCurrent: () => true,
                    onFinished: () {},
                    child: const SizedBox(
                      height: 80,
                      child: Text('Partly visible local turn'),
                    ),
                  ),
                  const SizedBox(height: 1600),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final flight = find.byKey(const ValueKey('coach-sent-message-flight'));
      expect(flight, findsOneWidget);
      final clip = find
          .ancestor(of: flight, matching: find.byType(ClipRect))
          .first;
      expect(clip, findsOneWidget);
      expect(tester.getRect(clip).top, 120);
      expect(tester.getRect(clip).bottom, 558);
      expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.hardEdge);
      await tester.pump(const Duration(milliseconds: 110));
      scroll.jumpTo(400);
      await tester.pump();
      expect(flight, findsNothing);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}

// Only the controller boundary is a fixture: RenderUiKitView and its factory
// validation are Flutter's real implementation. This does not certify SwiftUI.
class _RenderOnlyUiKitController implements UiKitViewController {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'The render-only regression must not call native services.',
  );
}

class _NativeCompositionProbe extends CustomPainter {
  var paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount++;
  }

  @override
  bool shouldRepaint(covariant _NativeCompositionProbe oldDelegate) => false;
}
