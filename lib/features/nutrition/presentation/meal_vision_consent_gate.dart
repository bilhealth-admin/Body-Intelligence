import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/runtime_copy.dart';

const mealVisionConsentPurpose = 'meal_vision_ai';
const mealVisionConsentPolicyVersion = '1';

String mealVisionConsentText(BuildContext context, String english) =>
    RuntimeCopy.resolve(
      english,
      Localizations.localeOf(context).toLanguageTag(),
    ) ??
    english;

/// Requires an explicit, current consent receipt before a meal photo can leave
/// the device for third-party AI analysis.
Future<bool> ensureMealVisionConsent(BuildContext context) async {
  final client = Supabase.instance.client;
  try {
    final current = await client
        .from('bil_consent_receipts')
        .select('granted,policy_version')
        .eq('purpose', mealVisionConsentPurpose)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (current?['granted'] == true &&
        current?['policy_version']?.toString() ==
            mealVisionConsentPolicyVersion) {
      return true;
    }
  } on Object {
    // Fail closed and offer the explicit consent surface below.
  }
  if (!context.mounted) return false;
  final granted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog.adaptive(
      title: Text(
        mealVisionConsentText(
          dialogContext,
          'Send this meal photo to Google Gemini?',
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          mealVisionConsentText(
            dialogContext,
            'If you agree, BIL sends the photo you select, your app language, and necessary technical request metadata to Google Gemini, a third-party AI service operated by Google. It is used to suggest foods and portions for your review. Nothing is logged until you confirm the results.\n\nYou can decline and continue with manual food entry. You can withdraw consent later in Privacy settings.',
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('meal-vision-consent-decline'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(mealVisionConsentText(dialogContext, "Don't Allow")),
        ),
        FilledButton(
          key: const Key('meal-vision-consent-accept'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(mealVisionConsentText(dialogContext, 'Allow & Continue')),
        ),
      ],
    ),
  );
  if (granted == null || !context.mounted) return false;
  try {
    await client.rpc(
      'bil_record_consent',
      params: <String, Object?>{
        'p_purpose': mealVisionConsentPurpose,
        'p_policy_version': mealVisionConsentPolicyVersion,
        'p_granted': granted,
      },
    );
    return granted;
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
