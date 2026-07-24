import '../domain/ai_platform_capability.dart';

/// Repository-owned, offline-only execution sequence for closing AI Platform.
///
/// This plan is governance data, not an inference engine. It records the
/// smallest authorized sequence and testable exit conditions. Production
/// packages remain responsible for implementing each capability.
final class AiPlatformClosurePlan {
  AiPlatformClosurePlan._();

  static final List<AiPlatformCapability>
  capabilities = List<AiPlatformCapability>.unmodifiable(<AiPlatformCapability>[
    AiPlatformCapability(
      key: 'truth_explain',
      title: 'Truth Engine and Explain Engine',
      status: AiPlatformCapabilityStatus.completed,
      exitCriteria: const <String>[
        'Public deterministic facade exposes only validated decisions, safe abstention, or rejection.',
        'Focused and regression tests preserve provenance, integrity, and explainability.',
      ],
      nextPackage: 'complete',
    ),
    AiPlatformCapability(
      key: 'body_twin',
      title: 'Body Twin',
      status: AiPlatformCapabilityStatus.partial,
      exitCriteria: const <String>[
        'Trusted snapshot foundation is extended with deterministic trend-ready state without inventing measurements.',
        'Completeness, freshness, consistency, provenance, and public outcome gates remain enforced.',
      ],
      nextPackage: 'BIL-AI-026',
    ),
    AiPlatformCapability(
      key: 'decision_memory',
      title: 'Decision Memory',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Immutable local decision records preserve input evidence, selected action, rationale, confidence, and outcome state.',
        'Deterministic retrieval and non-regression tests prove no hidden provider or cloud dependency.',
      ],
      nextPackage: 'after-body-twin',
    ),
    AiPlatformCapability(
      key: 'ai_context',
      title: 'AI Context Engine',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Context assembly is explicit, permission-bounded, deterministic, and source-attributed.',
        'Missing and stale context remain visible and cannot be silently fabricated.',
      ],
      nextPackage: 'after-decision-memory',
    ),
    AiPlatformCapability(
      key: 'tissue_water_noise',
      title: 'Tissue and Water Noise Isolation',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Local deterministic classification separates observed scale change from supported tissue and water explanations.',
        'Uncertainty, missing evidence, and alternative explanations are exposed with tests.',
      ],
      nextPackage: 'after-ai-context',
    ),
    AiPlatformCapability(
      key: 'adaptive_metabolic_forecasting',
      title: 'Adaptive Metabolic Forecasting',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Forecasts are derived from validated local inputs with explicit horizons, confidence, and assumptions.',
        'Sparse or conflicting evidence produces abstention or bounded uncertainty rather than false precision.',
      ],
      nextPackage: 'after-noise-isolation',
    ),
    AiPlatformCapability(
      key: 'one_best_action',
      title: 'One Best Action',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Candidate actions are ranked by deterministic policy over trusted evidence and safety gates.',
        'The engine may abstain and always returns explainable reasons and rejected alternatives.',
      ],
      nextPackage: 'after-forecasting',
    ),
    AiPlatformCapability(
      key: 'ai_safety',
      title: 'AI Safety Layer',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Medical, eating-disorder, dangerous-weight-loss, and harmful-request policies are explicit and testable.',
        'Unsafe recommendations are blocked before coach, prompt, or provider exposure.',
      ],
      nextPackage: 'after-one-best-action',
    ),
    AiPlatformCapability(
      key: 'health_insight_summaries',
      title: 'Automated Health Insight Summaries',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Summaries are generated only from validated local facts and preserve source, uncertainty, and missing-data disclosure.',
        'Deterministic summary contracts exist independently of LLM wording.',
      ],
      nextPackage: 'after-safety',
    ),
    AiPlatformCapability(
      key: 'ai_coach',
      title: 'AI Coach',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Coach responses consume trusted context, safety-approved actions, and explainable summaries only.',
        'The coach cannot override deterministic engines or invent health state.',
      ],
      nextPackage: 'after-insight-summaries',
    ),
    AiPlatformCapability(
      key: 'prompt_engine',
      title: 'Prompt Engine',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Prompts are versioned, provider-neutral, privacy-bounded, and covered by deterministic contract tests.',
        'Prompt output is advisory wording and cannot become the sole source of truth.',
      ],
      nextPackage: 'after-ai-coach',
    ),
    AiPlatformCapability(
      key: 'ai_cost_optimizer',
      title: 'AI Cost Optimizer',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Local-first routing, cache eligibility, token budgets, and provider fallback policy are explicit and testable.',
        'Cost optimization never weakens privacy, safety, evidence, or correctness gates.',
      ],
      nextPackage: 'after-prompt-engine',
    ),
    AiPlatformCapability(
      key: 'proprietary_intelligence',
      title: 'Proprietary BIL Intelligence',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'BIL-specific composition joins Body Twin, Decision Memory, context, forecasts, and action policy through stable contracts.',
        'Every derived output remains explainable, reproducible, and independently testable.',
      ],
      nextPackage: 'after-cost-optimizer',
    ),
    AiPlatformCapability(
      key: 'scientific_validation',
      title: 'Scientific Validation and Explainability',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'Scientific rules, assumptions, confidence language, alternative explanations, and validation fixtures are documented and tested.',
        'No unsupported medical conclusion or false precision passes the final consumption boundary.',
      ],
      nextPackage: 'after-proprietary-intelligence',
    ),
    AiPlatformCapability(
      key: 'final_integration',
      title: 'AI Platform Final Integration and Closure',
      status: AiPlatformCapabilityStatus.remaining,
      exitCriteria: const <String>[
        'All capability exit criteria pass focused, regression, analyzer, full-project, and non-regression gates.',
        'Living documents reconcile to code and Cloud Platform remains blocked until formal AI Platform closure.',
      ],
      nextPackage: 'final-ai-platform-closure',
    ),
  ]);

  static AiPlatformCapability get firstProductionPackage => capabilities
      .firstWhere((capability) => capability.nextPackage == 'BIL-AI-026');

  static bool get isClosed => capabilities.every(
    (capability) => capability.status == AiPlatformCapabilityStatus.completed,
  );
}
