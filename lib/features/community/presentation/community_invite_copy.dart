import '../../../app/localization/bil_locale_policy.dart';

const bilCommunityInviteDownloadUrl = 'https://www.bilhealth.com/download';

String bilCommunityInviteMessage(String localeTag, {required String name}) {
  final tag = BilLocalePolicy.canonicalSupportedTag(localeTag) ?? 'en';
  final greetingName = name.trim().isEmpty ? '' : ' ${name.trim()}';
  final template = _messages[tag] ?? _messages['en']!;
  return template
      .replaceAll('{name}', greetingName)
      .replaceAll('{url}', bilCommunityInviteDownloadUrl);
}

String bilCommunityContactPrivacy(String localeTag) {
  final tag = BilLocalePolicy.canonicalSupportedTag(localeTag) ?? 'en';
  return _contactPrivacy[tag] ?? _contactPrivacy['en']!;
}

const _contactPrivacy = <String, String>{
  'en': 'Only the contact you choose is shared with BIL.',
  'ar': 'تتم مشاركة جهة الاتصال التي تختارها فقط مع BIL.',
  'fr': 'Seul le contact que vous choisissez est partagé avec BIL.',
  'es': 'Solo se comparte con BIL el contacto que eliges.',
  'tr': 'Yalnızca seçtiğiniz kişi BIL ile paylaşılır.',
  'de': 'Nur der ausgewählte Kontakt wird mit BIL geteilt.',
  'it': 'Solo il contatto scelto viene condiviso con BIL.',
  'pt-BR': 'Somente o contato escolhido é compartilhado com o BIL.',
  'pt-PT': 'Apenas o contacto escolhido é partilhado com o BIL.',
  'ur': 'صرف آپ کا منتخب کردہ رابطہ BIL کے ساتھ شیئر ہوتا ہے۔',
  'fa': 'فقط مخاطبی که انتخاب می‌کنید با BIL به اشتراک گذاشته می‌شود.',
  'hi': 'केवल आपका चुना हुआ संपर्क BIL के साथ साझा होता है।',
  'id': 'Hanya kontak yang Anda pilih yang dibagikan dengan BIL.',
  'ms': 'Hanya kenalan yang anda pilih dikongsi dengan BIL.',
  'ja': '選択した連絡先だけが BIL と共有されます。',
  'ko': '선택한 연락처만 BIL과 공유됩니다.',
  'zh-Hans': '只有你选择的联系人会与 BIL 共享。',
  'zh-Hant': '只有你選擇的聯絡人會與 BIL 分享。',
  'ru': 'С BIL передаётся только выбранный вами контакт.',
  'bn': 'শুধু আপনার বেছে নেওয়া পরিচিতিটিই BIL-এর সঙ্গে শেয়ার করা হয়।',
  'vi': 'Chỉ liên hệ bạn chọn được chia sẻ với BIL.',
  'th': 'ระบบจะแชร์กับ BIL เฉพาะรายชื่อติดต่อที่คุณเลือก',
  'pl': 'Z BIL udostępniany jest tylko wybrany kontakt.',
  'nl': 'Alleen het gekozen contact wordt met BIL gedeeld.',
  'uk': 'BIL отримує лише вибраний вами контакт.',
};

