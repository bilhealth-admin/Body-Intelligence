import 'package:flutter/services.dart';

/// Cross-platform export boundary for destinations owned by the user.
class DataExportService {
  const DataExportService();

  Future<void> copyText(String value) =>
      Clipboard.setData(ClipboardData(text: value));
}
