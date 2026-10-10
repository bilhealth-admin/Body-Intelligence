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

void main() {
  testWidgets('multi-selection is staged, removable and never auto-accepted', (
    tester,
  ) async {
    List<int>? submitted;
    final bytes = _photoBytes();
    final entries = [
      for (var index = 0; index < 3; index++)
        BilMediaReviewEntry<int>(
          value: index,
          preview: MemoryImage(bytes),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open review'),
              onPressed: () async => submitted =
                  await showBilMediaReviewSheet<int>(
                    context,
                    entries: entries,
                    forCommunity: true,
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bil-media-review-confirm')), findsOneWidget);
    expect(submitted, isNull);
    await tester.tap(find.byKey(const Key('bil-media-review-remove-1')));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 2'), findsOneWidget);
    expect(submitted, isNull);
    await tester.tap(find.byKey(const Key('bil-media-review-confirm')));
    await tester.pumpAndSettle();
    expect(submitted, [0, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel closes review without returning any media', (tester) async {
    List<int>? submitted;
    final bytes = _photoBytes();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Review'),
              onPressed: () async => submitted =
                  await showBilMediaReviewSheet<int>(
                    context,
                    entries: [BilMediaReviewEntry(value: 17, preview: MemoryImage(bytes))],
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bil-media-review-cancel')));
    await tester.pumpAndSettle();
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
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('فتح'),
              onPressed: () async => chosen =
                  await showBilMediaReviewSheet<int>(
                    context,
                    entries: [
                      BilMediaReviewEntry(value: 1, preview: MemoryImage(_photoBytes())),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة الصور المحددة'), findsOneWidget);
    expect(find.text('استخدام هذه الصورة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('bil-media-review-confirm')));
    await tester.pumpAndSettle();
    expect(chosen, [1]);
  });

  test('shared camera does not commit the picture at shutter press', () {
    final code = File(
      'lib/shared/widgets/bil_camera_capture_page.dart',
    ).readAsStringSync();
    expect(code, contains("_capturedForReview = image"));
    expect(code, contains("Key('bil-camera-retake')"));
    expect(code, contains("Key('bil-camera-use-photo')"));
    expect(code, contains('onPressed: _useCapturedPhoto'));
    expect(code, isNot(contains('Navigator.of(context).pop(image)')));
  });
}
