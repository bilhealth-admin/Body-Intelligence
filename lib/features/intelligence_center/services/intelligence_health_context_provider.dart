import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_platform/domain/local_intelligence_runtime.dart';
import '../../ai_platform/providers/product_intelligence_provider.dart';

class IntelligenceHealthContext {
  const IntelligenceHealthContext({
    required this.primaryMessage,
    required this.explanation,
    required this.confidence,
    required this.evidence,
    required this.missingData,
    this.actionTitle,
    this.actionReason,
    this.actionId,
  });

  final String primaryMessage;
  final List<String> explanation;
  final double confidence;
  final List<String> evidence;
  final List<String> missingData;
  final String? actionTitle;
  final String? actionReason;
  final String? actionId;

  factory IntelligenceHealthContext.fromOutput(
    ProductIntelligenceOutput output,
  ) {
    final brain = output.brainResult;
    final action = brain.selectedAction;
    final missing = <String>{
      ...brain.reconciliationIssues,
      for (final signal in brain.signals)
        if (!signal.accepted) ...signal.reasons,
    }..removeWhere((value) => value.trim().isEmpty);
    return IntelligenceHealthContext(
      primaryMessage: output.primaryMessage,
      explanation: output.explanation,
      confidence: brain.confidence,
      evidence: brain.evidenceIds,
      missingData: missing.toList(growable: false)..sort(),
      actionTitle: action?.title,
      actionReason: action?.rationale,
      actionId: action?.id,
    );
  }
}

final intelligenceHealthContextProvider =
    FutureProvider.autoDispose<IntelligenceHealthContext>((ref) async {
      final output = await ref.watch(productIntelligenceOutputProvider.future);
      return IntelligenceHealthContext.fromOutput(output);
    });
