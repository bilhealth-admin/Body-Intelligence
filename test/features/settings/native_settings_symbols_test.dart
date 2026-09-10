import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/shared/widgets/bil_native_settings_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all 54 semantic symbols have iOS and Android native resources', () {
    expect(BilSettingsSymbol.values, hasLength(54));
    final swift = File(
      'ios/Runner/BILSettingsSymbolsBridge.swift',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILSettingsSymbolsBridge.kt',
    ).readAsStringSync();
    for (final symbol in BilSettingsSymbol.values) {
      expect(swift, contains('"${symbol.name}":'), reason: symbol.name);
      final match = RegExp(
        '"${symbol.name}" to R\\.drawable\\.(bil_symbol_\\w+)',
      ).firstMatch(kotlin);
      expect(match, isNotNull, reason: symbol.name);
      expect(
        File(
          'android/app/src/main/res/drawable/${match!.group(1)}.xml',
        ).existsSync(),
        isTrue,
        reason: symbol.name,
      );
    }
  });
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(BilNativeSettingsSymbols.clearCache);
  tearDown(() {
    BilNativeSettingsSymbols.clearCache();
    messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, null);
  });

  test('native icon reads are coalesced and pixel size is bounded', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, (
      call,
    ) async {
      calls.add(call);
      return Uint8List.fromList([1, 2, 3]);
    });
    final a = BilNativeSettingsSymbols.load(
      BilSettingsSymbol.email,
      999,
      TargetPlatform.android,
    );
    final b = BilNativeSettingsSymbols.load(
      BilSettingsSymbol.email,
      999,
      TargetPlatform.android,
    );
    expect(identical(a, b), isTrue);
    expect(await a, [1, 2, 3]);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'render');
    expect(calls.single.arguments, {'symbol': 'email', 'pixels': 128});
    await BilNativeSettingsSymbols.load(
      BilSettingsSymbol.email,
      -1,
      TargetPlatform.iOS,
    );
    expect(calls.last.arguments['pixels'], 16);
  });

  test(
    'missing native bridge is an explicit preview fallback, not proof',
    () async {
      messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, (
        call,
      ) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(
        await BilNativeSettingsSymbols.load(
          BilSettingsSymbol.profile,
          66,
          TargetPlatform.iOS,
        ),
        isNull,
      );
    },
  );

  test(
    'a transient native failure is retried on the next view request',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, (
        call,
      ) async {
        calls++;
        if (calls == 1) {
          throw PlatformException(code: 'temporarily_unavailable');
        }
        return Uint8List.fromList([1, 2, 3]);
      });
      Future<Uint8List?> load() => BilNativeSettingsSymbols.load(
        BilSettingsSymbol.email,
        66,
        TargetPlatform.android,
      );
      final first = load();
      expect(identical(first, load()), isTrue);
      expect(await first, isNull);
      final retry = load();
      expect(identical(retry, load()), isTrue);
      expect(await retry, [1, 2, 3]);
      expect(calls, 2);
    },
  );

  test('a late failed request cannot evict a newer cache entry', () async {
    final oldResult = Completer<Uint8List?>();
    final newResult = Completer<Uint8List?>();
    var calls = 0;
    messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, (
      call,
    ) {
      calls++;
      return calls == 1 ? oldResult.future : newResult.future;
    });
    Future<Uint8List?> load() => BilNativeSettingsSymbols.load(
      BilSettingsSymbol.profile,
      66,
      TargetPlatform.android,
    );
    final oldRequest = load();
    BilNativeSettingsSymbols.clearCache();
    final newRequest = load();
    oldResult.complete(null);
    expect(await oldRequest, isNull);
    expect(identical(load(), newRequest), isTrue);
    newResult.complete(Uint8List.fromList([4, 5, 6]));
    expect(await newRequest, [4, 5, 6]);
    expect(identical(load(), newRequest), isTrue);
    expect(calls, 2);
  });

  test(
    'native bitmap cache evicts old entries instead of growing indefinitely',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(BilNativeSettingsSymbols.channel, (
        call,
      ) async {
        calls++;
        return Uint8List.fromList([1]);
      });
      for (var pixels = 16; pixels < 96; pixels++) {
        await BilNativeSettingsSymbols.load(
          BilSettingsSymbol.profile,
          pixels,
          TargetPlatform.android,
        );
      }
      expect(calls, 80);
      await BilNativeSettingsSymbols.load(
        BilSettingsSymbol.profile,
        16,
        TargetPlatform.android,
      );
      expect(calls, 81);
    },
  );
}
