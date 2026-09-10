import 'bil_locale_rollout_manifest.dart';

/// Copy owned by the Coach review flows. Locale columns are checked against
/// the released 25-language manifest; never use a different language's column.
abstract final class CoachReviewRuntimeCopy {
  static const deleteSelection = 'Choose the conversation to delete';
  static const deleteSelectionTranslations = <String, String>{
    'en': 'Choose the conversation to delete',
    'ar': 'اختر المحادثة التي تريد حذفها',
    'fr': 'Choisissez la conversation à supprimer',
    'es': 'Elige la conversación que quieres eliminar',
    'tr': 'Silmek istediğiniz konuşmayı seçin',
    'de': 'Wähle die Unterhaltung aus, die du löschen möchtest',
    'it': 'Scegli la conversazione da eliminare',
    'pt-BR': 'Escolha a conversa que deseja excluir',
    'pt-PT': 'Escolha a conversa que pretende eliminar',
    'ur': 'وہ گفتگو منتخب کریں جسے حذف کرنا ہے',
    'fa': 'گفتگویی را که می‌خواهید حذف کنید انتخاب کنید',
    'hi': 'वह बातचीत चुनें जिसे मिटाना है',
    'id': 'Pilih percakapan yang ingin dihapus',
    'ms': 'Pilih perbualan yang ingin dipadamkan',
    'bn': 'যে কথোপকথনটি মুছতে চান সেটি বেছে নিন',
    'ru': 'Выберите разговор, который хотите удалить',
    'ja': '削除する会話を選んでください',
    'ko': '삭제할 대화를 선택하세요',
    'zh-Hans': '选择要删除的对话',
    'zh-Hant': '選擇要刪除的對話',
    'th': 'เลือกการสนทนาที่ต้องการลบ',
    'vi': 'Chọn cuộc trò chuyện muốn xóa',
    'pl': 'Wybierz rozmowę do usunięcia',
    'nl': 'Kies het gesprek dat je wilt verwijderen',
    'uk': 'Виберіть розмову, яку хочете видалити',
  };
  static const cameraRationale =
      "BIL opens the camera only for the food photo you selected and never at startup.";
  static const settingsRecovery =
      "This permission is off. Enable it in system settings to use this feature; typing remains available.";
  static const permissionTranslations = <String, List<String>>{
    "en": [
      "BIL opens the camera only for the food photo you selected and never at startup.",
      "This permission is off. Enable it in system settings to use this feature; typing remains available.",
    ],
    "ar": [
      "يفتح BIL الكاميرا فقط لصورة الطعام التي اخترتها وليس عند بدء التطبيق.",
      "هذا الإذن متوقف. فعّله في إعدادات النظام لاستخدام هذه الميزة؛ وتبقى الكتابة متاحة.",
    ],
    "fr": [
      "BIL ouvre la caméra uniquement pour la photo de repas que vous avez choisie, jamais au démarrage.",
      "Cette autorisation est désactivée. Activez-la dans les réglages système pour utiliser cette fonction ; la saisie au clavier reste disponible.",
    ],
    "es": [
      "BIL abre la cámara solo para la foto de comida que elegiste, nunca al iniciar la aplicación.",
      "Este permiso está desactivado. Actívalo en los ajustes del sistema para usar esta función; puedes seguir escribiendo.",
    ],
    "tr": [
      "BIL kamerayı yalnızca seçtiğiniz yemek fotoğrafı için açar, uygulama açılışında asla açmaz.",
      "Bu izin kapalı. Bu özelliği kullanmak için sistem ayarlarından açın; yazarak giriş kullanılabilir.",
    ],
    "de": [
      "BIL öffnet die Kamera nur für das von dir gewählte Essensfoto, niemals beim App-Start.",
      "Diese Berechtigung ist deaktiviert. Aktiviere sie in den Systemeinstellungen für diese Funktion; Texteingabe bleibt möglich.",
    ],
    "it": [
      "BIL apre la fotocamera solo per la foto del pasto che hai scelto, mai all’avvio.",
      "Questa autorizzazione è disattivata. Attivala nelle impostazioni di sistema per usare la funzione; puoi continuare a scrivere.",
    ],
    "pt-BR": [
      "O BIL abre a câmera apenas para a foto de refeição que você escolheu, nunca ao iniciar.",
      "Esta permissão está desativada. Ative-a nas configurações do sistema para usar este recurso; você pode continuar digitando.",
    ],
    "pt-PT": [
      "O BIL abre a câmara apenas para a fotografia de refeição que escolheu, nunca ao iniciar.",
      "Esta permissão está desativada. Ative-a nas definições do sistema para utilizar esta funcionalidade; pode continuar a escrever.",
    ],
    "ur": [
      "BIL کیمرا صرف آپ کی منتخب کردہ کھانے کی تصویر کے لیے کھولتا ہے، ایپ شروع ہوتے وقت کبھی نہیں۔",
      "یہ اجازت بند ہے۔ اس سہولت کے لیے سسٹم کی ترتیبات میں اسے فعال کریں؛ ٹائپ کرنا دستیاب رہے گا۔",
    ],
    "fa": [
      "BIL دوربین را فقط برای عکس غذایی که انتخاب کرده‌اید باز می‌کند، نه هنگام شروع برنامه.",
      "این مجوز غیرفعال است. برای استفاده از این قابلیت آن را در تنظیمات سیستم فعال کنید؛ تایپ کردن همچنان در دسترس است.",
    ],
    "hi": [
      "BIL कैमरा केवल आपके चुने गए भोजन की तस्वीर के लिए खोलता है, ऐप शुरू होने पर कभी नहीं।",
      "यह अनुमति बंद है। इस सुविधा के लिए इसे सिस्टम सेटिंग में चालू करें; टाइप करना उपलब्ध रहेगा।",
    ],
    "id": [
      "BIL membuka kamera hanya untuk foto makanan yang Anda pilih, tidak pernah saat aplikasi dimulai.",
      "Izin ini dinonaktifkan. Aktifkan di pengaturan sistem untuk menggunakan fitur ini; mengetik tetap tersedia.",
    ],
    "ms": [
      "BIL membuka kamera hanya untuk foto makanan yang anda pilih, bukan ketika aplikasi dimulakan.",
      "Kebenaran ini dimatikan. Aktifkannya dalam tetapan sistem untuk menggunakan ciri ini; menaip masih tersedia.",
    ],
    "ja": [
      "BILは選択した食事写真の撮影時にのみカメラを開き、アプリ起動時には開きません。",
      "この権限は無効です。この機能を使うにはシステム設定で有効にしてください。文字入力は引き続き利用できます。",
    ],
    "ko": [
      "BIL은 선택한 음식 사진을 촬영할 때만 카메라를 열며, 앱 시작 시에는 열지 않습니다.",
      "이 권한이 꺼져 있습니다. 이 기능을 사용하려면 시스템 설정에서 켜세요. 텍스트 입력은 계속 사용할 수 있습니다.",
    ],
    "zh-Hans": [
      "BIL仅在你选择拍摄餐食照片时打开相机，不会在应用启动时打开。",
      "此权限已关闭。请在系统设置中开启以使用此功能；你仍然可以打字。",
    ],
    "zh-Hant": [
      "BIL僅在你選擇拍攝餐點照片時開啟相機，不會在應用程式啟動時開啟。",
      "此權限已關閉。請在系統設定中開啟以使用此功能；你仍然可以打字。",
    ],
    "ru": [
      "BIL открывает камеру только для выбранной вами фотографии еды, но не при запуске приложения.",
      "Это разрешение отключено. Включите его в системных настройках для использования функции; ввод текста остаётся доступным.",
    ],
    "bn": [
      "BIL কেবল আপনার বেছে নেওয়া খাবারের ছবির জন্য ক্যামেরা খোলে, অ্যাপ চালুর সময় কখনো নয়।",
      "এই অনুমতি বন্ধ আছে। সুবিধাটি ব্যবহার করতে সিস্টেম সেটিংসে এটি চালু করুন; টাইপ করা চালু থাকবে।",
    ],
    "vi": [
      "BIL chỉ mở máy ảnh cho ảnh bữa ăn bạn đã chọn, không bao giờ mở khi khởi động ứng dụng.",
      "Quyền này đang tắt. Hãy bật trong cài đặt hệ thống để dùng tính năng này; bạn vẫn có thể nhập văn bản.",
    ],
    "th": [
      "BIL เปิดกล้องเฉพาะเมื่อคุณเลือกถ่ายภาพอาหาร ไม่เปิดเมื่อเริ่มแอป",
      "สิทธิ์นี้ปิดอยู่ เปิดในตั้งค่าระบบเพื่อใช้คุณสมบัตินี้ คุณยังสามารถพิมพ์ได้",
    ],
    "pl": [
      "BIL otwiera aparat tylko do wybranego zdjęcia posiłku, nigdy przy uruchamianiu aplikacji.",
      "To uprawnienie jest wyłączone. Włącz je w ustawieniach systemu, aby używać tej funkcji; wpisywanie tekstu pozostaje dostępne.",
    ],
    "nl": [
      "BIL opent de camera alleen voor de door jou gekozen maaltijdfoto, nooit bij het starten van de app.",
      "Deze toestemming staat uit. Schakel deze in via de systeeminstellingen voor deze functie; typen blijft beschikbaar.",
    ],
    "uk": [
      "BIL відкриває камеру лише для вибраної вами фотографії їжі, а не під час запуску застосунку.",
      "Цей дозвіл вимкнено. Увімкніть його в системних налаштуваннях для цієї функції; введення тексту залишається доступним.",
    ],
  };
  static const speechRationale =
      "BIL uses speech recognition only after you start voice input. Recognized text is sent after you pause.";
  static const deleteBody =
      "Delete this conversation and its entry from history? Other conversations will be kept.";
  static const deleteSubtitle =
      "Delete this conversation and its history entry";
  static const notice =
      "Review every suggestion and serving before adding it. Nutrition comes only from a verified food record.";
  static const languageFailure =
      "The image result was not in your app language. Nothing was added. Try again or use food search.";

