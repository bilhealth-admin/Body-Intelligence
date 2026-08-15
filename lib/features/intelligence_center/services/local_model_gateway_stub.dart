import '../domain/coach_context_snapshot.dart';
import 'local_model_gateway.dart';

LocalModelGateway createLocalModelGateway() => const _UnavailableGateway();

class _UnavailableGateway implements LocalModelGateway {
  const _UnavailableGateway();

  @override
  Future<LocalModelAnswer?> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
  }) async => null;
}
