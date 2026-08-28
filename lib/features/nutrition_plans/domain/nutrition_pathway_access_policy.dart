import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/domain/subscription_state.dart';
import 'nutrition_pathway.dart';
import 'nutrition_pathway_catalog.dart';

/// Exact, canonical lookup. Deliberately does not trim or normalize an ID:
/// an unknown or malformed deep link must never inherit another pathway.
NutritionPathway? nutritionPathwayForExactId(String pathwayId) {
  for (final pathway in nutritionPathways) {
    if (pathway.id == pathwayId) return pathway;
  }
  return null;
}

/// Runtime access policy shared by route presentation and activation.
///
/// Catalog metadata is never sufficient to grant Premium. Paid pathways open
/// only from a server-verified state carrying the specific program grant.
bool nutritionPathwayAccessGranted(
  NutritionPathway pathway,
  SubscriptionState? subscription,
) {
  if (pathway.access == NutritionPathwayAccess.free) return true;
  return subscription?.authority == EntitlementAuthority.verifiedServer &&
      (subscription?.grants(CommerceEntitlement.premiumPrograms) ?? false);
}
