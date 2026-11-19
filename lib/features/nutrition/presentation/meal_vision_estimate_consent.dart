import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import '../../../shared/widgets/bil_pearl_alert_dialog.dart'
    show BilDialogDecisionActions;
import '../../community/services/community_owner_operation.dart';
import 'meal_vision_consent_gate.dart';
import 'gemini_vision_copy.dart';

const mealVisionEstimateConsentPurpose = 'meal_vision_nutrition_ai';
const mealVisionEstimateConsentPolicyVersion = '1';

Future<Map<String, dynamic>?> _receipt(
  SupabaseClient client,
  CommunityOwnerOperation operation,
) async {
  operation.check();
  final row = await client
      .from('bil_consent_receipts')
      .select('granted,policy_version')
      .eq('user_id', operation.ownerId!)
      .eq('purpose', mealVisionEstimateConsentPurpose)
      .order('recorded_at', ascending: false)
      .limit(1)
      .maybeSingle()
      .timeout(const Duration(seconds: 8));
  operation.check();
  return row;
}

bool _granted(Map<String, dynamic>? row) =>
    row?['granted'] == true &&
    row?['policy_version']?.toString() ==
        mealVisionEstimateConsentPolicyVersion;

Future<bool> loadMealVisionEstimateConsent() async {
  final client = mealVisionConsentClient();
  final owner = client?.auth.currentUser?.id;
  if (client == null || owner == null) return false;
  return CommunityOwnerOperation.run(
    client: client,
    ownerId: owner,
    action: (operation) async => _granted(await _receipt(client, operation)),
  );
}

Future<bool> revokeMealVisionEstimateConsent() async {
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
                'p_purpose': mealVisionEstimateConsentPurpose,
                'p_policy_version': mealVisionEstimateConsentPolicyVersion,
                'p_granted': false,
              },
            )
            .timeout(const Duration(seconds: 8));
        operation.check();
        final row = await _receipt(client, operation);
        return row?['granted'] == false &&
            row?['policy_version']?.toString() ==
                mealVisionEstimateConsentPolicyVersion;
      },
    );
  } on Object {
    return false;
  }
}

/// Supplemental output consent never replaces the existing photo-send consent.
Future<bool> ensureMealVisionEstimateConsent(
  BuildContext context, {
  required bool Function() isCurrent,
}) async {
  final client = mealVisionConsentClient();
  final owner = client?.auth.currentUser?.id;
  if (client == null || owner == null || !isCurrent() || !context.mounted) {
    return false;
  }
  try {
    return await CommunityOwnerOperation.run(
      client: client,
      ownerId: owner,
      isCurrentOwner: () => context.mounted && isCurrent(),
      action: (operation) async {
        if (!await ensureMealVisionConsent(context)) return false;
        operation.check();
        try {
          if (_granted(await _receipt(client, operation))) return true;
        } on CommunityOwnerOperationCancelled {
          rethrow;
        } on Object {
          /* Offer the explicit disclosure, never assume a grant. */
        }
        operation.check();
        if (!context.mounted) return false;
        final title = geminiEstimateCopy(context, 2),
            body = geminiEstimateCopy(context, 3);
        final decline = geminiVisionText(context, "Don't Allow"),
            allow = geminiVisionText(context, 'Allow & Continue');
        final granted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialog) => BilPearlMaterialAlertDialog(
            scrollable: true,
            title: Text(title),
            content: Text(body),
            actions: [
              BilDialogDecisionActions(
                secondaryAction: OutlinedButton(
                  key: const Key('gemini-estimates-decline'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(decline, textAlign: TextAlign.center),
                ),
                primaryAction: FilledButton(
                  key: const Key('gemini-estimates-allow'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(allow, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        );
        operation.check();
        if (granted == null) return false;
        await client
            .rpc(
              'bil_record_consent',
              params: {
                'p_purpose': mealVisionEstimateConsentPurpose,
                'p_policy_version': mealVisionEstimateConsentPolicyVersion,
                'p_granted': granted,
              },
            )
            .timeout(const Duration(seconds: 8));
        operation.check();
        return granted && _granted(await _receipt(client, operation));
      },
    );
  } on CommunityOwnerOperationCancelled {
    return false;
  } on Object {
    return false;
  }
}
