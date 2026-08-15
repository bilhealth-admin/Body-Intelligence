abstract interface class ExternalKnowledgeProvider {
  String get providerId;
  bool get isConfigured;

  Future<String?> answerGeneralQuestion({
    required String question,
    required String locale,
  });
}

class DisabledExternalKnowledgeProvider implements ExternalKnowledgeProvider {
  const DisabledExternalKnowledgeProvider();

  @override
  String get providerId => 'disabled';

  @override
  bool get isConfigured => false;

  @override
  Future<String?> answerGeneralQuestion({
    required String question,
    required String locale,
  }) async => null;
}