const _messages = <String, String>{
  'en':
      'Hi{name}! Join me in the BIL community — track food and progress, follow personalized nutrition goals, explore wellness plans, and support friends on healthier journeys. Download BIL: {url}',
  'ar':
      'مرحبًا{name}! أدعوك للانضمام إليّ في مجتمع BIL — سجّل طعامك وتقدمك، واتبع أهدافًا غذائية مخصصة، واكتشف خطط العافية، وشجّع أصدقاءك في رحلتهم الصحية. حمّل BIL: {url}',
  'fr':
      'Bonjour{name} ! Rejoins-moi dans la communauté BIL : suis ton alimentation et tes progrès, adopte des objectifs nutritionnels personnalisés, découvre des programmes bien-être et encourage tes amis. Télécharge BIL : {url}',
  'es':
      '¡Hola{name}! Únete a mí en la comunidad BIL: registra tu alimentación y progreso, sigue objetivos de nutrición personalizados, descubre planes de bienestar y apoya a tus amigos. Descarga BIL: {url}',
  'tr':
      'Merhaba{name}! BIL topluluğunda bana katıl: beslenmeni ve ilerlemeni takip et, kişisel beslenme hedeflerini uygula, iyi yaşam planlarını keşfet ve arkadaşlarını destekle. BIL’i indir: {url}',
  'de':
      'Hallo{name}! Komm mit mir in die BIL-Community: Ernährung und Fortschritt verfolgen, persönliche Ernährungsziele nutzen, Wellnesspläne entdecken und Freunde unterstützen. BIL herunterladen: {url}',
  'it':
      'Ciao{name}! Unisciti a me nella community BIL: registra alimentazione e progressi, segui obiettivi nutrizionali personalizzati, scopri piani benessere e sostieni gli amici. Scarica BIL: {url}',
  'pt-BR':
      'Olá{name}! Junte-se a mim na comunidade BIL: acompanhe alimentação e progresso, siga metas nutricionais personalizadas, explore planos de bem-estar e apoie seus amigos. Baixe o BIL: {url}',
  'pt-PT':
      'Olá{name}! Junta-te a mim na comunidade BIL: acompanha a alimentação e o progresso, segue metas nutricionais personalizadas, explora planos de bem-estar e apoia os teus amigos. Transfere o BIL: {url}',
  'ur':
      'السلام علیکم{name}! BIL کمیونٹی میں میرے ساتھ شامل ہوں—خوراک اور پیش رفت ریکارڈ کریں، ذاتی غذائی اہداف اپنائیں، فلاحی منصوبے دیکھیں اور دوستوں کی صحت مند سفر میں حوصلہ افزائی کریں۔ BIL ڈاؤن لوڈ کریں: {url}',
  'fa':
      'سلام{name}! در جامعه BIL به من بپیوند؛ غذا و پیشرفتت را ثبت کن، هدف‌های تغذیه‌ای شخصی را دنبال کن، برنامه‌های تندرستی را ببین و از دوستانت حمایت کن. دانلود BIL: {url}',
  'hi':
      'नमस्ते{name}! BIL समुदाय में मेरे साथ जुड़ें—भोजन और प्रगति ट्रैक करें, व्यक्तिगत पोषण लक्ष्य अपनाएँ, वेलनेस योजनाएँ देखें और दोस्तों की स्वस्थ यात्रा में सहयोग करें। BIL डाउनलोड करें: {url}',
  'id':
      'Hai{name}! Bergabunglah bersama saya di komunitas BIL—catat makanan dan kemajuan, ikuti target nutrisi pribadi, jelajahi rencana kebugaran, dan dukung teman. Unduh BIL: {url}',
  'ms':
      'Hai{name}! Sertai saya dalam komuniti BIL—rekod makanan dan kemajuan, ikuti sasaran pemakanan peribadi, terokai pelan kesejahteraan dan sokong rakan. Muat turun BIL: {url}',
  'ja':
      'こんにちは{name}！BILコミュニティに参加しませんか。食事と進捗を記録し、個人向けの栄養目標に取り組み、ウェルネスプランを見つけ、友だちと励まし合えます。BILをダウンロード：{url}',
  'ko':
      '안녕하세요{name}! BIL 커뮤니티에 함께하세요. 음식과 진행 상황을 기록하고, 맞춤 영양 목표와 웰니스 플랜을 확인하며 친구의 건강 여정을 응원할 수 있어요. BIL 다운로드: {url}',
  'zh-Hans':
      '你好{name}！邀请你加入 BIL 社区：记录饮食与进展，遵循个性化营养目标，探索健康计划，并与朋友互相鼓励。下载 BIL：{url}',
  'zh-Hant':
      '你好{name}！邀請你加入 BIL 社群：記錄飲食與進度，遵循個人化營養目標，探索健康計畫，並與朋友互相鼓勵。下載 BIL：{url}',
  'ru':
      'Привет{name}! Присоединяйся ко мне в сообществе BIL: отслеживай питание и прогресс, следуй персональным целям, изучай планы здорового образа жизни и поддерживай друзей. Скачать BIL: {url}',
  'bn':
      'হ্যালো{name}! BIL কমিউনিটিতে আমার সঙ্গে যোগ দিন—খাবার ও অগ্রগতি ট্র্যাক করুন, ব্যক্তিগত পুষ্টি লক্ষ্য অনুসরণ করুন, সুস্থতার পরিকল্পনা দেখুন এবং বন্ধুদের উৎসাহ দিন। BIL ডাউনলোড করুন: {url}',
  'vi':
      'Chào{name}! Hãy tham gia cộng đồng BIL cùng tôi—ghi lại dinh dưỡng và tiến trình, theo đuổi mục tiêu cá nhân, khám phá kế hoạch sức khỏe và động viên bạn bè. Tải BIL: {url}',
  'th':
      'สวัสดี{name}! มาร่วมชุมชน BIL กับฉัน—บันทึกอาหารและความคืบหน้า ทำตามเป้าหมายโภชนาการเฉพาะบุคคล สำรวจแผนสุขภาพ และให้กำลังใจเพื่อน ดาวน์โหลด BIL: {url}',
  'pl':
      'Cześć{name}! Dołącz do mnie w społeczności BIL: zapisuj posiłki i postępy, realizuj spersonalizowane cele żywieniowe, odkrywaj plany wellness i wspieraj znajomych. Pobierz BIL: {url}',
  'nl':
      'Hallo{name}! Word lid van de BIL-community: houd voeding en voortgang bij, volg persoonlijke voedingsdoelen, ontdek wellnessplannen en steun vrienden. Download BIL: {url}',
  'uk':
      'Привіт{name}! Приєднуйся до мене у спільноті BIL: відстежуй харчування і прогрес, дотримуйся персональних цілей, відкривай оздоровчі плани та підтримуй друзів. Завантажити BIL: {url}',
};
