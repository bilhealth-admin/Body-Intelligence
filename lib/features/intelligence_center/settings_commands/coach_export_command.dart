import '../../../app/services/data_export_service.dart';
import '../../../app/services/local_data_lifecycle_service.dart';

const _exportDatasetFiles = <String, String>{
  'progress': 'BIL-progress.csv',
  'meal_nutrition': 'BIL-meal-nutrition.csv',
  'exercise_notes': 'BIL-exercise-notes.csv',
};

abstract interface class CoachExportDataGateway {
  Future<Map<String, String>> exportCsvFiles({DateTime? from, DateTime? to});
}

class LocalDataExportGateway implements CoachExportDataGateway {
  const LocalDataExportGateway(this.lifecycle);
  final LocalDataLifecycleService lifecycle;

  @override
  Future<Map<String, String>> exportCsvFiles({DateTime? from, DateTime? to}) =>
      lifecycle.exportCsvFiles(from: from, to: to);
}

abstract interface class CoachExportShareGateway {
  Future<void> sharePortableCsvFiles(Map<String, String> files);
}

class DataExportShareGateway implements CoachExportShareGateway {
  const DataExportShareGateway(this.service);
  final DataExportService service;

  @override
  Future<void> sharePortableCsvFiles(Map<String, String> files) =>
      service.sharePortableCsvFiles(files);
}

class CoachPreparedExport {
  const CoachPreparedExport({
    required this.from,
    required this.to,
    required this.datasets,
    required this.files,
    required this.preparedAt,
  });

  final DateTime? from;
  final DateTime? to;
  final Set<String> datasets;
  final Map<String, String> files;
  final DateTime preparedAt;
}

enum CoachExportShareStatus {
  /// The app handed the prepared bytes to the OS-owned share UI and control
  /// returned. The current platform boundary does not prove recipient delivery.
  handoffReturned,
}

class CoachExportCommandService {
  const CoachExportCommandService({required this.data, required this.share});

  factory CoachExportCommandService.production(
    LocalDataLifecycleService lifecycle,
  ) => CoachExportCommandService(
    data: LocalDataExportGateway(lifecycle),
    share: const DataExportShareGateway(DataExportService()),
  );

  final CoachExportDataGateway data;
  final CoachExportShareGateway share;

  Future<CoachPreparedExport> prepare({
    DateTime? from,
    DateTime? to,
    Set<String> datasets = const {
      'progress',
      'meal_nutrition',
      'exercise_notes',
    },
  }) async {
    final normalizedFrom = from == null ? null : _dateOnly(from);
    final normalizedTo = to == null ? null : _dateOnly(to);
    if (normalizedFrom != null &&
        normalizedTo != null &&
        normalizedFrom.isAfter(normalizedTo)) {
      throw ArgumentError('Export start date must not follow end date.');
    }
    if (datasets.isEmpty || !datasets.every(_exportDatasetFiles.containsKey)) {
      throw ArgumentError.value(datasets, 'datasets');
    }
    final all = await data.exportCsvFiles(
      from: normalizedFrom,
      to: normalizedTo,
    );
    final selected = <String, String>{
      for (final dataset in datasets)
        _exportDatasetFiles[dataset]!: all[_exportDatasetFiles[dataset]!]!,
    };
    return CoachPreparedExport(
      from: normalizedFrom,
      to: normalizedTo,
      datasets: Set<String>.unmodifiable(datasets),
      files: Map<String, String>.unmodifiable(selected),
      preparedAt: DateTime.now().toUtc(),
    );
  }

  /// This must be invoked by a second explicit user action. Preparing an export
  /// never calls this method and never sends health data outside the app.
  Future<CoachExportShareStatus> sharePrepared(
    CoachPreparedExport prepared,
  ) async {
    if (prepared.files.isEmpty) {
      throw StateError('No prepared export files to share.');
    }
    await share.sharePortableCsvFiles(prepared.files);
    return CoachExportShareStatus.handoffReturned;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
