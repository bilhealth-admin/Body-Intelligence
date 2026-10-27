import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

bool get coachUsesNativeMarkdown => !kIsWeb && Platform.isIOS;

/// UIKit checks the factory's declared type, not only its constructed object.
Set<Factory<OneSequenceGestureRecognizer>> coachNativeMarkdownGestures() => {
  Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer()),
  Factory<HorizontalDragGestureRecognizer>(
    () => HorizontalDragGestureRecognizer(),
  ),
};

/// Native layout needs a composed platform surface before its readiness reply.
class CoachNativeMarkdownSurface extends StatelessWidget {
  const CoachNativeMarkdownSurface({
    required this.height,
    required this.ready,
    required this.child,
    super.key,
  });

  final double height;
  final bool ready;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: IgnorePointer(
      ignoring: !ready,
      child: ExcludeSemantics(
        excluding: !ready,
        // Zero Flutter opacity skips platform-view composition altogether.
        // UIKit owns temporary visibility while SwiftUI measures this surface.
        child: child,
      ),
    ),
  );
}

/// The current ai-coach contract is one validated JSON response, not SSE.
/// This native view formats that response; it never simulates token streaming.
class CoachNativeMarkdown extends StatefulWidget {
  const CoachNativeMarkdown({
    super.key,
    required this.text,
    required this.direction,
    required this.style,
    required this.visitIsCurrent,
    required this.fallback,
    this.onVisibleContentReady,
  });

  final String text;
  final TextDirection direction;
  final TextStyle style;
  final bool Function() visitIsCurrent;
  final Widget fallback;
  final ValueChanged<bool>? onVisibleContentReady;

  @override
  State<CoachNativeMarkdown> createState() => CoachNativeMarkdownState();
}

class CoachNativeMarkdownState extends State<CoachNativeMarkdown> {
  static const _diagnosticsEnabled =
      kDebugMode && bool.fromEnvironment('BIL_QA_NATIVE_DIAGNOSTIC');
  final _diagnosticClock = Stopwatch()..start();
  final _diagnosticEvents = <Map<String, Object?>>[];
  void _diagnostic(String event, [Map<String, Object?> values = const {}]) {
    if (!_diagnosticsEnabled || _diagnosticEvents.length >= 512) return;
    _diagnosticEvents.add({
      'ms': _diagnosticClock.elapsedMilliseconds,
      'event': event,
      'generation': _generation,
      ...values,
    });
  }

  Map<String, Object?> get nativeQaDiagnostics => {
    'id': identityHashCode(this),
    'generation': _generation,
    'height': _height,
    'width': _width,
    'height_ready': _heightReady,
    'paint_ready': _paintReady,
    'paint_gate_scheduled': _paintGateScheduled,
    'failed': _failed,
    'first_bounds': _firstContentBounds?.toString(),
    'events': [..._diagnosticEvents],
  };
  MethodChannel? _channel;
  String _generation = UniqueKey().toString();
  double _height = 60;
  double? _width;
  bool _failed = false;
  bool _heightReady = false;
  bool _paintReady = false;
  bool _paintGateScheduled = false;
  Rect? _firstContentBounds;
  Timer? _layoutTimer;
  bool? _reportedReadiness;
  bool _readinessQueued = false;
  bool get nativeLayoutReady => _paintReady;
  Rect? get nativeFirstContentBounds => _firstContentBounds;
  Map<String, Object>? _parameters;

  void _reportReadinessAfterPaint() {
    if (widget.onVisibleContentReady == null || _readinessQueued) return;
    final ready =
        widget.visitIsCurrent() &&
        (_failed || !coachUsesNativeMarkdown || _paintReady);
    if (ready == _reportedReadiness) return;
    _readinessQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readinessQueued = false;
      if (!mounted) return;
      final readyNow =
          widget.visitIsCurrent() &&
          (_failed || !coachUsesNativeMarkdown || _paintReady);
      if (readyNow != _reportedReadiness) {
        _reportedReadiness = readyNow;
        widget.onVisibleContentReady?.call(readyNow);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CoachNativeMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text ||
        widget.direction != oldWidget.direction ||
        widget.style != oldWidget.style) {
      _diagnostic('widget_parameters_changed', {
        'text_changed': widget.text != oldWidget.text,
        'style_changed': widget.style != oldWidget.style,
      });
      _generation = UniqueKey().toString();
      _parameters = null;
      _heightReady = false;
      _paintReady = false;
      _firstContentBounds = null;
    }
  }

  Map<String, Object> _payload(BuildContext context) => {
    'generation': _generation,
    'text': widget.visitIsCurrent() ? widget.text : '',
    'rtl': widget.direction == TextDirection.rtl,
    'fontSize': MediaQuery.textScalerOf(
      context,
    ).scale(widget.style.fontSize ?? 16),
    'foreground':
        (widget.style.color ?? Theme.of(context).colorScheme.onSurface)
            .toARGB32(),
    'accent': Theme.of(context).colorScheme.primary.toARGB32(),
  };

