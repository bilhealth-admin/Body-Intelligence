import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../domain/commerce_entitlement.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';

/// A failed or pending verification is not a commercial decision. This
/// boundary never navigates until the member explicitly chooses View plans.
Future<void> showOptionalAccessOffer(
  BuildContext context,
  WidgetRef ref, {
  required bool verifiedDenied,
  String focus = 'subscription',
}) async {
  if (!context.mounted) return;
  final owner = ref.read(verifiedEntitlementOwnerIdProvider);
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  String tr(String en, String ar) => arabic ? ar : context.strings.text(en);
  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        tr(
          verifiedDenied
              ? 'This feature needs access'
              : 'Access check unavailable',
          verifiedDenied
              ? 'هذه الميزة تحتاج إلى صلاحية'
              : 'تعذر التحقق من الصلاحية',
        ),
      ),
      content: Text(
        tr(
          verifiedDenied
              ? 'You can continue using the app. View plans only if you wish to change your access.'
              : 'Your subscription was not classified as Free. Check your connection and retry; the rest of the app remains available.',
          verifiedDenied
              ? 'يمكنك متابعة استخدام التطبيق. افتح الخطط فقط إن رغبت في تغيير صلاحية هذه الميزة.'
              : 'لم نصنف اشتراكك كمجاني. تحقق من الاتصال وأعد المحاولة؛ تظل بقية وظائف التطبيق متاحة.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(tr('Continue', 'متابعة')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'retry'),
          child: Text(tr('Refresh access', 'تحديث الصلاحية')),
        ),
        if (verifiedDenied)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'plans'),
            child: Text(tr('View plans', 'عرض الخطط')),
          ),
      ],
    ),
  );
  if (!context.mounted ||
      ref.read(verifiedEntitlementOwnerIdProvider) != owner) {
    return;
  }
  if (choice == 'retry') {
    ref.invalidate(verifiedSubscriptionStateProvider);
    ref.invalidate(aiVisionCreditStateProvider);
    ref.invalidate(aiBoostVisionAccessProvider);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Access is refreshing. Try the feature again.',
            'جارٍ تحديث الصلاحية. أعد فتح الميزة.',
          ),
        ),
      ),
    );
  } else if (choice == 'plans') {
    await GoRouter.maybeOf(
      context,
    )?.push('/plans?focus=${Uri.encodeQueryComponent(focus)}');
  }
}

Future<bool> requestVerifiedFeatureAccess(
  BuildContext context,
  WidgetRef ref,
  CommerceEntitlement entitlement,
) async {
  final owner = ref.read(verifiedEntitlementOwnerIdProvider);
  var retired = false;
  // Provider authority is owner scoped. Capture the original lease rather than
  // granting access from a stale response after an A -> B -> A transition.
  final container = ProviderScope.containerOf(context, listen: false);
  final lease = container.listen(verifiedEntitlementOwnerIdProvider, (
    previous,
    next,
  ) {
    if (previous != next) retired = true;
  });
  SubscriptionState? verified;
  try {
    var access = ref.read(verifiedSubscriptionAccessProvider);
    if (access.asData?.value.authority != EntitlementAuthority.verifiedServer) {
      if (access.hasError || access.hasValue) {
        ref.invalidate(verifiedSubscriptionStateProvider);
      }
      await ref
          .read(verifiedSubscriptionStateProvider.future)
          .timeout(const Duration(seconds: 8));
      access = ref.read(verifiedSubscriptionAccessProvider);
    }
    verified = access.asData?.value;
  } on Object {
    // Retain an unknown result, never manufacture a verified Free result.
  } finally {
    lease.close();
  }
  if (!context.mounted ||
      retired ||
      ref.read(verifiedEntitlementOwnerIdProvider) != owner) {
    return false;
  }
  final authoritative =
      verified?.authority == EntitlementAuthority.verifiedServer;
  if (authoritative && verified!.grants(entitlement)) return true;
  await showOptionalAccessOffer(context, ref, verifiedDenied: authoritative);
  return false;
}

Future<void> explainVisionAccess(BuildContext context, WidgetRef ref) async {
  final status = ref.read(aiVisionCreditStateProvider).asData?.value;
  await showOptionalAccessOffer(
    context,
    ref,
    verifiedDenied: status == AiVisionCreditState.insufficient,
    focus: 'boost',
  );
}
