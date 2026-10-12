import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/providers/profile_auth_identity_provider.dart';

/// Decimal draft arithmetic; repetition never changes a step or saves a record.
double decimalStep({
  required double value,
  required double step,
  required int direction,
  required int decimalPlaces,
  required double minimum,
  required double maximum,
}) {
  if (!value.isFinite ||
      !step.isFinite ||
      step <= 0 ||
      decimalPlaces < 0 ||
      decimalPlaces > 9 ||
      !minimum.isFinite ||
      !maximum.isFinite ||
      minimum > maximum ||
      (direction != -1 && direction != 1)) {
    throw ArgumentError('Invalid decimal draft step');
  }
  // Preserve finer manual input (e.g. 20.05 + 0.1), while avoiding binary
  // accumulation. Nine decimal places are ample for these bounded editors.
  final parts = value.toString().toLowerCase().split('e');
  final fraction = parts.first.split('.');
  final exponent = parts.length == 2 ? int.parse(parts.last) : 0;
  final originalPlaces =
      (fraction.length == 2 ? fraction.last.length : 0) - exponent;
  final precision = math.max(decimalPlaces, originalPlaces.clamp(0, 9));
  final scale = math.pow(10, precision).toInt();
  // Beyond exact integer precision a small step may be unrepresentable. Keep
  // the original draft rather than overflowing Dart's int conversion.
  final scaled = value * scale;
  if (!scaled.isFinite || scaled.abs() > 9007199254740991) {
    final next = value + direction * step;
    return next.isFinite ? next.clamp(minimum, maximum) : value;
  }
  final increment = (step * scale).round();
  if (increment == 0) throw ArgumentError('Step precision is insufficient');
  return (((value * scale).round() + direction * increment) / scale).clamp(
    minimum,
    maximum,
  );
}

typedef RepeatingStepBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback? onPressed,
      bool pressed,
    );

/// Existing buttons retain their appearance and their single-step semantics.
/// A real long-press wins the gesture arena before the first repeat, so a scroll
/// never modifies the draft and release cannot dispatch a trailing tap.
class RepeatingStepAction extends StatefulWidget {
  const RepeatingStepAction({
    super.key,
    required this.onPressed,
    required this.builder,
    this.cancelScope,
    this.cancelSignal,
    this.canStep,
    this.startDelay = const Duration(milliseconds: 340),
    this.repeatInterval = const Duration(milliseconds: 75),
  }) : assert(startDelay > Duration.zero),
       assert(repeatInterval > Duration.zero);

  final VoidCallback? onPressed;
  final RepeatingStepBuilder builder;
  final Object? cancelScope;
  final Listenable? cancelSignal;
  final ValueGetter<bool>? canStep;
  final Duration startDelay;
  final Duration repeatInterval;

  @override
  State<RepeatingStepAction> createState() => _RepeatingStepState();
}

