import 'package:flutter/material.dart';

import 'bil_wordmark.dart';

/// Compatibility facade for the historical class name. The metallic visual
/// treatment itself is retired; this always renders the canonical BIL™ mark.
@Deprecated('Use BilWordmark. The metallic identity has been retired.')
class BilMetallicWordmark extends BilWordmark {
  const BilMetallicWordmark({
    super.key,
    double fontSize = 54,
    bool showDescriptor = true,
    bool compact = false,
  }) : super(
         height: fontSize,
         alignment: compact
             ? AlignmentDirectional.centerStart
             : Alignment.center,
       );
}
