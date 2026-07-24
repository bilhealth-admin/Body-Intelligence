import '../adapters/local_intelligence_repository_adapter.dart';
import '../domain/local_intelligence_runtime.dart';
import 'local_intelligence_reality_runtime.dart';

/// Backward-compatible facade for the canonical local intelligence runtime.
///
/// This class owns no intelligence logic. New product composition must use
/// [BilLocalIntelligenceCompositionRoot] and
/// [BilLocalIntelligenceRealityRuntime] directly.
@Deprecated(
  'Use BilLocalIntelligenceCompositionRoot or '
  'BilLocalIntelligenceRealityRuntime.',
)
final class BilLocalIntelligenceRuntime {
  BilLocalIntelligenceRuntime({
    required LocalIntelligenceRepositoryAdapter adapter,
  }) : _delegate = BilLocalIntelligenceRealityRuntime(adapter: adapter);

  final BilLocalIntelligenceRealityRuntime _delegate;

  Future<ProductIntelligenceOutput> run({required DateTime asOf}) =>
      _delegate.run(asOf: asOf);
}
