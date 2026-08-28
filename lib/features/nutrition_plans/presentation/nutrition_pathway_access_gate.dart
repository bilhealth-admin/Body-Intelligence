import 'package:flutter/widgets.dart';

import '../../commerce/presentation/premium_route_glass_gate.dart';
import '../domain/nutrition_pathway.dart';
import '../domain/nutrition_pathway_access_policy.dart';

/// Static route classification for a nutrition pathway deep link.
///
/// Unknown IDs continue to the editor's explicit not-found state. Premium
/// IDs retain the real editor as a visible preview beneath the shared glass.
class NutritionPathwayAccessGate extends StatelessWidget {
  const NutritionPathwayAccessGate({
    required this.pathwayId,
    required this.child,
    super.key,
  });

  final String pathwayId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pathway = nutritionPathwayForExactId(pathwayId);
    if (pathway == null || pathway.access == NutritionPathwayAccess.free) {
      return child;
    }
    return PremiumRouteGlassGate(
      feature: PremiumGateFeature.nutritionPrograms,
      child: child,
    );
  }
}
