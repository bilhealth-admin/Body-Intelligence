import 'dart:async';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/share_studio/share_studio_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'share_studio_test_fixture.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final fault in ['raster', 'native']) {
      testWidgets('Share Studio $fault failure is recoverable $language', (
        tester,
      ) async {
        final f = await pumpShareStudio(tester, language: language);
        try {
          if (fault == 'raster') f.rasterFails = true;
          if (fault == 'native') f.client.failures = 1;
          await f.tapShare();
          expect(
            find.text(f.t('Could not prepare sharing data. Try again.')),
            findsOneWidget,
          );
          final retry = tester.widget<FilledButton>(f.shareButton);
          expect(retry.onPressed, isNotNull);
          expect(f.client.requests, hasLength(fault == 'native' ? 1 : 0));
          if (fault == 'native') expect(f.images.single.disposeCalls, 1);
          f.rasterFails = false;
          await f.tapShare();
          expect(f.client.requests, hasLength(fault == 'native' ? 2 : 1));
          expect(f.images.every((image) => image.disposeCalls == 1), isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          await f.dispose();
        }
      });
    }
  }

  for (final fault in ['empty', 'encode']) {
    testWidgets(
      'Share Studio $fault PNG result unlocks without native dispatch',
      (tester) async {
        final f = await pumpShareStudio(tester);
        try {
          f.emptyRaster = fault == 'empty';
          f.encodeFails = fault == 'encode';
          await f.tapShare();
          expect(f.client.requests, isEmpty);
          expect(f.images.single.disposeCalls, 1);
          expect(
            find.text(f.t('Could not prepare sharing data. Try again.')),
            findsOneWidget,
          );
          expect(
            tester.widget<FilledButton>(f.shareButton).onPressed,
            isNotNull,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await f.dispose();
        }
      },
    );
  }

  testWidgets(
    'Share Studio prepares PNG metadata and a visible native origin without weight values',
    (tester) async {
      final f = await pumpShareStudio(tester);
      try {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ShareStudioPage)),
        );
        await f.real(() => WeightRepository(f.database).addWeight(88.8));
        container.invalidate(shareStudioDataProvider);
        await f.real(() => container.read(shareStudioDataProvider.future));
        await tester.pumpAndSettle();
        expect(find.textContaining('88.8'), findsNothing);
        await f.tapShare();
        expect(
          MediaQuery.sizeOf(tester.element(find.byType(ShareStudioPage))),
          const Size(390, 844),
          reason:
              'Native share geometry must use the configured phone viewport.',
        );
        final params = f.client.requests.single;
        expect(params.text, 'BIL progress card');
        expect(params.subject, 'My BIL progress');
        expect(params.files, hasLength(1));
        final file = params.files!.single;
        // IO XFile ignores name; the native share adapter consumes overrides.
        expect(params.fileNameOverrides, ['bil-progress.png']);
        expect(file.mimeType, 'image/png');
        final bytes = await file.readAsBytes();
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final origin = params.sharePositionOrigin!;
        final viewport = const Rect.fromLTWH(0, 0, 390, 844);
        expect(origin.isFinite, isTrue);
        expect(origin.isEmpty, isFalse);
        expect(viewport.contains(origin.topLeft), isTrue);
        expect(
          viewport.contains(origin.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
        expect(f.images.single.disposeCalls, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    },
  );

  testWidgets(
    'Share Studio handles two actual taps as one pending raster/share',
    (tester) async {
      final held = Completer<ui.Image>();
      final f = await pumpShareStudio(
        tester,
        configure: (fixture) => fixture.heldRaster = held,
      );
      try {
        await f.revealShare();
        final action = f.shareButton;
        // Both gestures are delivered before the rebuilding frame disables it.
        await tester.tap(action);
        await tester.tap(action);
        await tester.pump();
        expect(f.captures, 1);
        expect(f.client.requests, isEmpty);
        final image = TrackedShareImage();
        f.images.add(image);
        held.complete(image);
        await tester.pumpAndSettle();
        expect(f.client.requests, hasLength(1));
        expect(image.disposeCalls, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    },
  );

  for (final stage in ['raster', 'encoding', 'native']) {
    testWidgets('Share Studio leaving during $stage never uses a stale view', (
      tester,
    ) async {
      final f = await pumpShareStudio(tester);
      try {
        if (stage == 'raster') f.heldRaster = Completer<ui.Image>();
        if (stage == 'encoding') f.heldEncode = Completer<ByteData?>();
        if (stage == 'native') f.client.pending = Completer<ShareResult>();
        await f.tapShare();
        expect(f.captures, 1);
        if (stage != 'native') expect(f.client.requests, isEmpty);
        f.router.go('/dashboard');
        await tester.pumpAndSettle();
        if (stage == 'raster') {
          final image = TrackedShareImage();
          f.images.add(image);
          f.heldRaster!.complete(image);
        } else if (stage == 'encoding') {
          f.heldEncode!.complete(ByteData(8));
        } else {
          f.client.pending!.completeError(
            PlatformException(code: 'synthetic_late_native_error'),
          );
        }
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('share-studio-return-dashboard')),
          findsOneWidget,
        );
        expect(f.client.requests, hasLength(stage == 'native' ? 1 : 0));
        expect(f.images.single.disposeCalls, 1);
        expect(
          find.text(f.t('Could not prepare sharing data. Try again.')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    });
  }

  testWidgets(
    'Share Studio default adapter rasterizes the actual boundary to PNG locally',
    (tester) async {
      final f = await pumpShareStudio(tester, actualRaster: true);
      ui.Image? image;
      try {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ShareStudioPage)),
        );
        final boundaryFinder = find.descendant(
          of: find.byType(ShareStudioPage),
          matching: find.byWidgetPredicate(
            (widget) => widget is RepaintBoundary && widget.key is GlobalKey,
          ),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          boundaryFinder,
        );
        final capture = container.read(shareStudioImageCaptureProvider);
        final captured = await f.real(() => capture(boundary));
        image = captured;
        expect(captured.width, greaterThan(0));
        expect(captured.height, greaterThan(0));
        final png = await f.real(
          () => captured.toByteData(format: ui.ImageByteFormat.png),
        );
        expect(png, isNotNull);
        expect(png!.buffer.asUint8List().take(8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]);
        expect(
          f.client.requests,
          isEmpty,
          reason: 'This is a local raster boundary probe only.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        image?.dispose();
        if (image != null) expect(image.debugDisposed, isTrue);
        await f.dispose();
      }
    },
  );

  for (final pushed in [false, true]) {
    testWidgets('Share Studio Back keeps a real destination pushed=$pushed', (
      tester,
    ) async {
      final f = await pumpShareStudio(tester, pushed: pushed);
      try {
        expect(find.byType(ShareStudioPage), findsOneWidget);
        await tester.tap(find.byKey(const Key('secondary-page-back')));
        await tester.pumpAndSettle();
        expect(f.router.state.uri.path, '/dashboard');
        expect(
          find.byKey(const Key('share-studio-return-dashboard')),
          findsOneWidget,
        );
        expect(f.client.requests, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    });
  }
}
