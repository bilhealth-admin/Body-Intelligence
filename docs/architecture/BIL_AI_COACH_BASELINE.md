# BIL AI Coach and Intelligence Architecture Baseline

Generated from:
`BIL-ARCHITECTURE-BASELINE-d8bc3e2-20260801-160655`

## Executive finding

The project already contains a substantial deterministic, offline-first AI platform.
This package therefore reuses that platform and does not create a competing AI engine.

## Existing AI platform inventory

- Total AI platform Dart files: 130
- Domain models: 66
- Services/engines: 63
- Adapters: 1

## Reused canonical components

- `AiCoachEngine`
- `AiCoachResponse`
- `BilLocalIntelligenceRealityRuntime`
- `BilLocalIntelligenceCompositionRoot`
- `TruthEngine`
- `TruthDecisionExplainer`
- `BodyTwinEngine`
- `OneBestActionEngine`
- `AiSafetyEngine`
- `DecisionMemory`
- `PromptEngine`
- `BilIntelligenceIntegrationEngine`
- `PersonalHealthAiEngine`

## Integration rule

The new Intelligence Center is a presentation and orchestration boundary over the
existing engines. It does not diagnose, invent evidence, silently mutate user data,
or execute an action without explicit user confirmation.

## Provider neutrality

The package introduces a provider-neutral external knowledge interface. Local,
deterministic BIL intelligence remains first. An external provider can only enrich
general-knowledge answers when configured, and must never replace Truth Engine or
Body Twin outputs.

## AI platform files

