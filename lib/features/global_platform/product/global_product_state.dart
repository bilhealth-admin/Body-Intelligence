import 'dart:collection';

final class GlobalModuleState {
  GlobalModuleState({
    required this.moduleId,
    required this.available,
    required this.authorized,
    required this.lastSuccessAt,
    required this.failureCode,
    required Map<String, Object?> details,
  }) : details = UnmodifiableMapView(Map<String, Object?>.of(details));
  final String moduleId;
  final bool available;
  final bool authorized;
  final DateTime? lastSuccessAt;
  final String? failureCode;
  final Map<String, Object?> details;
}

final class GlobalProductState {
  GlobalProductState({
    required Iterable<GlobalModuleState> modules,
    required this.offline,
    required this.generatedAt,
  }) : modules = List.unmodifiable(modules);
  final List<GlobalModuleState> modules;
  final bool offline;
  final DateTime generatedAt;
  bool get fullyOperational =>
      modules.length == 11 &&
      modules.every((m) => m.available && m.failureCode == null);
}
