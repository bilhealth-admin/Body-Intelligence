import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_workout_video_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeWorkoutVideoPlatform platform;
  late VideoPlayerPlatform originalPlatform;
  late List<VideoPlayerController> controllers;

  Future<VideoPlayerController> createController() async {
    final controller = _ObservedController(
      Uri.parse('https://workouts.bilhealth.com/test.mp4'),
    );
    controllers.add(controller);
    return controller;
  }

  Widget player({
    Future<VideoPlayerController> Function()? factory,
    Duration position = Duration.zero,
    ValueChanged<Duration>? onPosition,
    Duration timeout = const Duration(seconds: 1),
  }) => buildWorkoutFullscreenVideoForTest(
    controllerFactory: factory ?? createController,
    initialPosition: position,
    onPositionChanged: onPosition,
    initializationTimeout: timeout,
    commandTimeout: timeout,
    bufferingTimeout: const Duration(seconds: 2),
    controlsAutoHideDuration: const Duration(seconds: 1),
  );

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    platform = FakeWorkoutVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    controllers = [];
  });
  tearDown(() => VideoPlayerPlatform.instance = originalPlatform);

  for (final screen in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 1366),
    const Size(1366, 1024),
  ]) {
    testWidgets('complete frame and filled backdrop at $screen', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screen;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(player()));
      await _flush(tester);
      final frame = tester.getSize(_key('workout-video-complete-frame'));
      expect(frame.width / frame.height, closeTo(720 / 1280, 0.0001));
      expect(frame.width, lessThanOrEqualTo(screen.width));
      expect(frame.height, lessThanOrEqualTo(screen.height));
      expect(tester.getSize(_key('workout-video-blurred-background')), screen);
      expect(controllers.single.value.isPlaying, isTrue);
      expect(tester.takeException(), isNull);
      await _remove(tester);
      expect((controllers.single as _ObservedController).disposals, 1);
      expect(
        (controllers.single as _ObservedController).disposeErrors,
        isEmpty,
      );
      expect(platform.disposed, [0]);
    });
  }

  testWidgets('controls autohide, replay, seek and change speed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(player(position: const Duration(seconds: 12))),
    );
    await _flush(tester);
    expect(platform.positions[0], const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<AnimatedOpacity>(_key('workout-video-controls-overlay'))
          .opacity,
      0,
    );
    await tester.tap(_key('workout-video-fullscreen-surface'));
    await _flush(tester);
    expect(controllers.single.value.isPlaying, isFalse);
    await tester.tap(_key('workout-video-control-replay'));
    await _flush(tester);
    expect(platform.positions[0], Duration.zero);
    expect(controllers.single.value.isPlaying, isTrue);
    final slider = tester.widget<Slider>(_key('workout-video-progress'));
    slider.onChangeStart!(15000);
    slider.onChanged!(15000);
    slider.onChangeEnd!(15000);
    await _flush(tester);
    expect(platform.positions[0], const Duration(seconds: 15));
    await tester.tap(_key('workout-video-control-speed'));
    await _flush(tester);
    await tester.tap(find.text('1.5×').last);
    await _flush(tester);
    expect(platform.speeds, contains(1.5));
    await _remove(tester);
  });

  testWidgets('ongoing buffering expires, then Retry creates a new player', (
    tester,
  ) async {
    await tester.pumpWidget(_app(player()));
    await _flush(tester);
    platform.positions[0] = const Duration(seconds: 8);
    controllers.single.value = controllers.single.value.copyWith(
      position: const Duration(seconds: 8),
      isBuffering: true,
    );
    await tester.pump(const Duration(seconds: 3));
    await _flush(tester);
    expect(find.textContaining('Playback stalled'), findsOneWidget);
    await _drainDisposal(tester);
    expect(platform.disposed, [0]);
    await tester.tap(_key('workout-video-fullscreen-retry'));
    await _flush(tester);
    expect(platform.sources, hasLength(2));
    expect(platform.positions[1], const Duration(seconds: 8));
    expect(controllers.last.value.isPlaying, isTrue);
    await _remove(tester);
  });

  testWidgets('advancing stream does not expire despite buffering flag', (
    tester,
  ) async {
    await tester.pumpWidget(_app(player()));
    await _flush(tester);
    for (var second = 1; second <= 5; second++) {
      platform.positions[0] = Duration(seconds: second);
      controllers.single.value = controllers.single.value.copyWith(
        position: Duration(seconds: second),
        isBuffering: true,
      );
      await tester.pump(const Duration(seconds: 1));
    }
    expect(_key('workout-video-fullscreen-retry'), findsNothing);
    expect(platform.disposed, isEmpty);
    await _remove(tester);
  });

  testWidgets('controls hide after playback recovers from buffering', (
    tester,
  ) async {
    await tester.pumpWidget(_app(player()));
    await _flush(tester);
    controllers.single.value = controllers.single.value.copyWith(
      isBuffering: true,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _flush(tester);
    controllers.single.value = controllers.single.value.copyWith(
      isBuffering: false,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<AnimatedOpacity>(_key('workout-video-controls-overlay'))
          .opacity,
      0,
    );
    await _remove(tester);
  });

  testWidgets(
    'stuck seek enters Retry and its late result cannot alter the new player',
    (tester) async {
      await tester.pumpWidget(_app(player()));
      await _flush(tester);
      final blockedSeek = Completer<void>();
      platform.pendingSeek = blockedSeek.future;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 2));
      await _flush(tester);
      expect(_key('workout-video-fullscreen-retry'), findsOneWidget);
      platform.pendingSeek = null;
      await tester.tap(_key('workout-video-fullscreen-retry'));
      await _flush(tester);
      blockedSeek.complete();
      await _flush(tester);
      expect(controllers, hasLength(2));
      expect(controllers.last.value.position, Duration.zero);
      expect(controllers.last.value.isPlaying, isTrue);
      expect(tester.takeException(), isNull);
      await _remove(tester);
    },
  );

  testWidgets('factory timeout is retryable and late source is disposed', (
    tester,
  ) async {
    final pending = Completer<VideoPlayerController>();
    await tester.pumpWidget(_app(player(factory: () => pending.future)));
    await _flush(tester);
    await tester.pump(const Duration(seconds: 2));
    await _flush(tester);
    expect(_key('workout-video-fullscreen-retry'), findsOneWidget);
    final late = await createController();
    pending.complete(late);
    await _flush(tester);
    expect(platform.sources, isEmpty);
    expect(() => late.addListener(() {}), throwsFlutterError);
    await _remove(tester);
  });

  testWidgets('native initialization timeout does not erase resume position', (
    tester,
  ) async {
    platform.initializeAutomatically = false;
    var saved = const Duration(seconds: 16);
    await tester.pumpWidget(
      _app(player(position: saved, onPosition: (value) => saved = value)),
    );
    await _flush(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(_key('workout-video-fullscreen-retry'), findsOneWidget);
    expect(saved, const Duration(seconds: 16));
    platform.initializeAutomatically = true;
    await tester.tap(_key('workout-video-fullscreen-retry'));
    await _flush(tester);
    expect(platform.positions[1], const Duration(seconds: 16));
    await _remove(tester);
  });

  testWidgets('background during initialization never autoplays on resume', (
    tester,
  ) async {
    platform.initializeAutomatically = false;
    await tester.pumpWidget(_app(player()));
    await _flush(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    platform.initializePlayer(0);
    await _flush(tester);
    expect(platform.plays, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    expect(platform.plays, isEmpty);
    await tester.tap(_key('workout-video-control-play-pause'));
    await _flush(tester);
    expect(platform.plays, [0]);
    await _remove(tester);
  });

  testWidgets('background pauses active video and resume waits for user', (
    tester,
  ) async {
    await tester.pumpWidget(_app(player()));
    await _flush(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _flush(tester);
    final playCount = platform.plays.length;
    expect(controllers.single.value.isPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    expect(platform.plays, hasLength(playCount));
    await _remove(tester);
  });

  testWidgets('Back does not await a hung native pause', (tester) async {
    final blockedPause = Completer<void>();
    await tester.pumpWidget(_app(const Scaffold(body: Text('Library'))));
    await _flush(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(MaterialPageRoute<void>(builder: (_) => player())),
    );
    await _flush(tester);
    platform.pendingPause = blockedPause.future;
    await tester.tap(_key('workout-video-fullscreen-back'));
    await tester.pump(const Duration(milliseconds: 400));
    await _flush(tester);
    expect(find.text('Library'), findsOneWidget);
    blockedPause.complete();
    await _flush(tester);
    await _remove(tester);
  });

  testWidgets('Back during initial resume seek preserves the saved position', (
    tester,
  ) async {
    final seek = Completer<void>();
    platform.pendingSeek = seek.future;
    var saved = const Duration(seconds: 16);
    await tester.pumpWidget(_app(const Scaffold(body: Text('Library'))));
    await _flush(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => player(
            position: saved,
            onPosition: (position) => saved = position,
          ),
        ),
      ),
    );
    await _flush(tester);
    await tester.tap(_key('workout-video-fullscreen-back'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(saved, const Duration(seconds: 16));
    seek.complete();
    await _flush(tester);
    await _remove(tester);
  });

  testWidgets('stuck initial play command becomes a retry error', (
    tester,
  ) async {
    final blockedPlay = Completer<void>();
    platform.pendingPlay = blockedPlay.future;
    await tester.pumpWidget(_app(player()));
    await _flush(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(_key('workout-video-fullscreen-retry'), findsOneWidget);
    blockedPlay.complete();
    await _flush(tester);
    await _remove(tester);
  });

  testWidgets('completed playback clears saved position', (tester) async {
    var saved = const Duration(seconds: 20);
    await tester.pumpWidget(
      _app(player(position: saved, onPosition: (p) => saved = p)),
    );
    await _flush(tester);
    controllers.single.value = controllers.single.value.copyWith(
      position: const Duration(minutes: 1),
      isCompleted: true,
      isPlaying: false,
    );
    await _remove(tester);
    expect(saved, Duration.zero);
  });

  testWidgets('unsupported speed restores normal playback', (tester) async {
    platform.rejectFastSpeed = true;
    await tester.pumpWidget(_app(player()));
    await _flush(tester);
    await tester.tap(_key('workout-video-control-speed'));
    await _flush(tester);
    await tester.tap(find.text('1.5×').last);
    await _flush(tester);
    expect(controllers.single.value.playbackSpeed, 1);
    expect(controllers.single.value.isPlaying, isTrue);
    expect(_key('workout-video-fullscreen-retry'), findsNothing);
    await _remove(tester);
  });

  testWidgets('unsupported speed selected while paused recovers at Play', (
    tester,
  ) async {
    platform.rejectFastSpeed = true;
    await tester.pumpWidget(_app(player()));
    await _flush(tester);
    await tester.tap(_key('workout-video-control-play-pause'));
    await _flush(tester);
    await tester.tap(_key('workout-video-control-speed'));
    await _flush(tester);
    await tester.tap(find.text('1.5×').last);
    await _flush(tester);
    await tester.tap(_key('workout-video-control-play-pause'));
    await _flush(tester);
    expect(controllers.single.value.playbackSpeed, 1);
    expect(controllers.single.value.isPlaying, isTrue);
    expect(_key('workout-video-fullscreen-retry'), findsNothing);
    await _remove(tester);
  });

  testWidgets('large Arabic error in landscape scrolls to Retry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(568, 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        player(factory: () => Future.error(StateError('offline'))),
        locale: const Locale('ar'),
        scale: 3,
      ),
    );
    await _flush(tester);
    expect(_key('workout-video-fullscreen-retry'), findsOneWidget);
    await tester.ensureVisible(_key('workout-video-fullscreen-retry'));
    await _flush(tester);
    expect(tester.takeException(), isNull);
    await _remove(tester);
  });

  testWidgets('keyboard and Arabic large text remain usable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(player(), locale: const Locale('ar'), scale: 2),
    );
    await _flush(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _flush(tester);
    expect(controllers.single.value.isPlaying, isFalse);
    expect(
      tester.getSize(_key('workout-video-fullscreen-back')),
      const Size(48, 48),
    );
    expect(tester.takeException(), isNull);
    await _remove(tester);
  });
}

Finder _key(String value) => find.byKey(ValueKey(value));

Widget _app(
  Widget home, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

Future<void> _remove(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _flush(tester);
  await _drainDisposal(tester);
}

Future<void> _drainDisposal(WidgetTester tester) async {
  // Plugin stream cancellation leaves the widget fake clock. Drain that
  // future before checking cleanup or restoring the platform singleton.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await _flush(tester);
}

class _ObservedController extends VideoPlayerController {
  _ObservedController(super.dataSource) : super.networkUrl();

  int disposals = 0;
  final disposeErrors = <Object>[];

  @override
  Future<void> dispose() async {
    disposals += 1;
    try {
      await super.dispose();
    } catch (error) {
      disposeErrors.add(error);
      rethrow;
    }
  }
}
