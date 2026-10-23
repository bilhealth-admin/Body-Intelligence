import 'bil_glass_press_feedback.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared platform vocabulary for all semantic entry points in the app.
enum BilSettingsSymbol {
  profile,
  camera,
  email,
  height,
  people,
  calendar,
  location,
  postal,
  time,
  measure,
  nutrition,
  goals,
  preferences,
  language,
  appearance,
  privacy,
  exercise,
  notifications,
  health,
  cloud,
  support,
  moderation,
  weight,
  foodSearch,
  barcode,
  voice,
  notes,
  water,
  breakfast,
  lunch,
  dinner,
  snack,
  progress,
  report,
  challenges,
  recipes,
  fasting,
  sleep,
  devices,
  learn,
  messages,
  aiCoach,
  verifiedFood,
  export,
  accountDeletion,
  legal,
  heartRate,
  distance,
  bodyFat,
  oxygen,
  dashboard,
  discover,
  more,
  diary,
}

/// Non-sensitive outcomes for a native render attempt. No raw exception
/// messages, stack traces, user data or platform arguments are captured.
enum BilNativeSymbolRenderOutcome {
  success,
  nativeNull,
  timeout,
  missingPlugin,
  platformError,
  unexpectedError,
}

@immutable
class BilNativeSymbolRenderDiagnostic {
  const BilNativeSymbolRenderDiagnostic({
    required this.symbol,
    required this.pixels,
    required this.outcome,
    required this.elapsedMilliseconds,
    this.errorType,
  });

  final BilSettingsSymbol symbol;
  final int pixels;
  final BilNativeSymbolRenderOutcome outcome;
  final int elapsedMilliseconds;
  final String? errorType;

  Map<String, Object?> toJson() => {
    'symbol': symbol.name,
    'pixels': pixels,
    'outcome': outcome.name,
    'elapsed_ms': elapsedMilliseconds,
    if (errorType != null) 'error_type': errorType,
  };
}

/// Loads real SF Symbols from UIKit or Google's bundled Material Symbols
/// VectorDrawables on Android. No network, platform view or health data.
abstract final class BilNativeSettingsSymbols {
  static const channel = MethodChannel('bil/settings_symbols');
  static final _cache = <String, Future<Uint8List?>>{};

  /// Opt-in test diagnostics only. An observer cannot alter render results.
  @visibleForTesting
  static ValueChanged<BilNativeSymbolRenderDiagnostic>? onDiagnostic;

  static void _report(
    BilSettingsSymbol symbol,
    int pixels,
    Stopwatch clock,
    BilNativeSymbolRenderOutcome outcome, [
    Object? error,
  ]) {
    final observer = onDiagnostic;
    if (observer == null) return;
    try {
      observer(
        BilNativeSymbolRenderDiagnostic(
          symbol: symbol,
          pixels: pixels,
          outcome: outcome,
          elapsedMilliseconds: clock.elapsedMilliseconds,
          errorType: error?.runtimeType.toString(),
        ),
      );
    } on Object {
      // Diagnostics must never change the production fallback/cache behavior.
    }
  }

  static Future<Uint8List?> load(
    BilSettingsSymbol symbol,
    int pixels,
    TargetPlatform platform,
  ) {
    final safePixels = pixels.clamp(16, 128);
    final key = '${platform.name}:${symbol.name}:$safePixels';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    final future = _render(symbol, safePixels);
    _cache[key] = future;
    unawaited(
      future.then((bytes) {
        // Keep successful bitmaps, not transient platform failures. A later
        // page request can retry without a late failure evicting its result.
        if (bytes == null && identical(_cache[key], future)) {
          _cache.remove(key);
        }
      }),
    );
    while (_cache.length > 72) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  static Future<Uint8List?> _render(
    BilSettingsSymbol symbol,
    int pixels,
  ) async {
    final clock = Stopwatch()..start();
    try {
      final bytes = await channel
          .invokeMethod<Uint8List>('render', {
            'symbol': symbol.name,
            'pixels': pixels,
          })
          .timeout(const Duration(seconds: 2));
      _report(
        symbol,
        pixels,
        clock,
        bytes == null
            ? BilNativeSymbolRenderOutcome.nativeNull
            : BilNativeSymbolRenderOutcome.success,
      );
      return bytes;
    } on TimeoutException catch (error) {
      _report(
        symbol,
        pixels,
        clock,
        BilNativeSymbolRenderOutcome.timeout,
        error,
      );
      return null;
    } on MissingPluginException catch (error) {
      _report(
        symbol,
        pixels,
        clock,
        BilNativeSymbolRenderOutcome.missingPlugin,
        error,
      );
      return null;
    } on PlatformException catch (error) {
      _report(
        symbol,
        pixels,
        clock,
        BilNativeSymbolRenderOutcome.platformError,
        error,
      );
      return null;
    } on Object catch (error) {
      _report(
        symbol,
        pixels,
        clock,
        BilNativeSymbolRenderOutcome.unexpectedError,
        error,
      );
      // Desktop/web/widget previews must not pretend to be native iOS proof.
      return null;
    }
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();
}

class BilNativeSymbolGlyph extends StatelessWidget {
  const BilNativeSymbolGlyph({
    required this.symbol,
    required this.fallback,
    required this.size,
    required this.color,
    this.platformOverride,
    super.key,
  });
  final BilSettingsSymbol symbol;
  final IconData fallback;
  final double size;
  final Color color;
  final TargetPlatform? platformOverride;

  @override
  Widget build(BuildContext context) {
    final platform = platformOverride ?? Theme.of(context).platform;
    final native =
        !kIsWeb &&
        ((Platform.isIOS && platform == TargetPlatform.iOS) ||
            (Platform.isAndroid && platform == TargetPlatform.android));
    final preview = BilGlassPressFeedback(
      child: Icon(
        fallback,
        size: size,
        color: color,
        key: const Key('settings-symbol-preview-fallback'),
      ),
    );
    if (!native) return preview;
    return FutureBuilder<Uint8List?>(
      future: BilNativeSettingsSymbols.load(
        symbol,
        (size * MediaQuery.devicePixelRatioOf(context)).round(),
        platform,
      ),
      builder: (context, snapshot) => snapshot.data == null
          ? preview
          : BilGlassPressFeedback(
              always: BilArrowGlyph.isArrow(fallback),
              child: Image.memory(
                snapshot.data!,
                width: size,
                height: size,
                color: color,
                colorBlendMode: BlendMode.srcIn,
                key: ValueKey('native-settings-symbol-${symbol.name}'),
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
    );
  }
}
