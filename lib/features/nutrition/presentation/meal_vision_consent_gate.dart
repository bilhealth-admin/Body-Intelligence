import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/runtime_copy.dart';
import '../../../shared/widgets/bil_pearl_alert_dialog.dart';
import '../../community/services/community_owner_operation.dart';

const mealVisionConsentPurpose = 'meal_vision_ai';
const mealVisionConsentPolicyVersion = '1';

SupabaseClient? mealVisionConsentClient() {
  try {
    final sdk = Supabase.instance;
    return sdk.isInitialized ? sdk.client : null;
  } on Object {
    return null;
  }
}

String mealVisionConsentText(BuildContext context, String english) =>
    RuntimeCopy.resolve(
      english,
      Localizations.localeOf(context).toLanguageTag(),
    ) ??
    english;

/// Presentation only: opening or dismissing this disclosure never saves a grant.
/// The shared dialog scrolls its disclosure while keeping both actions outside
/// the scroll area. Avoid nesting another padded card inside its narrow body.
Future<bool?> showMealVisionConsentDisclosure(
  BuildContext context,
) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => BilPearlAlertDialog(
    title: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.image_search_rounded,
          color: Theme.of(dialogContext).colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mealVisionConsentText(
              dialogContext,
              'Send this meal photo to Google Gemini?',
            ),
          ),
        ),
      ],
    ),
    content: Text(
      mealVisionConsentText(
        dialogContext,
        'If you agree, BIL sends the photo you select, your app language, and necessary technical request metadata to Google Gemini, a third-party AI service operated by Google. It is used to suggest foods and portions for your review. Nothing is logged until you confirm the results.\n\nYou can decline and continue with manual food entry. You can withdraw consent later in Privacy settings.',
      ),
    ),
    actions: [
      OutlinedButton(
        key: const Key('meal-vision-consent-decline'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(136, 48)),
        onPressed: () => Navigator.pop(dialogContext, false),
        child: Text(mealVisionConsentText(dialogContext, "Don't Allow")),
      ),
      FilledButton(
        key: const Key('meal-vision-consent-accept'),
        style: FilledButton.styleFrom(minimumSize: const Size(136, 48)),
        onPressed: () => Navigator.pop(dialogContext, true),
        child: Text(mealVisionConsentText(dialogContext, 'Allow & Continue')),
      ),
    ],
  ),
);

Future<bool> loadMealVisionConsent() async {
  final client = mealVisionConsentClient();
  final owner = client?.auth.currentUser?.id;
  if (client == null || owner == null) return false;
  return CommunityOwnerOperation.run(
    client: client,
    ownerId: owner,
    action: (operation) async {
      final receipt = await _mealVisionReceipt(client, operation);
      return receipt?['granted'] == true &&
          receipt?['policy_version']?.toString() ==
              mealVisionConsentPolicyVersion;
    },
  );
}

/// Withdrawal is confirmed only by the same owner's current server receipt.
Future<bool> revokeMealVisionConsent() async {
  final client = mealVisionConsentClient();
  final owner = client?.auth.currentUser?.id;
  if (client == null || owner == null) return false;
  try {
    return await CommunityOwnerOperation.run(
      client: client,
      ownerId: owner,
      action: (operation) async {
        await client
            .rpc(
              'bil_record_consent',
              params: {
                'p_purpose': mealVisionConsentPurpose,
                'p_policy_version': mealVisionConsentPolicyVersion,
                'p_granted': false,
              },
            )
            .timeout(const Duration(seconds: 8));
        operation.check();
        final receipt = await _mealVisionReceipt(client, operation);
        return receipt?['granted'] == false &&
            receipt?['policy_version']?.toString() ==
                mealVisionConsentPolicyVersion;
      },
    );
  } on Object {
    return false;
  }
}

Future<Map<String, dynamic>?> _mealVisionReceipt(
  SupabaseClient client,
  CommunityOwnerOperation operation,
) async {
  final receipt = await client
      .from('bil_consent_receipts')
      .select('granted,policy_version')
      .eq('user_id', operation.ownerId!)
      .eq('purpose', mealVisionConsentPurpose)
      .order('recorded_at', ascending: false)
      .limit(1)
      .maybeSingle()
      .timeout(const Duration(seconds: 8));
  operation.check();
  return receipt;
}

/// Requires an explicit, current consent receipt before a meal photo can leave
/// the device for third-party AI analysis.
Future<bool> ensureMealVisionConsent(BuildContext context) async {
  final client = mealVisionConsentClient();
  final owner = client?.auth.currentUser?.id;
  if (client == null || owner == null) return false;
  try {
    return await CommunityOwnerOperation.run(
      client: client,
      ownerId: owner,
      isCurrentOwner: () => context.mounted,
      action: (operation) =>
          _ensureMealVisionConsent(context, client, operation),
    );
  } on CommunityOwnerOperationCancelled {
    return false;
  }
}

Future<bool> _ensureMealVisionConsent(
  BuildContext context,
  SupabaseClient client,
  CommunityOwnerOperation operation,
) async {
  try {
    final current = await _mealVisionReceipt(client, operation);
    if (current?['granted'] == true &&
        current?['policy_version']?.toString() ==
            mealVisionConsentPolicyVersion) {
      return true;
    }
  } on CommunityOwnerOperationCancelled {
    rethrow;
  } on Object {
    // Fail closed and offer the explicit consent surface below.
  }
  operation.check();
  if (!context.mounted) return false;
  final granted = await showMealVisionConsentDisclosure(context);
  operation.check();
  if (granted == null || !context.mounted) return false;
  try {
    await client
        .rpc(
          'bil_record_consent',
          params: <String, Object?>{
            'p_purpose': mealVisionConsentPurpose,
            'p_policy_version': mealVisionConsentPolicyVersion,
            'p_granted': granted,
          },
        )
        .timeout(const Duration(seconds: 8));
    operation.check();
    if (granted) {
      // A completed request is not proof that a current Allow was persisted.
      final receipt = await _mealVisionReceipt(client, operation);
      return receipt?['granted'] == true &&
          receipt?['policy_version']?.toString() ==
              mealVisionConsentPolicyVersion;
    }
    return granted;
  } on CommunityOwnerOperationCancelled {
    rethrow;
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mealVisionConsentText(
              context,
              'Could not save photo-analysis consent. The photo was not sent.',
            ),
          ),
        ),
      );
    }
    return false;
  }
}