  static const keys = <String>[
    "BIL uses speech recognition only after you start voice input. Recognized text is sent after you pause.",
    "Delete this conversation and its entry from history? Other conversations will be kept.",
    "Delete this conversation and its history entry",
    "Meal-image analysis is not configured for this build.",
    "Sign in before sending a meal image for secure analysis.",
    "AI Boost credit is required to analyze a meal photo.",
    "Choose a JPG, PNG, or WebP image up to 12 MB.",
    "Meal-image analysis is temporarily unavailable. Try later or use food search.",
    "Too many image requests. Wait a moment, then try again.",
    "No food could be identified reliably. Try another photo or add it manually.",
    "The image result could not be trusted, so no food was added.",
    "Review every suggestion and serving before adding it. Nutrition comes only from a verified food record.",
    "piece",
    "The image result was not in your app language. Nothing was added. Try again or use food search.",
  ];

  static const translations = <String, List<String>>{
    'en': keys,
    'ar': <String>[
      "يستخدم BIL التعرف على الكلام فقط بعد بدء الإدخال الصوتي. يُرسل النص المتعرف عليه بعد أن تتوقف عن الكلام.",
      "حذف هذه المحادثة وبطاقتها من السجل؟ ستبقى المحادثات الأخرى محفوظة.",
      "احذف هذه المحادثة وبطاقتها من السجل",
      "تحليل صور الوجبات غير مفعّل في هذا الإصدار.",
      "سجّل الدخول قبل إرسال صورة الوجبة للتحليل الآمن.",
      "يلزم رصيد AI Boost لتحليل صورة الوجبة.",
      "اختر صورة JPG أو PNG أو WebP بحجم لا يتجاوز 12 ميغابايت.",
      "تحليل صور الوجبات غير متاح مؤقتًا. حاول لاحقًا أو استخدم البحث عن الطعام.",
      "تم إرسال طلبات صور كثيرة. انتظر قليلًا ثم حاول مجددًا.",
      "تعذر التعرّف على طعام موثوق. جرّب صورة أخرى أو أضفه يدويًا.",
      "تعذر الوثوق بنتيجة الصورة، لذلك لم تتم إضافة أي طعام.",
      "راجع كل اقتراح وحصة قبل الإضافة. تأتي القيم الغذائية فقط من سجل طعام موثّق.",
      "قطعة",
      "لم تصل نتيجة الصورة بلغة تطبيقك. لم يُضف شيء. أعد المحاولة أو استخدم البحث عن الطعام.",
    ],
    'fr': <String>[
      "BIL utilise la reconnaissance vocale uniquement après le démarrage de la saisie vocale. Le texte reconnu est envoyé lorsque vous faites une pause.",
      "Supprimer cette conversation et son entrée dans l’historique ? Les autres conversations seront conservées.",
      "Supprimer cette conversation et son entrée dans l’historique",
      "L’analyse des photos de repas n’est pas configurée dans cette version.",
      "Connectez-vous avant d’envoyer une photo de repas pour une analyse sécurisée.",
      "Un crédit AI Boost est requis pour analyser une photo de repas.",
      "Choisissez une image JPG, PNG ou WebP de 12 Mo maximum.",
      "L’analyse des photos de repas est temporairement indisponible. Réessayez plus tard ou utilisez la recherche alimentaire.",
      "Trop de demandes d’image. Patientez puis réessayez.",
      "Aucun aliment n’a pu être identifié avec fiabilité. Essayez une autre photo ou ajoutez-le manuellement.",
      "Le résultat de l’image n’était pas fiable ; aucun aliment n’a été ajouté.",
      "Vérifiez chaque suggestion et portion avant l’ajout. Les valeurs nutritionnelles proviennent uniquement d’une fiche vérifiée.",
      "pièce",
      "Le résultat de l’image n’était pas dans la langue de votre application. Rien n’a été ajouté. Réessayez ou utilisez la recherche alimentaire.",
    ],
    'es': <String>[
      "BIL usa el reconocimiento de voz solo después de que inicies la entrada de voz. El texto reconocido se envía cuando haces una pausa.",
      "¿Eliminar esta conversación y su entrada del historial? Se conservarán las demás conversaciones.",
      "Eliminar esta conversación y su entrada del historial",
      "El análisis de imágenes de comidas no está configurado en esta versión.",
      "Inicia sesión antes de enviar una imagen de comida para un análisis seguro.",
      "Se requiere crédito de AI Boost para analizar una foto de comida.",
      "Elige una imagen JPG, PNG o WebP de hasta 12 MB.",
      "El análisis de imágenes no está disponible temporalmente. Inténtalo más tarde o usa la búsqueda.",
      "Hay demasiadas solicitudes de imágenes. Espera e inténtalo de nuevo.",
      "No se pudo identificar comida de forma fiable. Prueba otra foto o añádela manualmente.",
      "El resultado no era fiable, por lo que no se añadió ningún alimento.",
      "Revisa cada sugerencia y porción antes de añadirla. La nutrición procede únicamente de un registro verificado.",
      "pieza",
      "El resultado de la imagen no estaba en el idioma de tu aplicación. No se añadió nada. Inténtalo de nuevo o usa la búsqueda de alimentos.",
    ],
    'tr': <String>[
      "BIL, konuşma tanımayı yalnızca sesli girişi başlattığınızda kullanır. Tanınan metin, konuşmaya ara verdiğinizde gönderilir.",
      "Bu konuşma ve geçmişteki kaydı silinsin mi? Diğer konuşmalar korunacak.",
      "Bu konuşmayı ve geçmişteki kaydını sil",
      "Yemek görseli analizi bu sürüm için yapılandırılmamış.",
      "Güvenli analiz için yemek görselini göndermeden önce oturum açın.",
      "Bir yemek fotoğrafını analiz etmek için AI Boost kredisi gerekir.",
      "En fazla 12 MB boyutunda JPG, PNG veya WebP seçin.",
      "Yemek görseli analizi geçici olarak kullanılamıyor. Daha sonra deneyin veya yiyecek aramasını kullanın.",
      "Çok fazla görsel isteği gönderildi. Biraz bekleyip yeniden deneyin.",
      "Yiyecek güvenilir biçimde tanımlanamadı. Başka bir fotoğraf deneyin veya elle ekleyin.",
      "Görsel sonucuna güvenilemediği için hiçbir yiyecek eklenmedi.",
      "Eklemeden önce her öneriyi ve porsiyonu inceleyin. Besin değerleri yalnızca doğrulanmış bir kayıttan alınır.",
      "adet",
      "Görsel sonucu uygulamanızın dilinde değildi. Hiçbir şey eklenmedi. Yeniden deneyin veya yiyecek aramasını kullanın.",
    ],
    'de': <String>[
      "BIL nutzt die Spracherkennung erst, wenn du die Spracheingabe startest. Der erkannte Text wird nach einer Sprechpause gesendet.",
      "Diese Unterhaltung und ihren Verlaufseintrag löschen? Andere Unterhaltungen bleiben erhalten.",
      "Diese Unterhaltung und ihren Verlaufseintrag löschen",
      "Die Analyse von Essensfotos ist in dieser Version nicht eingerichtet.",
      "Melde dich an, bevor du ein Essensfoto zur sicheren Analyse sendest.",
      "Für die Analyse eines Essensfotos ist AI Boost-Guthaben erforderlich.",
      "Wähle ein JPG-, PNG- oder WebP-Bild mit höchstens 12 MB.",
      "Die Analyse von Essensfotos ist vorübergehend nicht verfügbar. Versuche es später oder nutze die Lebensmittelsuche.",
      "Zu viele Bildanfragen. Warte kurz und versuche es erneut.",
      "Es konnte kein Lebensmittel zuverlässig erkannt werden. Versuche ein anderes Foto oder füge es manuell hinzu.",
      "Das Bildergebnis war nicht verlässlich. Es wurde kein Lebensmittel hinzugefügt.",
      "Prüfe jeden Vorschlag und jede Portion vor dem Hinzufügen. Nährwerte stammen nur aus einem verifizierten Lebensmitteleintrag.",
      "Stück",
      "Das Bildergebnis war nicht in deiner App-Sprache. Nichts wurde hinzugefügt. Versuche es erneut oder nutze die Lebensmittelsuche.",
    ],
    'it': <String>[
      "BIL usa il riconoscimento vocale solo quando avvii l’input vocale. Il testo riconosciuto viene inviato dopo una pausa nel parlato.",
      "Eliminare questa conversazione e la sua voce nella cronologia? Le altre conversazioni verranno conservate.",
      "Elimina questa conversazione e la sua voce nella cronologia",
      "L’analisi delle foto dei pasti non è configurata in questa versione.",
      "Accedi prima di inviare una foto del pasto per un’analisi sicura.",
      "Per analizzare una foto del pasto serve credito AI Boost.",
      "Scegli un’immagine JPG, PNG o WebP fino a 12 MB.",
      "L’analisi delle foto dei pasti non è al momento disponibile. Riprova più tardi o usa la ricerca degli alimenti.",
      "Troppe richieste di immagini. Attendi un momento e riprova.",
      "Non è stato possibile identificare alimenti in modo affidabile. Prova un’altra foto o aggiungili manualmente.",
      "Il risultato dell’immagine non era affidabile, quindi non è stato aggiunto alcun alimento.",
      "Controlla ogni suggerimento e porzione prima di aggiungerli. I valori nutrizionali provengono solo da una scheda alimentare verificata.",
      "pezzo",
      "Il risultato dell’immagine non era nella lingua dell’app. Non è stato aggiunto nulla. Riprova o usa la ricerca degli alimenti.",
    ],
    'pt-BR': <String>[
      "O BIL usa o reconhecimento de fala apenas quando você inicia a entrada de voz. O texto reconhecido é enviado quando você faz uma pausa.",
      "Excluir esta conversa e sua entrada no histórico? As outras conversas serão mantidas.",
      "Excluir esta conversa e sua entrada no histórico",
      "A análise de fotos de refeições não está configurada nesta versão.",
      "Entre na sua conta antes de enviar uma foto de refeição para análise segura.",
      "É necessário crédito AI Boost para analisar uma foto de refeição.",
      "Escolha uma imagem JPG, PNG ou WebP de até 12 MB.",
      "A análise de fotos de refeições está temporariamente indisponível. Tente mais tarde ou use a busca de alimentos.",
      "Muitas solicitações de imagens. Aguarde um momento e tente novamente.",
      "Não foi possível identificar alimentos com segurança. Tente outra foto ou adicione manualmente.",
      "O resultado da imagem não era confiável, então nenhum alimento foi adicionado.",
      "Revise cada sugestão e porção antes de adicionar. Os valores nutricionais vêm apenas de um registro de alimento verificado.",
      "unidade",
      "O resultado da imagem não estava no idioma do aplicativo. Nada foi adicionado. Tente novamente ou use a busca de alimentos.",
    ],
    'pt-PT': <String>[
      "O BIL utiliza o reconhecimento de fala apenas quando inicia a introdução por voz. O texto reconhecido é enviado após uma pausa na fala.",
      "Eliminar esta conversa e a respetiva entrada no histórico? As outras conversas serão mantidas.",
      "Eliminar esta conversa e a respetiva entrada no histórico",
      "A análise de fotografias de refeições não está configurada nesta versão.",
      "Inicie sessão antes de enviar uma fotografia da refeição para análise segura.",
      "É necessário saldo AI Boost para analisar uma fotografia de refeição.",
      "Escolha uma imagem JPG, PNG ou WebP até 12 MB.",
      "A análise de fotografias de refeições está temporariamente indisponível. Tente mais tarde ou utilize a pesquisa de alimentos.",
      "Demasiados pedidos de imagens. Aguarde um momento e tente novamente.",
      "Não foi possível identificar alimentos com confiança. Tente outra fotografia ou adicione manualmente.",
      "O resultado da imagem não era fiável, pelo que nenhum alimento foi adicionado.",
      "Reveja cada sugestão e porção antes de adicionar. Os valores nutricionais provêm apenas de um registo alimentar verificado.",
      "unidade",
      "O resultado da imagem não estava no idioma da aplicação. Nada foi adicionado. Tente novamente ou utilize a pesquisa de alimentos.",
    ],
    'ur': <String>[
      "BIL صرف صوتی اندراج شروع کرنے کے بعد آواز کو متن میں بدلتا ہے۔ آپ کے رکنے پر پہچانا گیا متن بھیج دیا جاتا ہے۔",
      "یہ گفتگو اور تاریخ میں اس کا اندراج حذف کریں؟ دوسری گفتگوئیں محفوظ رہیں گی۔",
      "یہ گفتگو اور تاریخ میں اس کا اندراج حذف کریں",
      "اس ورژن میں کھانے کی تصاویر کا تجزیہ ترتیب نہیں دیا گیا۔",
      "محفوظ تجزیے کے لیے کھانے کی تصویر بھیجنے سے پہلے سائن ان کریں۔",
      "کھانے کی تصویر کے تجزیے کے لیے AI Boost کریڈٹ درکار ہے۔",
      "12 MB تک کی JPG، PNG یا WebP تصویر منتخب کریں۔",
      "کھانے کی تصاویر کا تجزیہ عارضی طور پر دستیاب نہیں۔ بعد میں کوشش کریں یا کھانا تلاش کریں۔",
      "تصاویر کی بہت زیادہ درخواستیں ہیں۔ کچھ دیر رک کر دوبارہ کوشش کریں۔",
      "کھانے کی قابل اعتماد شناخت نہیں ہو سکی۔ دوسری تصویر آزمائیں یا دستی طور پر شامل کریں۔",
      "تصویر کا نتیجہ قابل اعتماد نہیں تھا، اس لیے کوئی کھانا شامل نہیں کیا گیا۔",
      "شامل کرنے سے پہلے ہر تجویز اور مقدار کا جائزہ لیں۔ غذائی معلومات صرف تصدیق شدہ کھانے کے ریکارڈ سے آتی ہیں۔",
      "عدد",
      "تصویر کا نتیجہ آپ کی ایپ کی زبان میں نہیں تھا۔ کچھ شامل نہیں کیا گیا۔ دوبارہ کوشش کریں یا کھانا تلاش کریں۔",
    ],
    'fa': <String>[
      "BIL فقط پس از شروع ورودی صوتی از تشخیص گفتار استفاده می‌کند. متن تشخیص‌داده‌شده پس از مکث شما ارسال می‌شود.",
      "این گفتگو و ورودی آن در تاریخچه حذف شود؟ گفتگوهای دیگر حفظ می‌شوند.",
      "این گفتگو و ورودی آن در تاریخچه را حذف کنید",
      "تحلیل تصویر غذا در این نسخه پیکربندی نشده است.",
      "پیش از ارسال تصویر غذا برای تحلیل امن، وارد حساب شوید.",
      "برای تحلیل تصویر غذا به اعتبار AI Boost نیاز است.",
      "یک تصویر JPG، PNG یا WebP با حجم حداکثر ۱۲ مگابایت انتخاب کنید.",
      "تحلیل تصویر غذا موقتاً در دسترس نیست. بعداً تلاش کنید یا از جستجوی غذا استفاده کنید.",
      "درخواست‌های تصویر بیش از حد است. کمی صبر کنید و دوباره تلاش کنید.",
      "غذایی به‌طور قابل اعتماد شناسایی نشد. تصویر دیگری امتحان کنید یا دستی اضافه کنید.",
      "نتیجه تصویر قابل اعتماد نبود، بنابراین هیچ غذایی اضافه نشد.",
      "پیش از افزودن، هر پیشنهاد و مقدار را بررسی کنید. اطلاعات تغذیه فقط از رکورد غذایی تأییدشده گرفته می‌شود.",
      "عدد",
      "نتیجه تصویر به زبان برنامه شما نبود. چیزی اضافه نشد. دوباره تلاش کنید یا از جستجوی غذا استفاده کنید.",
    ],
    'hi': <String>[
      "BIL आवाज़ से इनपुट शुरू करने के बाद ही वाक् पहचान का उपयोग करता है। आपके रुकने पर पहचाना गया पाठ भेजा जाता है।",
      "क्या इस बातचीत और इतिहास में इसकी प्रविष्टि को मिटाएँ? बाकी बातचीत सुरक्षित रहेंगी।",
      "इस बातचीत और इतिहास में इसकी प्रविष्टि को मिटाएँ",
      "इस संस्करण में भोजन की तस्वीरों का विश्लेषण कॉन्फ़िगर नहीं है।",
      "सुरक्षित विश्लेषण के लिए भोजन की तस्वीर भेजने से पहले साइन इन करें।",
      "भोजन की तस्वीर का विश्लेषण करने के लिए AI Boost क्रेडिट चाहिए।",
      "12 MB तक की JPG, PNG या WebP तस्वीर चुनें।",
      "भोजन की तस्वीरों का विश्लेषण अभी उपलब्ध नहीं है। बाद में कोशिश करें या भोजन खोज का उपयोग करें।",
      "तस्वीरों के बहुत अधिक अनुरोध हैं। थोड़ा रुकें, फिर कोशिश करें।",
      "भोजन की विश्वसनीय पहचान नहीं हो सकी। दूसरी तस्वीर आज़माएँ या मैन्युअल रूप से जोड़ें।",
      "तस्वीर का परिणाम विश्वसनीय नहीं था, इसलिए कोई भोजन नहीं जोड़ा गया।",
      "जोड़ने से पहले हर सुझाव और मात्रा की जाँच करें। पोषण संबंधी जानकारी केवल सत्यापित भोजन रिकॉर्ड से आती है।",
      "नग",
      "तस्वीर का परिणाम आपकी ऐप की भाषा में नहीं था। कुछ नहीं जोड़ा गया। फिर कोशिश करें या भोजन खोज का उपयोग करें।",
    ],
    'id': <String>[
      "BIL menggunakan pengenalan ucapan hanya setelah Anda memulai input suara. Teks yang dikenali dikirim setelah Anda berhenti sejenak.",
      "Hapus percakapan ini dan entrinya dari riwayat? Percakapan lain akan tetap disimpan.",
      "Hapus percakapan ini dan entrinya dari riwayat",
      "Analisis foto makanan belum dikonfigurasi untuk versi ini.",
      "Masuk sebelum mengirim foto makanan untuk analisis yang aman.",
      "Kredit AI Boost diperlukan untuk menganalisis foto makanan.",
      "Pilih gambar JPG, PNG, atau WebP hingga 12 MB.",
      "Analisis foto makanan sementara tidak tersedia. Coba nanti atau gunakan pencarian makanan.",
      "Terlalu banyak permintaan gambar. Tunggu sebentar, lalu coba lagi.",
      "Makanan tidak dapat dikenali dengan andal. Coba foto lain atau tambahkan secara manual.",
      "Hasil gambar tidak dapat dipercaya, jadi tidak ada makanan yang ditambahkan.",
      "Tinjau setiap saran dan porsi sebelum menambahkannya. Nilai gizi hanya berasal dari catatan makanan terverifikasi.",
      "buah",
      "Hasil gambar tidak menggunakan bahasa aplikasi Anda. Tidak ada yang ditambahkan. Coba lagi atau gunakan pencarian makanan.",
    ],
    'ms': <String>[
      "BIL menggunakan pengecaman pertuturan hanya selepas anda memulakan input suara. Teks yang dikenal pasti dihantar selepas anda berhenti seketika.",
      "Padam perbualan ini dan entrinya daripada sejarah? Perbualan lain akan dikekalkan.",
      "Padam perbualan ini dan entrinya daripada sejarah",
      "Analisis foto makanan belum dikonfigurasikan untuk versi ini.",
      "Log masuk sebelum menghantar foto makanan untuk analisis yang selamat.",
      "Kredit AI Boost diperlukan untuk menganalisis foto makanan.",
      "Pilih imej JPG, PNG atau WebP sehingga 12 MB.",
      "Analisis foto makanan tidak tersedia buat sementara waktu. Cuba kemudian atau gunakan carian makanan.",
      "Terlalu banyak permintaan imej. Tunggu sebentar, kemudian cuba lagi.",
      "Makanan tidak dapat dikenal pasti dengan pasti. Cuba foto lain atau tambah secara manual.",
      "Hasil imej tidak boleh dipercayai, jadi tiada makanan ditambahkan.",
      "Semak setiap cadangan dan hidangan sebelum menambahkannya. Nilai pemakanan hanya diambil daripada rekod makanan yang disahkan.",
      "biji",
      "Hasil imej bukan dalam bahasa aplikasi anda. Tiada apa-apa ditambahkan. Cuba lagi atau gunakan carian makanan.",
    ],
    'ja': <String>[
      "BILは音声入力を開始した後にのみ音声認識を使用します。話すのを一時停止すると、認識されたテキストが送信されます。",
      "この会話と履歴の項目を削除しますか？他の会話は保持されます。",
      "この会話と履歴の項目を削除",
      "このバージョンでは食事写真の分析が設定されていません。",
      "安全な分析のため、食事写真を送信する前にログインしてください。",
      "食事写真の分析にはAI Boostクレジットが必要です。",
      "12 MB以下のJPG、PNG、WebP画像を選択してください。",
      "食事写真の分析は一時的に利用できません。後で試すか、食品検索を使用してください。",
      "画像リクエストが多すぎます。少し待ってから再試行してください。",
      "食品を確実に特定できませんでした。別の写真を試すか、手動で追加してください。",
      "画像の結果を信頼できなかったため、食品は追加されませんでした。",
      "追加する前に各候補と分量を確認してください。栄養情報は検証済みの食品記録のみを使用します。",
      "個",
      "画像の結果がアプリの言語と一致しませんでした。何も追加されていません。再試行するか、食品検索を使用してください。",
    ],
    'ko': <String>[
      "BIL은 음성 입력을 시작한 후에만 음성 인식을 사용합니다. 말을 잠시 멈추면 인식된 텍스트가 전송됩니다.",
      "이 대화와 기록의 항목을 삭제할까요? 다른 대화는 유지됩니다.",
      "이 대화와 기록의 항목 삭제",
      "이 버전에는 음식 사진 분석이 설정되지 않았습니다.",
      "안전한 분석을 위해 음식 사진을 보내기 전에 로그인하세요.",
      "음식 사진을 분석하려면 AI Boost 크레딧이 필요합니다.",
      "12 MB 이하의 JPG, PNG 또는 WebP 이미지를 선택하세요.",
      "음식 사진 분석을 일시적으로 사용할 수 없습니다. 나중에 다시 시도하거나 음식 검색을 사용하세요.",
      "이미지 요청이 너무 많습니다. 잠시 기다린 후 다시 시도하세요.",
      "음식을 신뢰할 수 있게 식별하지 못했습니다. 다른 사진을 사용하거나 직접 추가하세요.",
      "이미지 결과를 신뢰할 수 없어 음식이 추가되지 않았습니다.",
      "추가하기 전에 모든 제안과 분량을 확인하세요. 영양 정보는 검증된 음식 기록에서만 가져옵니다.",
      "개",
      "이미지 결과가 앱 언어와 다릅니다. 아무것도 추가되지 않았습니다. 다시 시도하거나 음식 검색을 사용하세요.",
    ],
    'zh-Hans': <String>[
      "BIL仅在你启动语音输入后使用语音识别。你暂停说话后，识别出的文字会被发送。",
      "删除此对话及其历史记录条目吗？其他对话将被保留。",
      "删除此对话及其历史记录条目",
      "此版本尚未配置餐食图片分析。",
      "请先登录，再发送餐食图片进行安全分析。",
      "分析餐食照片需要AI Boost额度。",
      "请选择不超过12 MB的JPG、PNG或WebP图片。",
      "餐食图片分析暂时不可用。请稍后重试或使用食物搜索。",
      "图片请求过多。请稍等后重试。",
      "无法可靠地识别食物。请尝试其他照片或手动添加。",
      "图片结果不可靠，因此未添加任何食物。",
      "添加前请核对每项建议及份量。营养信息仅来自已验证的食物记录。",
      "个",
      "图片结果不是你的应用语言。未添加任何内容。请重试或使用食物搜索。",
    ],
    'zh-Hant': <String>[
      "BIL僅在你啟動語音輸入後使用語音辨識。你暫停說話後，辨識出的文字會被傳送。",
      "刪除此對話及其歷史紀錄項目嗎？其他對話將被保留。",
      "刪除此對話及其歷史紀錄項目",
      "此版本尚未設定餐點圖片分析。",
      "請先登入，再傳送餐點圖片進行安全分析。",
      "分析餐點照片需要AI Boost額度。",
      "請選擇不超過12 MB的JPG、PNG或WebP圖片。",
      "餐點圖片分析暫時無法使用。請稍後重試或使用食物搜尋。",
      "圖片請求過多。請稍候再試。",
      "無法可靠地辨識食物。請嘗試其他照片或手動新增。",
      "圖片結果不可靠，因此未新增任何食物。",
      "新增前請核對每項建議及份量。營養資訊僅來自已驗證的食物紀錄。",
      "個",
      "圖片結果不是你的應用程式語言。未新增任何內容。請重試或使用食物搜尋。",
    ],
    'ru': <String>[
      "BIL использует распознавание речи только после запуска голосового ввода. Распознанный текст отправляется после паузы в речи.",
      "Удалить этот разговор и его запись из истории? Другие разговоры сохранятся.",
      "Удалить этот разговор и его запись из истории",
      "Анализ фотографий еды не настроен в этой версии.",
      "Войдите в аккаунт перед отправкой фотографии еды для безопасного анализа.",
      "Для анализа фотографии еды необходимы кредиты AI Boost.",
      "Выберите изображение JPG, PNG или WebP размером до 12 МБ.",
      "Анализ фотографий еды временно недоступен. Попробуйте позже или используйте поиск продуктов.",
      "Слишком много запросов изображений. Подождите немного и повторите попытку.",
      "Не удалось надёжно распознать еду. Попробуйте другое фото или добавьте вручную.",
      "Результат анализа изображения оказался ненадёжным, поэтому еда не была добавлена.",
      "Проверьте каждое предложение и порцию перед добавлением. Пищевая ценность берётся только из проверенной записи продукта.",
      "штука",
      "Результат анализа изображения не на языке приложения. Ничего не добавлено. Повторите попытку или используйте поиск продуктов.",
    ],
    'bn': <String>[
      "BIL কেবল ভয়েস ইনপুট শুরু করার পরই স্পিচ রিকগনিশন ব্যবহার করে। আপনি বিরতি দিলে শনাক্ত করা লেখা পাঠানো হয়।",
      "এই কথোপকথন এবং ইতিহাসে এর এন্ট্রি মুছবেন? অন্য কথোপকথনগুলো রাখা হবে।",
      "এই কথোপকথন এবং ইতিহাসে এর এন্ট্রি মুছুন",
      "এই সংস্করণে খাবারের ছবি বিশ্লেষণ কনফিগার করা নেই।",
      "নিরাপদ বিশ্লেষণের জন্য খাবারের ছবি পাঠানোর আগে সাইন ইন করুন।",
      "খাবারের ছবি বিশ্লেষণ করতে AI Boost ক্রেডিট প্রয়োজন।",
      "১২ MB পর্যন্ত JPG, PNG বা WebP ছবি বেছে নিন।",
      "খাবারের ছবি বিশ্লেষণ সাময়িকভাবে অনুপলব্ধ। পরে চেষ্টা করুন বা খাবার অনুসন্ধান ব্যবহার করুন।",
      "ছবির অনুরোধ অত্যধিক হয়েছে। একটু অপেক্ষা করে আবার চেষ্টা করুন।",
      "নির্ভরযোগ্যভাবে খাবার শনাক্ত করা যায়নি। অন্য ছবি চেষ্টা করুন বা নিজে যোগ করুন।",
      "ছবির ফলাফল নির্ভরযোগ্য ছিল না, তাই কোনো খাবার যোগ করা হয়নি।",
      "যোগ করার আগে প্রতিটি পরামর্শ ও পরিমাণ যাচাই করুন। পুষ্টির তথ্য শুধু যাচাইকৃত খাবারের রেকর্ড থেকে নেওয়া হয়।",
      "টি",
      "ছবির ফলাফল আপনার অ্যাপের ভাষায় ছিল না। কিছু যোগ করা হয়নি। আবার চেষ্টা করুন বা খাবার অনুসন্ধান ব্যবহার করুন।",
    ],
    'vi': <String>[
      "BIL chỉ dùng nhận dạng giọng nói sau khi bạn bắt đầu nhập bằng giọng nói. Văn bản nhận dạng được sẽ gửi sau khi bạn ngừng nói một lúc.",
      "Xóa cuộc trò chuyện này và mục tương ứng trong lịch sử? Các cuộc trò chuyện khác sẽ được giữ lại.",
      "Xóa cuộc trò chuyện này và mục tương ứng trong lịch sử",
      "Phiên bản này chưa được cấu hình phân tích ảnh bữa ăn.",
      "Đăng nhập trước khi gửi ảnh bữa ăn để phân tích an toàn.",
      "Cần có tín dụng AI Boost để phân tích ảnh bữa ăn.",
      "Chọn ảnh JPG, PNG hoặc WebP có dung lượng tối đa 12 MB.",
      "Phân tích ảnh bữa ăn tạm thời không khả dụng. Hãy thử lại sau hoặc dùng tìm kiếm thực phẩm.",
      "Quá nhiều yêu cầu ảnh. Hãy đợi một chút rồi thử lại.",
      "Không thể nhận diện thực phẩm một cách đáng tin cậy. Hãy thử ảnh khác hoặc thêm thủ công.",
      "Kết quả ảnh không đáng tin cậy nên không có thực phẩm nào được thêm.",
      "Kiểm tra từng gợi ý và khẩu phần trước khi thêm. Dinh dưỡng chỉ lấy từ bản ghi thực phẩm đã xác minh.",
      "cái",
      "Kết quả ảnh không đúng ngôn ngữ ứng dụng của bạn. Chưa thêm gì. Hãy thử lại hoặc dùng tìm kiếm thực phẩm.",
    ],
    'th': <String>[
      "BIL ใช้การรู้จำเสียงหลังจากคุณเริ่มป้อนข้อมูลด้วยเสียงเท่านั้น ข้อความที่รู้จำได้จะถูกส่งเมื่อคุณหยุดพูดชั่วครู่",
      "ลบการสนทนานี้และรายการในประวัติหรือไม่ การสนทนาอื่นจะยังคงอยู่",
      "ลบการสนทนานี้และรายการในประวัติ",
      "ยังไม่ได้ตั้งค่าการวิเคราะห์ภาพอาหารสำหรับเวอร์ชันนี้",
      "ลงชื่อเข้าใช้ก่อนส่งภาพอาหารเพื่อวิเคราะห์อย่างปลอดภัย",
      "ต้องมีเครดิต AI Boost เพื่อวิเคราะห์ภาพอาหาร",
      "เลือกภาพ JPG, PNG หรือ WebP ขนาดไม่เกิน 12 MB",
      "การวิเคราะห์ภาพอาหารไม่พร้อมใช้งานชั่วคราว ลองใหม่ภายหลังหรือใช้การค้นหาอาหาร",
      "มีคำขอรูปภาพมากเกินไป รอสักครู่แล้วลองอีกครั้ง",
      "ไม่สามารถระบุอาหารได้อย่างน่าเชื่อถือ ลองใช้ภาพอื่นหรือเพิ่มด้วยตนเอง",
      "ผลลัพธ์ของภาพไม่น่าเชื่อถือ จึงไม่มีการเพิ่มอาหาร",
      "ตรวจสอบข้อเสนอและปริมาณแต่ละรายการก่อนเพิ่ม ข้อมูลโภชนาการมาจากบันทึกอาหารที่ตรวจสอบแล้วเท่านั้น",
      "ชิ้น",
      "ผลลัพธ์ของภาพไม่ใช่ภาษาของแอปคุณ ยังไม่ได้เพิ่มอะไร ลองอีกครั้งหรือใช้การค้นหาอาหาร",
    ],
    'pl': <String>[
      "BIL używa rozpoznawania mowy dopiero po rozpoczęciu wprowadzania głosowego. Rozpoznany tekst jest wysyłany po przerwie w mówieniu.",
      "Usunąć tę rozmowę i jej wpis w historii? Pozostałe rozmowy zostaną zachowane.",
      "Usuń tę rozmowę i jej wpis w historii",
      "Analiza zdjęć posiłków nie jest skonfigurowana w tej wersji.",
      "Zaloguj się przed wysłaniem zdjęcia posiłku do bezpiecznej analizy.",
      "Do analizy zdjęcia posiłku potrzebne są środki AI Boost.",
      "Wybierz obraz JPG, PNG lub WebP o rozmiarze do 12 MB.",
      "Analiza zdjęć posiłków jest chwilowo niedostępna. Spróbuj później lub użyj wyszukiwania żywności.",
      "Zbyt wiele zapytań o obrazy. Poczekaj chwilę i spróbuj ponownie.",
      "Nie udało się wiarygodnie rozpoznać jedzenia. Spróbuj innego zdjęcia lub dodaj ręcznie.",
      "Wynik analizy obrazu był niewiarygodny, więc nie dodano jedzenia.",
      "Przed dodaniem sprawdź każdą propozycję i porcję. Wartości odżywcze pochodzą wyłącznie ze zweryfikowanego rekordu żywności.",
      "sztuka",
      "Wynik analizy obrazu nie był w języku aplikacji. Nic nie dodano. Spróbuj ponownie lub użyj wyszukiwania żywności.",
    ],
    'nl': <String>[
      "BIL gebruikt spraakherkenning alleen nadat je spraakinvoer start. De herkende tekst wordt verzonden zodra je even stopt met praten.",
      "Dit gesprek en de vermelding in de geschiedenis verwijderen? Andere gesprekken blijven bewaard.",
      "Dit gesprek en de vermelding in de geschiedenis verwijderen",
      "Analyse van maaltijdbeelden is niet ingesteld voor deze versie.",
      "Log in voordat je een maaltijdbeeld voor veilige analyse verstuurt.",
      "Voor analyse van een maaltijdfoto is AI Boost-tegoed nodig.",
      "Kies een JPG-, PNG- of WebP-afbeelding van maximaal 12 MB.",
      "Analyse van maaltijdbeelden is tijdelijk niet beschikbaar. Probeer het later of zoek naar voedingsmiddelen.",
      "Te veel afbeeldingsverzoeken. Wacht even en probeer het opnieuw.",
      "Er kon geen voedsel betrouwbaar worden herkend. Probeer een andere foto of voeg het handmatig toe.",
      "Het afbeeldingsresultaat was niet betrouwbaar, dus er is geen voedsel toegevoegd.",
      "Controleer elk voorstel en elke portie vóór het toevoegen. Voedingswaarden komen alleen uit een geverifieerd voedingsmiddelrecord.",
      "stuk",
      "Het afbeeldingsresultaat was niet in de taal van je app. Er is niets toegevoegd. Probeer het opnieuw of zoek naar voedingsmiddelen.",
    ],
    'uk': <String>[
      "BIL використовує розпізнавання мовлення лише після початку голосового введення. Розпізнаний текст надсилається після паузи в мовленні.",
      "Видалити цю розмову та її запис з історії? Інші розмови буде збережено.",
      "Видалити цю розмову та її запис з історії",
      "Аналіз фотографій їжі не налаштовано в цій версії.",
      "Увійдіть, перш ніж надсилати фотографію їжі для безпечного аналізу.",
      "Для аналізу фотографії їжі потрібні кредити AI Boost.",
      "Виберіть зображення JPG, PNG або WebP розміром до 12 МБ.",
      "Аналіз фотографій їжі тимчасово недоступний. Спробуйте пізніше або скористайтеся пошуком продуктів.",
      "Забагато запитів зображень. Зачекайте трохи та спробуйте знову.",
      "Не вдалося надійно розпізнати їжу. Спробуйте іншу фотографію або додайте вручну.",
      "Результат аналізу зображення був ненадійним, тому їжу не додано.",
      "Перевірте кожну пропозицію та порцію перед додаванням. Харчова цінність береться лише з перевіреного запису продукту.",
      "штука",
      "Результат аналізу зображення не відповідає мові застосунку. Нічого не додано. Спробуйте ще раз або скористайтеся пошуком продуктів.",
    ],
  };

