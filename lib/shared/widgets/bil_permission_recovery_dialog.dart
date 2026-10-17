import 'package:flutter/material.dart';

import 'bil_pearl_alert_dialog.dart';

/// Optional BIL rationale/recovery surface. Native iOS/Android permissions
/// remain exclusively owned by the platform permission request API.
Future<bool> showBilPearlPermissionDecision(
  BuildContext context, {
  required String title,
  required String description,
  required String cancelLabel,
  required String confirmLabel,
}) async {
  if (!context.mounted) return false;
  final approved = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => BilPearlAlertDialog(
      key: const Key('bil-permission-pearl-dialog'),
      title: Text(title),
      content: Text(description),
      actions: [
        TextButton(
          key: const Key('bil-permission-cancel'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          key: const Key('bil-permission-confirm'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return approved == true && context.mounted;
}
