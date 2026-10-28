/// Localized terminal outcomes, separate from catalog and in-flight copy.
/// These messages never imply that cancelled or unconfirmed restoration
/// verified an empty purchase history or changed account access.
abstract final class BilStoreTerminalCopy {
  static String? text(String locale, String key) {
    final language = locale.split('-').first;
    final restoreOutcome = _restoreOutcomeCopy[key];
    if (restoreOutcome != null) {
      return restoreOutcome[locale] ??
          restoreOutcome[language] ??
          restoreOutcome['en']!;
    }
    if (key == 'purchase_verified') {
      return _extendedPurchaseVerifiedCopy[locale] ??
          _extendedPurchaseVerifiedCopy[language];
    }
    return null;
  }

  // Terminal verification copy is deliberately independent of the older
  // RuntimeCopy sentence that also claimed access was still updating.
  static const _extendedPurchaseVerifiedCopy = <String, String>{
    'de': 'Kauf verifiziert.',
    'it': 'Acquisto verificato.',
    'pt-br': 'Compra verificada.',
    'pt-pt': 'Compra verificada.',
    'ur': 'خریداری کی تصدیق ہو گئی۔',
    'fa': 'خرید تأیید شد.',
    'hi': 'खरीद सत्यापित.',
    'id': 'Pembelian terverifikasi.',
    'ms': 'Pembelian disahkan.',
    'ja': '購入確認済み。',
    'ko': '구매가 확인되었습니다.',
    'zh-hans': '购买已验证。',
    'zh-hant': '購買已驗證。',
    'ru': 'Покупка подтверждена.',
    'bn': 'ক্রয় যাচাই করা হয়েছে।',
    'vi': 'Đã xác minh mua hàng.',
    'th': 'ยืนยันการซื้อแล้ว',
    'pl': 'Zakup zweryfikowany.',
    'nl': 'Aankoop geverifieerd.',
    'uk': 'Покупка перевірена.',
  };

  static const _restoreOutcomeCopy = <String, Map<String, String>>{
    'restore_cancelled': {
      'en': 'Restore was cancelled.',
      'ar': 'أُلغيت استعادة المشتريات.',
      'fr': 'La restauration a été annulée.',
      'es': 'Se canceló la restauración.',
      'tr': 'Geri yükleme iptal edildi.',
      'de': 'Die Wiederherstellung wurde abgebrochen.',
      'it': 'Il ripristino è stato annullato.',
      'pt-br': 'A restauração foi cancelada.',
      'pt-pt': 'O restauro foi cancelado.',
      'ur': 'بحالی منسوخ کر دی گئی۔',
      'fa': 'بازیابی لغو شد.',
      'hi': 'पुनर्स्थापना रद्द कर दी गई।',
      'id': 'Pemulihan dibatalkan.',
      'ms': 'Pemulihan dibatalkan.',
      'ja': '復元はキャンセルされました。',
      'ko': '복원이 취소되었습니다.',
      'zh-hans': '恢复已取消。',
      'zh-hant': '還原已取消。',
      'ru': 'Восстановление отменено.',
      'bn': 'পুনরুদ্ধার বাতিল করা হয়েছে।',
      'vi': 'Đã hủy khôi phục.',
      'th': 'ยกเลิกการกู้คืนแล้ว',
      'pl': 'Przywracanie zostało anulowane.',
      'nl': 'Herstellen is geannuleerd.',
      'uk': 'Відновлення скасовано.',
    },
    'restore_unconfirmed': {
      'en': 'Restoration was not confirmed. You can try again.',
      'ar': 'لم يتم تأكيد الاستعادة. يمكنك المحاولة مجددًا.',
      'fr': 'La restauration n’a pas été confirmée. Vous pouvez réessayer.',
      'es': 'No se confirmó la restauración. Puedes volver a intentarlo.',
      'tr': 'Geri yükleme doğrulanmadı. Yeniden deneyebilirsiniz.',
      'de':
          'Die Wiederherstellung wurde nicht bestätigt. Du kannst es erneut versuchen.',
      'it': 'Il ripristino non è stato confermato. Puoi riprovare.',
      'pt-br': 'A restauração não foi confirmada. Você pode tentar novamente.',
      'pt-pt': 'O restauro não foi confirmado. Pode tentar novamente.',
      'ur': 'بحالی کی تصدیق نہیں ہوئی۔ آپ دوبارہ کوشش کر سکتے ہیں۔',
      'fa': 'بازیابی تأیید نشد. می‌توانید دوباره تلاش کنید.',
      'hi': 'पुनर्स्थापना की पुष्टि नहीं हुई। आप फिर कोशिश कर सकते हैं।',
      'id': 'Pemulihan belum dikonfirmasi. Anda dapat mencoba lagi.',
      'ms': 'Pemulihan belum disahkan. Anda boleh cuba lagi.',
      'ja': '復元は確認されませんでした。もう一度お試しいただけます。',
      'ko': '복원이 확인되지 않았습니다. 다시 시도할 수 있습니다.',
      'zh-hans': '恢复尚未确认。您可以重试。',
      'zh-hant': '尚未確認還原。您可以再試一次。',
      'ru': 'Восстановление не подтверждено. Можно попробовать ещё раз.',
      'bn': 'পুনরুদ্ধার নিশ্চিত হয়নি। আপনি আবার চেষ্টা করতে পারেন।',
      'vi': 'Chưa xác nhận việc khôi phục. Bạn có thể thử lại.',
      'th': 'ยังไม่ได้ยืนยันการกู้คืน คุณสามารถลองอีกครั้งได้',
      'pl': 'Przywracanie nie zostało potwierdzone. Możesz spróbować ponownie.',
      'nl': 'Het herstel is niet bevestigd. Je kunt het opnieuw proberen.',
      'uk': 'Відновлення не підтверджено. Можна спробувати ще раз.',
    },
  };
}