- `lib/features/ai_platform/adapters/local_intelligence_repository_adapter.dart`
- `lib/features/ai_platform/domain/adaptive_metabolic_forecast.dart`
- `lib/features/ai_platform/domain/adaptive_metabolic_forecast_policy.dart`
- `lib/features/ai_platform/domain/ai_coach_policy.dart`
- `lib/features/ai_platform/domain/ai_coach_response.dart`
- `lib/features/ai_platform/domain/ai_context.dart`
- `lib/features/ai_platform/domain/ai_cost_optimization.dart`
- `lib/features/ai_platform/domain/ai_cost_optimizer_policy.dart`
- `lib/features/ai_platform/domain/ai_evidence.dart`
- `lib/features/ai_platform/domain/ai_platform_capability.dart`
- `lib/features/ai_platform/domain/ai_platform_closure.dart`
- `lib/features/ai_platform/domain/ai_platform_closure_policy.dart`
- `lib/features/ai_platform/domain/ai_safety.dart`
- `lib/features/ai_platform/domain/ai_safety_policy.dart`
- `lib/features/ai_platform/domain/automated_health_insight_policy.dart`
- `lib/features/ai_platform/domain/automated_health_insight_summary.dart`
- `lib/features/ai_platform/domain/bil_intelligence_integration.dart`
- `lib/features/ai_platform/domain/bil_intelligence_integration_policy.dart`
- `lib/features/ai_platform/domain/body_twin_consistency_result.dart`
- `lib/features/ai_platform/domain/body_twin_engine_result.dart`
- `lib/features/ai_platform/domain/body_twin_foundation_result.dart`
- `lib/features/ai_platform/domain/body_twin_freshness_result.dart`
- `lib/features/ai_platform/domain/body_twin_metric_provenance.dart`
- `lib/features/ai_platform/domain/body_twin_observation.dart`
- `lib/features/ai_platform/domain/body_twin_outcome.dart`
- `lib/features/ai_platform/domain/body_twin_snapshot.dart`
- `lib/features/ai_platform/domain/body_twin_snapshot_gate_result.dart`
- `lib/features/ai_platform/domain/body_twin_snapshot_integrity_result.dart`
- `lib/features/ai_platform/domain/body_twin_trend_state.dart`
- `lib/features/ai_platform/domain/decision_memory_archive.dart`
- `lib/features/ai_platform/domain/decision_memory_compaction.dart`
- `lib/features/ai_platform/domain/decision_memory_history.dart`
- `lib/features/ai_platform/domain/decision_memory_record.dart`
- `lib/features/ai_platform/domain/decision_memory_retention.dart`
- `lib/features/ai_platform/domain/decision_outcome_transition.dart`
- `lib/features/ai_platform/domain/explainable_ai_decision.dart`
- `lib/features/ai_platform/domain/local_intelligence_runtime.dart`
- `lib/features/ai_platform/domain/one_best_action.dart`
- `lib/features/ai_platform/domain/one_best_action_policy.dart`
- `lib/features/ai_platform/domain/personal_health_ai.dart`
- `lib/features/ai_platform/domain/prompt_engine_policy.dart`
- `lib/features/ai_platform/domain/prompt_envelope.dart`
- `lib/features/ai_platform/domain/proprietary_bil_intelligence.dart`
- `lib/features/ai_platform/domain/proprietary_bil_intelligence_policy.dart`
- `lib/features/ai_platform/domain/scientific_validation.dart`
- `lib/features/ai_platform/domain/scientific_validation_policy.dart`
- `lib/features/ai_platform/domain/tissue_water_noise_analysis.dart`
- `lib/features/ai_platform/domain/tissue_water_noise_policy.dart`
- `lib/features/ai_platform/domain/trusted_body_twin_snapshot_result.dart`
- `lib/features/ai_platform/domain/trusted_truth_decision_result.dart`
- `lib/features/ai_platform/domain/truth_assessment.dart`
- `lib/features/ai_platform/domain/truth_conflict_analysis.dart`
- `lib/features/ai_platform/domain/truth_decision_candidate.dart`
- `lib/features/ai_platform/domain/truth_decision_gate_result.dart`
- `lib/features/ai_platform/domain/truth_decision_integrity_result.dart`
- `lib/features/ai_platform/domain/truth_decision_pipeline_integrity_gate_result.dart`
- `lib/features/ai_platform/domain/truth_decision_pipeline_integrity_result.dart`
- `lib/features/ai_platform/domain/truth_decision_pipeline_result.dart`
- `lib/features/ai_platform/domain/truth_decision_validation_gate_result.dart`
- `lib/features/ai_platform/domain/truth_evaluation_gate_result.dart`
- `lib/features/ai_platform/domain/truth_evaluation_report.dart`
- `lib/features/ai_platform/domain/truth_evaluation_trace.dart`
- `lib/features/ai_platform/domain/truth_explain_foundation_result.dart`
- `lib/features/ai_platform/domain/truth_integrity_result.dart`
- `lib/features/ai_platform/domain/truth_proposition.dart`
- `lib/features/ai_platform/domain/truth_rule.dart`
- `lib/features/ai_platform/domain/truth_signal.dart`
- `lib/features/ai_platform/services/adaptive_metabolic_forecast_engine.dart`
- `lib/features/ai_platform/services/adaptive_metabolic_forecast_integrity_validator.dart`
- `lib/features/ai_platform/services/ai_coach_engine.dart`
- `lib/features/ai_platform/services/ai_coach_integrity_validator.dart`
- `lib/features/ai_platform/services/ai_context_engine.dart`
- `lib/features/ai_platform/services/ai_context_integrity_validator.dart`
- `lib/features/ai_platform/services/ai_cost_optimizer.dart`
- `lib/features/ai_platform/services/ai_cost_optimizer_integrity_validator.dart`
- `lib/features/ai_platform/services/ai_platform_closure_engine.dart`
- `lib/features/ai_platform/services/ai_platform_closure_integrity_validator.dart`
- `lib/features/ai_platform/services/ai_platform_closure_plan.dart`
- `lib/features/ai_platform/services/ai_safety_engine.dart`
- `lib/features/ai_platform/services/ai_safety_integrity_validator.dart`
- `lib/features/ai_platform/services/automated_health_insight_engine.dart`
- `lib/features/ai_platform/services/automated_health_insight_integrity_validator.dart`
- `lib/features/ai_platform/services/bil_intelligence_integration_engine.dart`
- `lib/features/ai_platform/services/body_twin_consistency_engine.dart`
- `lib/features/ai_platform/services/body_twin_engine.dart`
- `lib/features/ai_platform/services/body_twin_engine_integrity_validator.dart`
- `lib/features/ai_platform/services/body_twin_foundation.dart`
- `lib/features/ai_platform/services/body_twin_foundation_facade.dart`
- `lib/features/ai_platform/services/body_twin_freshness_gate.dart`
- `lib/features/ai_platform/services/body_twin_snapshot_foundation.dart`
- `lib/features/ai_platform/services/body_twin_snapshot_gate.dart`
- `lib/features/ai_platform/services/body_twin_snapshot_validator.dart`
- `lib/features/ai_platform/services/body_twin_trend_state_builder.dart`
- `lib/features/ai_platform/services/decision_memory.dart`
- `lib/features/ai_platform/services/decision_memory_archive_codec.dart`
- `lib/features/ai_platform/services/decision_memory_compaction_validator.dart`
- `lib/features/ai_platform/services/decision_memory_retention_engine.dart`
- `lib/features/ai_platform/services/decision_memory_store.dart`
- `lib/features/ai_platform/services/decision_outcome_reconciler.dart`
- `lib/features/ai_platform/services/local_intelligence_composition_root.dart`
- `lib/features/ai_platform/services/local_intelligence_reality_runtime.dart`
- `lib/features/ai_platform/services/local_intelligence_runtime.dart`
- `lib/features/ai_platform/services/one_best_action_engine.dart`
- `lib/features/ai_platform/services/one_best_action_integrity_validator.dart`
- `lib/features/ai_platform/services/personal_health_ai_engine.dart`
- `lib/features/ai_platform/services/physiological_reality_model.dart`
- `lib/features/ai_platform/services/product_intelligence_behavior_model.dart`
- `lib/features/ai_platform/services/prompt_engine.dart`
- `lib/features/ai_platform/services/prompt_engine_integrity_validator.dart`
- `lib/features/ai_platform/services/proprietary_bil_intelligence_engine.dart`
- `lib/features/ai_platform/services/proprietary_bil_intelligence_integrity_validator.dart`
- `lib/features/ai_platform/services/scientific_validation_engine.dart`
- `lib/features/ai_platform/services/scientific_validation_integrity_validator.dart`
- `lib/features/ai_platform/services/tissue_water_noise_engine.dart`
- `lib/features/ai_platform/services/tissue_water_noise_integrity_validator.dart`
- `lib/features/ai_platform/services/trusted_body_twin_snapshot_pipeline.dart`
- `lib/features/ai_platform/services/trusted_truth_decision_pipeline.dart`
- `lib/features/ai_platform/services/truth_conflict_analyzer.dart`
- `lib/features/ai_platform/services/truth_decision_explainer.dart`
- `lib/features/ai_platform/services/truth_decision_gate.dart`
- `lib/features/ai_platform/services/truth_decision_pipeline.dart`
- `lib/features/ai_platform/services/truth_decision_pipeline_integrity_gate.dart`
- `lib/features/ai_platform/services/truth_decision_pipeline_validator.dart`
- `lib/features/ai_platform/services/truth_decision_validation_gate.dart`
- `lib/features/ai_platform/services/truth_decision_validator.dart`
- `lib/features/ai_platform/services/truth_engine.dart`
- `lib/features/ai_platform/services/truth_evaluation_gate.dart`
- `lib/features/ai_platform/services/truth_evaluation_validator.dart`
- `lib/features/ai_platform/services/truth_explain_foundation.dart`
- `lib/features/ai_platform/services/truth_rule_composer.dart`

