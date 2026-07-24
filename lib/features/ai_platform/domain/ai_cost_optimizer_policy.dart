import 'ai_cost_optimization.dart';

final class AiCostOptimizerPolicy {
  const AiCostOptimizerPolicy({
    this.budget = const AiCostBudget(
      maximumRemoteRequests: 3,
      maximumInputCharacters: 4000,
      maximumOutputCharacters: 1200,
    ),
    this.localFirst = true,
  });

  final AiCostBudget budget;
  final bool localFirst;
}
