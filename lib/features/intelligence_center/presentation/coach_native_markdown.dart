import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'coach_native_paint_gate.dart';

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

/// Creates the existing native renderer during the normal Coach entry hold,
/// before a reply arrives. It contains only fixed, transparent preparation text;
/// no account/context data, input, semantics, network or AI work is involved.
class CoachNativeRendererPreparation extends StatelessWidget {
  const CoachNativeRendererPreparation({super.key});

  static Widget surface(Widget child) => SizedBox.square(
    dimension: 1,
    child: IgnorePointer(
      child: ExcludeSemantics(child: ClipRect(child: child)),
    ),
  );

  @override
  Widget build(BuildContext context) => surface(
    const UiKitView(
      viewType: 'bil/coach_markdown',
      layoutDirection: TextDirection.rtl,
      creationParamsCodec: StandardMessageCodec(),
      creationParams: <String, Object>{
        'generation': 'bil-renderer-preparation',
        if (CoachNativeStageDiagnostics.enabled) 'qaStageTiming': true,
        'text': 'BIL المدرب',
        'rtl': true,
        'fontSize': 32.0,
        'foreground': 0,
        'accent': 0,
      },
      // No visibility acknowledgement is sent. UIKit retains its initial
      // alpha=0 and accessibility-hidden state for this preparation view.
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
  @override
  void initState() {
    super.initState();
    CoachNativeStageDiagnostics.mark('markdown_init');
  }

  static void beginStageDiagnosticFixture() => CoachNativeStageDiagnostics.beginFixture();
  static void markStageDiagnosticReplyRelease() => CoachNativeStageDiagnostics.mark('reply_release');
  static Map<String, Object?> stageDiagnosticSnapshot() => CoachNativeStageDiagnostics.snapshot();

  /// Called only by the offline fixture after its original observation stops.
  Future<Map<String, Object?>> collectNativeStageDiagnostic() async {
    if (!CoachNativeStageDiagnostics.enabled || _channel == null) return {'enabled': false};
    CoachNativeStageDiagnostics.mark('diagnostic_read_send');
    try {
      final value = await _channel!.invokeMapMethod<String, Object?>(
        'qaReadStageTiming', {'generation': _generation},
      ).timeout(const Duration(seconds: 1));
      return value ?? {'enabled': true, 'available': false};
    } on PlatformException {
      return {'enabled': true, 'available': false, 'reason': 'platform_unavailable'};
    } on MissingPluginException {
      return {'enabled': true, 'available': false, 'reason': 'plugin_unavailable'};
    } on TimeoutException {
      return {'enabled': true, 'available': false, 'reason': 'diagnostic_read_timeout'};
    } finally {
      CoachNativeStageDiagnostics.mark('diagnostic_read_complete');
    }
  }

  MethodChannel? _channel;
  String _generation = UniqueKey().toString();
  double _height = 60;
  double? _width;
  bool _failed = false;
  bool _heightReady = false;
  bool _paintReady = false;
  final _paintGate = CoachNativePaintGate();
  final _surfaceKey = GlobalKey();
  Rect? _firstContentBounds;
  bool? _reportedReadiness;
  bool _readinessQueued = false;
  bool get nativeLayoutReady => _paintReady;
  bool get nativeHeightReady => _heightReady;
  bool get nativePaintGateScheduled => _paintGate.scheduled;
  String get nativePaintStage => _paintGate.stage;
  double get nativeMeasuredHeight => _height;
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
      _generation = UniqueKey().toString();
      _parameters = null;
      _heightReady = false;
      _paintReady = false;
      _firstContentBounds = null;
    }
  }

  Map<String, Object> _payload(BuildContext context) => {
    'generation': _generation,
    if (CoachNativeStageDiagnostics.enabled) 'qaStageTiming': true,
    'width': _width ?? 0,
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
        payload['generation'] != _generation ||
        _channel == null) {
      return;
    }
    final generation = _generation;
    _paintGate.beginLayout(
      generation: generation,
      isCurrent: () =>
          mounted &&
          widget.visitIsCurrent() &&
          _generation == generation &&
          !_paintReady &&
          !_failed,
      onFailure: () => setState(() => _failed = true),
    );
    try {
      CoachNativeStageDiagnostics.mark('update_send');
      await _channel?.invokeMethod<void>('update', payload);
      CoachNativeStageDiagnostics.mark('update_complete');
    } on PlatformException {
      if (mounted && widget.visitIsCurrent() && _generation == generation) {
        setState(() => _failed = true);
      }
    } on MissingPluginException {
      if (mounted && widget.visitIsCurrent() && _generation == generation) {
        setState(() => _failed = true);
      }
    }
  }

  void _schedulePaintGate() {
    if (!_heightReady ||
        _firstContentBounds == null ||
        _failed ||
        _paintReady ||
        _paintGate.scheduled) {
      return;
    }
    final generation = _generation;
    final channel = _channel;
    _paintGate.schedule(
      isCurrent: () =>
          mounted &&
          widget.visitIsCurrent() &&
          _generation == generation &&
          !_failed &&
          _heightReady &&
          _firstContentBounds != null,
      measuredSize: () => Size(_width ?? 0, _height),
      surface: () => _surfaceKey.currentContext?.findRenderObject(),
      setVisible: (visible) async => channel?.invokeMethod<bool>('setVisible', {
        'generation': generation,
        'visible': visible,
      }),
      onReady: () {
        setState(() => _paintReady = true);
      },
      onFailure: () {
        if (mounted) setState(() => _failed = true);
      },
      onComplete: () {
        if (mounted && widget.visitIsCurrent() && _generation != generation) {
          _schedulePaintGate();
        }
      },
    );
  }

  Future<Object?> _receive(MethodCall call) async {
    if (!mounted || !widget.visitIsCurrent() || call.arguments is! Map) {
      return null;
    }
    final args = call.arguments as Map;
    if (args['generation'] != _generation) return null;
    switch (call.method) {
      case 'height':
        CoachNativeStageDiagnostics.mark('height_received', {'height': args['height']});
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
        CoachNativeStageDiagnostics.mark('content_bounds_received', {'width': args['width'], 'height': args['height']});
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
    _paintGate.dispose();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CoachNativeStageDiagnostics.mark('markdown_build', {'height_ready': _heightReady, 'paint_ready': _paintReady});
    _reportReadinessAfterPaint();
    if (!widget.visitIsCurrent()) return const SizedBox.shrink();
    if (_failed || !coachUsesNativeMarkdown) return widget.fallback;
    return LayoutBuilder(
      builder: (context, constraints) {
        CoachNativeStageDiagnostics.mark('layout_builder', {'width': constraints.maxWidth, 'height': _height});
        if (_width != constraints.maxWidth) {
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
          key: _surfaceKey,
          height: _height,
          ready: nativeLayoutReady,
          child: UiKitView(
            viewType: 'bil/coach_markdown',
            layoutDirection: widget.direction,
            creationParams: payload,
            creationParamsCodec: const StandardMessageCodec(),
            gestureRecognizers: coachNativeMarkdownGestures(),
            onPlatformViewCreated: (id) {
              CoachNativeStageDiagnostics.mark('platform_created');
              _channel = MethodChannel('bil/coach_markdown/$id')
                ..setMethodCallHandler(_receive);
              _update(_payload(context));
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
