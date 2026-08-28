abstract final class CheckInRuntimeCopy {
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
    'Enter weight': {
      'ar': 'أدخل الوزن',
      'en': 'Enter weight',
      'fr': 'Saisir le poids',
      'es': 'Introducir peso',
      'tr': 'Kilo gir',
      'de': 'Gewicht eingeben',
      'it': 'Inserisci il peso',
      'pt-BR': 'Inserir peso',
      'pt-PT': 'Introduzir peso',
      'ur': 'وزن درج کریں',
      'fa': 'وزن را وارد کنید',
      'hi': 'वज़न दर्ज करें',
      'id': 'Masukkan berat badan',
      'ms': 'Masukkan berat badan',
      'ja': '体重を入力',
      'ko': '체중 입력',
      'zh-Hans': '输入体重',
      'zh-Hant': '輸入體重',
      'ru': 'Введите вес',
      'bn': 'ওজন লিখুন',
      'vi': 'Nhập cân nặng',
      'th': 'ป้อนน้ำหนัก',
      'pl': 'Wpisz wagę',
      'nl': 'Voer gewicht in',
      'uk': 'Введіть вагу',
    },
    'Apply': {
      'ar': 'تطبيق',
      'en': 'Apply',
      'fr': 'Appliquer',
      'es': 'Aplicar',
      'tr': 'Uygula',
      'de': 'Übernehmen',
      'it': 'Applica',
      'pt-BR': 'Aplicar',
      'pt-PT': 'Aplicar',
      'ur': 'لاگو کریں',
      'fa': 'اعمال',
      'hi': 'लागू करें',
      'id': 'Terapkan',
      'ms': 'Terapkan',
      'ja': '適用',
      'ko': '적용',
      'zh-Hans': '应用',
      'zh-Hant': '套用',
      'ru': 'Применить',
      'bn': 'প্রয়োগ করুন',
      'vi': 'Áp dụng',
      'th': 'นำไปใช้',
      'pl': 'Zastosuj',
      'nl': 'Toepassen',
      'uk': 'Застосувати',
    },
    'Enter a valid weight.': {
      'ar': 'أدخل وزنًا صالحًا.',
      'en': 'Enter a valid weight.',
      'fr': 'Saisissez un poids valide.',
      'es': 'Introduce un peso válido.',
      'tr': 'Geçerli bir kilo girin.',
      'de': 'Gib ein gültiges Gewicht ein.',
      'it': 'Inserisci un peso valido.',
      'pt-BR': 'Insira um peso válido.',
      'pt-PT': 'Introduza um peso válido.',
      'ur': 'درست وزن درج کریں۔',
      'fa': 'یک وزن معتبر وارد کنید.',
      'hi': 'मान्य वज़न दर्ज करें।',
      'id': 'Masukkan berat badan yang valid.',
      'ms': 'Masukkan berat badan yang sah.',
      'ja': '有効な体重を入力してください。',
      'ko': '올바른 체중을 입력하세요.',
      'zh-Hans': '请输入有效体重。',
      'zh-Hant': '請輸入有效體重。',
      'ru': 'Введите допустимый вес.',
      'bn': 'সঠিক ওজন লিখুন।',
      'vi': 'Nhập cân nặng hợp lệ.',
      'th': 'ป้อนน้ำหนักที่ถูกต้อง',
      'pl': 'Wpisz prawidłową wagę.',
      'nl': 'Voer een geldig gewicht in.',
      'uk': 'Введіть коректну вагу.',
    },
    'The check-in could not be changed on this device. Try again.': {
      'ar': 'تعذر تغيير تسجيل اليوم على هذا الجهاز. حاول مرة أخرى.',
      'en': 'The check-in could not be changed on this device. Try again.',
      'fr': 'Le bilan n’a pas pu être modifié sur cet appareil. Réessayez.',
      'es':
          'No se pudo cambiar el registro en este dispositivo. Inténtalo de nuevo.',
      'tr': 'Kontrol bu cihazda değiştirilemedi. Tekrar deneyin.',
      'de':
          'Der Check-in konnte auf diesem Gerät nicht geändert werden. Versuche es erneut.',
      'it':
          'Impossibile modificare il check-in su questo dispositivo. Riprova.',
      'pt-BR':
          'Não foi possível alterar o check-in neste dispositivo. Tente novamente.',
      'pt-PT':
          'Não foi possível alterar o registo neste dispositivo. Tente novamente.',
      'ur': 'اس ڈیوائس پر چیک اِن تبدیل نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
      'fa': 'تغییر ثبت روزانه در این دستگاه ممکن نشد. دوباره تلاش کنید.',
      'hi': 'इस डिवाइस पर चेक-इन बदला नहीं जा सका। फिर कोशिश करें।',
      'id': 'Check-in tidak dapat diubah di perangkat ini. Coba lagi.',
      'ms': 'Daftar masuk tidak dapat diubah pada peranti ini. Cuba lagi.',
      'ja': 'この端末ではチェックインを変更できませんでした。もう一度お試しください。',
      'ko': '이 기기에서 체크인을 변경할 수 없습니다. 다시 시도하세요.',
      'zh-Hans': '无法在此设备上更改签到。请重试。',
      'zh-Hant': '無法在此裝置上變更簽到。請再試一次。',
      'ru':
          'Не удалось изменить отметку на этом устройстве. Повторите попытку.',
      'bn': 'এই ডিভাইসে চেক-ইন পরিবর্তন করা যায়নি। আবার চেষ্টা করুন।',
      'vi': 'Không thể thay đổi lượt ghi nhận trên thiết bị này. Hãy thử lại.',
      'th': 'ไม่สามารถแก้ไขการเช็กอินบนอุปกรณ์นี้ได้ ลองอีกครั้ง',
      'pl': 'Nie udało się zmienić wpisu na tym urządzeniu. Spróbuj ponownie.',
      'nl':
          'De check-in kon niet worden gewijzigd op dit apparaat. Probeer opnieuw.',
      'uk': 'Не вдалося змінити запис на цьому пристрої. Спробуйте ще раз.',
    },
    'Weight data could not be loaded.': {
      'ar': 'تعذر تحميل بيانات الوزن.',
      'en': 'Weight data could not be loaded.',
      'fr': 'Impossible de charger les données de poids.',
      'es': 'No se pudieron cargar los datos de peso.',
      'tr': 'Kilo verileri yüklenemedi.',
      'de': 'Die Gewichtsdaten konnten nicht geladen werden.',
      'it': 'Impossibile caricare i dati del peso.',
      'pt-BR': 'Não foi possível carregar os dados de peso.',
      'pt-PT': 'Não foi possível carregar os dados de peso.',
      'ur': 'وزن کا ڈیٹا لوڈ نہیں ہو سکا۔',
      'fa': 'داده‌های وزن بارگیری نشد.',
      'hi': 'वज़न का डेटा लोड नहीं हो सका।',
      'id': 'Data berat badan tidak dapat dimuat.',
      'ms': 'Data berat badan tidak dapat dimuatkan.',
      'ja': '体重データを読み込めませんでした。',
      'ko': '체중 데이터를 불러올 수 없습니다.',
      'zh-Hans': '无法加载体重数据。',
      'zh-Hant': '無法載入體重資料。',
      'ru': 'Не удалось загрузить данные о весе.',
      'bn': 'ওজনের তথ্য লোড করা যায়নি।',
      'vi': 'Không thể tải dữ liệu cân nặng.',
      'th': 'ไม่สามารถโหลดข้อมูลน้ำหนักได้',
      'pl': 'Nie udało się wczytać danych wagi.',
      'nl': 'De gewichtsgegevens konden niet worden geladen.',
      'uk': 'Не вдалося завантажити дані про вагу.',
    },
    'Recommended targets restored from your latest weight and goal.': {
      'ar': 'تمت استعادة الأهداف الموصى بها من أحدث وزن وهدف لك.',
      'en': 'Recommended targets restored from your latest weight and goal.',
      'fr':
          'Les objectifs recommandés ont été restaurés selon votre dernier poids et votre objectif.',
      'es':
          'Se restauraron los objetivos recomendados según tu peso más reciente y tu meta.',
      'tr': 'Önerilen hedefler son kilonuza ve hedefinize göre geri yüklendi.',
      'de':
          'Die empfohlenen Ziele wurden anhand deines letzten Gewichts und Ziels wiederhergestellt.',
      'it':
          'Gli obiettivi consigliati sono stati ripristinati in base al peso e all’obiettivo più recenti.',
      'pt-BR':
          'As metas recomendadas foram restauradas com base no seu peso e objetivo mais recentes.',
      'pt-PT':
          'Os objetivos recomendados foram repostos com base no peso e objetivo mais recentes.',
      'ur': 'تجویز کردہ اہداف آپ کے تازہ ترین وزن اور ہدف سے بحال کر دیے گئے۔',
      'fa': 'هدف‌های پیشنهادی بر اساس آخرین وزن و هدف شما بازیابی شدند.',
      'hi':
          'आपके नवीनतम वज़न और लक्ष्य के आधार पर सुझाए गए लक्ष्य बहाल कर दिए गए।',
      'id':
          'Target yang disarankan dipulihkan dari berat dan sasaran terbaru Anda.',
      'ms':
          'Sasaran disyorkan dipulihkan daripada berat dan matlamat terkini anda.',
      'ja': '最新の体重と目標から推奨目標を復元しました。',
      'ko': '최근 체중과 목표를 기준으로 권장 목표를 복원했습니다.',
      'zh-Hans': '已根据你的最新体重和目标恢复推荐目标。',
      'zh-Hant': '已根據你的最新體重與目標恢復建議目標。',
      'ru': 'Рекомендуемые цели восстановлены по последнему весу и вашей цели.',
      'bn':
          'আপনার সর্বশেষ ওজন ও লক্ষ্য অনুযায়ী প্রস্তাবিত লক্ষ্য পুনরুদ্ধার করা হয়েছে।',
      'vi':
          'Đã khôi phục mục tiêu đề xuất theo cân nặng và mục tiêu mới nhất của bạn.',
      'th': 'กู้คืนเป้าหมายที่แนะนำจากน้ำหนักล่าสุดและเป้าหมายของคุณแล้ว',
      'pl': 'Przywrócono zalecane cele na podstawie ostatniej wagi i celu.',
      'nl':
          'Aanbevolen doelen zijn hersteld op basis van je laatste gewicht en doel.',
      'uk': 'Рекомендовані цілі відновлено за вашою останньою вагою та метою.',
    },
  };

  static String? resolve(String source, String localeTag) {
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final tag in supported) {
      if (tag.toLowerCase() == normalized) return values[source]?[tag];
    }
    final language = normalized.split('-').first;
    final matches = supported
        .where((tag) => tag.toLowerCase().split('-').first == language)
        .toList(growable: false);
    return matches.length == 1 ? (values[source]?[matches.single]) : null;
  }

  static bool get balanced => values.values.every(
    (copy) =>
        copy.keys.toSet().containsAll(supported) &&
        supported.containsAll(copy.keys) &&
        copy.values.every((value) => value.trim().isNotEmpty),
  );
}
