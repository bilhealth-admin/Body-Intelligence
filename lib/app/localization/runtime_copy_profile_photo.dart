/// Reviewed 25-locale copy for shared photo and camera surfaces.
abstract final class ProfilePhotoRuntimeCopy {
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
    'Profile photo': {
      'ar': 'الصورة الشخصية',
      'en': 'Profile photo',
      'fr': 'Photo de profil',
      'es': 'Foto de perfil',
      'tr': 'Profil fotoğrafı',
      'de': 'Profilfoto',
      'it': 'Foto del profilo',
      'pt-BR': 'Foto do perfil',
      'pt-PT': 'Fotografia de perfil',
      'ur': 'پروفائل تصویر',
      'fa': 'تصویر نمایه',
      'hi': 'प्रोफ़ाइल फ़ोटो',
      'id': 'Foto profil',
      'ms': 'Foto profil',
      'ja': 'プロフィール写真',
      'ko': '프로필 사진',
      'zh-Hans': '个人资料照片',
      'zh-Hant': '個人資料相片',
      'ru': 'Фото профиля',
      'bn': 'প্রোফাইল ছবি',
      'vi': 'Ảnh hồ sơ',
      'th': 'รูปโปรไฟล์',
      'pl': 'Zdjęcie profilowe',
      'nl': 'Profielfoto',
      'uk': 'Фото профілю',
    },
    'Enable camera access in system settings to take a profile photo. You can still choose a photo with the system picker.': {
      'ar':
          'فعّل الوصول إلى الكاميرا من إعدادات النظام لالتقاط صورة للملف الشخصي. يمكنك أيضًا اختيار صورة باستخدام منتقي النظام.',
      'en':
          'Enable camera access in system settings to take a profile photo. You can still choose a photo with the system picker.',
      'fr':
          'Activez l’accès à la caméra dans les réglages système pour prendre une photo de profil. Vous pouvez toujours choisir une photo avec le sélecteur système.',
      'es':
          'Activa el acceso a la cámara en los ajustes del sistema para hacer una foto de perfil. También puedes elegir una foto con el selector del sistema.',
      'tr':
          'Profil fotoğrafı çekmek için sistem ayarlarından kamera erişimini etkinleştirin. Sistem seçicisiyle fotoğraf seçmeye devam edebilirsiniz.',
      'de':
          'Aktivieren Sie den Kamerazugriff in den Systemeinstellungen, um ein Profilfoto aufzunehmen. Sie können weiterhin ein Foto über die Systemauswahl wählen.',
      'it':
          'Abilita l’accesso alla fotocamera nelle impostazioni di sistema per scattare una foto del profilo. Puoi comunque scegliere una foto dal selettore di sistema.',
      'pt-BR':
          'Ative o acesso à câmera nos ajustes do sistema para tirar uma foto de perfil. Você ainda pode escolher uma foto pelo seletor do sistema.',
      'pt-PT':
          'Ative o acesso à câmara nas definições do sistema para tirar uma fotografia de perfil. Pode escolher uma fotografia através do seletor do sistema.',
      'ur':
          'پروفائل تصویر لینے کے لیے سسٹم کی ترتیبات میں کیمرے کی رسائی فعال کریں۔ آپ سسٹم پکَر سے تصویر منتخب کر سکتے ہیں۔',
      'fa':
          'برای گرفتن عکس نمایه، دسترسی دوربین را در تنظیمات سیستم فعال کنید. همچنان می‌توانید عکس را از انتخابگر سیستم برگزینید.',
      'hi':
          'प्रोफ़ाइल फ़ोटो लेने के लिए सिस्टम सेटिंग्स में कैमरा एक्सेस चालू करें। आप सिस्टम पिकर से फ़ोटो भी चुन सकते हैं।',
      'id':
          'Aktifkan akses kamera di pengaturan sistem untuk mengambil foto profil. Anda tetap dapat memilih foto dengan pemilih sistem.',
      'ms':
          'Dayakan akses kamera dalam tetapan sistem untuk mengambil foto profil. Anda masih boleh memilih foto dengan pemilih sistem.',
      'ja':
          'プロフィール写真を撮影するには、システム設定でカメラへのアクセスを有効にしてください。システムピッカーで写真を選ぶこともできます。',
      'ko':
          '프로필 사진을 찍으려면 시스템 설정에서 카메라 접근을 허용하세요. 시스템 선택기로 사진을 선택할 수도 있습니다.',
      'zh-Hans':
          '要拍摄个人资料照片，请在系统设置中启用相机访问权限。你也可以使用系统选择器选择照片。',
      'zh-Hant':
          '若要拍攝個人資料相片，請在系統設定中啟用相機存取權限。你也可以使用系統選擇器選取相片。',
      'ru':
          'Включите доступ к камере в системных настройках, чтобы сделать фото профиля. Вы также можете выбрать фото через системный выбор.',
      'bn':
          'প্রোফাইল ছবি তুলতে সিস্টেম সেটিংসে ক্যামেরা অ্যাক্সেস চালু করুন। আপনি সিস্টেম পিকার ব্যবহার করে ছবিও বেছে নিতে পারেন।',
      'vi':
          'Hãy bật quyền truy cập camera trong cài đặt hệ thống để chụp ảnh hồ sơ. Bạn vẫn có thể chọn ảnh bằng trình chọn của hệ thống.',
      'th':
          'เปิดใช้การเข้าถึงกล้องในการตั้งค่าระบบเพื่อถ่ายรูปโปรไฟล์ คุณยังเลือกภาพผ่านตัวเลือกของระบบได้',
      'pl':
          'Włącz dostęp do aparatu w ustawieniach systemu, aby zrobić zdjęcie profilowe. Możesz też wybrać zdjęcie za pomocą selektora systemowego.',
      'nl':
          'Schakel cameratoegang in via de systeeminstellingen om een profielfoto te maken. Je kunt ook een foto kiezen met de systeemkiezer.',
      'uk':
          'Увімкніть доступ до камери в системних налаштуваннях, щоб зробити фото профілю. Ви також можете вибрати фото за допомогою системного вибору.',
    },
    'Your photo is saved on this device. Community sync will retry when the cloud is available.': {
      'ar':
          'حُفظت صورتك على هذا الجهاز. ستُعاد مزامنة المجتمع عند توفر السحابة.',
      'en':
          'Your photo is saved on this device. Community sync will retry when the cloud is available.',
      'fr':
          'Votre photo est enregistrée sur cet appareil. La synchronisation Community reprendra dès que le cloud sera disponible.',
      'es':
          'Tu foto se guardó en este dispositivo. Community volverá a sincronizar cuando la nube esté disponible.',
      'tr':
          'Fotoğrafınız bu cihaza kaydedildi. Bulut kullanılabilir olduğunda Community eşitlemesi yeniden denenecek.',
      'de':
          'Ihr Foto wurde auf diesem Gerät gespeichert. Community synchronisiert erneut, sobald die Cloud verfügbar ist.',
      'it':
          'La foto è salvata su questo dispositivo. Community riproverà la sincronizzazione quando il cloud sarà disponibile.',
      'pt-BR':
          'Sua foto foi salva neste dispositivo. O Community tentará sincronizar novamente quando a nuvem estiver disponível.',
      'pt-PT':
          'A sua fotografia foi guardada neste dispositivo. O Community voltará a sincronizar quando a nuvem estiver disponível.',
      'ur':
          'آپ کی تصویر اس ڈیوائس پر محفوظ ہے۔ کلاؤڈ دستیاب ہونے پر Community دوبارہ مطابقت کرے گا۔',
      'fa':
          'تصویر شما روی این دستگاه ذخیره شد. با در دسترس شدن ابر، Community دوباره همگام می‌شود.',
      'hi':
          'आपकी फ़ोटो इस डिवाइस पर सहेजी गई है। क्लाउड उपलब्ध होने पर Community फिर सिंक करेगा।',
      'id':
          'Foto Anda disimpan di perangkat ini. Community akan mencoba sinkronisasi lagi saat cloud tersedia.',
      'ms':
          'Foto anda disimpan pada peranti ini. Community akan cuba menyegerak semula apabila awan tersedia.',
      'ja': '写真はこの端末に保存されました。クラウドが利用可能になると Community の同期を再試行します。',
      'ko': '사진이 이 기기에 저장되었습니다. 클라우드를 사용할 수 있게 되면 Community 동기화를 다시 시도합니다.',
      'zh-Hans': '照片已保存在此设备上。云端可用后，Community 将重试同步。',
      'zh-Hant': '相片已儲存在此裝置上。雲端可用後，Community 將重試同步。',
      'ru':
          'Фото сохранено на этом устройстве. Community повторит синхронизацию, когда облако станет доступно.',
      'bn':
          'আপনার ছবি এই ডিভাইসে সংরক্ষিত হয়েছে। ক্লাউড উপলভ্য হলে Community আবার সিঙ্ক করবে।',
      'vi':
          'Ảnh đã được lưu trên thiết bị này. Community sẽ đồng bộ lại khi đám mây khả dụng.',
      'th':
          'บันทึกรูปไว้ในอุปกรณ์นี้แล้ว Community จะลองซิงค์อีกครั้งเมื่อคลาวด์พร้อมใช้งาน',
      'pl':
          'Zdjęcie zapisano na tym urządzeniu. Community ponowi synchronizację, gdy chmura będzie dostępna.',
      'nl':
          'Uw foto is op dit apparaat opgeslagen. Community probeert opnieuw te synchroniseren zodra de cloud beschikbaar is.',
      'uk':
          'Фото збережено на цьому пристрої. Community повторить синхронізацію, коли хмара стане доступною.',
    },
    'Toggle flash': {
      'ar': 'تبديل الفلاش',
      'en': 'Toggle flash',
      'fr': 'Activer ou désactiver le flash',
      'es': 'Activar o desactivar el flash',
      'tr': 'Flaşı aç veya kapat',
      'de': 'Blitz ein- oder ausschalten',
      'it': 'Attiva o disattiva il flash',
      'pt-BR': 'Ativar ou desativar o flash',
      'pt-PT': 'Ativar ou desativar o flash',
      'ur': 'فلیش آن یا آف کریں',
      'fa': 'فلش را روشن یا خاموش کنید',
      'hi': 'फ़्लैश चालू या बंद करें',
      'id': 'Aktifkan atau nonaktifkan lampu kilat',
      'ms': 'Hidupkan atau matikan denyar',
      'ja': 'フラッシュを切り替える',
      'ko': '플래시 전환',
      'zh-Hans': '切换闪光灯',
      'zh-Hant': '切換閃光燈',
      'ru': 'Переключить вспышку',
      'bn': 'ফ্ল্যাশ চালু বা বন্ধ করুন',
      'vi': 'Bật hoặc tắt đèn flash',
      'th': 'เปิดหรือปิดแฟลช',
      'pl': 'Włącz lub wyłącz lampę błyskową',
      'nl': 'Flitser in- of uitschakelen',
      'uk': 'Увімкнути або вимкнути спалах',
    },
    'Camera unavailable': {
      'ar': 'الكاميرا غير متاحة',
      'en': 'Camera unavailable',
      'fr': 'Appareil photo indisponible',
      'es': 'Cámara no disponible',
      'tr': 'Kamera kullanılamıyor',
      'de': 'Kamera nicht verfügbar',
      'it': 'Fotocamera non disponibile',
      'pt-BR': 'Câmera indisponível',
      'pt-PT': 'Câmara indisponível',
      'ur': 'کیمرا دستیاب نہیں ہے',
      'fa': 'دوربین در دسترس نیست',
      'hi': 'कैमरा उपलब्ध नहीं है',
      'id': 'Kamera tidak tersedia',
      'ms': 'Kamera tidak tersedia',
      'ja': 'カメラを利用できません',
      'ko': '카메라를 사용할 수 없습니다',
      'zh-Hans': '相机不可用',
      'zh-Hant': '相機無法使用',
      'ru': 'Камера недоступна',
      'bn': 'ক্যামেরা উপলভ্য নয়',
      'vi': 'Không thể sử dụng camera',
      'th': 'ไม่สามารถใช้กล้องได้',
      'pl': 'Aparat niedostępny',
      'nl': 'Camera niet beschikbaar',
      'uk': 'Камера недоступна',
    },
    'Retry': {
      'ar': 'إعادة المحاولة',
      'en': 'Retry',
      'fr': 'Réessayer',
      'es': 'Reintentar',
      'tr': 'Yeniden dene',
      'de': 'Erneut versuchen',
      'it': 'Riprova',
      'pt-BR': 'Tentar novamente',
      'pt-PT': 'Tentar novamente',
      'ur': 'دوبارہ کوشش کریں',
      'fa': 'تلاش دوباره',
      'hi': 'फिर कोशिश करें',
      'id': 'Coba lagi',
      'ms': 'Cuba lagi',
      'ja': '再試行',
      'ko': '다시 시도',
      'zh-Hans': '重试',
      'zh-Hant': '重試',
      'ru': 'Повторить',
      'bn': 'আবার চেষ্টা করুন',
      'vi': 'Thử lại',
      'th': 'ลองอีกครั้ง',
      'pl': 'Spróbuj ponownie',
      'nl': 'Opnieuw proberen',
      'uk': 'Спробувати ще раз',
    },
    'Capture': {
      'ar': 'التقاط صورة',
      'en': 'Capture',
      'fr': 'Prendre une photo',
      'es': 'Tomar foto',
      'tr': 'Fotoğraf çek',
      'de': 'Foto aufnehmen',
      'it': 'Scatta foto',
      'pt-BR': 'Tirar foto',
      'pt-PT': 'Tirar fotografia',
      'ur': 'تصویر لیں',
      'fa': 'گرفتن عکس',
      'hi': 'फ़ोटो लें',
      'id': 'Ambil foto',
      'ms': 'Ambil foto',
      'ja': '撮影',
      'ko': '사진 촬영',
      'zh-Hans': '拍照',
      'zh-Hant': '拍照',
      'ru': 'Сделать фото',
      'bn': 'ছবি তুলুন',
      'vi': 'Chụp ảnh',
      'th': 'ถ่ายภาพ',
      'pl': 'Zrób zdjęcie',
      'nl': 'Foto maken',
      'uk': 'Зробити фото',
    },
  };
}