## Dashboard integration files

- `lib/features/dashboard/composition/dashboard_command_coordinator.dart`
- `lib/features/dashboard/composition/dashboard_composition.dart`
- `lib/features/dashboard/composition/dashboard_intelligence_input_adapter.dart`
- `lib/features/dashboard/composition/dashboard_layout_model.dart`
- `lib/features/dashboard/composition/dashboard_section.dart`
- `lib/features/dashboard/dashboard_page.dart`
- `lib/features/dashboard/domain/dashboard_decision_authority.dart`
- `lib/features/dashboard/domain/dashboard_decision_authority_parity.dart`
- `lib/features/dashboard/domain/dashboard_decision_explanation.dart`
- `lib/features/dashboard/domain/dashboard_decision_release_boundary.dart`
- `lib/features/dashboard/domain/dashboard_intelligence_composer.dart`
- `lib/features/dashboard/domain/dashboard_runtime_state.dart`
- `lib/features/dashboard/domain/dashboard_trusted_body_twin_adapter.dart`
- `lib/features/dashboard/domain/dashboard_trusted_truth_decision_adapter.dart`
- `lib/features/dashboard/presentation/dashboard_decision_explanation_page.dart`
- `lib/features/dashboard/presentation/dashboard_intelligence_localizer.dart`
- `lib/features/dashboard/providers/dashboard_provider.dart`
- `lib/features/dashboard/widgets/confidence_ring.dart`
- `lib/features/dashboard/widgets/daily_return_card.dart`
- `lib/features/dashboard/widgets/dashboard_analytics_center.dart`
- `lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart`
- `lib/features/dashboard/widgets/dashboard_carousel.dart`
- `lib/features/dashboard/widgets/dashboard_check_in_card.dart`
- `lib/features/dashboard/widgets/dashboard_composition.dart`
- `lib/features/dashboard/widgets/dashboard_daily_summary.dart`
- `lib/features/dashboard/widgets/dashboard_data_gate.dart`
- `lib/features/dashboard/widgets/dashboard_experience_frame.dart`
- `lib/features/dashboard/widgets/dashboard_grid.dart`
- `lib/features/dashboard/widgets/dashboard_header.dart`
- `lib/features/dashboard/widgets/dashboard_insights_surface.dart`
- `lib/features/dashboard/widgets/dashboard_layout_metrics.dart`
- `lib/features/dashboard/widgets/dashboard_loading_skeleton.dart`
- `lib/features/dashboard/widgets/dashboard_meals_timeline.dart`
- `lib/features/dashboard/widgets/dashboard_motion_reveal.dart`
- `lib/features/dashboard/widgets/dashboard_nutrition_details.dart`
- `lib/features/dashboard/widgets/dashboard_section_heading.dart`
- `lib/features/dashboard/widgets/dashboard_shell.dart`
- `lib/features/dashboard/widgets/dashboard_top_bar.dart`
- `lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart`
- `lib/features/dashboard/widgets/dashboard_water_card.dart`
- `lib/features/dashboard/widgets/first_value_handoff_card.dart`
- `lib/features/dashboard/widgets/nutrient_evidence_status_text.dart`
- `lib/features/dashboard/widgets/nutrition_progress_card.dart`
- `lib/features/dashboard/widgets/personal_health_ai_panel.dart`
- `lib/features/dashboard/widgets/premium_dashboard_benchmark.dart`
- `lib/features/dashboard/widgets/stat_card.dart`

