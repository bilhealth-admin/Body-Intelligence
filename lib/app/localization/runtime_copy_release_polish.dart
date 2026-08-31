import 'package:flutter/widgets.dart';

import 'bil_locale_policy.dart';

/// Small, reviewed 25-locale catalog for release-polish strings that carry
/// accessibility, identity-boundary, or purchase-navigation meaning.
///
/// Production locales are required to resolve an authored row. English is
/// returned only for English (or an unsupported development locale), never as
/// a silent fallback for one of BIL's 25 shipped locales.
abstract final class ReleasePolishRuntimeCopy {
  static const seePremiumPlans = 'See Premium plans';
  static const sendMessage = 'Send message';
  static const accountChanged =
      'Your account changed. Open your profile and choose the photo again.';
  static const reportMember = 'Report member';
  static const reportSentToModeration = 'Report sent to moderation.';
  static const presenterSuitability =
      'Visual preference only; it does not determine training suitability.';
  static const routineCount = 'Routines: {count}';
  static const workoutMinutes = '{count} min';
  static const workoutRepetitions = '{count} reps';
  static const workoutSeconds = '{count} sec';
  static const workoutRestSeconds = 'Rest {count} sec';
  static const lockedWorkoutSemantics =
      'Workout instructions locked. Server-verified {level} access is required.';

  static const sources = <String>[
    seePremiumPlans,
    sendMessage,
    accountChanged,
    reportMember,
    reportSentToModeration,
    presenterSuitability,
    routineCount,
    workoutMinutes,
    workoutRepetitions,
    workoutSeconds,
    workoutRestSeconds,
    lockedWorkoutSemantics,
  ];