  static String localeTag(String tag) {
    final normalized = tag.trim().replaceAll('_', '-').toLowerCase();
    for (final key in translations.keys) {
      if (key.toLowerCase() == normalized) return key;
    }
    final parts = normalized.split('-');
    if (parts.first == 'zh' && parts.length > 1) {
      if (parts.contains('hant') ||
          parts.contains('tw') ||
          parts.contains('hk')) {
        return 'zh-Hant';
      }
      if (parts.contains('hans') ||
          parts.contains('cn') ||
          parts.contains('sg')) {
        return 'zh-Hans';
      }
    }
    return translations.containsKey(parts.first) ? parts.first : 'en';
  }

  static String? resolve(String english, String locale) {
    if (english == deleteSelection) {
      return deleteSelectionTranslations[localeTag(locale)];
    }
    if (english == cameraRationale || english == settingsRecovery) {
      return permissionTranslations[localeTag(
        locale,
      )]![english == cameraRationale ? 0 : 1];
    }
    final index = keys.indexOf(english);
    if (index < 0) return null;
    return translations[localeTag(locale)]![index];
  }

  static bool get balanced {
    const supported = BilLocaleRolloutManifest.releaseTargets25;
    return translations.keys.toSet().containsAll(supported) &&
        deleteSelectionTranslations.keys.toSet().containsAll(supported) &&
        supported.containsAll(deleteSelectionTranslations.keys) &&
        deleteSelectionTranslations.values.every(
          (value) => value.trim().isNotEmpty,
        ) &&
        supported.containsAll(translations.keys) &&
        permissionTranslations.keys.toSet().containsAll(supported) &&
        supported.containsAll(permissionTranslations.keys) &&
        translations.values.every(
          (row) =>
              row.length == keys.length &&
              row.every((value) => value.trim().isNotEmpty),
        ) &&
        permissionTranslations.values.every(
          (row) =>
              row.length == 2 && row.every((value) => value.trim().isNotEmpty),
        );
  }
}
