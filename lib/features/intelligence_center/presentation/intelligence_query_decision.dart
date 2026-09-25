part of 'intelligence_center_page.dart';

enum CoachPendingActionDecision { none, confirm, cancel }

@visibleForTesting
CoachPendingActionDecision coachPendingActionDecision(String input) {
  final normalized = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.!?؟،,]+$'), '')
      .trim();
  if (const <String>{
    'confirm',
    'confirmed',
    'yes confirm',
    'yes, confirm',
    'proceed',
    'execute',
    'approved',
    'تأكيد',
    'تاكيد',
    'نعم',
    'نعم تأكيد',
    'نعم تاكيد',
    'موافق',
    'نفذ',
    'ننفذ',
    'oui',
    'confirmer',
    'si',
    'sí',
    'confirmar',
    'evet',
    'onayla',
    'ja',
    'bestätigen',
    'conferma',
    'sim',
    'ہاں',
    'تصدیق',
    'بله',
    'تأیید',
    'हाँ',
    'पुष्टि',
    'ya',
    'konfirmasi',
    'sahkan',
    'はい',
    '確認',
    '네',
    '확인',
    '是',
    '确认',
    'да',
    'подтвердить',
    'হ্যাঁ',
    'xác nhận',
    'ใช่',
    'potwierdź',
    'bevestigen',
    'так',
  }.contains(normalized)) {
    return CoachPendingActionDecision.confirm;
  }
  if (const <String>{
    'cancel',
    'cancel it',
    'do not change it',
    "don't change it",
    'إلغاء',
    'الغاء',
    'لا تغيره',
    'لا تغيّره',
  }.contains(normalized)) {
    return CoachPendingActionDecision.cancel;
  }
  return CoachPendingActionDecision.none;
}
