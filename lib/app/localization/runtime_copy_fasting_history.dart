import 'package:flutter/widgets.dart';

import 'bil_locale_policy.dart';

/// Completed fasting history actions in all25 production locales.
abstract final class FastingHistoryRuntimeCopy {
  static const deleteRecord = "Delete completed fast";
  static const confirmation =
      "Remove this record from fasting history? Your active timer will not change.";
  static const failed = "Could not delete this record. Try again.";
  static const changed = "Fasting history changed. Review it and try again.";
  static const unavailable = "Fasting history is unavailable.";
  static const sources = [
    deleteRecord,
    confirmation,
    failed,
    changed,
    unavailable,
  ];
  static const rows = <String, List<String>>{
    "en": [
      "Delete completed fast",
      "Remove this record from fasting history? Your active timer will not change.",
      "Could not delete this record. Try again.",
      "Fasting history changed. Review it and try again.",
      "Fasting history is unavailable.",
    ],
    "ar": [
      "حذف جلسة الصيام المكتملة",
      "هل تريد إزالة هذا السجل من سجل الصيام؟ لن يتغير المؤقت النشط.",
      "تعذر حذف هذا السجل. حاول مرة أخرى.",
      "تغير سجل الصيام. راجعه وحاول مرة أخرى.",
      "سجل الصيام غير متاح.",
    ],
    "fr": [
      "Supprimer le jeûne terminé",
      "Supprimer cet enregistrement de l’historique du jeûne ? Le minuteur actif ne changera pas.",
      "Impossible de supprimer cet enregistrement. Réessayez.",
      "L’historique du jeûne a changé. Vérifiez-le et réessayez.",
      "L’historique du jeûne est indisponible.",
    ],
    "es": [
      "Eliminar ayuno finalizado",
      "¿Eliminar este registro del historial de ayuno? El temporizador activo no cambiará.",
      "No se pudo eliminar este registro. Inténtalo de nuevo.",
      "El historial de ayuno ha cambiado. Revísalo e inténtalo de nuevo.",
      "El historial de ayuno no está disponible.",
    ],
    "tr": [
      "Tamamlanan orucu sil",
      "Bu kayıt oruç geçmişinden silinsin mi? Etkin zamanlayıcı değişmez.",
      "Bu kayıt silinemedi. Yeniden deneyin.",
      "Oruç geçmişi değişti. Kontrol edip yeniden deneyin.",
      "Oruç geçmişi kullanılamıyor.",
    ],
    "de": [
      "Abgeschlossenes Fasten löschen",
      "Diesen Eintrag aus dem Fastenverlauf entfernen? Der aktive Timer bleibt unverändert.",
      "Dieser Eintrag konnte nicht gelöscht werden. Erneut versuchen.",
      "Der Fastenverlauf hat sich geändert. Prüfen und erneut versuchen.",
      "Der Fastenverlauf ist nicht verfügbar.",
    ],
    "it": [
      "Elimina digiuno completato",
      "Rimuovere questo record dalla cronologia dei digiuni? Il timer attivo non cambierà.",
      "Impossibile eliminare questo record. Riprova.",
      "La cronologia dei digiuni è cambiata. Controllala e riprova.",
      "La cronologia dei digiuni non è disponibile.",
    ],
    "pt-BR": [
      "Excluir jejum concluído",
      "Remover este registro do histórico de jejum? O cronômetro ativo não será alterado.",
      "Não foi possível excluir este registro. Tente novamente.",
      "O histórico de jejum mudou. Confira e tente novamente.",
      "O histórico de jejum não está disponível.",
    ],
    "pt-PT": [
      "Eliminar jejum concluído",
      "Remover este registo do histórico de jejum? O temporizador ativo não será alterado.",
      "Não foi possível eliminar este registo. Tente novamente.",
      "O histórico de jejum mudou. Verifique e tente novamente.",
      "O histórico de jejum não está disponível.",
    ],
    "ur": [
      "مکمل روزہ حذف کریں",
      "کیا یہ ریکارڈ روزے کی تاریخ سے ہٹانا ہے؟ فعال ٹائمر تبدیل نہیں ہوگا۔",
      "یہ ریکارڈ حذف نہیں ہو سکا۔ دوبارہ کوشش کریں۔",
      "روزے کی تاریخ بدل گئی ہے۔ جائزہ لے کر دوبارہ کوشش کریں۔",
      "روزے کی تاریخ دستیاب نہیں ہے۔",
    ],
    "fa": [
      "حذف روزه پایان‌یافته",
      "این رکورد از سابقه روزه حذف شود؟ زمان‌سنج فعال تغییر نمی‌کند.",
      "این رکورد حذف نشد. دوباره تلاش کنید.",
      "سابقه روزه تغییر کرده است. بررسی کنید و دوباره تلاش کنید.",
      "سابقه روزه در دسترس نیست.",
    ],
    "hi": [
      "पूरा हुआ उपवास मिटाएँ",
      "क्या यह रिकॉर्ड उपवास इतिहास से हटाना है? सक्रिय टाइमर नहीं बदलेगा।",
      "यह रिकॉर्ड मिटाया नहीं जा सका। फिर कोशिश करें।",
      "उपवास इतिहास बदल गया है। जाँचकर फिर कोशिश करें।",
      "उपवास इतिहास उपलब्ध नहीं है।",
    ],
    "id": [
      "Hapus puasa selesai",
      "Hapus catatan ini dari riwayat puasa? Pengatur waktu aktif tidak akan berubah.",
      "Catatan ini tidak dapat dihapus. Coba lagi.",
      "Riwayat puasa berubah. Periksa lalu coba lagi.",
      "Riwayat puasa tidak tersedia.",
    ],
    "ms": [
      "Padam puasa yang selesai",
      "Alih keluar rekod ini daripada sejarah puasa? Pemasa aktif tidak akan berubah.",
      "Rekod ini tidak dapat dipadamkan. Cuba lagi.",
      "Sejarah puasa berubah. Semak dan cuba lagi.",
      "Sejarah puasa tidak tersedia.",
    ],
    "ja": [
      "完了した断食を削除",
      "この記録を断食履歴から削除しますか？実行中のタイマーは変更されません。",
      "この記録を削除できませんでした。もう一度お試しください。",
      "断食履歴が変更されました。確認してからもう一度お試しください。",
      "断食履歴を利用できません。",
    ],
    "ko": [
      "완료된 단식 삭제",
      "이 기록을 단식 내역에서 삭제할까요? 실행 중인 타이머는 변경되지 않습니다.",
      "이 기록을 삭제할 수 없습니다. 다시 시도하세요.",
      "단식 내역이 변경되었습니다. 확인한 후 다시 시도하세요.",
      "단식 내역을 사용할 수 없습니다.",
    ],
    "zh-Hans": [
      "删除已完成的断食",
      "要从断食历史中移除此记录吗？正在运行的计时器不会改变。",
      "无法删除此记录。请重试。",
      "断食历史已更改。请检查后重试。",
      "断食历史暂不可用。",
    ],
    "zh-Hant": [
      "刪除已完成的斷食",
      "要從斷食歷史中移除此記錄嗎？正在運行的計時器不會改變。",
      "無法刪除此記錄。請重試。",
      "斷食歷史已變更。請檢查後重試。",
      "斷食歷史暫時無法使用。",
    ],
    "ru": [
      "Удалить завершённое голодание",
      "Удалить эту запись из истории голоданий? Активный таймер не изменится.",
      "Не удалось удалить запись. Повторите попытку.",
      "История голоданий изменилась. Проверьте её и повторите попытку.",
      "История голоданий недоступна.",
    ],
    "bn": [
      "সম্পন্ন উপবাস মুছুন",
      "উপবাসের ইতিহাস থেকে এই রেকর্ড সরাবেন? সক্রিয় টাইমার বদলাবে না।",
      "এই রেকর্ড মোছা যায়নি। আবার চেষ্টা করুন।",
      "উপবাসের ইতিহাস বদলেছে। দেখে আবার চেষ্টা করুন।",
      "উপবাসের ইতিহাস উপলব্ধ নয়।",
    ],
    "vi": [
      "Xóa lần nhịn ăn đã hoàn thành",
      "Xóa bản ghi này khỏi lịch sử nhịn ăn? Bộ hẹn giờ đang chạy sẽ không thay đổi.",
      "Không thể xóa bản ghi này. Hãy thử lại.",
      "Lịch sử nhịn ăn đã thay đổi. Hãy kiểm tra rồi thử lại.",
      "Không có lịch sử nhịn ăn.",
    ],
    "th": [
      "ลบการอดอาหารที่เสร็จแล้ว",
      "ลบรายการนี้จากประวัติการอดอาหารหรือไม่? ตัวจับเวลาที่กำลังทำงานจะไม่เปลี่ยนแปลง",
      "ไม่สามารถลบรายการนี้ได้ โปรดลองอีกครั้ง",
      "ประวัติการอดอาหารเปลี่ยนแปลงแล้ว โปรดตรวจสอบและลองอีกครั้ง",
      "ไม่สามารถดูประวัติการอดอาหารได้",
    ],
    "pl": [
      "Usuń zakończony post",
      "Usunąć ten wpis z historii postów? Aktywny minutnik się nie zmieni.",
      "Nie udało się usunąć wpisu. Spróbuj ponownie.",
      "Historia postów uległa zmianie. Sprawdź ją i spróbuj ponownie.",
      "Historia postów jest niedostępna.",
    ],
    "nl": [
      "Voltooide vastenperiode verwijderen",
      "Dit item uit de vastengeschiedenis verwijderen? De actieve timer blijft ongewijzigd.",
      "Dit item kon niet worden verwijderd. Probeer opnieuw.",
      "De vastengeschiedenis is gewijzigd. Controleer deze en probeer opnieuw.",
      "De vastengeschiedenis is niet beschikbaar.",
    ],
    "uk": [
      "Видалити завершене голодування",
      "Видалити цей запис з історії голодувань? Активний таймер не зміниться.",
      "Не вдалося видалити запис. Спробуйте ще раз.",
      "Історія голодувань змінилася. Перевірте її та спробуйте ще раз.",
      "Історія голодувань недоступна.",
    ],
  };
  static bool get balanced =>
      rows.keys.toSet().containsAll(BilLocalePolicy.productionTags) &&
      BilLocalePolicy.productionTags.toSet().containsAll(rows.keys) &&
      rows.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((text) => text.trim().isNotEmpty),
      );
  static String text(String source, Locale locale) {
    final index = sources.indexOf(source);
    if (index < 0) throw ArgumentError.value(source);
    return (rows[BilLocalePolicy.canonicalTag(locale)] ?? rows['en']!)[index];
  }
}
