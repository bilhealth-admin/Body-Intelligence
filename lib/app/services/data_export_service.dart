import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// Cross-platform export boundary for destinations owned by the user.
class DataExportService {
  const DataExportService();

  /// Opens the OS-owned destination picker. Sensitive health exports are never
  /// placed on the global clipboard, where other apps could read them.
  Future<void> sharePortableJson(String value) async {
    final export = XFile.fromData(
      utf8.encode(value),
      mimeType: 'application/json',
      name: 'BIL-private-data-export.json',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [export],
        subject: 'BIL private data export',
        fileNameOverrides: const ['BIL-private-data-export.json'],
      ),
    );
  }

  /// Shares the owner-requested progress, meal/nutrition and exercise CSVs
  /// through the OS destination picker without touching the clipboard.
  Future<void> sharePortableCsvFiles(Map<String, String> files) async {
    final exports = files.entries
        .map(
          (entry) => XFile.fromData(
            utf8.encode(entry.value),
            mimeType: 'text/csv',
            name: entry.key,
          ),
        )
        .toList(growable: false);
    await SharePlus.instance.share(
      ShareParams(
        files: exports,
        subject: 'BIL private CSV data export',
        fileNameOverrides: files.keys.toList(growable: false),
      ),
    );
  }
}
