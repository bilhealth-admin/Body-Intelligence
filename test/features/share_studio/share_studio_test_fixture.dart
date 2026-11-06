import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/share_studio/share_studio_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../qa_next/feature_splashes_test_support.dart'
    show openFeatureSplashDatabase, closeFeatureSplashDatabase;

class TrackedShareImage extends Fake implements ui.Image {
  TrackedShareImage({
    this.empty = false,
    this.encodeFails = false,
    this.pendingBytes,
  });
  final bool empty, encodeFails;
  final Completer<ByteData?>? pendingBytes;
  int disposeCalls = 0, encodeCalls = 0;

  @override
  Future<ByteData?> toByteData({
    ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba,
  }) async {
    encodeCalls++;
    expect(format, ui.ImageByteFormat.png);
    if (encodeFails) throw StateError('Synthetic raster encode failure');
    if (pendingBytes != null) return pendingBytes!.future;
    if (empty) return null;
    return ByteData.sublistView(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlYsAAAAASUVORK5CYII=',
      ),
    );
  }

  @override
  void dispose() => disposeCalls++;
}

class ControlledShareClient extends Fake implements SharePlus {
  final requests = <ShareParams>[];
  int failures = 0;
  Completer<ShareResult>? pending;
  @override
  Future<ShareResult> share(ShareParams params) async {
    requests.add(params);
    if (failures > 0) {
      failures--;
      throw PlatformException(code: 'synthetic_native_share_failure');
    }
    return pending?.future ??
        Future.value(const ShareResult('fixture', ShareResultStatus.success));
  }
}

class ShareStudioFixture {
  ShareStudioFixture(
    this.tester,
    this.database,
    this.router,
    this.client,
    this.language,
  );
  final WidgetTester tester;
  final AppDatabase database;
  final GoRouter router;
  final ControlledShareClient client;
  final String language;
  final images = <TrackedShareImage>[];
  Completer<ui.Image>? heldRaster;
  Completer<ByteData?>? heldEncode;
  int captures = 0;
  bool rasterFails = false,
      emptyRaster = false,
      encodeFails = false,
      disposed = false;
  String t(String source) => AppLocalizations(Locale(language)).text(source);

  Future<ui.Image> capture(RenderRepaintBoundary boundary) async {
    captures++;
    expect(boundary.attached, isTrue);
    if (rasterFails) throw StateError('Synthetic toImage failure');
    if (heldRaster != null) return heldRaster!.future;
    final image = TrackedShareImage(
      empty: emptyRaster,
      encodeFails: encodeFails,
      pendingBytes: heldEncode,
    );
    images.add(image);
    return image;
  }

  Future<T> real<T>(Future<T> Function() action) async {
    T? value;
    Object? error;
    StackTrace? stack;
    await tester.runAsync(() async {
      try {
        value = await action().timeout(const Duration(seconds: 5));
      } on Object catch (failure, trace) {
        error = failure;
        stack = trace;
      }
    });
    if (error != null) Error.throwWithStackTrace(error!, stack!);
    return value as T;
  }

  Finder get shareButton => find
      .ancestor(
        of: find.text(t('Share image')),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      )
      .last;

  Future<void> revealShare() async {
    await tester.scrollUntilVisible(
      shareButton,
      150,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
      maxScrolls: 30,
    );
    await tester.ensureVisible(shareButton);
    await tester.pumpAndSettle();
  }

  Future<void> tapShare() async {
    await revealShare();
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    // Dispose providers/widgets within the test body before Flutter invariants.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final raster = heldRaster;
    if (raster != null && !raster.isCompleted) {
      final image = TrackedShareImage();
      images.add(image);
      raster.complete(image);
    }
    final encoding = heldEncode;
    if (encoding != null && !encoding.isCompleted) {
      encoding.complete(ByteData(1));
    }
    final native = client.pending;
    if (native != null && !native.isCompleted) {
      native.complete(
        const ShareResult('fixture', ShareResultStatus.dismissed),
      );
    }
    await tester.pumpAndSettle();
    router.dispose();
    await tester.pump(Duration.zero);
    await closeFeatureSplashDatabase(tester, database);
    await tester.binding.setSurfaceSize(null);
  }
}

Future<ShareStudioFixture> pumpShareStudio(
  WidgetTester tester, {
  String language = 'en',
  bool pushed = false,
  bool actualRaster = false,
  void Function(ShareStudioFixture)? configure,
}) async {
  final database = await openFeatureSplashDatabase(tester);
  final client = ControlledShareClient();
  final router = GoRouter(
    initialLocation: pushed ? '/dashboard' : '/share-studio',
    routes: [
      GoRoute(
        path: '/share-studio',
        builder: (_, _) => const ShareStudioPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, _) => Scaffold(
          key: const Key('share-studio-return-dashboard'),
          body: FilledButton(
            onPressed: () => context.push('/share-studio'),
            child: const Text('Open Share Studio'),
          ),
        ),
      ),
    ],
  );
  final fixture = ShareStudioFixture(
    tester,
    database,
    router,
    client,
    language,
  );
  configure?.call(fixture);
  // Keep FlutterView metrics and the render surface consistent for popovers.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.binding.setSurfaceSize(const Size(390, 844));
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          shareStudioShareClientProvider.overrideWithValue(client),
          if (!actualRaster)
            shareStudioImageCaptureProvider.overrideWithValue(fixture.capture),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (pushed) {
      await tester.tap(find.text('Open Share Studio'));
      await tester.pumpAndSettle();
    }
    return fixture;
  } on Object {
    await fixture.dispose();
    rethrow;
  }
}
