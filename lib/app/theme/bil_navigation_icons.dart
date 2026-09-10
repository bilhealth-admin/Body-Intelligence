import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'bil_semantic_icons.dart';
import '../../shared/widgets/bil_native_symbols.dart';

/// Navigation uses the selected-state palette, while its glyphs follow the
/// platform. Functional entry tiles use [BilSemanticIcons] instead.
enum BilNavigationDestination {
  today,
  diary,
  discover,
  progress,
  insights,
  more,
  profile,
}

class BilNativeNavigationGlyph extends StatelessWidget {
  const BilNativeNavigationGlyph({
    required this.destination,
    required this.selected,
    this.color,
    this.size = 24,
    super.key,
  });
  final BilNavigationDestination destination;
  final bool selected;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final pair = BilNavigationIcons.forDestination(
      destination,
      Theme.of(context).platform,
    );
    return BilNativeSymbolGlyph(
      symbol: switch (destination) {
        BilNavigationDestination.today => BilSettingsSymbol.dashboard,
        BilNavigationDestination.diary => BilSettingsSymbol.diary,
        BilNavigationDestination.discover => BilSettingsSymbol.discover,
        BilNavigationDestination.progress => BilSettingsSymbol.progress,
        BilNavigationDestination.insights => BilSettingsSymbol.aiCoach,
        BilNavigationDestination.more => BilSettingsSymbol.more,
        BilNavigationDestination.profile => BilSettingsSymbol.profile,
      },
      fallback: selected ? pair.selected : pair.icon,
      color:
          color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurface,
      size: size,
    );
  }
}

abstract final class BilNavigationIcons {
  static ({IconData icon, IconData selected}) forDestination(
    BilNavigationDestination destination,
    TargetPlatform platform,
  ) {
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return switch (destination) {
      BilNavigationDestination.today =>
        apple
            ? (
                icon: CupertinoIcons.square_grid_2x2,
                selected: CupertinoIcons.square_grid_2x2_fill,
              )
            : (
                icon: BilSemanticIcons.today,
                selected: BilSemanticIcons.todaySelected,
              ),
      BilNavigationDestination.diary =>
        apple
            ? (icon: CupertinoIcons.book, selected: CupertinoIcons.book_fill)
            : (
                icon: BilSemanticIcons.diary,
                selected: BilSemanticIcons.diarySelected,
              ),
      BilNavigationDestination.discover =>
        apple
            ? (
                icon: CupertinoIcons.compass,
                selected: CupertinoIcons.compass_fill,
              )
            : (
                icon: BilSemanticIcons.discover,
                selected: BilSemanticIcons.discoverSelected,
              ),
      BilNavigationDestination.progress =>
        apple
            ? (
                icon: CupertinoIcons.chart_bar,
                selected: CupertinoIcons.chart_bar_fill,
              )
            : (
                icon: BilSemanticIcons.progress,
                selected: BilSemanticIcons.progressSelected,
              ),
      BilNavigationDestination.insights =>
        apple
            ? (icon: CupertinoIcons.sparkles, selected: CupertinoIcons.sparkles)
            : (
                icon: BilSemanticIcons.insights,
                selected: BilSemanticIcons.insightsSelected,
              ),
      BilNavigationDestination.more =>
        apple
            ? (icon: CupertinoIcons.ellipsis, selected: CupertinoIcons.ellipsis)
            : (
                icon: BilSemanticIcons.more,
                selected: BilSemanticIcons.moreSelected,
              ),
      BilNavigationDestination.profile =>
        apple
            ? (
                icon: CupertinoIcons.person_crop_circle,
                selected: CupertinoIcons.person_crop_circle_fill,
              )
            : (
                icon: Icons.account_circle_outlined,
                selected: Icons.account_circle_rounded,
              ),
    };
  }

  static IconData quickAdd(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => CupertinoIcons.plus,
    _ => Icons.add_rounded,
  };
}
