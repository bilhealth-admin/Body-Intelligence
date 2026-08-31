/// Reviewed, benefit-led consent copy for BIL's selective encrypted backup.
///
/// Keep the scope precise: only profile, weight, and water are synchronized.
/// Nutrition remains device-local. Every shipped locale is explicit so this
/// sensitive choice never falls back to English.
abstract final class CloudSyncConsentCopy {
  static const settingsTitle = 'Progress backup';
  static const settingsSubtitle =
      'Restore and continue your profile, weight and water. Meals stay fast and private on this device.';
  static const title = 'Take your progress with you';
  static const restoreBenefit =
      'Restore your profile, weight and water after reinstalling BIL or moving to a new phone.';
  static const continuityBenefit =
      'Continue those records across your signed-in devices.';
  static const privacyBenefit =
      'Encrypted before upload and private to your account. Other users cannot see it, and BIL does not sell your data.';
  static const localNutrition = 'Meals stay fast and private on this device.';
  static const choiceControl = 'You can change this choice anytime in Privacy.';
  static const deletionControl =
      'You can also request deletion of the saved cloud copy in Privacy.';
  static const primaryAction = 'Back up & sync my progress';
  static const localAction = 'Keep my progress on this device';

  static const sources = <String>[
    settingsTitle,
    settingsSubtitle,
    title,
    restoreBenefit,
    continuityBenefit,
    privacyBenefit,
    localNutrition,
    choiceControl,
    deletionControl,
    primaryAction,
    localAction,
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
      'نسخ التقدّم احتياطيًا',
      'استعد ملفك الشخصي ووزنك ومياهك وتابعها. تبقى الوجبات سريعة وخاصة على هذا الجهاز.',
      'خذ تقدّمك معك أينما ذهبت',
      'استعد ملفك الشخصي ووزنك ومياهك بعد إعادة تثبيت BIL أو الانتقال إلى هاتف جديد.',
      'تابع هذه السجلات عبر أجهزتك التي سجلت الدخول عليها.',
      'تُشفَّر قبل الرفع وتبقى خاصة بحسابك. لا يمكن للمستخدمين الآخرين رؤيتها، ولا يبيع BIL بياناتك.',
      'تبقى وجباتك سريعة وخاصة على هذا الجهاز.',
      'يمكنك تغيير هذا الاختيار في أي وقت من «الخصوصية».',
      'يمكنك أيضًا طلب حذف النسخة السحابية المحفوظة من «الخصوصية».',
      'نسخ تقدمي احتياطيًا ومزامنته',
      'الاحتفاظ بتقدمي على هذا الجهاز',
    ],
    'en': sources,
    'fr': <String>[
      'Sauvegarde de la progression',
      'Restaurez et retrouvez votre profil, votre poids et votre hydratation. Les repas restent rapides et privés sur cet appareil.',
      'Emportez votre progression avec vous',
      'Restaurez votre profil, votre poids et votre hydratation après avoir réinstallé BIL ou changé de téléphone.',
      'Retrouvez ces données sur vos appareils connectés.',
      'Chiffrées avant l’envoi et privées dans votre compte. Les autres utilisateurs ne peuvent pas les voir et BIL ne vend pas vos données.',
      'Vos repas restent rapides et privés sur cet appareil.',
      'Vous pouvez modifier ce choix à tout moment dans Confidentialité.',
      'Vous pouvez aussi demander la suppression de la copie enregistrée dans le cloud depuis Confidentialité.',
      'Sauvegarder et synchroniser ma progression',
      'Garder ma progression sur cet appareil',
    ],
    'es': <String>[
      'Copia de seguridad del progreso',
      'Restaura y continúa tu perfil, peso y agua. Las comidas siguen siendo rápidas y privadas en este dispositivo.',
      'Lleva tu progreso contigo',
      'Restaura tu perfil, peso y agua tras reinstalar BIL o cambiar a un teléfono nuevo.',
      'Continúa con esos registros en tus dispositivos con sesión iniciada.',
      'Se cifran antes de subirlos y son privados de tu cuenta. Otros usuarios no pueden verlos y BIL no vende tus datos.',
      'Las comidas siguen siendo rápidas y privadas en este dispositivo.',
      'Puedes cambiar esta elección en cualquier momento en Privacidad.',
      'También puedes solicitar en Privacidad la eliminación de la copia guardada en la nube.',
      'Hacer copia y sincronizar mi progreso',
      'Mantener mi progreso en este dispositivo',
    ],
    'tr': <String>[
      'İlerleme yedeklemesi',
      'Profilinizi, kilonuzu ve su kayıtlarınızı geri yükleyip sürdürün. Öğünler bu cihazda hızlı ve özel kalır.',
      'İlerlemeni yanında götür',
      "BIL'i yeniden yükledikten veya yeni bir telefona geçtikten sonra profilinizi, kilonuzu ve su kayıtlarınızı geri yükleyin.",
      'Oturum açtığınız cihazlarda bu kayıtlara kaldığınız yerden devam edin.',
      'Yüklenmeden önce şifrelenir ve hesabınıza özel kalır. Diğer kullanıcılar göremez; BIL verilerinizi satmaz.',
      'Öğünleriniz bu cihazda hızlı ve özel kalır.',
      'Bu seçimi Gizlilik bölümünden istediğiniz zaman değiştirebilirsiniz.',
      'Kaydedilmiş bulut kopyasının silinmesini de Gizlilik bölümünden isteyebilirsiniz.',
      'İlerlememi yedekle ve eşitle',
      'İlerlememi bu cihazda tut',
    ],
    'de': <String>[
      'Fortschrittssicherung',
      'Profil, Gewicht und Wasser wiederherstellen und fortführen. Mahlzeiten bleiben auf diesem Gerät schnell verfügbar und privat.',
      'Nehmen Sie Ihren Fortschritt mit',
      'Stellen Sie Profil, Gewicht und Wasser nach einer Neuinstallation von BIL oder auf einem neuen Smartphone wieder her.',
      'Setzen Sie diese Aufzeichnungen auf Ihren angemeldeten Geräten fort.',
      'Vor dem Hochladen verschlüsselt und nur für Ihr Konto bestimmt. Andere Nutzer können sie nicht sehen und BIL verkauft Ihre Daten nicht.',
      'Mahlzeiten bleiben auf diesem Gerät schnell verfügbar und privat.',
      'Sie können diese Auswahl jederzeit unter „Datenschutz“ ändern.',
      'Dort können Sie auch die Löschung der gespeicherten Cloud-Kopie beantragen.',
      'Meinen Fortschritt sichern und synchronisieren',
      'Meinen Fortschritt auf diesem Gerät behalten',
    ],
    'it': <String>[
      'Backup dei progressi',
      'Ripristina e continua profilo, peso e acqua. I pasti restano rapidi e privati su questo dispositivo.',
      'Porta con te i tuoi progressi',
      'Ripristina profilo, peso e acqua dopo aver reinstallato BIL o quando passi a un nuovo telefono.',
      'Continua con questi dati sui dispositivi in cui hai effettuato l’accesso.',
      'Vengono crittografati prima del caricamento e restano privati nel tuo account. Gli altri utenti non possono vederli e BIL non vende i tuoi dati.',
      'I pasti restano rapidi e privati su questo dispositivo.',
      'Puoi modificare questa scelta in qualsiasi momento in Privacy.',
      'In Privacy puoi anche richiedere l’eliminazione della copia salvata nel cloud.',
      'Esegui backup e sincronizza i miei progressi',
      'Mantieni i miei progressi su questo dispositivo',
    ],
    'pt-BR': <String>[
      'Backup do progresso',
      'Restaure e continue seu perfil, peso e água. As refeições continuam rápidas e privadas neste dispositivo.',
      'Leve seu progresso com você',
      'Restaure seu perfil, peso e água após reinstalar o BIL ou trocar para um celular novo.',
      'Continue com esses registros nos dispositivos em que você entrou.',
      'Criptografados antes do envio e privados na sua conta. Outros usuários não podem vê-los, e o BIL não vende seus dados.',
      'Suas refeições continuam rápidas e privadas neste dispositivo.',
      'Você pode mudar esta escolha a qualquer momento em Privacidade.',
      'Em Privacidade, você também pode solicitar a exclusão da cópia salva na nuvem.',
      'Fazer backup e sincronizar meu progresso',
      'Manter meu progresso neste dispositivo',
    ],
    'pt-PT': <String>[
      'Cópia de segurança do progresso',
      'Restaure e continue o perfil, o peso e a água. As refeições continuam rápidas e privadas neste dispositivo.',
      'Leve o seu progresso consigo',
      'Restaure o perfil, o peso e a água após reinstalar o BIL ou mudar para um novo telemóvel.',
      'Continue estes registos nos dispositivos onde iniciou sessão.',
      'São encriptados antes do envio e ficam privados na sua conta. Outros utilizadores não os podem ver e o BIL não vende os seus dados.',
      'As suas refeições continuam rápidas e privadas neste dispositivo.',
      'Pode alterar esta escolha a qualquer momento em Privacidade.',
      'Em Privacidade, também pode pedir a eliminação da cópia guardada na nuvem.',
      'Criar cópia e sincronizar o meu progresso',
      'Manter o meu progresso neste dispositivo',
    ],
    'ur': <String>[
      'پیش رفت کا بیک اپ',
      'اپنا پروفائل، وزن اور پانی بحال کر کے جاری رکھیں۔ کھانے اس ڈیوائس پر تیز اور نجی رہتے ہیں۔',
      'اپنی پیش رفت ساتھ لے جائیں',
      'BIL دوبارہ انسٹال کرنے یا نئے فون پر منتقل ہونے کے بعد اپنا پروفائل، وزن اور پانی بحال کریں۔',
      'اپنے سائن اِن کردہ آلات پر ان ریکارڈز کو جاری رکھیں۔',
      'اپ لوڈ سے پہلے خفیہ کردہ اور آپ کے اکاؤنٹ تک نجی۔ دوسرے صارفین انہیں نہیں دیکھ سکتے، اور BIL آپ کا ڈیٹا فروخت نہیں کرتا۔',
      'کھانے اس ڈیوائس پر تیز اور نجی رہتے ہیں۔',
      'آپ رازداری میں یہ انتخاب کسی بھی وقت تبدیل کر سکتے ہیں۔',
      'آپ رازداری میں محفوظ کردہ کلاؤڈ کاپی حذف کرنے کی درخواست بھی کر سکتے ہیں۔',
      'میری پیش رفت کا بیک اپ اور مطابقت پذیری کریں',
      'میری پیش رفت اس ڈیوائس پر رکھیں',
    ],
    'fa': <String>[
      'پشتیبان‌گیری پیشرفت',
      'نمایه، وزن و آب خود را بازیابی و ادامه دهید. وعده‌ها در این دستگاه سریع و خصوصی می‌مانند.',
      'پیشرفت خود را همراه ببرید',
      'پس از نصب دوباره BIL یا رفتن به تلفن جدید، نمایه، وزن و آب خود را بازیابی کنید.',
      'این سوابق را در دستگاه‌هایی که وارد حساب شده‌اید ادامه دهید.',
      'پیش از بارگذاری رمزگذاری می‌شوند و در حساب شما خصوصی می‌مانند. کاربران دیگر نمی‌توانند آن‌ها را ببینند و BIL داده‌های شما را نمی‌فروشد.',
      'وعده‌های غذایی در این دستگاه سریع و خصوصی می‌مانند.',
      'می‌توانید این انتخاب را هر زمان در بخش حریم خصوصی تغییر دهید.',
      'همچنین می‌توانید در بخش حریم خصوصی حذف نسخهٔ ابری ذخیره‌شده را درخواست دهید.',
      'پشتیبان‌گیری و همگام‌سازی پیشرفت من',
      'نگه‌داشتن پیشرفت من در این دستگاه',
    ],
    'hi': <String>[
      'प्रगति का बैकअप',
      'अपनी प्रोफ़ाइल, वज़न और पानी को वापस पाएँ और जारी रखें। भोजन इस डिवाइस पर तेज़ी से उपलब्ध और निजी रहता है।',
      'अपनी प्रगति साथ ले जाएँ',
      'BIL को दोबारा इंस्टॉल करने या नए फ़ोन पर जाने के बाद अपनी प्रोफ़ाइल, वज़न और पानी का रिकॉर्ड वापस पाएँ।',
      'साइन इन किए हुए अपने डिवाइसों पर इन रिकॉर्ड को जारी रखें।',
      'अपलोड से पहले एन्क्रिप्ट किया जाता है और आपके खाते में निजी रहता है। दूसरे उपयोगकर्ता इसे नहीं देख सकते और BIL आपका डेटा नहीं बेचता।',
      'भोजन इस डिवाइस पर तेज़ी से उपलब्ध और निजी रहता है।',
      'आप गोपनीयता में यह विकल्प कभी भी बदल सकते हैं।',
      'आप गोपनीयता में सेव की गई क्लाउड कॉपी मिटाने का अनुरोध भी कर सकते हैं।',
      'मेरी प्रगति का बैकअप और सिंक करें',
      'मेरी प्रगति इस डिवाइस पर रखें',
    ],
    'id': <String>[
      'Cadangan progres',
      'Pulihkan dan lanjutkan profil, berat badan, dan air Anda. Makanan tetap cepat dan privat di perangkat ini.',
      'Bawa progres Anda',
      'Pulihkan profil, berat badan, dan catatan air setelah menginstal ulang BIL atau pindah ke ponsel baru.',
      'Lanjutkan catatan tersebut di perangkat tempat Anda masuk.',
      'Dienkripsi sebelum diunggah dan tetap privat di akun Anda. Pengguna lain tidak dapat melihatnya, dan BIL tidak menjual data Anda.',
      'Makanan tetap cepat dan privat di perangkat ini.',
      'Anda dapat mengubah pilihan ini kapan saja di Privasi.',
      'Anda juga dapat meminta penghapusan salinan cloud yang tersimpan di Privasi.',
      'Cadangkan & sinkronkan progres saya',
      'Simpan progres saya di perangkat ini',
    ],
    'ms': <String>[
      'Sandaran kemajuan',
      'Pulihkan dan teruskan profil, berat dan rekod air anda. Makanan kekal pantas dan peribadi pada peranti ini.',
      'Bawa kemajuan anda bersama',
      'Pulihkan profil, berat dan rekod air selepas memasang semula BIL atau beralih ke telefon baharu.',
      'Teruskan rekod tersebut pada peranti yang anda log masuk.',
      'Disulitkan sebelum dimuat naik dan kekal peribadi dalam akaun anda. Pengguna lain tidak boleh melihatnya dan BIL tidak menjual data anda.',
      'Makanan kekal pantas dan peribadi pada peranti ini.',
      'Anda boleh menukar pilihan ini pada bila-bila masa dalam Privasi.',
      'Anda juga boleh meminta salinan awan yang disimpan dipadam dalam Privasi.',
      'Sandarkan & segerakkan kemajuan saya',
      'Simpan kemajuan saya pada peranti ini',
    ],
    'ja': <String>[
      '進捗のバックアップ',
      'プロフィール、体重、水分記録を復元して継続できます。食事記録はこの端末上で素早く非公開のまま利用できます。',
      '進捗を持ち歩けます',
      'BIL を再インストールした後や新しいスマートフォンに替えたときに、プロフィール、体重、水分記録を復元できます。',
      'サインインした端末で、これらの記録を引き続き利用できます。',
      'アップロード前に暗号化され、あなたのアカウント内で非公開に保たれます。他のユーザーには表示されず、BIL があなたのデータを販売することはありません。',
      '食事記録はこの端末上で素早く非公開のまま利用できます。',
      'この選択は「プライバシー」でいつでも変更できます。',
      '保存されたクラウドコピーの削除も「プライバシー」から依頼できます。',
      '進捗をバックアップして同期',
      '進捗をこの端末にのみ保存',
    ],
    'ko': <String>[
      '진행 상황 백업',
      '프로필, 체중 및 물 기록을 복원하고 이어가세요. 식사 기록은 이 기기에서 빠르고 비공개로 유지됩니다.',
      '진행 상황을 어디서나 이어가세요',
      'BIL을 다시 설치하거나 새 휴대폰으로 옮긴 후 프로필, 체중 및 물 기록을 복원하세요.',
      '로그인한 기기에서 해당 기록을 계속 이용하세요.',
      '업로드 전에 암호화되며 내 계정에만 비공개로 유지됩니다. 다른 사용자는 볼 수 없으며 BIL은 내 데이터를 판매하지 않습니다.',
      '식사 기록은 이 기기에서 빠르고 비공개로 유지됩니다.',
      '이 선택은 개인정보 보호에서 언제든 변경할 수 있습니다.',
      '개인정보 보호에서 저장된 클라우드 사본 삭제를 요청할 수도 있습니다.',
      '내 진행 상황 백업 및 동기화',
      '내 진행 상황을 이 기기에만 보관',
    ],
    'zh-Hans': <String>[
      '进度备份',
      '恢复并继续使用您的个人资料、体重和饮水记录。餐食记录在此设备上保持快速和私密。',
      '随身延续您的进度',
      '重新安装 BIL 或换用新手机后，恢复您的个人资料、体重和饮水记录。',
      '在已登录的设备上继续使用这些记录。',
      '上传前会加密，并仅在您的账户中保持私密。其他用户无法查看，BIL 也不会出售您的数据。',
      '餐食记录在此设备上保持快速和私密。',
      '您可以随时在“隐私”中更改此选择。',
      '您也可以在“隐私”中申请删除已保存的云端副本。',
      '备份并同步我的进度',
      '仅在此设备上保留我的进度',
    ],
    'zh-Hant': <String>[
      '進度備份',
      '還原並繼續使用您的個人資料、體重和飲水記錄。餐食記錄在此裝置上保持快速和私密。',
      '隨時延續您的進度',
      '重新安裝 BIL 或換用新手機後，還原您的個人資料、體重和飲水記錄。',
      '在已登入的裝置上繼續使用這些記錄。',
      '上傳前會加密，並只在您的帳戶中保持私密。其他使用者無法查看，BIL 也不會出售您的資料。',
      '餐食記錄在此裝置上保持快速和私密。',
      '您可以隨時在「私隱」中更改此選擇。',
      '您也可以在「私隱」中要求刪除已儲存的雲端副本。',
      '備份並同步我的進度',
      '只在此裝置上保留我的進度',
    ],
    'ru': <String>[
      'Резервная копия прогресса',
      'Восстановите и продолжайте вести профиль, вес и воду. Записи о питании остаются быстрыми и приватными на этом устройстве.',
      'Берите свой прогресс с собой',
      'Восстановите профиль, вес и данные о воде после переустановки BIL или перехода на новый телефон.',
      'Продолжайте вести эти записи на устройствах, где вы вошли в аккаунт.',
      'Данные шифруются до загрузки и остаются приватными в вашем аккаунте. Другие пользователи их не видят, а BIL не продаёт ваши данные.',
      'Записи о питании остаются быстрыми и приватными на этом устройстве.',
      'Этот выбор можно в любое время изменить в разделе «Конфиденциальность».',
      'Там же можно запросить удаление сохранённой облачной копии.',
      'Сохранить и синхронизировать мой прогресс',
      'Оставить мой прогресс на этом устройстве',
    ],
    'bn': <String>[
      'অগ্রগতির ব্যাকআপ',
      'আপনার প্রোফাইল, ওজন ও পানির রেকর্ড পুনরুদ্ধার করে চালিয়ে যান। খাবারের রেকর্ড এই ডিভাইসে দ্রুত ও ব্যক্তিগত থাকে।',
      'আপনার অগ্রগতি সঙ্গে রাখুন',
      'BIL পুনরায় ইনস্টল করার বা নতুন ফোনে যাওয়ার পরে আপনার প্রোফাইল, ওজন ও পানির রেকর্ড পুনরুদ্ধার করুন।',
      'সাইন ইন করা ডিভাইসগুলোতে এই রেকর্ডগুলো চালিয়ে যান।',
      'আপলোডের আগে এনক্রিপ্ট করা হয় এবং আপনার অ্যাকাউন্টে ব্যক্তিগত থাকে। অন্য ব্যবহারকারীরা এগুলো দেখতে পারেন না এবং BIL আপনার ডেটা বিক্রি করে না।',
      'খাবারের রেকর্ড এই ডিভাইসে দ্রুত ও ব্যক্তিগত থাকে।',
      'গোপনীয়তায় আপনি যেকোনো সময় এই পছন্দ পরিবর্তন করতে পারেন।',
      'গোপনীয়তায় আপনি সংরক্ষিত ক্লাউড কপি মুছে ফেলার অনুরোধও করতে পারেন।',
      'আমার অগ্রগতি ব্যাকআপ ও সিঙ্ক করুন',
      'আমার অগ্রগতি এই ডিভাইসে রাখুন',
    ],
    'vi': <String>[
      'Sao lưu tiến trình',
      'Khôi phục và tiếp tục hồ sơ, cân nặng và lượng nước. Bữa ăn luôn nhanh và riêng tư trên thiết bị này.',
      'Mang theo tiến trình của bạn',
      'Khôi phục hồ sơ, cân nặng và lượng nước sau khi cài đặt lại BIL hoặc chuyển sang điện thoại mới.',
      'Tiếp tục các bản ghi đó trên những thiết bị bạn đã đăng nhập.',
      'Được mã hóa trước khi tải lên và giữ riêng tư trong tài khoản của bạn. Người dùng khác không thể xem và BIL không bán dữ liệu của bạn.',
      'Bữa ăn luôn nhanh và riêng tư trên thiết bị này.',
      'Bạn có thể thay đổi lựa chọn này bất cứ lúc nào trong Quyền riêng tư.',
      'Bạn cũng có thể yêu cầu xóa bản sao đám mây đã lưu trong Quyền riêng tư.',
      'Sao lưu & đồng bộ tiến trình của tôi',
      'Giữ tiến trình của tôi trên thiết bị này',
    ],
    'th': <String>[
      'สำรองความคืบหน้า',
      'กู้คืนและใช้โปรไฟล์ น้ำหนัก และบันทึกน้ำต่อ บันทึกมื้ออาหารยังคงรวดเร็วและเป็นส่วนตัวในอุปกรณ์นี้',
      'พกความคืบหน้าของคุณไปด้วย',
      'กู้คืนโปรไฟล์ น้ำหนัก และบันทึกน้ำหลังติดตั้ง BIL ใหม่หรือย้ายไปโทรศัพท์เครื่องใหม่',
      'ใช้บันทึกเหล่านี้ต่อในอุปกรณ์ที่คุณลงชื่อเข้าใช้',
      'เข้ารหัสก่อนอัปโหลดและเก็บเป็นส่วนตัวในบัญชีของคุณ ผู้ใช้อื่นมองไม่เห็น และ BIL ไม่ขายข้อมูลของคุณ',
      'บันทึกมื้ออาหารยังคงรวดเร็วและเป็นส่วนตัวในอุปกรณ์นี้',
      'คุณเปลี่ยนตัวเลือกนี้ได้ทุกเมื่อในความเป็นส่วนตัว',
      'คุณยังขอให้ลบสำเนาบนคลาวด์ที่บันทึกไว้ได้ในความเป็นส่วนตัว',
      'สำรองและซิงค์ความคืบหน้าของฉัน',
      'เก็บความคืบหน้าของฉันไว้ในอุปกรณ์นี้',
    ],
    'pl': <String>[
      'Kopia zapasowa postępu',
      'Przywróć i kontynuuj profil, wagę i wodę. Posiłki pozostają szybkie i prywatne na tym urządzeniu.',
      'Zabierz swój postęp ze sobą',
      'Przywróć profil, wagę i zapisy wody po ponownej instalacji BIL lub zmianie telefonu.',
      'Kontynuuj te zapisy na urządzeniach, na których się zalogujesz.',
      'Dane są szyfrowane przed wysłaniem i pozostają prywatne na Twoim koncie. Inni użytkownicy ich nie widzą, a BIL nie sprzedaje Twoich danych.',
      'Posiłki pozostają szybkie i prywatne na tym urządzeniu.',
      'Ten wybór możesz w każdej chwili zmienić w sekcji Prywatność.',
      'Możesz tam również poprosić o usunięcie zapisanej kopii w chmurze.',
      'Utwórz kopię i synchronizuj mój postęp',
      'Zachowaj mój postęp na tym urządzeniu',
    ],
    'nl': <String>[
      'Voortgangsback-up',
      'Herstel en vervolg uw profiel, gewicht en waterregistratie. Maaltijden blijven snel en privé op dit apparaat.',
      'Neem uw voortgang mee',
      'Herstel uw profiel, gewicht en waterregistratie nadat u BIL opnieuw installeert of naar een nieuwe telefoon overstapt.',
      'Ga met deze gegevens verder op apparaten waarop u bent ingelogd.',
      'Ze worden vóór upload versleuteld en blijven privé in uw account. Andere gebruikers kunnen ze niet zien en BIL verkoopt uw gegevens niet.',
      'Maaltijden blijven snel en privé op dit apparaat.',
      'U kunt deze keuze op elk moment wijzigen in Privacy.',
      'U kunt in Privacy ook verwijdering van de opgeslagen cloudkopie aanvragen.',
      'Mijn voortgang back-uppen en synchroniseren',
      'Mijn voortgang op dit apparaat houden',
    ],
    'uk': <String>[
      'Резервна копія прогресу',
      'Відновіть і продовжуйте профіль, вагу й записи води. Записи про харчування залишаються швидкими й приватними на цьому пристрої.',
      'Беріть свій прогрес із собою',
      'Відновіть профіль, вагу й записи води після повторного встановлення BIL або переходу на новий телефон.',
      'Продовжуйте ці записи на пристроях, де ви ввійшли в обліковий запис.',
      'Дані шифруються до завантаження й залишаються приватними у вашому обліковому записі. Інші користувачі їх не бачать, а BIL не продає ваші дані.',
      'Записи про харчування залишаються швидкими й приватними на цьому пристрої.',
      'Цей вибір можна будь-коли змінити в розділі «Конфіденційність».',
      'Там також можна подати запит на видалення збереженої хмарної копії.',
      'Створити копію й синхронізувати мій прогрес',
      'Залишити мій прогрес на цьому пристрої',
    ],
  };

  static String? resolve(String english, String localeTag) {
    final index = sources.indexOf(english);
    if (index < 0) return null;
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    String? matchedTag;
    for (final tag in supported) {
      if (tag.toLowerCase() == normalized) {
        matchedTag = tag;
        break;
      }
    }
    if (matchedTag == null) {
      final language = normalized.split('-').first;
      final matches = supported
          .where(
            (tag) =>
                tag.toLowerCase() == language ||
                tag.toLowerCase().startsWith('$language-'),
          )
          .toList(growable: false);
      if (matches.length == 1) matchedTag = matches.single;
    }
    if (matchedTag == null) return null;
    final row = rows[matchedTag];
    if (row == null || index >= row.length) return null;
    return row[index];
  }

  static bool get balanced =>
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
