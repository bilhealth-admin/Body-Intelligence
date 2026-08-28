enum CommunityTextSurface {
  post,
  message,
  profileDisplayName,
  profileBio,
  foodName,
  foodLocalizedName,
  foodAlias,
  foodBrand,
  foodReviewNote,
  peerReviewNote,
}

enum CommunityTextViolationKind {
  email,
  urlOrDomain,
  socialHandle,
  phoneNumber,
  offPlatformInvitation,
}

final class CommunityTextPolicyException implements Exception {
  const CommunityTextPolicyException({
    required this.surface,
    required this.kind,
  });

  static const code = 'community_contact_exchange_not_allowed';

  final CommunityTextSurface surface;
  final CommunityTextViolationKind kind;

  String localizedMessage(String localeTag) {
    final normalized = localeTag.trim().replaceAll('_', '-').toLowerCase();
    final exact = CommunityTextPolicy.localizedMessages.entries
        .where((entry) => entry.key.toLowerCase() == normalized)
        .map((entry) => entry.value)
        .firstOrNull;
    if (exact != null) return exact;
    final language = normalized.split('-').first;
    return CommunityTextPolicy.localizedMessages[language] ??
        CommunityTextPolicy.localizedMessages['en']!;
  }

  @override
  String toString() => '$code:${surface.name}:${kind.name}';
}

abstract final class CommunityTextPolicy {
  static const errorCode = CommunityTextPolicyException.code;

  static const localizedMessages = <String, String>{
    'en':
        "To protect your privacy, don't share contact details or ask people to continue outside BIL.",
    'ar':
        'لحماية خصوصيتك، لا تشارك بيانات الاتصال ولا تطلب متابعة المحادثة خارج BIL.',
    'fr':
        'Pour protéger votre vie privée, ne partagez pas vos coordonnées et ne demandez pas de poursuivre hors de BIL.',
    'es':
        'Para proteger tu privacidad, no compartas datos de contacto ni pidas continuar fuera de BIL.',
    'tr':
        'Gizliliğinizi korumak için iletişim bilgisi paylaşmayın veya konuşmayı BIL dışında sürdürmeyi istemeyin.',
    'de':
        'Teile zum Schutz deiner Privatsphäre keine Kontaktdaten und bitte nicht darum, das Gespräch außerhalb von BIL fortzusetzen.',
    'it':
        'Per proteggere la tua privacy, non condividere contatti e non chiedere di continuare fuori da BIL.',
    'pt-BR':
        'Para proteger sua privacidade, não compartilhe contatos nem peça para continuar fora do BIL.',
    'pt-PT':
        'Para proteger a sua privacidade, não partilhe contactos nem peça para continuar fora do BIL.',
    'ur':
        'اپنی رازداری کے تحفظ کے لیے رابطے کی معلومات شیئر نہ کریں اور گفتگو BIL سے باہر جاری رکھنے کو نہ کہیں۔',
    'fa':
        'برای حفظ حریم خصوصی، اطلاعات تماس را به اشتراک نگذارید و درخواست ادامه گفتگو خارج از BIL نکنید.',
    'hi':
        'अपनी गोपनीयता के लिए संपर्क जानकारी साझा न करें और बातचीत BIL के बाहर जारी रखने को न कहें।',
    'id':
        'Untuk melindungi privasi, jangan bagikan detail kontak atau mengajak melanjutkan percakapan di luar BIL.',
    'ms':
        'Untuk melindungi privasi, jangan kongsi butiran hubungan atau ajak meneruskan perbualan di luar BIL.',
    'ja': 'プライバシー保護のため、連絡先を共有したり、BILの外で会話を続けるよう求めたりしないでください。',
    'ko': '개인정보 보호를 위해 연락처를 공유하거나 BIL 밖에서 대화를 계속하자고 요청하지 마세요.',
    'zh-Hans': '为保护隐私，请勿分享联系方式，也不要邀请他人在 BIL 之外继续交流。',
    'zh-Hant': '為保護隱私，請勿分享聯絡方式，也不要邀請他人在 BIL 之外繼續交流。',
    'ru':
        'Чтобы защитить конфиденциальность, не сообщайте контакты и не предлагайте продолжить общение вне BIL.',
    'bn':
        'গোপনীয়তা রক্ষায় যোগাযোগের তথ্য শেয়ার করবেন না এবং BIL-এর বাইরে কথা চালিয়ে যেতে বলবেন না।',
    'vi':
        'Để bảo vệ quyền riêng tư, đừng chia sẻ thông tin liên hệ hoặc đề nghị tiếp tục trò chuyện bên ngoài BIL.',
    'th': 'เพื่อปกป้องความเป็นส่วนตัว อย่าแชร์ข้อมูลติดต่อหรือชวนคุยต่อนอก BIL',
    'pl':
        'Aby chronić prywatność, nie udostępniaj danych kontaktowych ani nie proponuj rozmowy poza BIL.',
    'nl':
        'Deel om je privacy te beschermen geen contactgegevens en vraag niet om buiten BIL verder te praten.',
    'uk':
        'Щоб захистити приватність, не повідомляйте контакти й не пропонуйте продовжити спілкування поза BIL.',
  };

  static const _digitCharacters = '0-9٠-٩۰-۹०-९০-৯０-９';

