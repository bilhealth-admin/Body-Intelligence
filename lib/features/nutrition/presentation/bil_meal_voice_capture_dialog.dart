import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_meal_voice.dart';
import '../../../app/localization/runtime_copy_voice_status.dart';
import '../services/meal_voice_session.dart';
import '../../../app/theme/bil_pearl_finish.dart';

/// Reusable BIL voice-capture presentation shared by meal entry points.
class BilMealVoiceCaptureDialog extends StatelessWidget {
  const BilMealVoiceCaptureDialog({
    super.key,
    required this.title,
    required this.instructions,
    required this.transcript,
    required this.editor,
    required this.editing,
    required this.cancelLabel,
    required this.useLabel,
    required this.onEdit,
    required this.onCancel,
    required this.onUse,
    this.error,
    this.phase = MealVoicePhase.review,
    this.onTextChanged,
    this.onRetry,
    this.onStop,
    this.textFieldKey = const Key('editable-voice-food-candidate'),
    this.useKey = const Key('accept-reviewed-voice-candidate'),
    this.reviewLabel,
    this.unitLabel,
    this.maxLength,
    this.buildCounter,
    this.keyboardType,
    this.useIcon = Icons.search_rounded,
  });

  final String title;
  final String instructions;
  final String transcript;
  final TextEditingController editor;
  final bool editing;
  final String cancelLabel;
  final String useLabel;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback? onUse;
  final String? error;
  final MealVoicePhase phase;
  final ValueChanged<String>? onTextChanged;
  final VoidCallback? onRetry, onStop;
  final Key textFieldKey, useKey;
  final String? reviewLabel, unitLabel;
  final int? maxLength;
  final InputCounterWidgetBuilder? buildCounter;
  final TextInputType? keyboardType;
  final IconData useIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    String statusCopy(VoiceStatusCopyKey key) =>
        VoiceStatusRuntimeCopy.resolve(key, locale);
    final listening = phase == MealVoicePhase.listening;
    final preparing = phase == MealVoicePhase.initializing;
    final status = switch (phase) {
      MealVoicePhase.initializing => statusCopy(
        VoiceStatusCopyKey.initializing,
      ),
      MealVoicePhase.listening => statusCopy(VoiceStatusCopyKey.listening),
      MealVoicePhase.stopped => statusCopy(VoiceStatusCopyKey.stopped),
      MealVoicePhase.review =>
        reviewLabel ??
            MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.reviewLabel, locale),
      MealVoicePhase.failure => MealVoiceRuntimeCopy.resolve(
        MealVoiceCopyKey.unavailable,
        locale,
      ),
    };
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 560),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: BilFrostedPanel(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom -
                        48)
                    .clamp(160, double.infinity),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        if (preparing &&
                            !MediaQuery.disableAnimationsOf(context))
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            listening
                                ? Icons.mic_rounded
                                : Icons.mic_off_outlined,
                            size: 22,
                            color: listening
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            status,
                            key: const Key('meal-voice-status'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: textFieldKey,
                    controller: editor,
                    minLines: 2,
                    maxLines: 5,
                    keyboardType: keyboardType,
                    maxLength: maxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    buildCounter: buildCounter,
                    onTap: onEdit,
                    onChanged: onTextChanged ?? (_) => onEdit(),
                    decoration: InputDecoration(
                      hintText:
                          reviewLabel ??
                          MealVoiceRuntimeCopy.resolve(
                            MealVoiceCopyKey.reviewLabel,
                            locale,
                          ),
                      suffixText: unitLabel,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    instructions,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        key: const Key('cancel-voice-food-candidate'),
                        onPressed: onCancel,
                        child: Text(cancelLabel),
                      ),
                      if (onRetry != null && !listening && !preparing)
                        OutlinedButton(
                          key: const Key('retry-voice-food-candidate'),
                          onPressed: onRetry,
                          child: Text(statusCopy(VoiceStatusCopyKey.retry)),
                        ),
                      if (listening)
                        FilledButton.icon(
                          key: const Key('stop-voice-food-candidate'),
                          onPressed: onStop,
                          icon: const Icon(Icons.stop_rounded),
                          label: Text(statusCopy(VoiceStatusCopyKey.stop)),
                        )
                      else
                        FilledButton.icon(
                          key: useKey,
                          onPressed: preparing ? null : onUse,
                          icon: Icon(useIcon),
                          label: Text(useLabel),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