  static const supported = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt-BR',
    'pt-PT',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh-Hans',
    'zh-Hant',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  };

  static const rows = <String, List<String>>{
    'ar': <String>[
      'شاهد خطط Premium',
      'إرسال الرسالة',
      'تغيّر حسابك. افتح ملفك الشخصي واختر الصورة مرة أخرى.',
      'الإبلاغ عن العضو',
      'تم إرسال البلاغ إلى فريق الإشراف.',
      'تفضيل بصري فقط؛ ولا يحدد مدى ملاءمة التمرين.',
      'الروتينات: {count}',
      '{count} د',
      '{count} تكرار',
      '{count} ث',
      'راحة {count} ث',
      'تعليمات التمرين مقفلة. يلزم وصول {level} موثّق من الخادم.',
    ],
    'en': <String>[
      seePremiumPlans,
      sendMessage,
      accountChanged,
      reportMember,
      reportSentToModeration,
      presenterSuitability,
      routineCount,
      workoutMinutes,
      workoutRepetitions,
      workoutSeconds,
      workoutRestSeconds,
      lockedWorkoutSemantics,
    ],
    'fr': <String>[
      'Voir les offres Premium',
      'Envoyer le message',
      'Votre compte a changé. Ouvrez votre profil et choisissez de nouveau la photo.',
      'Signaler le membre',
      'Signalement envoyé à la modération.',
      'Il s’agit uniquement d’une préférence visuelle ; elle ne détermine pas l’aptitude à l’entraînement.',
      'Routines : {count}',
      '{count} min',
      '{count} répét.',
      '{count} s',
      'Repos {count} s',
      'Instructions d’entraînement verrouillées. Un accès {level} vérifié par le serveur est requis.',
    ],
    'es': <String>[
      'Ver planes Premium',
      'Enviar mensaje',
      'Tu cuenta cambió. Abre tu perfil y vuelve a elegir la foto.',
      'Denunciar al miembro',
      'Denuncia enviada a moderación.',
      'Es solo una preferencia visual; no determina la aptitud para entrenar.',
      'Rutinas: {count}',
      '{count} min',
      '{count} rep.',
      '{count} s',
      'Descanso {count} s',
      'Las instrucciones del entrenamiento están bloqueadas. Se requiere acceso {level} verificado por el servidor.',
    ],
    'tr': <String>[
      'Premium planlarını gör',
      'Mesaj gönder',
      'Hesabınız değişti. Profilinizi açıp fotoğrafı yeniden seçin.',
      'Üyeyi bildir',
      'Bildirim moderasyona gönderildi.',
      'Bu yalnızca görsel bir tercihtir; antrenmana uygunluğu belirlemez.',
      'Rutinler: {count}',
      '{count} dk',
      '{count} tekrar',
      '{count} sn',
      'Dinlenme {count} sn',
      'Antrenman talimatları kilitli. Sunucu tarafından doğrulanmış {level} erişimi gerekir.',
    ],
    'de': <String>[
      'Premium-Pläne ansehen',
      'Nachricht senden',
      'Ihr Konto hat sich geändert. Öffnen Sie Ihr Profil und wählen Sie das Foto erneut aus.',
      'Mitglied melden',
      'Meldung an die Moderation gesendet.',
      'Dies ist nur eine visuelle Präferenz und bestimmt nicht die Eignung für das Training.',
      'Routinen: {count}',
      '{count} Min.',
      '{count} Wdh.',
      '{count} Sek.',
      'Pause {count} Sek.',
      'Die Trainingsanweisungen sind gesperrt. Ein serverseitig verifizierter {level}-Zugriff ist erforderlich.',
    ],
    'it': <String>[
      'Vedi i piani Premium',
      'Invia messaggio',
      'Il tuo account è cambiato. Apri il profilo e scegli di nuovo la foto.',
      'Segnala membro',
      'Segnalazione inviata alla moderazione.',
      'È solo una preferenza visiva e non determina l’idoneità all’allenamento.',
      'Routine: {count}',
      '{count} min',
      '{count} rip.',
      '{count} s',
      'Recupero {count} s',
      'Le istruzioni dell’allenamento sono bloccate. È richiesto un accesso {level} verificato dal server.',
    ],
    'pt-BR': <String>[
      'Ver planos Premium',
      'Enviar mensagem',
      'Sua conta mudou. Abra seu perfil e escolha a foto novamente.',
      'Denunciar membro',
      'Denúncia enviada à moderação.',
      'Esta é apenas uma preferência visual e não determina a aptidão para o treino.',
      'Rotinas: {count}',
      '{count} min de treino',
      '{count} rep.',
      '{count} s',
      'Descanso {count} s',
      'As instruções do treino estão bloqueadas. É necessário acesso {level} verificado pelo servidor.',
    ],
    'pt-PT': <String>[
      'Ver planos Premium',
      'Enviar mensagem',
      'A sua conta mudou. Abra o perfil e escolha novamente a fotografia.',
      'Denunciar membro',
      'Denúncia enviada para moderação.',
      'Esta é apenas uma preferência visual e não determina a aptidão para o treino.',
      'Rotinas: {count}',
      '{count} min de exercício',
      '{count} rep.',
      '{count} s',
      'Descanso {count} s',
      'As instruções do treino estão bloqueadas. É necessário acesso {level} verificado pelo servidor.',
    ],
    'ur': <String>[
      'Premium پلان دیکھیں',
      'پیغام بھیجیں',
      'آپ کا اکاؤنٹ بدل گیا ہے۔ اپنا پروفائل کھولیں اور تصویر دوبارہ منتخب کریں۔',
      'رکن کی اطلاع دیں',
      'رپورٹ ماڈریشن کو بھیج دی گئی۔',
      'یہ صرف بصری ترجیح ہے؛ یہ ورزش کی موزونیت طے نہیں کرتی۔',
      'روٹینز: {count}',
      '{count} منٹ',
      '{count} تکرار',
      '{count} سیکنڈ',
      'آرام {count} سیکنڈ',
      'ورزش کی ہدایات مقفل ہیں۔ سرور سے تصدیق شدہ {level} رسائی درکار ہے۔',
    ],
    'fa': <String>[
      'مشاهده طرح‌های Premium',
      'ارسال پیام',
      'حساب شما تغییر کرده است. نمایه را باز کنید و دوباره عکس را انتخاب کنید.',
      'گزارش عضو',
      'گزارش برای بررسی ارسال شد.',
      'این فقط یک ترجیح ظاهری است و مناسب‌بودن تمرین را تعیین نمی‌کند.',
      'روتین‌ها: {count}',
      '{count} دقیقه',
      '{count} تکرار',
      '{count} ثانیه',
      'استراحت {count} ثانیه',
      'دستورهای تمرین قفل هستند. دسترسی {level} تأییدشده توسط سرور لازم است.',
    ],
    'hi': <String>[
      'Premium प्लान देखें',
      'संदेश भेजें',
      'आपका खाता बदल गया है। अपनी प्रोफ़ाइल खोलें और फ़ोटो फिर से चुनें।',
      'सदस्य की रिपोर्ट करें',
      'रिपोर्ट मॉडरेशन को भेज दी गई है।',
      'यह केवल दृश्य पसंद है; इससे प्रशिक्षण की उपयुक्तता तय नहीं होती।',
      'रूटीन: {count}',
      '{count} मिनट',
      '{count} दोहराव',
      '{count} सेकंड',
      'आराम {count} सेकंड',
      'वर्कआउट निर्देश लॉक हैं। सर्वर से सत्यापित {level} एक्सेस आवश्यक है।',
    ],
    'id': <String>[
      'Lihat paket Premium',
      'Kirim pesan',
      'Akun Anda berubah. Buka profil dan pilih kembali foto tersebut.',
      'Laporkan anggota',
      'Laporan dikirim ke moderasi.',
      'Ini hanya preferensi visual dan tidak menentukan kesesuaian latihan.',
      'Rutinitas: {count}',
      '{count} mnt',
      '{count} repetisi',
      '{count} dtk',
      'Istirahat {count} dtk',
      'Petunjuk latihan terkunci. Akses {level} yang diverifikasi server diperlukan.',
    ],
    'ms': <String>[
      'Lihat pelan Premium',
      'Hantar mesej',
      'Akaun anda telah berubah. Buka profil dan pilih semula foto tersebut.',
      'Laporkan ahli',
      'Laporan dihantar kepada moderator.',
      'Ini hanya pilihan visual dan tidak menentukan kesesuaian latihan.',
      'Rutin: {count}',
      '{count} min',
      '{count} ulangan',
      '{count} saat',
      'Rehat {count} saat',
      'Arahan senaman dikunci. Akses {level} yang disahkan pelayan diperlukan.',
    ],
    'ja': <String>[
      'Premiumプランを見る',
      'メッセージを送信',
      'アカウントが変更されました。プロフィールを開き、写真をもう一度選択してください。',
      'メンバーを報告',
      'モデレーションに報告を送信しました。',
      'これは見た目の設定にすぎず、トレーニングの適性を判断するものではありません。',
      'ルーティン：{count}',
      '{count}分',
      '{count}回',
      '{count}秒',
      '休憩 {count}秒',
      'ワークアウトの手順はロックされています。サーバーで確認された{level}アクセスが必要です。',
    ],
    'ko': <String>[
      'Premium 플랜 보기',
      '메시지 보내기',
      '계정이 변경되었습니다. 프로필을 열고 사진을 다시 선택하세요.',
      '회원 신고',
      '검토팀에 신고를 보냈습니다.',
      '시각적 선호 설정일 뿐이며 운동 적합성을 판단하지 않습니다.',
      '루틴: {count}',
      '{count}분',
      '{count}회',
      '{count}초',
      '휴식 {count}초',
      '운동 지침이 잠겨 있습니다. 서버에서 확인된 {level} 액세스가 필요합니다.',
    ],
    'zh-Hans': <String>[
      '查看Premium方案',
      '发送消息',
      '你的账户已更改。请打开个人资料并重新选择照片。',
      '举报成员',
      '举报已提交审核。',
      '这只是视觉偏好，不用于判断训练是否适合你。',
      '训练方案：{count}',
      '{count}分钟',
      '{count}次',
      '{count}秒',
      '休息 {count}秒',
      '训练说明已锁定。需要服务器验证的{level}访问权限。',
    ],
    'zh-Hant': <String>[
      '查看Premium方案',
      '傳送訊息',
      '你的帳戶已變更。請開啟個人資料並重新選擇照片。',
      '檢舉成員',
      '檢舉已送交審核。',
      '這只是視覺偏好，不用於判斷訓練是否適合你。',
      '訓練方案：{count}',
      '{count}分鐘',
      '{count}次',
      '{count}秒',
      '休息 {count}秒',
      '訓練說明已鎖定。需要伺服器驗證的{level}存取權限。',
    ],
    'ru': <String>[
      'Посмотреть планы Premium',
      'Отправить сообщение',
      'Ваша учётная запись изменилась. Откройте профиль и снова выберите фотографию.',
      'Пожаловаться на участника',
      'Жалоба отправлена на модерацию.',
      'Это только визуальное предпочтение; оно не определяет пригодность тренировки.',
      'Комплексы: {count}',
      '{count} мин',
      '{count} повт.',
      '{count} с',
      'Отдых {count} с',
      'Инструкции к тренировке заблокированы. Требуется подтверждённый сервером доступ {level}.',
    ],
    'bn': <String>[
      'Premium প্ল্যান দেখুন',
      'বার্তা পাঠান',
      'আপনার অ্যাকাউন্ট বদলেছে। প্রোফাইল খুলে ছবিটি আবার বেছে নিন।',
      'সদস্যকে রিপোর্ট করুন',
      'রিপোর্টটি মডারেশনে পাঠানো হয়েছে।',
      'এটি শুধু দেখার পছন্দ; এটি প্রশিক্ষণের উপযুক্ততা নির্ধারণ করে না।',
      'রুটিন: {count}',
      '{count} মিনিট',
      '{count} বার',
      '{count} সেকেন্ড',
      'বিশ্রাম {count} সেকেন্ড',
      'ওয়ার্কআউট নির্দেশনা লক করা আছে। সার্ভার-যাচাইকৃত {level} অ্যাক্সেস প্রয়োজন।',
    ],
    'vi': <String>[
      'Xem các gói Premium',
      'Gửi tin nhắn',
      'Tài khoản của bạn đã thay đổi. Hãy mở hồ sơ và chọn lại ảnh.',
      'Báo cáo thành viên',
      'Đã gửi báo cáo để kiểm duyệt.',
      'Đây chỉ là tùy chọn hiển thị; không dùng để xác định mức độ phù hợp của bài tập.',
      'Bài tập: {count}',
      '{count} phút',
      '{count} lần',
      '{count} giây',
      'Nghỉ {count} giây',
      'Hướng dẫn tập luyện đã bị khóa. Cần quyền truy cập {level} được máy chủ xác minh.',
    ],
    'th': <String>[
      'ดูแผน Premium',
      'ส่งข้อความ',
      'บัญชีของคุณเปลี่ยนแล้ว เปิดโปรไฟล์แล้วเลือกรูปอีกครั้ง',
      'รายงานสมาชิก',
      'ส่งรายงานให้ทีมตรวจสอบแล้ว',
      'นี่เป็นเพียงการตั้งค่าด้านภาพ และไม่ได้ใช้ตัดสินความเหมาะสมของการฝึก',
      'กิจวัตร: {count}',
      '{count} นาที',
      '{count} ครั้ง',
      '{count} วินาที',
      'พัก {count} วินาที',
      'คำแนะนำการออกกำลังกายถูกล็อก ต้องมีสิทธิ์เข้าถึง {level} ที่เซิร์ฟเวอร์ยืนยันแล้ว',
    ],
    'pl': <String>[
      'Zobacz plany Premium',
      'Wyślij wiadomość',
      'Twoje konto się zmieniło. Otwórz profil i ponownie wybierz zdjęcie.',
      'Zgłoś członka',
      'Zgłoszenie wysłano do moderacji.',
      'To wyłącznie preferencja wizualna i nie określa przydatności treningu.',
      'Plany: {count}',
      '{count} min',
      '{count} powt.',
      '{count} s',
      'Odpoczynek {count} s',
      'Instrukcje treningowe są zablokowane. Wymagany jest zweryfikowany przez serwer dostęp {level}.',
    ],
    'nl': <String>[
      'Premium-abonnementen bekijken',
      'Bericht verzenden',
      'Uw account is gewijzigd. Open uw profiel en kies de foto opnieuw.',
      'Lid rapporteren',
      'Melding naar moderatie verzonden.',
      'Dit is alleen een visuele voorkeur en bepaalt niet of een training geschikt is.',
      'Routines: {count}',
      '{count} min',
      '{count} herh.',
      '{count} sec',
      'Rust {count} sec',
      'De trainingsinstructies zijn vergrendeld. Door de server geverifieerde {level}-toegang is vereist.',
    ],
    'uk': <String>[
      'Переглянути плани Premium',
      'Надіслати повідомлення',
      'Ваш обліковий запис змінився. Відкрийте профіль і знову виберіть фотографію.',
      'Поскаржитися на учасника',
      'Скаргу надіслано модераторам.',
      'Це лише візуальна перевага; вона не визначає придатність тренування.',
      'Комплекси: {count}',
      '{count} хв',
      '{count} повт.',
      '{count} с',
      'Відпочинок {count} с',
      'Інструкції до тренування заблоковано. Потрібен підтверджений сервером доступ {level}.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing release-polish copy for $tag.');
    }
    return row[index];
  }

  static String textForLocale(String source, Locale locale) =>
      resolve(source, BilLocalePolicy.canonicalTag(locale)) ?? source;

  static String format(
    String source,
    Locale locale, {
    int? count,
    String? level,
  }) {
    var value = textForLocale(source, locale);
    if (count != null) value = value.replaceAll('{count}', '$count');
    if (level != null) value = value.replaceAll('{level}', level);
    return value;
  }

  static bool get balanced =>
      supported.length == 25 &&
      rows.keys.toSet().containsAll(supported) &&
      supported.containsAll(rows.keys) &&
      rows.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((value) => value.trim().isNotEmpty),
      ) &&
      _sameValues(rows['en'], sources);

  static bool _sameValues(List<String>? left, List<String> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < right.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
