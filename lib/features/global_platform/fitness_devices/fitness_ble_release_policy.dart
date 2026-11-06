import 'package:flutter/foundation.dart';

/// Android BLE is withheld from this release until real fitness-device reads
/// are verified. Health Connect has a separate, read-only activity scope.
/// Keep the existing iOS BLE journey available.
bool fitnessBleAvailableForPlatform(
  TargetPlatform platform, {
  bool isWeb = false,
}) => !isWeb && platform == TargetPlatform.iOS;

bool get fitnessBleAvailableOnCurrentPlatform =>
    fitnessBleAvailableForPlatform(defaultTargetPlatform, isWeb: kIsWeb);
