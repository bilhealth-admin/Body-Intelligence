part of 'admin_notification_controls.dart';

class _AdminNotificationRequest {
  const _AdminNotificationRequest({
    required this.kind,
    required this.audience,
    required this.email,
    required this.message,
    required this.previewMessage,
  });

  final AiCoachAdminNotificationKind kind;
  final AiCoachAdminNotificationAudience audience;
  final String? email;
  final String? message;
  final String previewMessage;
}
