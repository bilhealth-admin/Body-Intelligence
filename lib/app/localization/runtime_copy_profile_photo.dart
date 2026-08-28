/// Reviewed 25-locale copy for the shared account/Community photo contract.
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
    'Choose an image smaller than 5 MB.': {
      'ar': 'اختر صورة أصغر من 5 ميجابايت.',
      'en': 'Choose an image smaller than 5 MB.',
      'fr': 'Choisissez une image de moins de 5 Mo.',
      'es': 'Elige una imagen de menos de 5 MB.',
      'tr': '5 MB’tan küçük bir görsel seçin.',
      'de': 'Wählen Sie ein Bild unter 5 MB.',
      'it': 'Scegli un’immagine inferiore a 5 MB.',
      'pt-BR': 'Escolha uma imagem com menos de 5 MB.',
      'pt-PT': 'Escolha uma imagem com menos de 5 MB.',
      'ur': '5 MB سے چھوٹی تصویر منتخب کریں۔',
      'fa': 'تصویری کوچک‌تر از ۵ مگابایت انتخاب کنید.',
      'hi': '5 MB से छोटी तस्वीर चुनें।',
      'id': 'Pilih gambar yang lebih kecil dari 5 MB.',
      'ms': 'Pilih imej yang lebih kecil daripada 5 MB.',
      'ja': '5 MB 未満の画像を選択してください。',
      'ko': '5MB보다 작은 이미지를 선택하세요.',
      'zh-Hans': '请选择小于 5 MB 的图片。',
      'zh-Hant': '請選擇小於 5 MB 的圖片。',
      'ru': 'Выберите изображение размером менее 5 МБ.',
      'bn': '৫ MB-এর ছোট ছবি বেছে নিন।',
      'vi': 'Chọn ảnh nhỏ hơn 5 MB.',
      'th': 'เลือกรูปภาพที่มีขนาดเล็กกว่า 5 MB',
      'pl': 'Wybierz obraz mniejszy niż 5 MB.',
      'nl': 'Kies een afbeelding kleiner dan 5 MB.',
      'uk': 'Виберіть зображення розміром менше 5 МБ.',
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
  };
}
