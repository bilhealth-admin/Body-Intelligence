import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic controls exercise the shared Crystal without changing other
// workstreams. Production calendar and video routes still need device QA.
const _bubble = Key('bil-crystal-arrow-bubble');
const _captureKey = Key('bil39-crystal-calendar-video-capture');

class _CalendarVideoFixture extends StatefulWidget {
  const _CalendarVideoFixture();

  @override
  State<_CalendarVideoFixture> createState() => _CalendarVideoFixtureState();
}

class _CalendarVideoFixtureState extends State<_CalendarVideoFixture> {
  int month = 0;
  int video = 0;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _captureKey,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Synthetic calendar navigation'),
              Row(
                children: [
                  IconButton(
                    key: const Key('calendar-previous'),
                    tooltip: 'Previous month',
                    onPressed: month > 0
                        ? () => setState(() => month--)
                        : null,
                    icon: const BilCrystalArrow(
                      child: Icon(Icons.chevron_left_rounded),
                    ),
                  ),
                  Expanded(child: Center(child: Text('Month $month'))),
                  IconButton(
                    key: const Key('calendar-next'),
                    tooltip: 'Next month',
                    onPressed: month < 1
                        ? () => setState(() => month++)
                        : null,
                    icon: const BilCrystalArrow(
                      child: Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Synthetic video carousel'),
              Row(
                children: [
                  IconButton(
                    key: const Key('video-previous'),
                    tooltip: 'Previous video',
                    onPressed: video > 0
                        ? () => setState(() => video--)
                        : null,
                    icon: const BilCrystalArrow(
                      child: Icon(Icons.chevron_left_rounded),
                    ),
                  ),
                  Expanded(child: Center(child: Text('Video $video'))),
                  IconButton(
                    key: const Key('video-next'),
                    tooltip: 'Next video',
                    onPressed: video < 1
                        ? () => setState(() => video++)
                        : null,
                    icon: const BilCrystalArrow(
                      child: Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
  });
  expect(bytes, isNotNull);
  final file = File('build/bil39_crystal_calendar_video/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  for (final width in <double>[320, 390, 430, 768]) {
    for (final dark in [false, true]) {
      for (final rtl in [false, true]) {
        testWidgets('calendar/video crystal width=$width dark=$dark rtl=$rtl', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1024);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: const _CalendarVideoFixture(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final caseId = width.toInt().toString() +
              (dark ? '_dark' : '_light') +
              (rtl ? '_rtl' : '_ltr');
          expect(find.byKey(_bubble), findsNWidgets(4));

          final nextMonth = find.byKey(const Key('calendar-next'));
          final nextVideo = find.byKey(const Key('video-next'));
          final previousMonth = find.byKey(const Key('calendar-previous'));
          final previousVideo = find.byKey(const Key('video-previous'));
          final nextMonthRect = tester.getRect(nextMonth);
          final crystal = find.descendant(
            of: nextMonth,
            matching: find.byKey(_bubble),
          );
          expect(crystal, findsOneWidget);
          expect(tester.getSize(crystal), const Size(48, 48));
          expect(tester.getSize(nextMonth).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(nextMonth).height, greaterThanOrEqualTo(44));
          expect(
            (tester.getRect(crystal).center - nextMonthRect.center).distance,
            lessThan(1),
          );
          expect(tester.widget<IconButton>(previousMonth).onPressed, isNull);
          expect(tester.widget<IconButton>(previousVideo).onPressed, isNull);

          final semantics = tester.ensureSemantics();
          final node = tester.getSemantics(nextMonth);
          expect(node.flagsCollection.isButton, isTrue);
          expect(node.getSemanticsData().tooltip, 'Next month');
          await _capture(tester, 'rest_$caseId');

          final touch = await tester.startGesture(
            tester.getCenter(nextMonth),
          );
          await tester.pump();
          expect(find.byKey(_bubble), findsNWidgets(4));
          await _capture(tester, 'pressed_$caseId');
          await touch.cancel();
          await tester.pumpAndSettle();
          expect(find.text('Month 0'), findsOneWidget);
          expect(find.byKey(_bubble), findsNWidgets(4));

          await tester.tap(nextMonth);
          await tester.pumpAndSettle();
          expect(find.text('Month 1'), findsOneWidget);
          expect(tester.widget<IconButton>(nextMonth).onPressed, isNull);

          await tester.tap(nextVideo);
          await tester.pumpAndSettle();
          expect(find.text('Video 1'), findsOneWidget);
          expect(tester.widget<IconButton>(nextVideo).onPressed, isNull);

          await tester.tap(previousMonth);
          await tester.tap(previousVideo);
          await tester.pumpAndSettle();
          expect(find.text('Month 0'), findsOneWidget);
          expect(find.text('Video 0'), findsOneWidget);
          expect(find.byKey(_bubble), findsNWidgets(4));
          expect(tester.getRect(nextMonth), nextMonthRect);
          expect(tester.takeException(), isNull);
          semantics.dispose();
          await _capture(tester, 'after_$caseId');
        });
      }
    }
  }
}
