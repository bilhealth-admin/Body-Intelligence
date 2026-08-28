import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/commerce_plan.dart';
import '../providers/commerce_providers.dart';

/// Server-verified boundary shared by every production barcode entry point.
Future<bool> requestPremiumBarcodeAccess(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final cached = ref.read(verifiedSubscriptionStateProvider).value;
    final state =
        cached ??
        await ref
            .read(verifiedSubscriptionStateProvider.future)
            .timeout(const Duration(seconds: 6));
    if (const {
      CommercePlan.pro,
      CommercePlan.premium,
      CommercePlan.premiumAiCoach,
    }.contains(state.plan)) {
      return true;
    }
  } on Object {
    // Paid access fails closed when the server cannot verify entitlement.
  }
  if (context.mounted) await context.push('/plans?focus=subscription');
  return false;
}