class _RepeatingStepState extends State<RepeatingStepAction>
    with WidgetsBindingObserver {
  static _RepeatingStepState? _pointerOwner;
  final _focus = FocusNode();
  Timer? _timer;
  int? _pointer;
  Offset? _origin;
  bool _blocked = false;
  bool _cancelled = false;
  bool _holding = false;
  bool _suppressTap = false;
  bool _finishingPhysicalTap = false;
  bool _foreground = true;
  bool _watchingPointers = false;
  ProviderContainer? _ownerContainer;
  ProviderSubscription<AsyncValue<ProfileAuthIdentity>>? _ownerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    widget.cancelSignal?.addListener(_cancel);
  }

  bool get _enabled =>
      mounted &&
      _foreground &&
      widget.onPressed != null &&
      (widget.canStep?.call() ?? true) &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (_holding && mounted) setState(() => _holding = false);
  }

  void _cancel() {
    _cancelled = true;
    _stop();
  }

  void _down(PointerDownEvent event) {
    if (!mounted || !_enabled) return;
    if (_pointer != null || (_pointerOwner != null && _pointerOwner != this)) {
      _pointerOwner?._cancel();
      _blocked = true;
      _cancel();
      return;
    }
    _pointerOwner = this;
    _pointer = event.pointer;
    _origin = event.position;
    _blocked = false;
    _cancelled = false;
    _suppressTap = false;
    _finishingPhysicalTap = false;
    if (!_watchingPointers) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_otherPointer);
      _watchingPointers = true;
    }
  }

  void _otherPointer(PointerEvent event) {
    if (mounted &&
        _pointer != null &&
        event is PointerDownEvent &&
        event.pointer != _pointer) {
      _cancel();
    }
  }

  void _unwatchPointers() {
    if (!_watchingPointers) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_otherPointer);
    _watchingPointers = false;
  }

  void _move(PointerMoveEvent event) {
    if (!mounted) return;
    if (_pointer != event.pointer) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null ||
        !(Offset.zero & box.size).contains(box.globalToLocal(event.position)) ||
        (!_holding && (event.position - _origin!).distance > kTouchSlop)) {
      _cancel();
    }
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _stop();
    _pointer = null;
    _origin = null;
    if (_pointerOwner == this) _pointerOwner = null;
    _unwatchPointers();
    _finishingPhysicalTap = true;
    scheduleMicrotask(() {
      _suppressTap = false;
      _finishingPhysicalTap = false;
    });
  }

  void _shortTap() {
    if (_enabled &&
        !_suppressTap &&
        (!(_pointer != null || _finishingPhysicalTap) ||
            !_blocked && !_cancelled)) {
      widget.onPressed!.call();
    }
  }

  void _begin(LongPressStartDetails _) {
    if (!_enabled || _blocked || _cancelled || _pointerOwner != this) return;
    _focus.requestFocus();
    _suppressTap = true;
    setState(() => _holding = true);
    widget.onPressed!.call();
    if (!_enabled || !_holding) {
      _stop();
      return;
    }
    _timer = Timer.periodic(widget.repeatInterval, (_) {
      if (!_enabled || !_holding || _cancelled || _blocked) {
        _stop();
      } else {
        widget.onPressed!.call();
        if (!_enabled) _stop();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pure local editors can be hosted without Riverpod. In BIL the existing
    // account provider is shared, so each button does not create an Auth stream.
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context);
    } on StateError {
      container = null;
    }
    if (!identical(container, _ownerContainer)) {
      _cancel();
      _ownerSubscription?.close();
      _ownerContainer = container;
      _ownerSubscription = container?.listen(profileAuthIdentityProvider, (
        previous,
        next,
      ) {
        if (previous?.value?.ownerId != next.value?.ownerId || next.hasError) {
          _cancel();
        }
      });
    }
    if (!TickerMode.valuesOf(context).enabled ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      _cancel();
    }
  }

  @override
  void didUpdateWidget(covariant RepeatingStepAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.cancelSignal, oldWidget.cancelSignal)) {
      oldWidget.cancelSignal?.removeListener(_cancel);
      widget.cancelSignal?.addListener(_cancel);
      _cancel();
    }
    if (widget.onPressed == null ||
        widget.cancelScope != oldWidget.cancelScope ||
        widget.startDelay != oldWidget.startDelay ||
        widget.repeatInterval != oldWidget.repeatInterval) {
      _cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unwatchPointers();
    widget.cancelSignal?.removeListener(_cancel);
    _ownerSubscription?.close();
    if (_pointerOwner == this) _pointerOwner = null;
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onFocusChange: (focused) {
        if (!focused) _cancel();
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) &&
            _pointerOwner == null) {
          if (_enabled) widget.onPressed!.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: (event) {
          _cancel();
          _up(event);
        },
        child: RawGestureDetector(
          excludeFromSemantics: true,
          gestures: {
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(duration: widget.startDelay),
                  (instance) {
                    instance.onLongPressStart = _begin;
                    instance.onLongPressEnd = (_) => _stop();
                    instance.onLongPressCancel = _stop;
                  },
                ),
          },
          child: widget.builder(
            context,
            widget.onPressed == null ? null : _shortTap,
            _holding,
          ),
        ),
      ),
    );
  }
}
