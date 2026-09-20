import 'package:flutter/services.dart';

/// Local, optional microphone affordance sounds.
///
/// The files are bundled with each native target and never leave the device.
/// Sound failure is intentionally surfaced to the caller so it can fall back
/// to the platform click without affecting voice capture.
final class BilMicSound {
  const BilMicSound._();

  static const MethodChannel _channel = MethodChannel('bil/mic_sound');

  static Future<void> playOpen() => _play('playOpen');

  static Future<void> playEnd() => _play('playEnd');

  static Future<void> _play(String method) async {
    await _channel.invokeMethod<void>(method);
  }
}
