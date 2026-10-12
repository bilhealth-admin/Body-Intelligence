import 'dart:io';
import 'dart:typed_data';

import 'package:body_intelligence_log/shared/widgets/bil_media_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

Uint8List _photoBytes() {
  final photo = image.Image(width: 12, height: 9)
    ..clear(image.ColorRgb8(24, 101, 172));
  return Uint8List.fromList(image.encodePng(photo));
}

Future<void> _pumpDecodedPreviews(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('bil-media-review-confirm')),
    );
    if (button.onPressed != null) return;
  }
  fail(
    'The original selected previews did not become ready within the bounded wait.',
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Widget _app({
  required Future<void> Function(BuildContext) open,
  Locale locale = const Locale('en'),
  double scale = 1,
  bool reduced = false,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => open(context),
        child: const Text('Open review'),
      ),
    ),
  ),
);

void main() {
  late bool previousHitTestSetting;
  setUp(() {
    previousHitTestSetting = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(
    () => WidgetController.hitTestWarningShouldBeFatal = previousHitTestSetting,
  );

  testWidgets(
    'reduced motion keeps the actual review and confirmation immediately reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<int>? submitted;
      await tester.pumpWidget(
        _app(
          locale: const Locale('ar'),
          scale: 2,
          reduced: true,
          open: (context) async {
            submitted = await showBilMediaReviewSheet<int>(
              context,
              entries: [
                BilMediaReviewEntry(
                  value: 7,
                  preview: MemoryImage(_photoBytes()),
                ),
              ],
              forCommunity: true,
            );
          },
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pump();
      final confirm = find.byKey(const Key('bil-media-review-confirm'));
      expect(confirm, findsOneWidget);
      final route = ModalRoute.of(tester.element(confirm))!;
      expect(route.transitionDuration, Duration.zero);
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(740));
      await _pumpDecodedPreviews(tester);
      expect(submitted, isNull, reason: 'no automatic acceptance');
      expect(confirm.hitTestable(), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(submitted, [7]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('multi-selection is staged, removable and never auto-accepted', (
    tester,
  ) async {
    List<int>? submitted;
    final bytes = _photoBytes();
    final entries = [
      for (var i = 0; i < 3; i++)
        BilMediaReviewEntry<int>(value: i, preview: MemoryImage(bytes)),
    ];
    await tester.pumpWidget(
      _app(
        open: (context) async {
          submitted = await showBilMediaReviewSheet<int>(
            context,
            entries: entries,
            forCommunity: true,
          );
        },
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    await _pumpDecodedPreviews(tester);
    await _tap(tester, 'bil-media-review-remove-1');
    expect(find.text('Selected: 2'), findsOneWidget);
    expect(submitted, isNull);
    await _tap(tester, 'bil-media-review-confirm');
    expect(submitted, [0, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel closes review without returning any media', (
    tester,
  ) async {
    List<int>? submitted;
    await tester.pumpWidget(
      _app(
        open: (context) async {
          submitted = await showBilMediaReviewSheet<int>(
            context,
            entries: [
              BilMediaReviewEntry(
                value: 17,
                preview: MemoryImage(_photoBytes()),
              ),
            ],
          );
        },
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    await _tap(tester, 'bil-media-review-cancel');
    expect(submitted, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small Arabic screen uses localized actions without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<int>? chosen;
    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        open: (context) async {
          chosen = await showBilMediaReviewSheet<int>(
            context,
            entries: [
              BilMediaReviewEntry(
                value: 1,
                preview: MemoryImage(_photoBytes()),
              ),
            ],
          );
        },
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة الصور المحددة'), findsOneWidget);
    expect(find.text('استخدام هذه الصورة'), findsOneWidget);
    await _pumpDecodedPreviews(tester);
    await _tap(tester, 'bil-media-review-confirm');
    expect(chosen, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile review has explicit update action and can be cancelled',
    (tester) async {
      bool? approved;
      await tester.pumpWidget(
        _app(
          open: (context) async {
            approved = await showBilSingleImageBytesReview(
              context,
              bytes: _photoBytes(),
            );
          },
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(find.text('Review your profile photo'), findsOneWidget);
      expect(find.text('Update photo'), findsOneWidget);
      await _tap(tester, 'bil-media-review-cancel');
      expect(approved, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  test('shared camera does not commit the picture at shutter press', () {
    final code = File(
      'lib/shared/widgets/bil_camera_capture_page.dart',
    ).readAsStringSync();
    expect(code, contains('_capturedForReview = image'));
    expect(code, contains("Key('bil-camera-retake')"));
    expect(code, contains("Key('bil-camera-use-photo')"));
    expect(
      RegExp(
        r'onPressed:\s*_reviewReady\s*&&\s*!_reviewFailed\s*\?\s*_useCapturedPhoto\s*:\s*null',
      ).hasMatch(code),
      isTrue,
      reason:
          'Camera acceptance must stay disabled until the original frame decoded successfully.',
    );
    expect(code, contains('!_reviewReady || _reviewFailed'));
    expect(code, isNot(contains('Navigator.of(context).pop(image)')));
  });

  testWidgets(
    'all four previews become ready without scrolling each into view',
    (tester) async {
      List<int>? chosen;
      final bytes = _photoBytes();
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          open: (context) async {
            chosen = await showBilMediaReviewSheet<int>(
              context,
              entries: [
                for (var i = 0; i < 4; i++)
                  BilMediaReviewEntry(value: i, preview: MemoryImage(bytes)),
              ],
              forCommunity: true,
            );
          },
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      await _pumpDecodedPreviews(tester);
      await _tap(tester, 'bil-media-review-confirm');
      expect(chosen, [0, 1, 2, 3]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'corrupt preview cannot be approved and can always be cancelled',
    (tester) async {
      List<int>? chosen;
      await tester.pumpWidget(
        _app(
          open: (context) async {
            chosen = await showBilMediaReviewSheet<int>(
              context,
              entries: [
                BilMediaReviewEntry(
                  value: 9,
                  preview: MemoryImage(Uint8List.fromList([1, 2, 3])),
                ),
              ],
            );
          },
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find
            .byKey(const Key('bil-media-review-error'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const Key('bil-media-review-error')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('bil-media-review-confirm')),
            )
            .onPressed,
        isNull,
      );
      expect(chosen, isNull);
      await _tap(tester, 'bil-media-review-cancel');
      expect(chosen, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [Size(320, 568), Size(390, 844), Size(640, 320)]) {
    testWidgets('Arabic 2x review scrolls to actions at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      List<int>? chosen;
      await tester.pumpWidget(
        _app(
          locale: const Locale('ar'),
          scale: 2,
          open: (context) async {
            chosen = await showBilMediaReviewSheet<int>(
              context,
              entries: [
                BilMediaReviewEntry(
                  value: 5,
                  preview: MemoryImage(_photoBytes()),
                ),
              ],
            );
          },
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      await _pumpDecodedPreviews(tester);
      final confirm = find.byKey(const Key('bil-media-review-confirm'));
      expect(
        tester.getBottomRight(confirm).dy,
        lessThanOrEqualTo(size.height),
        reason: 'Review confirmation must remain visible without scrolling.',
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, 'bil-media-review-confirm');
      expect(chosen, [5]);
      expect(tester.takeException(), isNull);
    });
  }
}
