import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/premium_motion_tokens.dart';

/// Presentation-only pager shared by the dashboard's horizontal sections.
///
/// Pages never advance automatically. Motion follows the platform reduced
/// motion preference and the existing premium motion tokens.
class DashboardCarousel extends StatefulWidget {
  const DashboardCarousel({
    super.key,
    required this.pages,
    required this.height,
    this.viewportFraction = 1,
    this.semanticLabel,
    this.compactControls = false,
    this.microControls = false,
    this.onPageChanged,
  });

  final List<Widget> pages;
  final double height;
  final double viewportFraction;
  final String? semanticLabel;
  final bool compactControls;
  final bool microControls;
  final ValueChanged<int>? onPageChanged;

  @override
  State<DashboardCarousel> createState() => _DashboardCarouselState();
}

class _DashboardCarouselState extends State<DashboardCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;
  var _page = 0;
  var _targetPage = 0;
  double _dragExtent = 0;

  bool get _hasPrevious => _page > 0;
  bool get _hasNext => _page < widget.pages.length - 1;

  void _moveTo(int page) {
    if (_rotation.isAnimating ||
        page < 0 ||
        page >= widget.pages.length ||
        page == _page) {
      return;
    }
    if (PremiumMotionTokens.prefersReducedMotion(context)) {
      setState(() {
        _page = page;
        _targetPage = page;
      });
      widget.onPageChanged?.call(page);
      return;
    }
    _targetPage = page;
    _rotation.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _rotation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 390),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() {
              _page = _targetPage;
              _rotation.value = 0;
            });
            widget.onPageChanged?.call(_page);
          }
        });
  }

  @override
  void didUpdateWidget(covariant DashboardCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = widget.pages.isEmpty ? 0 : widget.pages.length - 1;
    if (_page > lastPage || _targetPage > lastPage) {
      _rotation.stop();
      _page = _page.clamp(0, lastPage);
      _targetPage = _targetPage.clamp(0, lastPage);
      _rotation.value = 0;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        autofocus: false,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              _PreviousCarouselIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): _NextCarouselIntent(),
        },
        actions: {
          _PreviousCarouselIntent: CallbackAction<_PreviousCarouselIntent>(
            onInvoke: (_) {
              _moveTo(_page - 1);
              return null;
            },
          ),
          _NextCarouselIntent: CallbackAction<_NextCarouselIntent>(
            onInvoke: (_) {
              _moveTo(_page + 1);
              return null;
            },
          ),
        },
        child: Column(
          children: [
            SizedBox(
              height: widget.height,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is! PointerScrollEvent) return;
                  final delta =
                      event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
                      ? event.scrollDelta.dx
                      : event.scrollDelta.dy;
                  if (delta > 0) _moveTo(_page + 1);
                  if (delta < 0) _moveTo(_page - 1);
                },
                onPointerDown: (_) => _dragExtent = 0,
                onPointerMove: (event) {
                  _dragExtent += event.delta.dx;
                },
                onPointerUp: (_) {
                  if (_dragExtent < -48) _moveTo(_page + 1);
                  if (_dragExtent > 48) _moveTo(_page - 1);
                  _dragExtent = 0;
                },
                onPointerCancel: (_) => _dragExtent = 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hasNext ? () => _moveTo(_page + 1) : null,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final controlGap = widget.microControls
                          ? 4.0
                          : (widget.compactControls ? 12.0 : 16.0);
                      final deck = Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          FractionallySizedBox(
                            key: const Key('dashboard-carousel-card-frame'),
                            widthFactor: widget.viewportFraction,
                            child: AnimatedBuilder(
                              animation: _rotation,
                              builder: (context, _) {
                                final progress = Curves.easeInOutCubic
                                    .transform(_rotation.value);
                                final firstHalf = progress < .5;
                                final angle = firstHalf
                                    ? progress * math.pi
                                    : (progress - 1) * math.pi;
                                final index = firstHalf ? _page : _targetPage;
                                final scale =
                                    1 - .035 * math.sin(progress * math.pi);
                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, .00135)
                                    ..scaleByDouble(scale, scale, 1, 1)
                                    ..rotateY(angle),
                                  child: DecoratedBox(
                                    key: const Key(
                                      'dashboard-deck-active-card',
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: KeyedSubtree(
                                        key: ValueKey(index),
                                        child: widget.pages[index],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                      if (widget.pages.length == 1) return deck;
                      if (widget.microControls) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            deck,
                            PositionedDirectional(
                              start: 6,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _CarouselArrow(
                                  key: const Key('dashboard-carousel-previous'),
                                  icon: Icons.chevron_left_rounded,
                                  enabled: _hasPrevious,
                                  onPressed: () => _moveTo(_page - 1),
                                  compact: true,
                                  micro: true,
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              end: 6,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _CarouselArrow(
                                  key: const Key('dashboard-carousel-next'),
                                  icon: Icons.chevron_right_rounded,
                                  enabled: _hasNext,
                                  onPressed: () => _moveTo(_page + 1),
                                  compact: true,
                                  micro: true,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _CarouselArrow(
                            key: const Key('dashboard-carousel-previous'),
                            icon: Icons.chevron_left_rounded,
                            enabled: _hasPrevious,
                            onPressed: () => _moveTo(_page - 1),
                            compact: widget.compactControls,
                            micro: false,
                          ),
                          SizedBox(width: controlGap),
                          Expanded(child: deck),
                          SizedBox(width: controlGap),
                          _CarouselArrow(
                            key: const Key('dashboard-carousel-next'),
                            icon: Icons.chevron_right_rounded,
                            enabled: _hasNext,
                            onPressed: () => _moveTo(_page + 1),
                            compact: widget.compactControls,
                            micro: false,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (widget.pages.length > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(
                    widget.pages.length,
                    (index) => AnimatedContainer(
                      duration: PremiumMotionTokens.durationFor(
                        context,
                        PremiumMotionTokens.stateChangeDuration,
                      ),
                      curve: PremiumMotionTokens.stateChangeCurve,
                      width: index == _page
                          ? (widget.microControls
                                ? 10
                                : (widget.compactControls ? 14 : 20))
                          : (widget.microControls
                                ? 3
                                : (widget.compactControls ? 4 : 6)),
                      height: widget.microControls
                          ? 3
                          : (widget.compactControls ? 4 : 6),
                      margin: EdgeInsets.symmetric(
                        horizontal: widget.microControls
                            ? 1
                            : (widget.compactControls ? 1.5 : 3),
                      ),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviousCarouselIntent extends Intent {
  const _PreviousCarouselIntent();
}

class _NextCarouselIntent extends Intent {
  const _NextCarouselIntent();
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.compact = false,
    this.micro = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final bool compact;
  final bool micro;

  @override
  Widget build(BuildContext context) {
    final dimension = micro ? 18.0 : (compact ? 24.0 : 40.0);
    final iconSize = micro ? 14.0 : (compact ? 18.0 : 24.0);
    return SizedBox.square(
      dimension: dimension,
      child: IconButton.filledTonal(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: iconSize),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: dimension,
          height: dimension,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: .72),
        ),
      ),
    );
  }
}
