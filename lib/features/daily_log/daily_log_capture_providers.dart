import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services/runtime_permission_policy.dart';
import '../nutrition/presentation/food_barcode_scanner_page.dart';

typedef DailyLogBarcodeScannerLauncher =
    Future<String?> Function(BuildContext context);

/// Platform boundaries for the real Daily Log barcode flow.
///
/// Production receives the native permission policy and full-screen scanner.
/// Tests can replace only these boundaries while still exercising the real
/// Quick Add dispatch and Daily Log lifecycle.
final dailyLogRuntimePermissionPolicyProvider =
    Provider<BilRuntimePermissionPolicy>(
      (ref) => const BilRuntimePermissionPolicy(),
    );

final dailyLogBarcodeScannerLauncherProvider =
    Provider<DailyLogBarcodeScannerLauncher>(
      (ref) =>
          (context) => Navigator.of(context).push<String>(
            MaterialPageRoute<String>(
              builder: (_) => const FoodBarcodeScannerPage(),
            ),
          ),
    );
