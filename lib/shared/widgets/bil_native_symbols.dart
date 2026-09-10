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

/// Loads real SF Symbols from UIKit or Google's bundled Material Symbols
/// VectorDrawables on Android. No network, platform view or health data.
abstract final class BilNativeSettingsSymbols {
  static const channel = MethodChannel('bil/settings_symbols');
  static final _cache = <String, Future<Uint8List?>>{};

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
    try {
      return await channel
          .invokeMethod<Uint8List>('render', {
            'symbol': symbol.name,
            'pixels': pixels,
          })
          .timeout(const Duration(seconds: 2));
    } on Object {
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
    final preview = Icon(
      fallback,
      size: size,
      color: color,
      key: const Key('settings-symbol-preview-fallback'),
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
          : Image.memory(
              snapshot.data!,
              width: size,
              height: size,
              color: color,
              colorBlendMode: BlendMode.srcIn,
              key: ValueKey('native-settings-symbol-${symbol.name}'),
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
    );
  }
}
