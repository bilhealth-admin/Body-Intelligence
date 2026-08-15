import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/global_product_composition_root.dart';
import 'global_product_coordinators.dart';

final globalProductFlowsProvider = Provider<GlobalProductFlows>((ref) {
  final flows = GlobalNativeIntegrationHost.instance.productFlows;
  if (flows == null) throw StateError('global_product_flows_not_initialized');
  return flows;
});
