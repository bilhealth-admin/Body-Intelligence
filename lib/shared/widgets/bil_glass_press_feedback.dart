import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';

/// A decoration only: never handles a tap, changes navigation or adds semantics.
/// Its anchor keeps the original child size and inherited text/icon styling.
class BilGlassPressFeedback extends StatefulWidget {
  const BilGlassPressFeedback({
    required this.child,
    this.always = false,
    super.key,
  });
  final Widget child;

  /// Force the pearl press bubble for approved non-arrow controls.
  /// Arrow and sync glyphs keep their bubble automatically.
  final bool always;
  @override
  State<BilGlassPressFeedback> createState() => _GlassPressState();
}

class _GlassPressState extends State<BilGlassPressFeedback> {
  static final _visible = <_GlassPressState>{};
  static final _lifecycle = _GlassPressLifecycle();
  static int? _pointer;
  static Offset? _origin;
  bool _pressed = false;
  bool _registered = false;
  int? _activePointer;
  Offset? _pressOrigin;
  bool get _eligible =>
      widget.always ||
      widget.child is Icon &&
          BilArrowGlyph.isArrow((widget.child as Icon).icon);

  static void _route(PointerEvent event) {
    if (event is PointerDownEvent) {
      if (_pointer != null) {
        _clear();
        return;
      }
      _pointer = event.pointer;
      _origin = event.position;
      // Feedback belongs to the pressed widget. Never search a page's render
      // subtree for another arrow or clone a glyph into the root overlay.
    } else if (event.pointer == _pointer &&
        (event is PointerUpEvent ||
            event is PointerCancelEvent ||
            event is PointerMoveEvent &&
                (event.position - _origin!).distance > kTouchSlop)) {
      _clear();
    }
  }

  static void _clear() {
    _pointer = null;
    _origin = null;
    for (final state in _visible.toList()) {
      state._activePointer = null;
      state._pressOrigin = null;
      state._show(false);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_eligible || _activePointer != null) return;
    _activePointer = event.pointer;
    _pressOrigin = event.position;
    _show(true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _pressOrigin;
    if (event.pointer != _activePointer || origin == null) return;
    if ((event.position - origin).distance > kTouchSlop) _show(false);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _pressOrigin = null;
    _show(false);
  }

  static bool _key(KeyEvent event) {
    if (event is KeyUpEvent) {
      _clear();
      return false;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.space) {
      return false;
    }
    for (final state in _visible.toList()) {
      if (Focus.maybeOf(state.context)?.hasFocus ?? false) {
        state._show(event is KeyDownEvent || event is KeyRepeatEvent);
      }
    }
    return false; // The original Focus/Actions pipeline owns activation.
  }

  void _show(bool value) {
    if (mounted && value != _pressed) setState(() => _pressed = value);
  }

  void _register() {
    if (!_eligible) return;
    if (_visible.isEmpty) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
      HardwareKeyboard.instance.addHandler(_key);
      WidgetsBinding.instance.addObserver(_lifecycle);
    }
    _visible.add(this);
    _registered = true;
  }

