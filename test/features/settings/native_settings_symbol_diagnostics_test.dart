import 'dart:async';

import 'package:body_intelligence_log/shared/widgets/bil_native_symbols.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final diagnostics = <BilNativeSymbolRenderDiagnostic>[];
  const pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  setUp(() {
    BilNativeSettingsSymbols.clearCache();
    diagnostics.clear();
    BilNativeSettingsSymbols.onDiagnostic = diagnostics.add;
  });

  tearDown(() {
    BilNativeSettingsSymbols.onDiagnostic = null;
    BilNativeSettingsSymbols.clearCache();
    messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, null);
  });

  Future<Uint8List?> load() => BilNativeSettingsSymbols.load(
    BilSettingsSymbol.profile,
    66,
    TargetPlatform.iOS,
  );

  test('successful bytes and cache coalescing remain unchanged', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, (
      call,
    ) async {
      calls++;
      expect(call.method, 'render');
      expect(call.arguments, {'symbol': 'profile', 'pixels': 66});
      return Uint8List.fromList(pngSignature);
    });
    final first = load();
    expect(identical(first, load()), isTrue);
    expect(await first, pngSignature);
    expect(await load(), pngSignature);
    expect(calls, 1);
    expect(diagnostics.single.outcome, BilNativeSymbolRenderOutcome.success);
    expect(diagnostics.single.errorType, isNull);
  });

  test('native null is distinguishable from a missing plugin', () async {
    messenger.setMockMethodCallHandler(
      BilNativeSettingsSymbols.channel,
      (_) async => null,
    );
    expect(await load(), isNull);
    expect(diagnostics.single.outcome, BilNativeSymbolRenderOutcome.nativeNull);
    expect(diagnostics.single.errorType, isNull);

    diagnostics.clear();
    messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, null);
    expect(await load(), isNull);
    expect(
      diagnostics.single.outcome,
      BilNativeSymbolRenderOutcome.missingPlugin,
    );
    expect(diagnostics.single.errorType, 'MissingPluginException');
  });

  test(
    'platform error is classified without message code or details',
    () async {
      messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, (
        _,
      ) async {
        throw PlatformException(
          code: 'diagnostic-only-private-code',
          message: 'DO_NOT_LOG_MESSAGE',
          details: {'private': 'DO_NOT_LOG_DETAILS'},
        );
      });
      expect(await load(), isNull);
      final diagnostic = diagnostics.single;
      expect(diagnostic.outcome, BilNativeSymbolRenderOutcome.platformError);
      expect(diagnostic.errorType, 'PlatformException');
      final json = diagnostic.toJson().toString();
      expect(json, isNot(contains('DO_NOT_LOG')));
      expect(json, isNot(contains('diagnostic-only-private-code')));
      expect(diagnostic.toJson().keys.toSet(), {
        'symbol',
        'pixels',
        'outcome',
        'elapsed_ms',
        'error_type',
      });
    },
  );

  test(
    'wrong native result type is reported without changing fallback',
    () async {
      messenger.setMockMethodCallHandler(
        BilNativeSettingsSymbols.channel,
        (_) async => 'not typed bytes',
      );
      expect(await load(), isNull);
      expect(
        diagnostics.single.outcome,
        BilNativeSymbolRenderOutcome.unexpectedError,
      );
      expect(diagnostics.single.errorType, contains('TypeError'));
    },
  );

  test(
    'unchanged two-second deadline rejects pending call and allows next retry',
    () async {
      final firstReply = Completer<Uint8List?>();
      var calls = 0;
      messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, (_) {
        calls++;
        return calls == 1
            ? firstReply.future
            : Future.value(Uint8List.fromList(pngSignature));
      });
      final clock = Stopwatch()..start();
      expect(await load(), isNull);
      expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(1900));
      expect(diagnostics.single.outcome, BilNativeSymbolRenderOutcome.timeout);
      expect(diagnostics.single.errorType, 'TimeoutException');
      expect(calls, 1);
      expect(await load(), pngSignature);
      firstReply.complete(Uint8List.fromList(pngSignature));
      expect(diagnostics.map((d) => d.outcome), [
        BilNativeSymbolRenderOutcome.timeout,
        BilNativeSymbolRenderOutcome.success,
      ]);
      expect(calls, 2);
    },
  );

  test(
    'throwing diagnostic observer cannot change successful render or retry',
    () async {
      BilNativeSettingsSymbols.onDiagnostic = (_) =>
          throw StateError('observer failure');
      messenger.setMockMethodCallHandler(
        BilNativeSettingsSymbols.channel,
        (_) async => Uint8List.fromList(pngSignature),
      );
      expect(await load(), pngSignature);
      BilNativeSettingsSymbols.clearCache();
      messenger.setMockMethodCallHandler(
        BilNativeSettingsSymbols.channel,
        (_) async => null,
      );
      expect(await load(), isNull);
    },
  );
}
