import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_brief_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../visual_closure/visual_evidence_font.dart';

const featureSplashDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Host-only visual evidence: production retains the native platform font.
/// Explicit BILDisplay/BILArabic widget styles still override this theme.
ThemeData featureSplashEvidenceTheme({
  required String language,
  required bool dark,
  bool highContrast = false,
}) => visualEvidenceTheme(
  dark
      ? BilFlagshipTheme.dark(
          isArabic: language == 'ar',
          highContrast: highContrast,
        )
      : BilFlagshipTheme.light(
          isArabic: language == 'ar',
          highContrast: highContrast,
        ),
  fontFamily: language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
);

Widget featureSplashApp({
  required Widget child,
  required String language,
  required bool dark,
  double scale = 1,
  bool reduceMotion = false,
  bool highContrast = false,
}) => MaterialApp(
  theme: featureSplashEvidenceTheme(
    language: language,
    dark: dark,
    highContrast: highContrast,
  ),
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: featureSplashDelegates,
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduceMotion,
      highContrast: highContrast,
    ),
    child: widget!,
  ),
  home: child,
);

/// Create AND first-open the native test database in the same real async
/// zone. runAsync does not migrate an earlier future's scheduling zone.
/// This is fixture setup; the production 2.2-second visual hold stays virtual.
Future<AppDatabase> openFeatureSplashDatabase(WidgetTester tester) async {
  final opened = await tester.runAsync(() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    debugPrint('BIL_FEATURE_SQLITE stage=constructed real_async=true');
    try {
      final rows = await database
          .customSelect('SELECT 1 AS opened')
          .get()
          .timeout(const Duration(seconds: 15));
      if (rows.length != 1 || rows.single.read<int>('opened') != 1) {
        throw StateError('Native SQLite fixture readback failed');
      }
      debugPrint('BIL_FEATURE_SQLITE stage=opened readback=1');
      return database;
    } catch (error, stack) {
      // Keep the original setup failure. Shutdown is bounded in the same
      // real zone, so a failed opener cannot orphan runAsync for 10 minutes.
      try {
        await database.close().timeout(const Duration(seconds: 5));
      } catch (closeError) {
        debugPrint(
          'BIL_FEATURE_SQLITE stage=cleanup_failed '
          'type=${closeError.runtimeType}',
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
  });
  if (opened == null) {
    throw StateError('Native SQLite fixture setup failed; see async exception');
  }
  return opened;
}

Future<void> closeFeatureSplashDatabase(
  WidgetTester tester,
  AppDatabase database,
) async {
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  final watch = Stopwatch()..start();
  final closing = database.close();
  unawaited(
    closing.then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        completed = true;
      },
    ),
  );
  while (!completed && watch.elapsed < const Duration(seconds: 5)) {
    // An omitted duration drains only microtasks. Explicit zero also runs
    // Drift's due Timer.run stream-cache cleanup without advancing the clock.
    // These are teardown frames after the 2.2-second hold assertions.
    await tester.pump(Duration.zero);
    if (!completed) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }
  if (!completed) {
    throw TimeoutException(
      'Native feature fixture close did not complete '
      'after draining fake/real queues',
      const Duration(seconds: 5),
    );
  }
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  debugPrint(
    'BIL_FEATURE_SQLITE stage=closed drain_ms=${watch.elapsedMilliseconds}',
  );
}

class _CaptureOnlyGateway implements LocalModelGateway {
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) =>
      throw StateError('Splash capture must never ask the AI or spend credits');
}

/// The real page, actual SQLite and presentation; only unavailable network
/// health/model dependencies are replaced with empty synthetic evidence.
class FeatureCoachSplashHarness {
  FeatureCoachSplashHarness({
    required this.language,
    required this.dark,
    this.scale = 1,
    this.reduceMotion = false,
    this.highContrast = false,
  });
  final String language;
  final bool dark;
  final double scale;
  final bool reduceMotion;
  final bool highContrast;
  AppDatabase? database;
  GoRouter? router;
  VoidCallback? _releaseTtsMock;

  Future<void> mount(WidgetTester tester, {GlobalKey? captureKey}) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const tts = MethodChannel('bil/tts');
    if (messenger.checkMockMessageHandler(tts.name, null)) {
      // Host-only teardown contract: production native bridges support stop.
      // Any available/speak/other method still fails, never inventing speech.
      messenger.setMockMethodCallHandler(tts, (call) async {
        if (call.method != 'stop') throw MissingPluginException(call.method);
        return null;
      });
      _releaseTtsMock = () => messenger.setMockMethodCallHandler(tts, null);
    }
    final db = await openFeatureSplashDatabase(tester);
    database = db;
    router = GoRouter(
      initialLocation: '/intelligence-center',
      routes: [
        GoRoute(
          path: '/intelligence-center',
          builder: (_, _) => const IntelligenceCenterPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Destination')),
        ),
      ],
    );
    debugPrint('BIL_FEATURE_HARNESS stage=before_pump_widget');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          coachContextSnapshotProvider.overrideWith(
            (ref) async => CoachContextSnapshot.empty(),
          ),
          coachHealthBriefProvider.overrideWith(
            (ref) async => CoachContextSnapshot.empty(),
          ),
          intelligenceCenterModelGatewayProvider.overrideWithValue(
            _CaptureOnlyGateway(),
          ),
          intelligenceHealthContextProvider.overrideWith(
            (ref) async => const IntelligenceHealthContext(
              primaryMessage: '',
              explanation: [],
              confidence: 1,
              evidence: [],
              missingData: [],
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: featureSplashEvidenceTheme(
            language: language,
            dark: dark,
            highContrast: highContrast,
          ),
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: featureSplashDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
              highContrast: highContrast,
            ),
            child: captureKey == null
                ? child!
                : RepaintBoundary(key: captureKey, child: child!),
          ),
        ),
      ),
    );
    debugPrint('BIL_FEATURE_HARNESS stage=after_pump_widget');
    await tester.pump();
    debugPrint('BIL_FEATURE_HARNESS stage=after_first_pump');
  }

  Future<void> dispose(WidgetTester tester) async {
    try {
      debugPrint('BIL_FEATURE_HARNESS stage=before_unmount');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // Keep the precise stop-only handler through unmount and queue draining.
      debugPrint('BIL_FEATURE_HARNESS stage=after_unmount');
      router?.dispose();
      router = null;
      final closing = database;
      database = null;
      if (closing == null) return;
      debugPrint('BIL_FEATURE_HARNESS stage=before_close');
      await closeFeatureSplashDatabase(tester, closing);
      debugPrint('BIL_FEATURE_HARNESS stage=after_close');
    } finally {
      _releaseTtsMock?.call();
      _releaseTtsMock = null;
    }
  }
}

Future<void> writeFeatureSplashCapture(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final directory = Platform.environment['BIL_FEATURE_SPLASH_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
