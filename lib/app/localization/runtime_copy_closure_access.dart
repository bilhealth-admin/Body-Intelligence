import 'bil_locale_policy.dart';

/// Public access/action states. No subscription tier or financial policy changes.
abstract final class ClosureAccessRuntimeCopy {
  static const sources = [
    'Upgrade',
    'Review service unavailable',
    'This version cannot submit review decisions yet. Refresh after the review service is enabled.',
    'Could not load the moderation queue.',
    'Image unavailable',
  ];
  static const rows = <String, List<String>>{
    'en': sources,
    'ar': [
      'ترقية',
      'خدمة المراجعة غير متاحة',
      'لا تستطيع هذه النسخة إرسال قرارات المراجعة بعد. حدّث القائمة بعد تفعيل خدمة المراجعة.',
      'تعذر تحميل قائمة المراجعة.',
      'الصورة غير متاحة',
    ],
    'fr': [
      'Mettre à niveau',
      'Service de modération indisponible',
      'Cette version ne peut pas encore envoyer de décisions. Actualisez après l’activation du service de modération.',
      'Impossible de charger la file de modération.',
      'Image indisponible',
    ],
    'es': [
      'Mejorar plan',
      'Servicio de moderación no disponible',
      'Esta versión aún no puede enviar decisiones. Actualiza cuando se active el servicio de moderación.',
      'No se pudo cargar la cola de moderación.',
      'Imagen no disponible',
    ],
    'tr': [
      'Yükselt',
      'İnceleme hizmeti kullanılamıyor',
      'Bu sürüm henüz inceleme kararlarını gönderemez. Hizmet etkinleştirildiğinde yenileyin.',
      'İnceleme kuyruğu yüklenemedi.',
      'Görsel kullanılamıyor',
    ],
    'de': [
      'Upgrade',
      'Prüfdienst nicht verfügbar',
      'Diese Version kann noch keine Prüfentscheidungen senden. Nach Aktivierung des Prüfdienstes aktualisieren.',
      'Die Prüfwarteschlange konnte nicht geladen werden.',
      'Bild nicht verfügbar',
    ],
    'it': [
      'Passa al piano superiore',
      'Servizio di revisione non disponibile',
      'Questa versione non può ancora inviare decisioni. Aggiorna dopo l’attivazione del servizio di revisione.',
      'Impossibile caricare la coda di revisione.',
      'Immagine non disponibile',
    ],
    'pt-BR': [
      'Melhorar plano',
      'Serviço de revisão indisponível',
      'Esta versão ainda não pode enviar decisões. Atualize após a ativação do serviço de revisão.',
      'Não foi possível carregar a fila de revisão.',
      'Imagem indisponível',
    ],
    'pt-PT': [
      'Melhorar plano',
      'Serviço de revisão indisponível',
      'Esta versão ainda não pode enviar decisões. Atualize após a ativação do serviço de revisão.',
      'Não foi possível carregar a fila de revisão.',
      'Imagem indisponível',
    ],
    'ur': [
      'اپ گریڈ',
      'جائزے کی سروس دستیاب نہیں',
      'یہ ورژن ابھی جائزے کے فیصلے نہیں بھیج سکتا۔ سروس فعال ہونے کے بعد تازہ کریں۔',
      'جائزے کی فہرست لوڈ نہیں ہو سکی۔',
      'تصویر دستیاب نہیں',
    ],
    'fa': [
      'ارتقا',
      'سرویس بررسی در دسترس نیست',
      'این نسخه هنوز نمی‌تواند تصمیم‌های بررسی را ارسال کند. پس از فعال شدن سرویس، تازه‌سازی کنید.',
      'صف بررسی بارگیری نشد.',
      'تصویر در دسترس نیست',
    ],
    'hi': [
      'अपग्रेड करें',
      'समीक्षा सेवा उपलब्ध नहीं',
      'यह संस्करण अभी समीक्षा निर्णय नहीं भेज सकता। सेवा सक्रिय होने पर रीफ़्रेश करें।',
      'समीक्षा सूची लोड नहीं हो सकी।',
      'छवि उपलब्ध नहीं',
    ],
    'id': [
      'Tingkatkan paket',
      'Layanan peninjauan tidak tersedia',
      'Versi ini belum dapat mengirim keputusan. Muat ulang setelah layanan peninjauan diaktifkan.',
      'Antrean peninjauan gagal dimuat.',
      'Gambar tidak tersedia',
    ],
    'ms': [
      'Naik taraf',
      'Perkhidmatan semakan tidak tersedia',
      'Versi ini belum boleh menghantar keputusan. Muat semula selepas perkhidmatan semakan diaktifkan.',
      'Baris gilir semakan tidak dapat dimuatkan.',
      'Imej tidak tersedia',
    ],
    'ja': [
      'アップグレード',
      '審査サービスを利用できません',
      'このバージョンではまだ審査結果を送信できません。サービス有効化後に更新してください。',
      '審査一覧を読み込めませんでした。',
      '画像を利用できません',
    ],
    'ko': [
      '업그레이드',
      '검토 서비스를 사용할 수 없음',
      '이 버전은 아직 검토 결정을 보낼 수 없습니다. 서비스가 활성화되면 새로 고치세요.',
      '검토 목록을 불러오지 못했습니다.',
      '이미지를 사용할 수 없음',
    ],
    'zh-Hans': [
      '升级',
      '审核服务不可用',
      '此版本暂时无法提交审核决定。审核服务启用后请刷新。',
      '无法加载审核列表。',
      '图片不可用',
    ],
    'zh-Hant': [
      '升級',
      '審核服務無法使用',
      '此版本暫時無法提交審核決定。審核服務啟用後請重新整理。',
      '無法載入審核清單。',
      '圖片無法使用',
    ],
    'ru': [
      'Улучшить план',
      'Служба проверки недоступна',
      'Эта версия пока не может отправлять решения. Обновите после включения службы проверки.',
      'Не удалось загрузить очередь проверки.',
      'Изображение недоступно',
    ],
    'bn': [
      'আপগ্রেড করুন',
      'পর্যালোচনা সেবা উপলব্ধ নয়',
      'এই সংস্করণ এখনো পর্যালোচনার সিদ্ধান্ত পাঠাতে পারে না। সেবা চালু হলে রিফ্রেশ করুন।',
      'পর্যালোচনার তালিকা লোড করা যায়নি।',
      'ছবি উপলব্ধ নয়',
    ],
    'vi': [
      'Nâng cấp',
      'Dịch vụ xét duyệt không khả dụng',
      'Phiên bản này chưa thể gửi quyết định. Làm mới sau khi dịch vụ xét duyệt được bật.',
      'Không thể tải danh sách xét duyệt.',
      'Ảnh không khả dụng',
    ],
    'th': [
      'อัปเกรด',
      'บริการตรวจสอบไม่พร้อมใช้งาน',
      'เวอร์ชันนี้ยังส่งผลการตรวจสอบไม่ได้ โปรดรีเฟรชเมื่อเปิดใช้บริการตรวจสอบแล้ว',
      'โหลดรายการตรวจสอบไม่สำเร็จ',
      'รูปภาพไม่พร้อมใช้งาน',
    ],
    'pl': [
      'Ulepsz plan',
      'Usługa moderacji jest niedostępna',
      'Ta wersja nie może jeszcze wysyłać decyzji. Odśwież po włączeniu usługi moderacji.',
      'Nie udało się wczytać kolejki moderacji.',
      'Obraz jest niedostępny',
    ],
    'nl': [
      'Upgraden',
      'Beoordelingsdienst niet beschikbaar',
      'Deze versie kan nog geen beslissingen versturen. Vernieuw nadat de beoordelingsdienst is ingeschakeld.',
      'De beoordelingslijst kon niet worden geladen.',
      'Afbeelding niet beschikbaar',
    ],
    'uk': [
      'Покращити план',
      'Служба перевірки недоступна',
      'Ця версія ще не може надсилати рішення. Оновіть після ввімкнення служби перевірки.',
      'Не вдалося завантажити чергу перевірки.',
      'Зображення недоступне',
    ],
  };
  static String? resolve(String source, String tag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    return rows[BilLocalePolicy.canonicalTag(
      BilLocalePolicy.localeFromTag(tag),
    )]?[index];
  }

  static bool get balanced =>
      rows.length == 25 &&
      rows.values.every(
        (r) =>
            r.length == sources.length && r.every((s) => s.trim().isNotEmpty),
      );
}
