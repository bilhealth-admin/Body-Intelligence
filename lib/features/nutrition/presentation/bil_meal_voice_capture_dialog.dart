import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Icon(
                      error == null
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_off_outlined,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!editing)
              Container(
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  transcript.trim().isEmpty ? instructions : transcript,
                  key: const Key('meal-voice-live-transcript'),
                ),
              )
            else
              TextField(
                key: const Key('editable-voice-food-candidate'),
                controller: editor,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
            if (error != null && !editing) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 8),
            if (!editing)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: const Key('edit-voice-food-candidate'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(context.strings.text('Edit')),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCancel, child: Text(cancelLabel)),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('accept-reviewed-voice-candidate'),
                  onPressed: onUse,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(useLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
