import '../../../data/database/app_database.dart';
import '../adapters/local_intelligence_repository_adapter.dart';
import 'local_intelligence_reality_runtime.dart';

/// The single product composition root for offline local intelligence.
///
/// Product code supplies the existing local database and receives the
/// canonical Reality Runtime. No alternate orchestration, provider, network,
/// or LLM path is created here.
final class BilLocalIntelligenceCompositionRoot {
  const BilLocalIntelligenceCompositionRoot();

  BilLocalIntelligenceRealityRuntime create({required AppDatabase database}) =>
      BilLocalIntelligenceRealityRuntime(
        adapter: LocalIntelligenceRepositoryAdapter(database),
      );
}