  static final RegExp _email = RegExp(
    r"[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+",
    caseSensitive: false,
  );
  static final RegExp _url = RegExp(
    r'(?:https?://|www\.)[^\s<>{}]+',
    caseSensitive: false,
  );
  static final RegExp _domain = RegExp(
    r'(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+(?:com|net|org|io|me|co|app|dev|ai|info|biz|xyz|site|online|link|health|fitness|social|chat|club|live|cloud|store|pro|world|gg|tv|ly|sa|ae|eg|uk|de|fr|es|tr|in|pk|bd|id|my|jp|kr|cn|ru|nl|pl|ua)\b',
    caseSensitive: false,
  );
  static final RegExp _handle = RegExp(
    r'(^|[\s(\[{])@[^\s@.,;:!?/\\]{2,32}',
    caseSensitive: false,
  );
  static final RegExp _phoneCandidate = RegExp(
    '(?:\\+?[\\s(.\\-\u2010-\u2015\u2212]*)?(?:[$_digitCharacters][\\s().\\-\u2010-\u2015\u2212]*){7,20}',
  );
  static final RegExp _date = RegExp(
    r'^(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})$',
  );
  static final RegExp _compactDate = RegExp(
    r'^(?:(?:19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])|(?:0[1-9]|[12]\d|3[01])(?:0[1-9]|1[0-2])(?:19|20)\d{2})$',
  );

  static const _platforms =
      r'whats?app|telegram|signal|instagram|insta|snapchat|snap|facebook|messenger|discord|wechat|微信|viber|tiktok|line|واتس\s*آب|واتساب|تلغرام|تيليجرام|انستغرام|إنستغرام|سناب(?:\s*شات)?|فيسبوك|ديسكورد|سيجنال|व्हाट्सएप|टेलीग्राम|इंस्टाग्राम';
  static const _inviteTerms =
      r'message\s+me|contact\s+me|text\s+me|add\s+me|follow\s+me|find\s+me|reach\s+me|dm\s+me|continue|move|switch|write\s+me|écris-moi|contacte-moi|ajoute-moi|continu(?:er|ons)|escríbeme|contacta(?:me| conmigo)|sígueme|hablemos|continu(?:ar|emos)|yaz(?:ın)?|ulaş|ekle|takip\s+et|konuş|devam\s+et|schreib\s+mir|kontaktiere\s+mich|scrivimi|contattami|fale\s+comigo|me\s+chama|напиши\s+мне|свяжись|hubungi\s+saya|kirim\s+pesan|連絡|メッセージ|연락|메시지|联系我|加我|私信|যোগাযোগ|বার্তা|nhắn\s+tin|liên\s+hệ|ติดต่อ|ส่งข้อความ|napisz\s+do\s+mnie|skontaktuj|stuur\s+me|voeg\s+me\s+toe|напиши\s+мені|راسلني|تواصل\s+معي|كلمني|أضفني|تابعني|نكمل|ننقل|مرا\s+رابطہ|پیغام|جاری|संपर्क|संदेश|जारी';
  static final RegExp _platformInvitation = RegExp(
    '(?:$_inviteTerms)[^\\n]{0,40}(?:$_platforms)|(?:$_platforms)[^\\n]{0,40}(?:$_inviteTerms)',
    caseSensitive: false,
  );
  static final RegExp _moveOutsideBil = RegExp(
    r'(?:continue|move|take|switch).{0,28}(?:outside|off|away\s+from).{0,12}bil|(?:نكمل|ننقل).{0,30}(?:خارج|برا).{0,12}bil|(?:continuar|continuer|devam).{0,30}(?:fuera|hors|dışında).{0,12}bil',
    caseSensitive: false,
  );

  static CommunityTextViolationKind? firstViolation(String value) {
    if (_email.hasMatch(value)) return CommunityTextViolationKind.email;
    if (_url.hasMatch(value) || _domain.hasMatch(value)) {
      return CommunityTextViolationKind.urlOrDomain;
    }
    if (_handle.hasMatch(value)) {
      return CommunityTextViolationKind.socialHandle;
    }
    if (_containsPhoneNumber(value)) {
      return CommunityTextViolationKind.phoneNumber;
    }
    if (_platformInvitation.hasMatch(value) ||
        _moveOutsideBil.hasMatch(value)) {
      return CommunityTextViolationKind.offPlatformInvitation;
    }
    return null;
  }

  static void enforce(String value, {required CommunityTextSurface surface}) {
    final violation = firstViolation(value);
    if (violation == null) return;
    throw CommunityTextPolicyException(surface: surface, kind: violation);
  }

  static void enforceAll(Map<CommunityTextSurface, String?> values) {
    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null || value.trim().isEmpty) continue;
      enforce(value, surface: entry.key);
    }
  }

  static bool _containsPhoneNumber(String value) {
    for (final match in _phoneCandidate.allMatches(value)) {
      final normalized = _normalizeDigits(match.group(0)!).trim();
      final compact = normalized.replaceAll(RegExp(r'\s+'), '');
      final dateCandidate = compact.replaceFirst(RegExp(r'[().-]+$'), '');
      if (_date.hasMatch(dateCandidate) ||
          _compactDate.hasMatch(dateCandidate)) {
        continue;
      }
      final digitCount = RegExp(r'\d').allMatches(compact).length;
      if (digitCount >= 7 && digitCount <= 20) return true;
    }
    return false;
  }

  static String _normalizeDigits(String value) {
    const source = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹०१२३४५६७८९০১২৩৪৫৬৭৮৯０１２３４５６７８９';
    const target = '01234567890123456789012345678901234567890123456789';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final index = source.indexOf(character);
      buffer.write(index < 0 ? character : target[index]);
    }
    return buffer.toString();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
