/// Reviewed copy for the AI Coach credit boundary.
///
/// These messages are deliberately kept in a complete 25-locale catalog:
/// losing AI access is a purchase boundary and must never fall back to English
/// inside another supported locale. Product names remain unchanged where that
/// is the clearest storefront reference.
abstract final class AiAccessRuntimeCopy {
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

  static const values = <String, Map<String, String>>{
    'Your available AI tokens are exhausted. No message was charged. Reactivate the smart coach with Premium AI Coach or add AI Boost tokens.': {
      'ar':
          'نفدت توكنات AI المتاحة. لم تُحتسب الرسالة. أعد تفعيل المدرب الذكي عبر Premium AI Coach أو أضف توكنات AI Boost.',
      'en':
          'Your available AI tokens are exhausted. No message was charged. Reactivate the smart coach with Premium AI Coach or add AI Boost tokens.',
      'fr':
          'Vos jetons AI disponibles sont épuisés. Aucun message n’a été facturé. Réactivez le coach intelligent avec Premium AI Coach ou ajoutez des jetons AI Boost.',
      'es':
          'Tus tokens de AI disponibles se han agotado. No se cobró ningún mensaje. Reactiva el coach inteligente con Premium AI Coach o añade tokens de AI Boost.',
      'tr':
          'Kullanılabilir AI tokenlarınız tükendi. Mesaj için ücret alınmadı. Akıllı koçu Premium AI Coach ile yeniden etkinleştirin veya AI Boost tokenları ekleyin.',
      'de':
          'Deine verfügbaren AI-Token sind aufgebraucht. Es wurde keine Nachricht berechnet. Aktiviere den intelligenten Coach mit Premium AI Coach erneut oder füge AI-Boost-Token hinzu.',
      'it':
          'I token AI disponibili sono esauriti. Non è stato addebitato alcun messaggio. Riattiva lo smart coach con Premium AI Coach oppure aggiungi token AI Boost.',
      'pt-BR':
          'Seus tokens de IA disponíveis acabaram. Nenhuma mensagem foi cobrada. Reative o coach inteligente com o Premium AI Coach ou adicione tokens do AI Boost.',
      'pt-PT':
          'Os seus tokens de IA disponíveis esgotaram-se. Nenhuma mensagem foi cobrada. Reative o treinador inteligente com o Premium AI Coach ou adicione tokens do AI Boost.',
      'ur':
          'آپ کے دستیاب AI ٹوکن ختم ہو گئے ہیں۔ کسی پیغام کا معاوضہ نہیں لیا گیا۔ Premium AI Coach کے ذریعے اسمارٹ کوچ دوبارہ فعال کریں یا AI Boost ٹوکن شامل کریں۔',
      'fa':
          'توکن‌های AI موجود شما تمام شده‌اند. هزینه‌ای برای پیام کسر نشد. مربی هوشمند را با Premium AI Coach دوباره فعال کنید یا توکن AI Boost بیفزایید.',
      'hi':
          'आपके उपलब्ध AI टोकन समाप्त हो गए हैं। संदेश के लिए कोई शुल्क नहीं लिया गया। Premium AI Coach से स्मार्ट कोच फिर सक्रिय करें या AI Boost टोकन जोड़ें।',
      'id':
          'Token AI yang tersedia telah habis. Tidak ada pesan yang ditagihkan. Aktifkan kembali pelatih pintar dengan Premium AI Coach atau tambahkan token AI Boost.',
      'ms':
          'Token AI anda yang tersedia telah habis. Tiada mesej dikenakan caj. Aktifkan semula jurulatih pintar dengan Premium AI Coach atau tambah token AI Boost.',
      'ja':
          '利用可能なAIトークンを使い切りました。メッセージの料金は発生していません。Premium AI Coachでスマートコーチを再開するか、AI Boostトークンを追加してください。',
      'ko':
          '사용 가능한 AI 토큰을 모두 사용했습니다. 메시지 비용은 청구되지 않았습니다. Premium AI Coach로 스마트 코치를 다시 활성화하거나 AI Boost 토큰을 추가하세요.',
      'zh-Hans':
          '可用的 AI 令牌已用尽。本条消息未扣费。请通过 Premium AI Coach 重新启用智能教练，或添加 AI Boost 令牌。',
      'zh-Hant':
          '可用的 AI 權杖已用盡。本則訊息未扣費。請透過 Premium AI Coach 重新啟用智慧教練，或新增 AI Boost 權杖。',
      'ru':
          'Доступные AI-токены закончились. Сообщение не было списано. Снова активируйте умного тренера через Premium AI Coach или добавьте токены AI Boost.',
      'bn':
          'আপনার উপলভ্য AI টোকেন শেষ হয়ে গেছে। বার্তাটির জন্য কোনো চার্জ নেওয়া হয়নি। Premium AI Coach দিয়ে স্মার্ট কোচ আবার চালু করুন অথবা AI Boost টোকেন যোগ করুন।',
      'vi':
          'Bạn đã hết token AI khả dụng. Tin nhắn này không bị tính phí. Hãy kích hoạt lại huấn luyện viên thông minh bằng Premium AI Coach hoặc thêm token AI Boost.',
      'th':
          'โทเคน AI ที่ใช้ได้หมดแล้ว ไม่มีการคิดค่าข้อความนี้ เปิดใช้โค้ชอัจฉริยะอีกครั้งด้วย Premium AI Coach หรือเพิ่มโทเคน AI Boost',
      'pl':
          'Dostępne tokeny AI zostały wyczerpane. Wiadomość nie została naliczona. Włącz ponownie inteligentnego trenera przez Premium AI Coach albo dodaj tokeny AI Boost.',
      'nl':
          'Je beschikbare AI-tokens zijn op. Er is geen bericht in rekening gebracht. Activeer de slimme coach opnieuw met Premium AI Coach of voeg AI Boost-tokens toe.',
      'uk':
          'Доступні AI-токени вичерпано. Повідомлення не було списано. Знову активуйте розумного тренера через Premium AI Coach або додайте токени AI Boost.',
    },
    'Your Premium AI Coach subscription is active, but its available AI tokens are exhausted. No message was charged. Add AI Boost tokens to continue now.': {
      'ar':
          'اشتراك Premium AI Coach لديك فعّال، لكن توكنات AI المتاحة نفدت. لم تُحتسب الرسالة. أضف توكنات AI Boost للمتابعة الآن.',
      'en':
          'Your Premium AI Coach subscription is active, but its available AI tokens are exhausted. No message was charged. Add AI Boost tokens to continue now.',
      'fr':
          'Votre abonnement Premium AI Coach est actif, mais ses jetons AI disponibles sont épuisés. Aucun message n’a été facturé. Ajoutez des jetons AI Boost pour continuer maintenant.',
      'es':
          'Tu suscripción a Premium AI Coach está activa, pero sus tokens de AI disponibles se han agotado. No se cobró ningún mensaje. Añade tokens de AI Boost para continuar ahora.',
      'tr':
          'Premium AI Coach aboneliğiniz etkin ancak kullanılabilir AI tokenları tükendi. Mesaj için ücret alınmadı. Şimdi devam etmek için AI Boost tokenları ekleyin.',
      'de':
          'Dein Premium AI Coach-Abo ist aktiv, aber die verfügbaren AI-Token sind aufgebraucht. Es wurde keine Nachricht berechnet. Füge AI-Boost-Token hinzu, um jetzt fortzufahren.',
      'it':
          'Il tuo abbonamento Premium AI Coach è attivo, ma i token AI disponibili sono esauriti. Non è stato addebitato alcun messaggio. Aggiungi token AI Boost per continuare ora.',
      'pt-BR':
          'Sua assinatura do Premium AI Coach está ativa, mas os tokens de IA disponíveis acabaram. Nenhuma mensagem foi cobrada. Adicione tokens do AI Boost para continuar agora.',
      'pt-PT':
          'A sua assinatura do Premium AI Coach está ativa, mas os tokens de IA disponíveis esgotaram-se. Nenhuma mensagem foi cobrada. Adicione tokens do AI Boost para continuar agora.',
      'ur':
          'آپ کی Premium AI Coach رکنیت فعال ہے، مگر دستیاب AI ٹوکن ختم ہو گئے ہیں۔ کسی پیغام کا معاوضہ نہیں لیا گیا۔ ابھی جاری رکھنے کے لیے AI Boost ٹوکن شامل کریں۔',
      'fa':
          'اشتراک Premium AI Coach شما فعال است، اما توکن‌های AI موجود تمام شده‌اند. هزینه‌ای برای پیام کسر نشد. برای ادامه، توکن AI Boost بیفزایید.',
      'hi':
          'आपकी Premium AI Coach सदस्यता सक्रिय है, लेकिन उपलब्ध AI टोकन समाप्त हो गए हैं। संदेश के लिए कोई शुल्क नहीं लिया गया। अभी जारी रखने के लिए AI Boost टोकन जोड़ें।',
      'id':
          'Langganan Premium AI Coach Anda aktif, tetapi token AI yang tersedia telah habis. Tidak ada pesan yang ditagihkan. Tambahkan token AI Boost untuk melanjutkan sekarang.',
      'ms':
          'Langganan Premium AI Coach anda aktif, tetapi token AI yang tersedia telah habis. Tiada mesej dikenakan caj. Tambah token AI Boost untuk teruskan sekarang.',
      'ja':
          'Premium AI Coachのサブスクリプションは有効ですが、利用可能なAIトークンを使い切りました。メッセージの料金は発生していません。今すぐ続けるにはAI Boostトークンを追加してください。',
      'ko':
          'Premium AI Coach 구독은 활성 상태지만 사용 가능한 AI 토큰을 모두 사용했습니다. 메시지 비용은 청구되지 않았습니다. 지금 계속하려면 AI Boost 토큰을 추가하세요.',
      'zh-Hans':
          '您的 Premium AI Coach 订阅处于有效状态，但可用的 AI 令牌已用尽。本条消息未扣费。请添加 AI Boost 令牌以立即继续。',
      'zh-Hant':
          '您的 Premium AI Coach 訂閱仍有效，但可用的 AI 權杖已用盡。本則訊息未扣費。請新增 AI Boost 權杖以立即繼續。',
      'ru':
          'Подписка Premium AI Coach активна, но доступные AI-токены закончились. Сообщение не было списано. Добавьте токены AI Boost, чтобы продолжить сейчас.',
      'bn':
          'আপনার Premium AI Coach সাবস্ক্রিপশন সক্রিয়, কিন্তু উপলভ্য AI টোকেন শেষ হয়ে গেছে। বার্তাটির জন্য কোনো চার্জ নেওয়া হয়নি। এখন চালিয়ে যেতে AI Boost টোকেন যোগ করুন।',
      'vi':
          'Gói Premium AI Coach của bạn đang hoạt động nhưng đã hết token AI khả dụng. Tin nhắn này không bị tính phí. Hãy thêm token AI Boost để tiếp tục ngay.',
      'th':
          'การสมัคร Premium AI Coach ของคุณยังใช้งานอยู่ แต่โทเคน AI ที่ใช้ได้หมดแล้ว ไม่มีการคิดค่าข้อความนี้ เพิ่มโทเคน AI Boost เพื่อใช้งานต่อทันที',
      'pl':
          'Subskrypcja Premium AI Coach jest aktywna, ale dostępne tokeny AI zostały wyczerpane. Wiadomość nie została naliczona. Dodaj tokeny AI Boost, aby kontynuować teraz.',
      'nl':
          'Je Premium AI Coach-abonnement is actief, maar de beschikbare AI-tokens zijn op. Er is geen bericht in rekening gebracht. Voeg AI Boost-tokens toe om nu door te gaan.',
      'uk':
          'Підписка Premium AI Coach активна, але доступні AI-токени вичерпано. Повідомлення не було списано. Додайте токени AI Boost, щоб продовжити зараз.',
    },
    'A gift from BIL 🎁 Your AI Coach usage has been fully reset. You can use your allowance again until the end of your current cycle.': {
      'ar':
          'هدية من BIL 🎁 تمت إعادة ضبط استخدام AI Coach بالكامل، ويمكنك الاستفادة من حصتك مجددًا حتى نهاية دورتك الحالية.',
      'en':
          'A gift from BIL 🎁 Your AI Coach usage has been fully reset. You can use your allowance again until the end of your current cycle.',
      'fr':
          'Un cadeau de BIL 🎁 L’utilisation d’AI Coach a été entièrement réinitialisée. Profitez de nouveau de votre quota jusqu’à la fin de votre cycle actuel.',
      'es':
          'Un regalo de BIL 🎁 El uso de AI Coach se restableció por completo. Puedes volver a usar tu cuota hasta el final de tu ciclo actual.',
      'tr':
          'BIL’den bir hediye 🎁 AI Coach kullanımınız tamamen sıfırlandı. Mevcut döneminiz bitene kadar kotanızı yeniden kullanabilirsiniz.',
      'de':
          'Ein Geschenk von BIL 🎁 Deine AI-Coach-Nutzung wurde vollständig zurückgesetzt. Nutze dein Kontingent bis zum Ende deines aktuellen Zyklus erneut.',
      'it':
          'Un regalo da BIL 🎁 L’utilizzo di AI Coach è stato azzerato. Puoi usare di nuovo la tua quota fino alla fine del ciclo attuale.',
      'pt-BR':
          'Um presente da BIL 🎁 O uso do AI Coach foi totalmente zerado. Você pode usar sua cota novamente até o fim do ciclo atual.',
      'pt-PT':
          'Um presente da BIL 🎁 A utilização do AI Coach foi totalmente reposta. Pode voltar a usar a sua quota até ao fim do ciclo atual.',
      'ur':
          'BIL کی طرف سے تحفہ 🎁 AI Coach کا استعمال مکمل طور پر ری سیٹ ہو گیا ہے۔ موجودہ دور کے اختتام تک اپنا کوٹہ دوبارہ استعمال کریں۔',
      'fa':
          'هدیه‌ای از BIL 🎁 میزان استفاده از AI Coach کاملاً بازنشانی شد. تا پایان دوره فعلی دوباره از سهمیه خود استفاده کنید.',
      'hi':
          'BIL की ओर से उपहार 🎁 AI Coach का उपयोग पूरी तरह रीसेट हो गया है। मौजूदा अवधि के अंत तक अपना कोटा फिर से इस्तेमाल करें।',
      'id':
          'Hadiah dari BIL 🎁 Penggunaan AI Coach telah direset sepenuhnya. Gunakan kembali kuota Anda hingga siklus saat ini berakhir.',
      'ms':
          'Hadiah daripada BIL 🎁 Penggunaan AI Coach telah ditetapkan semula sepenuhnya. Gunakan semula kuota anda hingga kitaran semasa berakhir.',
      'ja':
          'BILからのプレゼントです🎁 AI Coachの利用回数を完全にリセットしました。現在のサイクル終了まで、割り当てを再び利用できます。',
      'ko':
          'BIL의 선물입니다 🎁 AI Coach 사용량이 완전히 초기화되었습니다. 현재 주기가 끝날 때까지 할당량을 다시 이용하세요.',
      'zh-Hans': '来自 BIL 的礼物 🎁 AI Coach 使用量已全部重置。你可以在当前周期结束前再次使用配额。',
      'zh-Hant': '來自 BIL 的禮物 🎁 AI Coach 使用量已全部重設。你可以在目前週期結束前再次使用配額。',
      'ru':
          'Подарок от BIL 🎁 Использование AI Coach полностью сброшено. Снова используйте свою квоту до конца текущего цикла.',
      'bn':
          'BIL-এর পক্ষ থেকে উপহার 🎁 AI Coach-এর ব্যবহার পুরোপুরি রিসেট হয়েছে। বর্তমান চক্র শেষ হওয়া পর্যন্ত আবার আপনার কোটা ব্যবহার করুন।',
      'vi':
          'Quà tặng từ BIL 🎁 Mức sử dụng AI Coach đã được đặt lại hoàn toàn. Bạn có thể dùng lại hạn mức đến hết chu kỳ hiện tại.',
      'th':
          'ของขวัญจาก BIL 🎁 รีเซ็ตการใช้งาน AI Coach ทั้งหมดแล้ว คุณใช้โควตาได้อีกครั้งจนกว่ารอบปัจจุบันจะสิ้นสุด',
      'pl':
          'Prezent od BIL 🎁 Użycie AI Coach zostało całkowicie wyzerowane. Możesz ponownie korzystać z limitu do końca bieżącego cyklu.',
      'nl':
          'Een cadeau van BIL 🎁 Je AI Coach-gebruik is volledig gereset. Je kunt je tegoed opnieuw gebruiken tot het einde van je huidige cyclus.',
      'uk':
          'Подарунок від BIL 🎁 Використання AI Coach повністю скинуто. Знову користуйтеся своєю квотою до кінця поточного циклу.',
    },
    'Open AI Coach': {
      'ar': 'افتح AI Coach',
      'en': 'Open AI Coach',
      'fr': 'Ouvrir AI Coach',
      'es': 'Abrir AI Coach',
      'tr': 'AI Coach’u aç',
      'de': 'AI Coach öffnen',
      'it': 'Apri AI Coach',
      'pt-BR': 'Abrir AI Coach',
      'pt-PT': 'Abrir AI Coach',
      'ur': 'AI Coach کھولیں',
      'fa': 'باز کردن AI Coach',
      'hi': 'AI Coach खोलें',
      'id': 'Buka AI Coach',
      'ms': 'Buka AI Coach',
      'ja': 'AI Coachを開く',
      'ko': 'AI Coach 열기',
      'zh-Hans': '打开 AI Coach',
      'zh-Hant': '開啟 AI Coach',
      'ru': 'Открыть AI Coach',
      'bn': 'AI Coach খুলুন',
      'vi': 'Mở AI Coach',
      'th': 'เปิด AI Coach',
      'pl': 'Otwórz AI Coach',
      'nl': 'AI Coach openen',
      'uk': 'Відкрити AI Coach',
    },
    'Get AI Boost': {
      'ar': 'احصل على AI Boost',
      'en': 'Get AI Boost',
      'fr': 'Obtenir AI Boost',
      'es': 'Obtener AI Boost',
      'tr': 'AI Boost al',
      'de': 'AI Boost holen',
      'it': 'Ottieni AI Boost',
      'pt-BR': 'Obter AI Boost',
      'pt-PT': 'Obter AI Boost',
      'ur': 'AI Boost حاصل کریں',
      'fa': 'دریافت AI Boost',
      'hi': 'AI Boost प्राप्त करें',
      'id': 'Dapatkan AI Boost',
      'ms': 'Dapatkan AI Boost',
      'ja': 'AI Boostを入手',
      'ko': 'AI Boost 받기',
      'zh-Hans': '获取 AI Boost',
      'zh-Hant': '取得 AI Boost',
      'ru': 'Получить AI Boost',
      'bn': 'AI Boost নিন',
      'vi': 'Nhận AI Boost',
      'th': 'รับ AI Boost',
      'pl': 'Uzyskaj AI Boost',
      'nl': 'AI Boost nemen',
      'uk': 'Отримати AI Boost',
    },
    'Current period': {
      'ar': 'الفترة الحالية',
      'en': 'Current period',
      'fr': 'Période actuelle',
      'es': 'Periodo actual',
      'tr': 'Mevcut dönem',
      'de': 'Aktueller Zeitraum',
      'it': 'Periodo attuale',
      'pt-BR': 'Período atual',
      'pt-PT': 'Período atual',
      'ur': 'موجودہ مدت',
      'fa': 'دوره فعلی',
      'hi': 'वर्तमान अवधि',
      'id': 'Periode saat ini',
      'ms': 'Tempoh semasa',
      'ja': '現在の期間',
      'ko': '현재 기간',
      'zh-Hans': '当前周期',
      'zh-Hant': '目前週期',
      'ru': 'Текущий период',
      'bn': 'বর্তমান সময়কাল',
      'vi': 'Kỳ hiện tại',
      'th': 'รอบปัจจุบัน',
      'pl': 'Bieżący okres',
      'nl': 'Huidige periode',
      'uk': 'Поточний період',
    },
    'Use at least two characters or leave it blank.': {
      'ar': 'استخدم حرفين على الأقل أو اتركه فارغًا.',
      'en': 'Use at least two characters or leave it blank.',
      'fr': 'Saisissez au moins deux caractères ou laissez le champ vide.',
      'es': 'Usa al menos dos caracteres o déjalo en blanco.',
      'tr': 'En az iki karakter kullanın veya boş bırakın.',
      'de': 'Mindestens zwei Zeichen eingeben oder leer lassen.',
      'it': 'Usa almeno due caratteri oppure lascia vuoto.',
      'pt-BR': 'Use pelo menos dois caracteres ou deixe em branco.',
      'pt-PT': 'Utilize pelo menos dois caracteres ou deixe em branco.',
      'ur': 'کم از کم دو حروف لکھیں یا اسے خالی چھوڑ دیں۔',
      'fa': 'دست‌کم دو نویسه وارد کنید یا آن را خالی بگذارید.',
      'hi': 'कम से कम दो अक्षर लिखें या इसे खाली छोड़ दें।',
      'id': 'Gunakan setidaknya dua karakter atau biarkan kosong.',
      'ms': 'Gunakan sekurang-kurangnya dua aksara atau biarkan kosong.',
      'ja': '2文字以上入力するか、空欄のままにしてください。',
      'ko': '두 글자 이상 입력하거나 비워 두세요.',
      'zh-Hans': '至少输入两个字符，或留空。',
      'zh-Hant': '請至少輸入兩個字元，或留白。',
      'ru': 'Введите не менее двух символов или оставьте поле пустым.',
      'bn': 'অন্তত দুটি অক্ষর লিখুন অথবা ফাঁকা রাখুন।',
      'vi': 'Nhập ít nhất hai ký tự hoặc để trống.',
      'th': 'ใช้อย่างน้อยสองอักขระหรือเว้นว่างไว้',
      'pl': 'Wpisz co najmniej dwa znaki albo pozostaw puste.',
      'nl': 'Gebruik minstens twee tekens of laat het leeg.',
      'uk': 'Введіть щонайменше два символи або залиште поле порожнім.',
    },
    'The account’s current AI Coach usage was reset safely and one gift notice was sent.': {
      'ar':
          'تمّت إعادة ضبط استخدام AI Coach الحالي للحساب بأمان، وتم إرسال إشعار هدية واحد.',
      'en':
          'The account’s current AI Coach usage was reset safely and one gift notice was sent.',
      'fr':
          'L’utilisation actuelle d’AI Coach du compte a été réinitialisée en toute sécurité et une notification de cadeau a été envoyée.',
      'es':
          'El uso actual de AI Coach de la cuenta se restableció de forma segura y se envió una notificación de regalo.',
      'tr':
          'Hesabın mevcut AI Coach kullanımı güvenle sıfırlandı ve bir hediye bildirimi gönderildi.',
      'de':
          'Die aktuelle AI-Coach-Nutzung des Kontos wurde sicher zurückgesetzt und eine Geschenkbenachrichtigung gesendet.',
      'it':
          'L’utilizzo attuale di AI Coach dell’account è stato reimpostato in modo sicuro ed è stata inviata una notifica regalo.',
      'pt-BR':
          'O uso atual do AI Coach da conta foi redefinido com segurança e uma notificação de presente foi enviada.',
      'pt-PT':
          'A utilização atual do AI Coach da conta foi reposta em segurança e foi enviada uma notificação de oferta.',
      'ur':
          'اکاؤنٹ کا موجودہ AI Coach استعمال محفوظ طریقے سے ری سیٹ کر دیا گیا اور ایک تحفے کا اطلاع نامہ بھیج دیا گیا۔',
      'fa':
          'میزان استفاده فعلی حساب از AI Coach با موفقیت و ایمنی بازنشانی شد و یک اعلان هدیه ارسال شد.',
      'hi':
          'खाते का मौजूदा AI Coach उपयोग सुरक्षित रूप से रीसेट कर दिया गया और एक उपहार सूचना भेजी गई।',
      'id':
          'Penggunaan AI Coach akun saat ini telah direset dengan aman dan satu notifikasi hadiah dikirim.',
      'ms':
          'Penggunaan AI Coach semasa akaun telah ditetapkan semula dengan selamat dan satu pemberitahuan hadiah dihantar.',
      'ja': 'アカウントの現在のAI Coach利用状況を安全にリセットし、ギフト通知を1件送信しました。',
      'ko': '계정의 현재 AI Coach 사용량이 안전하게 초기화되었으며 선물 알림 한 건이 전송되었습니다.',
      'zh-Hans': '已安全重置该账户当前的 AI Coach 使用量，并发送了一条礼物通知。',
      'zh-Hant': '已安全重設該帳號目前的 AI Coach 使用量，並傳送了一則禮物通知。',
      'ru':
          'Текущее использование AI Coach в аккаунте безопасно сброшено, и отправлено одно уведомление о подарке.',
      'bn':
          'অ্যাকাউন্টের বর্তমান AI Coach ব্যবহার নিরাপদে রিসেট করা হয়েছে এবং একটি উপহারের বিজ্ঞপ্তি পাঠানো হয়েছে।',
      'vi':
          'Mức sử dụng AI Coach hiện tại của tài khoản đã được đặt lại an toàn và một thông báo quà tặng đã được gửi.',
      'th':
          'รีเซ็ตการใช้งาน AI Coach ปัจจุบันของบัญชีอย่างปลอดภัยแล้ว และส่งการแจ้งเตือนของขวัญหนึ่งรายการ',
      'pl':
          'Bieżące wykorzystanie AI Coach na koncie zostało bezpiecznie wyzerowane i wysłano jedno powiadomienie o prezencie.',
      'nl':
          'Het huidige AI Coach-gebruik van het account is veilig gereset en er is één cadeaumelding verzonden.',
      'uk':
          'Поточне використання AI Coach в обліковому записі безпечно скинуто, і надіслано одне сповіщення про подарунок.',
    },
    'The request could not be completed. No partial change was kept. Try again.': {
      'ar': 'تعذّر إكمال الطلب. لم يُحفظ أي تغيير جزئي. حاول مرة أخرى.',
      'en':
          'The request could not be completed. No partial change was kept. Try again.',
      'fr':
          'La demande n’a pas pu être effectuée. Aucune modification partielle n’a été conservée. Réessayez.',
      'es':
          'No se pudo completar la solicitud. No se conservó ningún cambio parcial. Inténtalo de nuevo.',
      'tr':
          'İstek tamamlanamadı. Kısmi bir değişiklik kaydedilmedi. Yeniden deneyin.',
      'de':
          'Die Anfrage konnte nicht abgeschlossen werden. Es wurde keine Teiländerung gespeichert. Versuche es erneut.',
      'it':
          'Non è stato possibile completare la richiesta. Nessuna modifica parziale è stata salvata. Riprova.',
      'pt-BR':
          'Não foi possível concluir a solicitação. Nenhuma alteração parcial foi mantida. Tente novamente.',
      'pt-PT':
          'Não foi possível concluir o pedido. Nenhuma alteração parcial foi mantida. Tente novamente.',
      'ur':
          'درخواست مکمل نہیں ہو سکی۔ کوئی جزوی تبدیلی محفوظ نہیں کی گئی۔ دوبارہ کوشش کریں۔',
      'fa': 'درخواست تکمیل نشد. هیچ تغییر ناقصی ذخیره نشد. دوباره تلاش کنید.',
      'hi':
          'अनुरोध पूरा नहीं हो सका। कोई आंशिक बदलाव सहेजा नहीं गया। फिर से कोशिश करें।',
      'id':
          'Permintaan tidak dapat diselesaikan. Tidak ada perubahan sebagian yang disimpan. Coba lagi.',
      'ms':
          'Permintaan tidak dapat diselesaikan. Tiada perubahan separa disimpan. Cuba lagi.',
      'ja': 'リクエストを完了できませんでした。途中の変更は保存されていません。もう一度お試しください。',
      'ko': '요청을 완료하지 못했습니다. 일부 변경 사항도 저장되지 않았습니다. 다시 시도하세요.',
      'zh-Hans': '无法完成请求。未保留任何部分更改。请重试。',
      'zh-Hant': '無法完成要求。未保留任何部分變更。請再試一次。',
      'ru':
          'Не удалось выполнить запрос. Частичные изменения не сохранены. Повторите попытку.',
      'bn':
          'অনুরোধটি সম্পন্ন করা যায়নি। কোনো আংশিক পরিবর্তন রাখা হয়নি। আবার চেষ্টা করুন।',
      'vi':
          'Không thể hoàn tất yêu cầu. Không có thay đổi dở dang nào được lưu. Hãy thử lại.',
      'th':
          'ไม่สามารถดำเนินการตามคำขอได้ ไม่มีการบันทึกการเปลี่ยนแปลงบางส่วน โปรดลองอีกครั้ง',
      'pl':
          'Nie udało się zrealizować żądania. Nie zachowano żadnej częściowej zmiany. Spróbuj ponownie.',
      'nl':
          'Het verzoek kon niet worden voltooid. Er is geen gedeeltelijke wijziging bewaard. Probeer opnieuw.',
      'uk':
          'Не вдалося виконати запит. Жодних часткових змін не збережено. Спробуйте ще раз.',
    },
  };

  static String? resolve(String english, String localeTag) {
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final tag in supported) {
      if (tag.toLowerCase() == normalized) return values[english]?[tag];
    }
    final language = normalized.split('-').first;
    final matches = supported
        .where(
          (tag) =>
              tag.toLowerCase() == language ||
              tag.toLowerCase().startsWith('$language-'),
        )
        .toList(growable: false);
    if (matches.length != 1) return null;
    final translations = values[english];
    return translations == null ? null : translations[matches.single];
  }

  static bool get balanced => values.values.every(
    (translations) =>
        translations.keys.toSet().containsAll(supported) &&
        supported.containsAll(translations.keys) &&
        translations.values.every((value) => value.trim().isNotEmpty),
  );
}
