import 'package:flutter/foundation.dart';

import '../global_platform/health_data/unified_health_data_integration.dart';

/// Presentation of imported DEVICE readings only. Manual wellness pages and
/// their stored histories do not use this filter. This never requests access,
/// changes a reading, or manufactures a supported-but-missing value.
bool connectedHealthDeviceSignalIsSupported(String key) =>
    defaultTargetPlatform != TargetPlatform.android ||
    BilHealthScope.healthConnectReadTypeNames.contains(key);
