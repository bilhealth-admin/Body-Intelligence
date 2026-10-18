import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/bil_semantic_icons.dart';
import 'bil_native_symbols.dart';
export 'bil_native_symbols.dart'
    show BilSettingsSymbol, BilNativeSettingsSymbols;

class BilNativeSettingsIcon extends StatefulWidget {
  const BilNativeSettingsIcon({
    required this.kind,
    this.symbol,
    this.flat = true,
    super.key,
  });
  final BilSemanticIconKind kind;
  final BilSettingsSymbol? symbol;
  final bool flat;

  static BilSettingsSymbol symbolFor(BilSemanticIconKind kind) =>
      BilSemanticIcons.nativeSymbol(kind);

  @override
  State<BilNativeSettingsIcon> createState() => _BilNativeSettingsIconState();
}

class _BilNativeSettingsIconState extends State<BilNativeSettingsIcon> {
  @override
  Widget build(BuildContext context) {
    final symbol =
        widget.symbol ?? BilNativeSettingsIcon.symbolFor(widget.kind);
    final platform = Theme.of(context).platform;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 29,
        child: Center(
          child: BilNativeSymbolGlyph(
            symbol: symbol,
            fallback: _fallback(symbol, platform),
            size: 22,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  IconData _fallback(BilSettingsSymbol symbol, TargetPlatform platform) {
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
      return BilSemanticIcons.spec(widget.kind).icon;
    }
    return switch (symbol) {
      BilSettingsSymbol.camera => CupertinoIcons.camera_fill,
      BilSettingsSymbol.email => CupertinoIcons.at,
      BilSettingsSymbol.height => CupertinoIcons.arrow_up_arrow_down,
      BilSettingsSymbol.people => CupertinoIcons.person_2_fill,
      BilSettingsSymbol.calendar => CupertinoIcons.calendar,
      BilSettingsSymbol.postal => CupertinoIcons.envelope_fill,
      BilSettingsSymbol.time => CupertinoIcons.clock_fill,
      BilSettingsSymbol.nutrition => CupertinoIcons.circle_grid_3x3_fill,
      BilSettingsSymbol.goals => CupertinoIcons.flag_fill,
      _ => BilSemanticIcons.spec(widget.kind).appleIcon,
    };
  }
}
