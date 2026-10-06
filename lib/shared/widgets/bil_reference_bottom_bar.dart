import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';
import 'bil_reference_navigation_glyph.dart';

/// The five primary destinations in the approved Coach reference. Quick Add
/// is an action: the caller opens the shared presenter after saving its state.
class BilReferenceBottomBar extends StatelessWidget {
  const BilReferenceBottomBar({
    required this.selected,
    required this.onSelected,
    this.dark,
    this.moreAttentionCount = 0,
    this.destinationKeys = const {},
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  /// Inherit the active surface theme unless a surface explicitly overrides it.
  final bool? dark;

  /// Authoritative count supplied by the caller's existing attention scope.
  final int moreAttentionCount;
  final Map<int, Key> destinationKeys;

  // Index 2 is the shared Quick Add action, never a navigation to this entry.
  static const routes = <String>[
    '/dashboard',
    '/intelligence-center',
    '/daily-log',
    '/community',
    '/settings',
  ];

  // Measured horizontal centres in the immutable 478px Coach dock. Keep the
  // optical anchors distinct from the non-overlapping, accessible tap regions.
  static const _centres = <double>[55.5, 134, 233.5, 339, 429];

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final labels = [
      for (final source in const [
        'Home',
        'AI Coach',
        'Quick Add',
        'Community',
        'More',
      ])
        copy?.text(source) ??
            RuntimeCopy.resolve(source, BilLocalePolicy.canonicalTag(locale)) ??
            source,
    ];
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFFB7C4D8) : const Color(0xFF596C88);
    final active = isDark ? const Color(0xFF2DA0FF) : const Color(0xFF145BDD);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final opticalScale = width.clamp(320.0, 414.0) / 478;
        final typeScale = (width / 390).clamp(1.0, 414 / 390).toDouble();
        final textScaler = MediaQuery.textScalerOf(context);
        // The measured optical anchors are for the reference's normal text.
        // At large accessibility sizes give each complete label the full
        // equal-width action region, so words do not split around the anchor.
        final expandedLabels = textScaler.scale(10) > 13;
        final labelStyle = TextStyle(
          fontSize: 10 * typeScale,
          height: 1.2,
          color: muted,
        );
        final boundaries = <double>[
          0,
          for (var i = 1; i < _centres.length; i++)
            expandedLabels
                ? i / 5 * width
                : (_centres[i - 1] + _centres[i]) / 2 / 478 * width,
          width,
        ];
        final centres = [
          for (var i = 0; i < _centres.length; i++)
            expandedLabels ? (i + .5) / 5 * width : _centres[i] / 478 * width,
        ];
        final labelWidths = <double>[
          for (var i = 0; i < 5; i++)
            2 *
                    math.min(
                      centres[i] - boundaries[i],
                      boundaries[i + 1] - centres[i],
                    ) -
                (expandedLabels ? 2 : 4),
        ];
        var maxLabelHeight = 12 * typeScale;
        var maxLabelAscent = 0.0;
        final labelAscents = <double>[];
        final labelHeights = <double>[];
        final inheritedStyle = DefaultTextStyle.of(context).style;
        for (var i = 0; i < 5; i++) {
          final painter = TextPainter(
            text: TextSpan(
              text: labels[i],
              style: inheritedStyle.merge(labelStyle),
            ),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            locale: locale,
          )..layout(maxWidth: labelWidths[i]);
          labelHeights.add(painter.height);
          final ascent = painter.computeLineMetrics().first.baseline;
          labelAscents.add(ascent);
          maxLabelAscent = math.max(maxLabelAscent, ascent);
          painter.dispose();
        }
        for (var i = 0; i < 5; i++) {
          maxLabelHeight = math.max(
            maxLabelHeight,
            labelHeights[i] + maxLabelAscent - labelAscents[i],
          );
        }
        final rise = 6 * opticalScale;
        final labelTop = 50 * opticalScale;
        final labelGrowth = math.max(
          0.0,
          maxLabelHeight - (12 * typeScale).ceilToDouble(),
        );
        final surfaceHeight = 79 * opticalScale + labelGrowth;
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        final contentHeight = rise + surfaceHeight;
        return SizedBox(
          key: const Key('bil-reference-navigation'),
          height: contentHeight + safeBottom,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: rise,
                bottom: 0,
                child: DecoratedBox(
                  key: const Key('bil-reference-nav-surface'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [Color(0xFF121B28), Color(0xFF101923)]
                          : const [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22 * opticalScale),
                    ),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF344350)
                          : const Color(0xFFDCE6F3),
                      width: .65,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < 5; i++)
                PositionedDirectional(
                  start: boundaries[i],
                  top: 0,
                  width: boundaries[i + 1] - boundaries[i],
                  height: contentHeight,
                  child: KeyedSubtree(
                    key: destinationKeys[i],
                    child: Semantics(
                      label: i == 4 && moreAttentionCount > 0
                          ? '${labels[i]}, $moreAttentionCount'
                          : labels[i],
                      button: true,
                      selected: i != 2 && selected == i,
                      onTap: () => onSelected(i),
                      child: ExcludeSemantics(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: Key('bil-reference-nav-$i'),
                            excludeFromSemantics: true,
                            onTap: () => onSelected(i),
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                PositionedDirectional(
                                  start:
                                      centres[i] -
                                      boundaries[i] -
                                      (i == 2 ? 24 : 16) * opticalScale,
                                  top: i == 2 ? 0 : rise + 13 * opticalScale,
                                  width: (i == 2 ? 48 : 32) * opticalScale,
                                  height: (i == 2 ? 48 : 32) * opticalScale,
                                  child: _glyph(
                                    i,
                                    isDark,
                                    opticalScale,
                                    muted,
                                    active,
                                  ),
                                ),
                                PositionedDirectional(
                                  start:
                                      centres[i] -
                                      boundaries[i] -
                                      labelWidths[i] / 2,
                                  top:
                                      rise +
                                      labelTop +
                                      maxLabelAscent -
                                      labelAscents[i],
                                  width: labelWidths[i],
                                  child: Text(
                                    labels[i],
                                    key: Key('bil-reference-nav-label-$i'),
                                    textAlign: TextAlign.center,
                                    style: labelStyle.copyWith(
                                      color: selected == i && i != 2
                                          ? active
                                          : muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _glyph(
    int index,
    bool isDark,
    double scale,
    Color muted,
    Color active,
  ) {
    final selectedGlyph = selected == index && index != 2;
    final glyph = BilReferenceNavigationGlyph(
      key: Key('bil-reference-nav-glyph-$index'),
      destination: index,
      color: selectedGlyph ? active : muted,
      selected: selectedGlyph,
    );
    if (index != 2) {
      final icon = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: selectedGlyph
              ? [
                  BoxShadow(
                    color: active.withValues(alpha: .13),
                    blurRadius: 7 * scale,
                    spreadRadius: -2 * scale,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: SizedBox(
            width: (index == 1 ? 27 : 24) * scale,
            height: (index == 1 ? 25 : 24) * scale,
            child: glyph,
          ),
        ),
      );
      if (index != 4 || moreAttentionCount <= 0) return icon;
      return Badge(
        alignment: AlignmentDirectional.topEnd,
        label: Text(moreAttentionCount > 99 ? '99+' : '$moreAttentionCount'),
        child: icon,
      );
    }
    return DecoratedBox(
      key: const Key('bil-reference-nav-circle'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF29384A), Color(0xFF172331)]
              : const [Color(0xFF30ABFF), Color(0xFF1659ED)],
        ),
        border: Border.all(
          width: 1,
          color: isDark ? const Color(0xFF71869E) : Colors.white,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : active).withValues(alpha: .2),
            blurRadius: 5 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Center(
        child: SizedBox.square(
          dimension: 17 * scale,
          child: BilReferenceNavigationGlyph(
            key: const Key('bil-reference-nav-glyph-2'),
            destination: 2,
            color: isDark ? muted : Colors.white,
          ),
        ),
      ),
    );
  }
}