## Nutrition/search integration files

- `lib/features/nutrition/adapters/branded_food_adapter.dart`
- `lib/features/nutrition/adapters/custom_food_adapter.dart`
- `lib/features/nutrition/adapters/database_food_adapter.dart`
- `lib/features/nutrition/adapters/foundation_food_adapter.dart`
- `lib/features/nutrition/adapters/legacy_food_adapter.dart`
- `lib/features/nutrition/adapters/unified_food_adapter.dart`
- `lib/features/nutrition/domain/barcode_identity.dart`
- `lib/features/nutrition/domain/central_nutrient_contract.dart`
- `lib/features/nutrition/domain/daily_nutrition_intelligence.dart`
- `lib/features/nutrition/domain/food_access.dart`
- `lib/features/nutrition/domain/food_image.dart`
- `lib/features/nutrition/domain/meal_builder.dart`
- `lib/features/nutrition/domain/meal_composition.dart`
- `lib/features/nutrition/domain/meal_template.dart`
- `lib/features/nutrition/domain/meal_validation.dart`
- `lib/features/nutrition/domain/serving_measure.dart`
- `lib/features/nutrition/domain/unified_food.dart`
- `lib/features/nutrition/food_page.dart`
- `lib/features/nutrition/integrations/open_food_facts/open_food_facts_client.dart`
- `lib/features/nutrition/integrations/open_food_facts/open_food_facts_lookup_service.dart`
- `lib/features/nutrition/integrations/open_food_facts/open_food_facts_mapper.dart`
- `lib/features/nutrition/presentation/food_barcode_scanner_page.dart`
- `lib/features/nutrition/repositories/active_catalog_registry.dart`
- `lib/features/nutrition/repositories/mobile_catalog_food_repository.dart`
- `lib/features/nutrition/repositories/unified_food_repository.dart`
- `lib/features/nutrition/repositories/usda_core_catalog_repository.dart`
- `lib/features/nutrition/services/active_mobile_catalog_resolver.dart`
- `lib/features/nutrition/services/bundled_core_catalog_installer.dart`
- `lib/features/nutrition/services/daily_nutrition_intelligence_engine.dart`
- `lib/features/nutrition/services/explainable_nutrition_engine.dart`
- `lib/features/nutrition/services/food_access_engine.dart`
- `lib/features/nutrition/services/food_deduplication_engine.dart`
- `lib/features/nutrition/services/food_foundation_integrity_engine.dart`
- `lib/features/nutrition/services/food_image_pipeline.dart`
- `lib/features/nutrition/services/food_migration_engine.dart`
- `lib/features/nutrition/services/food_quality_engine.dart`
- `lib/features/nutrition/services/food_quality_score_engine.dart`
- `lib/features/nutrition/services/food_runtime_search_authority.dart`
- `lib/features/nutrition/services/food_search_assistance.dart`
- `lib/features/nutrition/services/food_search_normalizer.dart`
- `lib/features/nutrition/services/food_unit_engine.dart`
- `lib/features/nutrition/services/gram_engine.dart`
- `lib/features/nutrition/services/meal_builder_engine.dart`
- `lib/features/nutrition/services/meal_composition_engine.dart`
- `lib/features/nutrition/services/meal_template_engine.dart`
- `lib/features/nutrition/services/meal_validation_engine.dart`
- `lib/features/nutrition/services/nutrition_calculation_engine.dart`
- `lib/features/nutrition/services/offline_barcode_resolver.dart`
- `lib/features/nutrition/services/offline_food_search_pipeline.dart`
- `lib/features/nutrition/services/serving_intelligence_engine.dart`