  Future<void> _update(Map<String, Object> payload) async {
    if (!mounted ||
        !widget.visitIsCurrent() ||
        payload['generation'] != _generation) {
      return;
    }
    try {
      _diagnostic('update_sent');
      await _channel?.invokeMethod<void>('update', payload);
    } on PlatformException {
      if (mounted) setState(() => _failed = true);
    } on MissingPluginException {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _schedulePaintGate() {
    if (!_heightReady ||
        _firstContentBounds == null ||
        _failed ||
        _paintReady ||
        _paintGateScheduled) {
      return;
    }
    _diagnostic('paint_gate_scheduled');
    _paintGateScheduled = true;
    final generation = _generation;
    // Let the existing Flutter history measure/reanchor the final native body
    // before revealing it. This is layout synchronization, not fake streaming.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (!mounted || !widget.visitIsCurrent()) return;
          if (_generation == generation && !_failed) {
            final channel = _channel;
            final acknowledged = await channel?.invokeMethod<bool>(
              'setVisible',
              {'generation': generation, 'visible': true},
            );
            _diagnostic('visibility_ack', {
              'ack': acknowledged,
              'scheduled_generation': generation,
            });
            if (!mounted ||
                !widget.visitIsCurrent() ||
                _generation != generation ||
                _failed) {
              await channel?.invokeMethod<bool>('setVisible', {
                'generation': generation,
                'visible': false,
              });
              return;
            }
            if (mounted &&
                widget.visitIsCurrent() &&
                _generation == generation &&
                acknowledged == true) {
              _layoutTimer?.cancel();
              setState(() => _paintReady = true);
            }
          }
        } on PlatformException {
          if (mounted) setState(() => _failed = true);
        } on MissingPluginException {
          if (mounted) setState(() => _failed = true);
        } finally {
          _paintGateScheduled = false;
          if (mounted && widget.visitIsCurrent() && _generation != generation) {
            _schedulePaintGate();
          }
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  Future<Object?> _receive(MethodCall call) async {
    if (!mounted || !widget.visitIsCurrent() || call.arguments is! Map) {
      return null;
    }
    final args = call.arguments as Map;
    _diagnostic('native_${call.method}', {
      'received_generation': args['generation'],
      if (call.method != 'openLink') ...args.cast<String, Object?>(),
    });
    if (args['generation'] != _generation) return null;
    switch (call.method) {
      case 'height':
        final height = args['height'];
        if (height is num &&
            height.isFinite &&
            height > 0 &&
            height <= 100000 &&
            (!_heightReady || (height - _height).abs() > .5)) {
          setState(() {
            _heightReady = true;
            _height = height.toDouble();
          });
        }
      case 'contentBounds':
        final coordinates = [
          args['x'],
          args['y'],
          args['width'],
          args['height'],
        ];
        if (coordinates.every((value) => value is num && value.isFinite)) {
          final values = coordinates.cast<num>();
          if (values[2] > 0 &&
              values[2] <= (_width ?? 0) + 1 &&
              values[3] > 0 &&
              values[3] <= 100000) {
            setState(
              () => _firstContentBounds = Rect.fromLTWH(
                values[0].toDouble(),
                values[1].toDouble(),
                values[2].toDouble(),
                values[3].toDouble(),
              ),
            );
          }
        }
      case 'openLink':
        final uri = coachMarkdownPublicLink(args['url']);
        if (uri != null) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } on PlatformException {
            // Existing copy/share and the complete transcript remain available.
          }
        }
    }
    _schedulePaintGate();
    return null;
  }

  @override
  void dispose() {
    _layoutTimer?.cancel();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reportReadinessAfterPaint();
    if (!widget.visitIsCurrent()) return const SizedBox.shrink();
    if (_failed || !coachUsesNativeMarkdown) return widget.fallback;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_width != constraints.maxWidth) {
          _diagnostic('width_changed', {
            'old_width': _width,
            'new_width': constraints.maxWidth,
          });
          _width = constraints.maxWidth;
          _generation = UniqueKey().toString();
          _parameters = null;
          _heightReady = false;
          _firstContentBounds = null;
          _paintReady = false;
        }
        var payload = _payload(context);
        if (!mapEquals(_parameters, payload)) {
          if (_parameters != null) {
            _generation = UniqueKey().toString();
            _paintReady = false;
            _heightReady = false;
            _firstContentBounds = null;
            payload = _payload(context);
          }
          _parameters = payload;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.visitIsCurrent()) _update(payload);
          });
        }
        _reportReadinessAfterPaint();
        return CoachNativeMarkdownSurface(
          height: _height,
          ready: nativeLayoutReady,
          child: UiKitView(
            viewType: 'bil/coach_markdown',
            layoutDirection: widget.direction,
            creationParams: payload,
            creationParamsCodec: const StandardMessageCodec(),
            gestureRecognizers: coachNativeMarkdownGestures(),
            onPlatformViewCreated: (id) {
              _diagnostic('platform_created', {'platform_id': id});
              _channel = MethodChannel('bil/coach_markdown/$id')
                ..setMethodCallHandler(_receive);
              _update(_payload(context));
              _layoutTimer?.cancel();
              _layoutTimer = Timer(const Duration(seconds: 3), () {
                if (mounted && widget.visitIsCurrent() && !nativeLayoutReady) {
                  _diagnostic('layout_deadline');
                  setState(() => _failed = true);
                }
              });
            },
          ),
        );
      },
    );
  }
}

/// Markdown is presentation, never a route/action authority. Only explicit
/// public HTTPS taps may leave the app. App-owned plan actions use their
/// existing admission/confirmation/receipt path below the native text.
Uri? coachMarkdownPublicLink(Object? raw) {
  if (raw is! String || raw.length > 4096) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      uri.hasPort && uri.port != 443) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (InternetAddress.tryParse(host) != null ||
      !host.contains('.') ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal') ||
      host.endsWith('.test') ||
      host.endsWith('.invalid') ||
      host.endsWith('.')) {
    return null;
  }
  return uri;
}
