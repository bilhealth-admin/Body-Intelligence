import 'package:flutter/material.dart';

/// Keeps a page or sheet heading separate from its scrolling viewport.
///
/// The caller owns the safe area and the scrollable's padding. Clipping the
/// body prevents moving content from painting over the stationary header.
class BilPinnedHeaderBody extends StatelessWidget {
  const BilPinnedHeaderBody({
    super.key,
    required this.header,
    required this.body,
    this.shrinkWrap = false,
    this.bodyReserve = 96,
  }) : assert(bodyReserve >= 0);

  final Widget header;
  final Widget body;
  final bool shrinkWrap;

  /// Preferred body reserve, capped at 40% of the finite available height.
  /// A naturally short heading can leave the body more space than this.
  final double bodyReserve;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedHeight) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, body],
        );
      }
      // Short viewports and accessibility text must leave room for the body.
      // A fitting heading has no scroll extent; oversized copy remains readable
      // inside the stationary region without a post-frame layout change.
      final reservedBody = (constraints.maxHeight * .4).clamp(0.0, bodyReserve);
      return Column(
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            key: const Key('bil-pinned-header-region'),
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight - reservedBody,
            ),
            child: SingleChildScrollView(
              key: const Key('bil-pinned-header-scroll'),
              primary: false,
              child: header,
            ),
          ),
          Flexible(
            fit: shrinkWrap ? FlexFit.loose : FlexFit.tight,
            child: ClipRect(child: body),
          ),
        ],
      );
    },
  );
}
