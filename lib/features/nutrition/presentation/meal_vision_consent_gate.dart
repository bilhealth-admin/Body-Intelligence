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
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: scheme.surface,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: .72),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: .20),
                            blurRadius: 24,
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(13),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    mealVisionConsentText(
                      dialogContext,
                      'Send this meal photo to Google Gemini?',
                    ),
                    style: Theme.of(dialogContext).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.18),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: .58),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        mealVisionConsentText(
                          dialogContext,
                          'If you agree, BIL sends the photo you select, your app language, and necessary technical request metadata to Google Gemini, a third-party AI service operated by Google. It is used to suggest foods and portions for your review. Nothing is logged until you confirm the results.\n\nYou can decline and continue with manual food entry. You can withdraw consent later in Privacy settings.',
                        ),
                        style: Theme.of(dialogContext).textTheme.bodyMedium
                            ?.copyWith(
                              height: 1.5,
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const Key('meal-vision-consent-accept'),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: Text(
                      mealVisionConsentText(dialogContext, 'Allow & Continue'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    key: const Key('meal-vision-consent-decline'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      mealVisionConsentText(dialogContext, "Don't Allow"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
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
