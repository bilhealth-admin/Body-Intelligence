/// Advertising data disclosures. Keep app-recorded data separate from SDK data.
/// Agent-authored locale copy; human linguistic review is not recorded.
abstract final class AdvertisingDisclosureRuntimeCopy {
  static const values = <String, String>{
    'ar':
        'لا يرسل BIL بياناتك المسجلة عن الصحة أو التغذية أو الوزن أو الموقع أو الملف الشخصي أو المجتمع الخاص ضمن طلبات الإعلانات. قد تعالج حزمة إعلانات Google بيانات تقنية وبيانات التفاعل مع الإعلانات، ومنها موقع تقريبي يُستنتج من عنوان IP. اشتراك Premium بلا إعلانات.',
    'en':
        'BIL does not send your recorded health, nutrition, weight, location, profile, or private community data in ad requests. Google’s ad SDK may process technical and ad-interaction data, including approximate location inferred from your IP address. Premium is ad-free.',
    'fr':
        'BIL n’envoie pas vos données enregistrées de santé, de nutrition, de poids, de localisation ou de profil, ni vos données privées de la communauté, dans les demandes publicitaires. Le SDK publicitaire de Google peut traiter des données techniques et des données d’interaction avec les publicités, y compris une localisation approximative déduite de votre adresse IP. Premium est sans publicité.',
    'es':
        'BIL no envía tus datos registrados de salud, nutrición, peso, ubicación o perfil, ni tus datos privados de la comunidad, en las solicitudes de anuncios. El SDK de anuncios de Google puede procesar datos técnicos y de interacción con los anuncios, incluida una ubicación aproximada deducida de tu dirección IP. Premium no tiene anuncios.',
    'tr':
        'BIL, kaydettiğiniz sağlık, beslenme, kilo, konum veya profil verilerinizi ya da özel topluluk verilerinizi reklam isteklerinde göndermez. Google’ın reklam SDK’sı, IP adresinizden çıkarılan yaklaşık konum da dahil olmak üzere teknik verileri ve reklam etkileşimi verilerini işleyebilir. Premium reklamsızdır.',
    'de':
        'BIL sendet Ihre erfassten Gesundheits-, Ernährungs-, Gewichts-, Standort- oder Profildaten sowie Ihre privaten Community-Daten nicht in Anzeigenanfragen. Das Anzeigen-SDK von Google kann technische Daten und Daten zu Anzeigeninteraktionen verarbeiten, einschließlich eines aus Ihrer IP-Adresse abgeleiteten ungefähren Standorts. Premium ist werbefrei.',
    'it':
        'BIL non invia i tuoi dati registrati su salute, alimentazione, peso, posizione o profilo, né i tuoi dati privati della community, nelle richieste di annunci. L’SDK pubblicitario di Google può elaborare dati tecnici e dati sulle interazioni con gli annunci, inclusa una posizione approssimativa dedotta dal tuo indirizzo IP. Premium è senza pubblicità.',
    'pt-BR':
        'O BIL não envia seus dados registrados de saúde, nutrição, peso, localização ou perfil, nem seus dados privados da comunidade, nas solicitações de anúncios. O SDK de anúncios do Google pode processar dados técnicos e de interação com anúncios, incluindo uma localização aproximada inferida do seu endereço IP. O Premium não tem anúncios.',
    'pt-PT':
        'O BIL não envia os seus dados registados de saúde, nutrição, peso, localização ou perfil, nem os seus dados privados da comunidade, nos pedidos de anúncios. O SDK de anúncios da Google pode tratar dados técnicos e de interação com anúncios, incluindo uma localização aproximada inferida a partir do seu endereço IP. O Premium não tem anúncios.',
    'ur':
        'BIL اشتہاری درخواستوں میں آپ کے درج کردہ صحت، غذائیت، وزن، مقام یا پروفائل سے متعلق ڈیٹا، یا کمیونٹی کا آپ کا نجی ڈیٹا نہیں بھیجتا۔ Google کا اشتہاری SDK تکنیکی ڈیٹا اور اشتہارات کے ساتھ تعامل سے متعلق ڈیٹا پر کارروائی کر سکتا ہے، جس میں آپ کے IP پتے سے اخذ کیا گیا اندازاً مقام بھی شامل ہے۔ Premium اشتہارات سے پاک ہے۔',
    'fa':
        'BIL در درخواست‌های تبلیغاتی، داده‌های ثبت‌شدهٔ شما دربارهٔ سلامت، تغذیه، وزن، موقعیت مکانی یا نمایه، یا داده‌های خصوصی شما در انجمن را ارسال نمی‌کند. SDK تبلیغاتی Google ممکن است داده‌های فنی و داده‌های تعامل با تبلیغات، از جمله موقعیت مکانی تقریبی استنباط‌شده از نشانی IP شما را پردازش کند. Premium بدون تبلیغات است.',
    'hi':
        'BIL विज्ञापन अनुरोधों में आपके दर्ज किए गए स्वास्थ्य, पोषण, वज़न, स्थान या प्रोफ़ाइल से जुड़े डेटा या कम्युनिटी में मौजूद आपके निजी डेटा को नहीं भेजता है। Google का विज्ञापन SDK तकनीकी डेटा और विज्ञापनों के साथ इंटरैक्शन से जुड़े डेटा को प्रोसेस कर सकता है, जिसमें आपके IP पते से मोटे तौर पर अनुमानित स्थान भी शामिल है। Premium में विज्ञापन नहीं होते।',
    'id':
        'BIL tidak mengirimkan data kesehatan, nutrisi, berat badan, lokasi, atau profil yang Anda catat, maupun data komunitas pribadi Anda, dalam permintaan iklan. SDK iklan Google dapat memproses data teknis dan interaksi iklan, termasuk perkiraan lokasi yang disimpulkan dari alamat IP Anda. Premium bebas iklan.',
    'ms':
        'BIL tidak menghantar data kesihatan, pemakanan, berat badan, lokasi atau profil yang anda rekodkan, atau data komuniti peribadi anda, dalam permintaan iklan. SDK iklan Google mungkin memproses data teknikal dan interaksi iklan, termasuk anggaran lokasi yang disimpulkan daripada alamat IP anda. Premium bebas iklan.',
    'ja':
        'BILは、記録した健康、栄養、体重、位置情報、プロフィールのデータや、非公開のコミュニティデータを広告リクエストに含めて送信しません。Googleの広告SDKは、IPアドレスから推定されるおおよその位置情報を含む、技術データや広告の操作に関するデータを処理する場合があります。Premiumでは広告は表示されません。',
    'ko':
        'BIL은 광고 요청에 사용자가 기록한 건강, 영양, 체중, 위치, 프로필 데이터나 비공개 커뮤니티 데이터를 포함하여 전송하지 않습니다. Google의 광고 SDK는 IP 주소에서 추정한 대략적인 위치를 포함한 기술 데이터와 광고 상호작용 데이터를 처리할 수 있습니다. Premium에는 광고가 없습니다.',
    'zh-Hans':
        'BIL不会在广告请求中发送您记录的健康、营养、体重、位置、个人资料或私密社区数据。Google的广告SDK可能会处理技术数据和广告互动数据，包括根据您的IP地址推断的大致位置。Premium不显示广告。',
    'zh-Hant':
        'BIL不會在廣告請求中傳送您記錄的健康、營養、體重、位置、個人資料或私人社群資料。Google的廣告SDK可能會處理技術資料和廣告互動資料，包括根據您的IP位址推斷的大致位置。Premium不顯示廣告。',
    'ru':
        'BIL не отправляет в рекламных запросах записанные вами данные о здоровье, питании, весе, местоположении или профиле, а также ваши непубличные данные сообщества. Рекламный SDK Google может обрабатывать технические данные и данные о взаимодействии с рекламой, включая приблизительное местоположение, определённое по вашему IP-адресу. В Premium нет рекламы.',
    'bn':
        'BIL বিজ্ঞাপনের অনুরোধে আপনার নথিভুক্ত স্বাস্থ্য, পুষ্টি, ওজন, অবস্থান বা প্রোফাইলের তথ্য কিংবা কমিউনিটিতে থাকা আপনার ব্যক্তিগত তথ্য পাঠায় না। Google-এর বিজ্ঞাপন SDK প্রযুক্তিগত তথ্য এবং বিজ্ঞাপনের সঙ্গে মিথস্ক্রিয়ার তথ্য প্রক্রিয়া করতে পারে, যার মধ্যে আপনার IP ঠিকানা থেকে অনুমান করা আনুমানিক অবস্থানও রয়েছে। Premium-এ কোনো বিজ্ঞাপন নেই।',
    'vi':
        'BIL không gửi dữ liệu bạn đã ghi lại về sức khỏe, dinh dưỡng, cân nặng, vị trí hoặc hồ sơ, hay dữ liệu cộng đồng riêng tư của bạn, trong các yêu cầu quảng cáo. SDK quảng cáo của Google có thể xử lý dữ liệu kỹ thuật và dữ liệu tương tác với quảng cáo, bao gồm vị trí gần đúng được suy ra từ địa chỉ IP của bạn. Premium không có quảng cáo.',
    'th':
        'BIL ไม่ส่งข้อมูลสุขภาพ โภชนาการ น้ำหนัก ตำแหน่งที่ตั้ง หรือโปรไฟล์ที่คุณบันทึกไว้ หรือข้อมูลส่วนตัวของคุณในชุมชนไปกับคำขอโฆษณา SDK โฆษณาของ Google อาจประมวลผลข้อมูลทางเทคนิคและข้อมูลการโต้ตอบกับโฆษณา รวมถึงตำแหน่งที่ตั้งโดยประมาณที่อนุมานจากที่อยู่ IP ของคุณ Premium ไม่มีโฆษณา',
    'pl':
        'BIL nie wysyła w żądaniach reklam zapisanych przez Ciebie danych dotyczących zdrowia, odżywiania, masy ciała, lokalizacji ani profilu, ani Twoich prywatnych danych społecznościowych. Pakiet SDK reklam Google może przetwarzać dane techniczne i dane dotyczące interakcji z reklamami, w tym przybliżoną lokalizację ustaloną na podstawie Twojego adresu IP. Premium nie zawiera reklam.',
    'nl':
        'BIL verstuurt je vastgelegde gegevens over gezondheid, voeding, gewicht, locatie of profiel en je privégegevens binnen de community niet in advertentieverzoeken. De advertentie-SDK van Google kan technische gegevens en gegevens over interacties met advertenties verwerken, waaronder een geschatte locatie die uit je IP-adres wordt afgeleid. Premium is advertentievrij.',
    'uk':
        'BIL не надсилає в рекламних запитах записані вами дані про здоров’я, харчування, вагу, місцеперебування чи профіль, а також ваші приватні дані спільноти. Рекламний SDK Google може обробляти технічні дані та дані про взаємодію з рекламою, зокрема приблизне місцеперебування, визначене за вашою IP-адресою. У Premium немає реклами.',
  };

  static String forLocale(String localeTag) {
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final entry in values.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    return values[normalized.split('-').first] ?? values['en']!;
  }
}
