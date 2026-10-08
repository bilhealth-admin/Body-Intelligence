import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../domain/commerce_plan.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';

/// Server-verified boundary shared by every production barcode entry point.
Future<bool> requestPremiumBarcodeAccess(
  BuildContext context,
  WidgetRef ref,
) async {
  final ownerBefore = ref.read(verifiedEntitlementOwnerIdProvider);
  SubscriptionState? verified;
  try {
    var access = ref.read(verifiedSubscriptionAccessProvider);
    if (access.asData?.value.authority !=
        EntitlementAuthority.verifiedServer) {
      // Local Free and failed reads are unknown, never confirmed Free.
      // A new on-demand verification prevents the reviewer from being sent
      // to Plans by the pre-sign-in fallback state.
      if (access.hasError || access.hasValue) {
        ref.invalidate(verifiedSubscriptionStateProvider);
      }
      await ref
          .read(verifiedSubscriptionStateProvider.future)
          .timeout(const Duration(seconds: 6));
      access = ref.read(verifiedSubscriptionAccessProvider);
    }
    // An in-flight request cannot unlock the previous owner's barcode tool.
    if (ref.read(verifiedEntitlementOwnerIdProvider) != ownerBefore) {
      return false;
    }
    verified = access.asData?.value;
  } on Object {
    // A network failure is not proof of a Free subscription.
  }
  if (verified?.authority == EntitlementAuthority.verifiedServer) {
    if (const {
      CommercePlan.pro,
      CommercePlan.premium,
      CommercePlan.premiumAiCoach,
    }.contains(verified!.plan)) {
      return true;
    }
    if (context.mounted) await context.push('/plans?focus=subscription');
    return false;
  }
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.strings.text('Subscription check unavailable')),
      ),
    );
  }
  return false;
}
