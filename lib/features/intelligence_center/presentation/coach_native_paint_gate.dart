import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';


/// Passive, bounded counters for the explicit offline Simulator diagnostic.
/// No text, message/account/generation identifiers or raw error data is stored.
class CoachNativeStageDiagnostics {
  static const enabled = kDebugMode &&
      bool.fromEnvironment('BIL_QA_NATIVE_COACH_STAGE_TIMING');
  static final _watch = Stopwatch();
  static final _rows = <Map<String, Object?>>[];
  static var _dropped = 0;
  static const _allowedStages = {
    'fixture_begin', 'reply_release', 'markdown_init', 'markdown_build', 'layout_builder',
    'platform_created', 'update_send', 'update_complete', 'height_received',
    'content_bounds_received', 'gate_schedule', 'gate_post_frame',
    'gate_size_wait', 'gate_set_visible_send', 'gate_set_visible_ack',
    'gate_ready', 'diagnostic_read_send', 'diagnostic_read_complete',
  };

  static void beginFixture() {
    if (!enabled) return;
    _rows.clear();
    _dropped = 0;
    _watch..reset()..start();
    mark('fixture_begin');
  }

  static void mark(String stage, [Map<String, Object?> values = const {}]) {
    if (!enabled) return;
    if (!_allowedStages.contains(stage) || _rows.length >= 512) {
      _dropped++;
      return;
    }
    _rows.add({
      'stage': stage, 'dart_elapsed_us': _watch.elapsedMicroseconds,
      for (final entry in values.entries)
        if (entry.value is bool || entry.value is int ||
            entry.value is double && (entry.value as double).isFinite)
          entry.key: entry.value,
    });
  }

  static Map<String, Object?> snapshot() => {
    'enabled': enabled, 'clock_domain': 'dart_fixture_stopwatch_us',
    'capacity': 512, 'dropped': _dropped,
    'rows': _rows.map((row) => Map<String, Object?>.of(row)).toList(),
  };
}

/// Opens the native surface after Flutter has reserved its measured body.
///
/// A frame count is not evidence of layout: a platform reply can arrive after
/// that frame's layout phase. Wait for the actual surface size instead, and
/// retain native acknowledgement and visit/generation ownership across awaits.
class CoachNativePaintGate {
  bool _scheduled = false;
  bool _disposed = false;
  String _stage = 'layout_wait';
  Object? _layoutGeneration;
  Timer? _layoutTimer;

  bool get scheduled => _scheduled;
  String get stage => _stage;

  /// Keeps the existing three-second fallback, once per native generation.
  /// Replayed geometry must not extend the deadline or restart a ready body.
  void beginLayout({
    required Object generation,
    required bool Function() isCurrent,
    required VoidCallback onFailure,
  }) {
    if (_disposed || _layoutGeneration == generation) return;
    _layoutTimer?.cancel();
    _layoutGeneration = generation;
    _stage = 'layout_wait';
    _layoutTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed && isCurrent()) {
        _stage = 'failed';
        onFailure();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _layoutTimer?.cancel();
  }

  void schedule({
    required bool Function() isCurrent,
    required Size Function() measuredSize,
    required RenderObject? Function() surface,
    required Future<bool?> Function(bool visible) setVisible,
    required VoidCallback onReady,
    required VoidCallback onFailure,
    required VoidCallback onComplete,
  }) {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    _stage = 'layout_wait';
    CoachNativeStageDiagnostics.mark('gate_schedule');

    bool active() => !_disposed && isCurrent();

    bool hasReservedBody() {
      final expected = measuredSize();
      final actual = surface();
      return expected.width.isFinite &&
          expected.height.isFinite &&
          expected.width > 0 &&
          expected.height > 0 &&
          actual is RenderBox &&
          actual.attached &&
          actual.hasSize &&
          actual.size.width.isFinite &&
          actual.size.height.isFinite &&
          (actual.size.width - expected.width).abs() <= .5 &&
          (actual.size.height - expected.height).abs() <= .5;
    }

    void finish() {
      _scheduled = false;
      onComplete();
    }

    void queue() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        CoachNativeStageDiagnostics.mark('gate_post_frame');
        if (!active()) {
          if (_stage != 'failed') _stage = 'retired';
          finish();
          return;
        }
        if (!hasReservedBody()) {
          CoachNativeStageDiagnostics.mark('gate_size_wait');
          _stage = 'layout_wait';
          queue();
          return;
        }
        var waitForLayout = false;
        try {
          _stage = 'native_ack';
          CoachNativeStageDiagnostics.mark('gate_set_visible_send');
          final acknowledged = await setVisible(true);
          CoachNativeStageDiagnostics.mark('gate_set_visible_ack', {'accepted': acknowledged == true});
          if (!active()) {
            await setVisible(false);
            if (_stage != 'failed') _stage = 'retired';
            return;
          }
          if (acknowledged == true) {
            // Geometry can change while the native main thread acknowledges.
            // Do not publish readiness for a body Flutter has not reserved.
            if (!hasReservedBody()) {
              await setVisible(false);
              waitForLayout = active();
              if (waitForLayout) {
                _stage = 'layout_wait';
              } else if (_stage != 'failed') {
                _stage = 'retired';
              }
              return;
            }
            _layoutTimer?.cancel();
            _stage = 'ready';
            CoachNativeStageDiagnostics.mark('gate_ready');
            onReady();
          } else {
            _stage = 'rejected';
          }
        } on PlatformException {
          if (active()) {
            _stage = 'failed';
            onFailure();
          } else if (_stage != 'failed') {
            _stage = 'retired';
          }
        } on MissingPluginException {
          if (active()) {
            _stage = 'failed';
            onFailure();
          } else if (_stage != 'failed') {
            _stage = 'retired';
          }
        } finally {
          if (waitForLayout) {
            queue();
          } else {
            finish();
          }
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    }

    queue();
  }
}