  void _unregister() {
    if (!_registered) return;
    _registered = false;
    _visible.remove(this);
    if (_visible.isEmpty) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
      HardwareKeyboard.instance.removeHandler(_key);
      WidgetsBinding.instance.removeObserver(_lifecycle);
      _clear();
    }
  }

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant BilGlassPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasEligible =
        oldWidget.always ||
        oldWidget.child is Icon &&
            BilArrowGlyph.isArrow((oldWidget.child as Icon).icon);
    if (wasEligible != _eligible) {
      _unregister();
      _pressed = false;
      _register();
    }
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.child;
    final child = original is Icon && BilArrowGlyph.isArrow(original.icon)
        ? BilArrowGlyph.modern(original)
        : original;
    if (!_eligible) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.maybeOf(context);
    final solid =
        media?.highContrast == true || media?.accessibleNavigation == true;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (_pressed)
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Center(
                    child: OverflowBox(
                      minWidth: 48,
                      maxWidth: 48,
                      minHeight: 48,
                      maxHeight: 48,
                      child: DecoratedBox(
                        key: const Key('bil-glass-press-bubble'),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: dark ? .18 : .09,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: solid ? 0 : 8,
                              sigmaY: solid ? 0 : 8,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: dark
                                      ? [
                                          Color(
                                            0xFF243A50,
                                          ).withValues(alpha: solid ? 1 : .86),
                                          Color(
                                            0xFF15283C,
                                          ).withValues(alpha: solid ? 1 : .74),
                                        ]
                                      : [
                                          Colors.white.withValues(
                                            alpha: solid ? 1 : .88,
                                          ),
                                          Color(
                                            0xFFE4F2FC,
                                          ).withValues(alpha: solid ? 1 : .74),
                                        ],
                                ),
                                border: Border.all(
                                  color: dark
                                      ? Colors.white.withValues(alpha: .24)
                                      : Colors.white.withValues(alpha: .94),
                                  width: solid ? 1.5 : .9,
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }
}

/// Preserve direction, RTL mirroring and labels; modernize equivalent glyphs.
abstract final class BilArrowGlyph {
  static final _modern = <IconData, IconData>{
    Icons.arrow_back: Icons.chevron_left_rounded,
    Icons.arrow_back_rounded: Icons.chevron_left_rounded,
    Icons.arrow_back_ios: Icons.chevron_left_rounded,
    Icons.arrow_back_ios_new: Icons.chevron_left_rounded,
    Icons.arrow_forward: Icons.chevron_right_rounded,
    Icons.arrow_forward_rounded: Icons.chevron_right_rounded,
    Icons.chevron_left: Icons.chevron_left_rounded,
    Icons.chevron_right: Icons.chevron_right_rounded,
    Icons.keyboard_arrow_left: Icons.chevron_left_rounded,
    Icons.keyboard_arrow_right: Icons.chevron_right_rounded,
    Icons.arrow_drop_down: Icons.keyboard_arrow_down_rounded,
    Icons.arrow_drop_down_rounded: Icons.keyboard_arrow_down_rounded,
    Icons.arrow_drop_up: Icons.keyboard_arrow_up_rounded,
    Icons.expand_more: Icons.keyboard_arrow_down_rounded,
    Icons.expand_more_rounded: Icons.keyboard_arrow_down_rounded,
    Icons.expand_less: Icons.keyboard_arrow_up_rounded,
  };
  static final _other = <IconData>{
    Icons.chevron_left_rounded,
    Icons.chevron_right_rounded,
    Icons.keyboard_arrow_left_rounded,
    Icons.keyboard_arrow_right_rounded,
    Icons.keyboard_arrow_down,
    Icons.keyboard_arrow_down_rounded,
    Icons.keyboard_arrow_up,
    Icons.keyboard_arrow_up_rounded,
    Icons.arrow_upward,
    Icons.arrow_upward_rounded,
    Icons.arrow_downward,
    Icons.arrow_downward_rounded,
    Icons.navigate_before,
    Icons.navigate_next,
    Icons.expand_less_rounded,
    Icons.unfold_more,
    Icons.unfold_less,
    Icons.first_page,
    Icons.last_page,
    Icons.double_arrow,
    Icons.reply,
    Icons.reply_rounded,
    Icons.reply_all,
    Icons.subdirectory_arrow_left,
    Icons.subdirectory_arrow_right,
    Icons.north_east,
    Icons.north_west,
    Icons.south_east,
    Icons.south_west,
    Icons.refresh,
    Icons.refresh_rounded,
    Icons.undo,
    Icons.redo,
  };
  static final _sourceArrows = <IconData>{
    CupertinoIcons.arrow_2_circlepath,
    CupertinoIcons.arrow_down_doc,
    CupertinoIcons.arrow_up_arrow_down,
    CupertinoIcons.chevron_back,
    CupertinoIcons.chevron_forward,
    Icons.arrow_back,
    Icons.arrow_back_ios_new_rounded,
    Icons.arrow_back_rounded,
    Icons.arrow_downward_rounded,
    Icons.arrow_drop_down_rounded,
    Icons.arrow_forward,
    Icons.arrow_forward_ios_rounded,
    Icons.arrow_forward_rounded,
    Icons.arrow_upward_rounded,
    Icons.chevron_left_rounded,
    Icons.chevron_right,
    Icons.chevron_right_rounded,
    Icons.expand_less_rounded,
    Icons.expand_more_rounded,
    Icons.keyboard_arrow_down_rounded,
    Icons.keyboard_arrow_up_rounded,
    Icons.north_east_rounded,
    Icons.north_rounded,
    Icons.refresh,
    Icons.refresh_rounded,
    Icons.reply_all_outlined,
    Icons.reply_rounded,
    Icons.south_east_rounded,
    Icons.south_rounded,
    Icons.undo_rounded,
    Icons.compare_arrows,
    Icons.download_for_offline_outlined,
    Icons.download_rounded,
    Icons.drive_file_move_outline,
    Icons.file_download_outlined,
    Icons.login_rounded,
    Icons.logout_rounded,
    Icons.open_in_new_rounded,
    Icons.play_arrow_rounded,
    Icons.send_rounded,
    Icons.swap_horiz_rounded,
    Icons.sync,
    Icons.sync_problem_rounded,
    Icons.sync_rounded,
    Icons.upload_rounded,
  };
  static bool isArrow(IconData? data) =>
      _modern.containsKey(data) ||
      _other.contains(data) ||
      _sourceArrows.contains(data);
  static bool containsCodePoint(int codePoint, String family) =>
      {..._modern.keys, ..._other, ..._sourceArrows}.any(
        (icon) =>
            icon.codePoint == codePoint &&
            (icon.fontFamily ?? '') == family.split('/').last,
      );
  static Icon modern(Icon icon) => Icon(
    _modern[icon.icon] ?? icon.icon,
    key: icon.key,
    size: icon.size,
    color: icon.color,
    fill: icon.fill,
    weight: icon.weight,
    grade: icon.grade,
    opticalSize: icon.opticalSize,
    shadows: icon.shadows,
    semanticLabel: icon.semanticLabel,
    textDirection: icon.textDirection,
    applyTextScaling: icon.applyTextScaling,
  );
}

class _GlassPressLifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _GlassPressState._clear();
  }
}
