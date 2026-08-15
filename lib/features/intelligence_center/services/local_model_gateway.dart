import '../domain/coach_context_snapshot.dart';
import 'local_model_gateway_stub.dart'
    if (dart.library.io) 'local_model_gateway_io.dart'
    as implementation;

class LocalModelAnswer {
  const LocalModelAnswer({
    required this.text,
    required this.action,
    this.spokenText,
    this.processedOnDevice = true,
  });

  final String text;
  final Map<String, Object?>? action;
  final String? spokenText;
  final bool processedOnDevice;
}

abstract interface class LocalModelGateway {
  Future<LocalModelAnswer?> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
  });
}

LocalModelGateway createLocalModelGateway() =>
    implementation.createLocalModelGateway();
