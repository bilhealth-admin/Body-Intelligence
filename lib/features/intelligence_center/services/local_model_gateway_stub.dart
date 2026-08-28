import '../domain/coach_context_snapshot.dart';
import 'local_model_gateway.dart';

LocalModelGateway createLocalModelGateway() => const _UnavailableGateway();

class _UnavailableGateway implements LocalModelGateway {
  const _UnavailableGateway();

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async => const LocalModelResult(
    status: CoachServiceStatus.temporarilyUnavailable,
    diagnosticCode: 'model_unavailable_on_platform',
  );
}
