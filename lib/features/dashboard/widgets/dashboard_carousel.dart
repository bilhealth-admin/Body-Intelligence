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
  });

  final List<Widget> pages;
  final double height;
  final double viewportFraction;
  final String? semanticLabel;
  final bool compactControls;

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
                      final controlGap = widget.compactControls ? 12.0 : 16.0;
                      final deck = Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 1,
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
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF174E8C,
                                          ).withValues(alpha: .18),
                                          blurRadius: 28,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
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
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _CarouselArrow(
                            key: const Key('dashboard-carousel-previous'),
                            icon: Icons.chevron_left_rounded,
                            enabled: _hasPrevious,
                            onPressed: () => _moveTo(_page - 1),
                            compact: widget.compactControls,
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
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${_page + 1} / ${widget.pages.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: widget.compactControls ? 5 : 10),
                  ...List.generate(
                    widget.pages.length,
                    (index) => AnimatedContainer(
                      duration: PremiumMotionTokens.durationFor(
                        context,
                        PremiumMotionTokens.stateChangeDuration,
                      ),
                      curve: PremiumMotionTokens.stateChangeCurve,
                      width: index == _page
                          ? (widget.compactControls ? 14 : 20)
                          : (widget.compactControls ? 4 : 6),
                      height: widget.compactControls ? 4 : 6,
                      margin: EdgeInsets.symmetric(
                        horizontal: widget.compactControls ? 1.5 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: .22),
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
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: compact ? 24 : 40,
    child: IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: compact ? 18 : 24),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: compact ? 24 : 40,
        height: compact ? 24 : 40,
      ),
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: .72),
      ),
    ),
  );
}
