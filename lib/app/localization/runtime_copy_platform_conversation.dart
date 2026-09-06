import 'bil_locale_policy.dart';

/// Reviewed labels shared by native health surfaces and AI conversation UI.
///
/// Apple Health and Health Connect are official product names, so they remain
/// unchanged. Every other label has an explicit translation for each release
/// locale; an untranslated English label is treated as an unbalanced catalog.
abstract final class PlatformConversationRuntimeCopy {
  static const appleHealth = 'Apple Health';
  static const healthConnect = 'Health Connect';
  static const conversationHistory = 'Conversation history';
  static const openEarlierChat = 'Open an earlier chat or start a new one';
  static const openConversationHistory = 'Open conversation history';
  static const speakYourLanguage = 'Speak your language';

  static const sources = <String>[
    appleHealth,
    healthConnect,
    conversationHistory,
    openEarlierChat,
    openConversationHistory,
    speakYourLanguage,
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
    'ar': [
      appleHealth,
      healthConnect,
      'سجل المحادثات',
      'افتح محادثة سابقة أو ابدأ محادثة جديدة',
      'افتح سجل المحادثات',
      'تحدث بلغتك',
    ],
    'en': sources,
    'fr': [
      appleHealth,
      healthConnect,
      'Historique des conversations',
      'Ouvrez une conversation précédente ou commencez-en une nouvelle',
      'Ouvrir l’historique des conversations',
      'Parlez dans votre langue',
    ],
    'es': [
      appleHealth,
      healthConnect,
      'Historial de conversaciones',
      'Abre una conversación anterior o inicia una nueva',
      'Abrir el historial de conversaciones',
      'Habla en tu idioma',
    ],
    'tr': [
      appleHealth,
      healthConnect,
      'Konuşma geçmişi',
      'Önceki bir sohbeti açın veya yeni bir sohbet başlatın',
      'Konuşma geçmişini aç',
      'Kendi dilinizde konuşun',
    ],
    'de': [
      appleHealth,
      healthConnect,
      'Gesprächsverlauf',
      'Öffnen Sie einen früheren Chat oder beginnen Sie einen neuen',
      'Gesprächsverlauf öffnen',
      'Sprechen Sie in Ihrer Sprache',
    ],
    'it': [
      appleHealth,
      healthConnect,
      'Cronologia delle conversazioni',
      'Apri una chat precedente o iniziane una nuova',
      'Apri la cronologia delle conversazioni',
      'Parla nella tua lingua',
    ],
    'pt-BR': [
      appleHealth,
      healthConnect,
      'Histórico de conversas',
      'Abra uma conversa anterior ou inicie uma nova',
      'Abrir o histórico de conversas',
      'Fale no seu idioma',
    ],
    'pt-PT': [
      appleHealth,
      healthConnect,
      'Histórico de conversas',
      'Abra uma conversa anterior ou inicie uma nova',
      'Abrir o histórico de conversas',
      'Fale na sua língua',
    ],
    'ur': [
      appleHealth,
      healthConnect,
      'گفتگو کی سرگزشت',
      'پچھلی گفتگو کھولیں یا نئی گفتگو شروع کریں',
      'گفتگو کی سرگزشت کھولیں',
      'اپنی زبان میں بات کریں',
    ],
    'fa': [
      appleHealth,
      healthConnect,
      'تاریخچه گفتگوها',
      'گفتگویی قبلی را باز کنید یا گفتگویی تازه آغاز کنید',
      'باز کردن تاریخچه گفتگوها',
      'به زبان خودتان صحبت کنید',
    ],
    'hi': [
      appleHealth,
      healthConnect,
      'बातचीत का इतिहास',
      'पिछली बातचीत खोलें या नई बातचीत शुरू करें',
      'बातचीत का इतिहास खोलें',
      'अपनी भाषा में बोलें',
    ],
    'id': [
      appleHealth,
      healthConnect,
      'Riwayat percakapan',
      'Buka percakapan sebelumnya atau mulai percakapan baru',
      'Buka riwayat percakapan',
      'Bicara dalam bahasa Anda',
    ],
    'ms': [
      appleHealth,
      healthConnect,
      'Sejarah perbualan',
      'Buka perbualan terdahulu atau mulakan perbualan baharu',
      'Buka sejarah perbualan',
      'Bercakap dalam bahasa anda',
    ],
    'ja': [
      appleHealth,
      healthConnect,
      '会話履歴',
      '過去のチャットを開くか、新しいチャットを始めます',
      '会話履歴を開く',
      'あなたの言語で話す',
    ],
    'ko': [
      appleHealth,
      healthConnect,
      '대화 기록',
      '이전 채팅을 열거나 새 채팅을 시작하세요',
      '대화 기록 열기',
      '원하는 언어로 말하세요',
    ],
    'zh-Hans': [
      appleHealth,
      healthConnect,
      '对话记录',
      '打开之前的聊天或开始新聊天',
      '打开对话记录',
      '使用你的语言交流',
    ],
    'zh-Hant': [
      appleHealth,
      healthConnect,
      '對話記錄',
      '開啟先前的聊天或開始新聊天',
      '開啟對話記錄',
      '使用你的語言交流',
    ],
    'ru': [
      appleHealth,
      healthConnect,
      'История разговоров',
      'Откройте предыдущий чат или начните новый',
      'Открыть историю разговоров',
      'Говорите на своём языке',
    ],
    'bn': [
      appleHealth,
      healthConnect,
      'কথোপকথনের ইতিহাস',
      'আগের চ্যাট খুলুন অথবা নতুন চ্যাট শুরু করুন',
      'কথোপকথনের ইতিহাস খুলুন',
      'আপনার ভাষায় কথা বলুন',
    ],
    'vi': [
      appleHealth,
      healthConnect,
      'Lịch sử trò chuyện',
      'Mở cuộc trò chuyện trước hoặc bắt đầu cuộc trò chuyện mới',
      'Mở lịch sử trò chuyện',
      'Nói bằng ngôn ngữ của bạn',
    ],
    'th': [
      appleHealth,
      healthConnect,
      'ประวัติการสนทนา',
      'เปิดแชตก่อนหน้าหรือเริ่มแชตใหม่',
      'เปิดประวัติการสนทนา',
      'พูดด้วยภาษาของคุณ',
    ],
    'pl': [
      appleHealth,
      healthConnect,
      'Historia rozmów',
      'Otwórz wcześniejszy czat lub rozpocznij nowy',
      'Otwórz historię rozmów',
      'Mów w swoim języku',
    ],
    'nl': [
      appleHealth,
      healthConnect,
      'Gespreksgeschiedenis',
      'Open een eerder gesprek of begin een nieuw gesprek',
      'Gespreksgeschiedenis openen',
      'Spreek in je eigen taal',
    ],
    'uk': [
      appleHealth,
      healthConnect,
      'Історія розмов',
      'Відкрийте попередній чат або почніть новий',
      'Відкрити історію розмов',
      'Говоріть своєю мовою',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = _canonicalTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing platform/conversation runtime copy for $tag.');
    }
    return row[index];
  }

  static bool get balanced =>
      supported.length == BilLocalePolicy.productionTags.length &&
      supported.containsAll(BilLocalePolicy.productionTags) &&
      BilLocalePolicy.productionTags.containsAll(supported) &&
      rows.keys.toSet().containsAll(supported) &&
      supported.containsAll(rows.keys) &&
      rows.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((value) => value.trim().isNotEmpty) &&
            row[0] == appleHealth &&
            row[1] == healthConnect,
      ) &&
      _sameValues(rows['en'], sources) &&
      rows.entries
          .where((entry) => entry.key != 'en')
          .every(
            (entry) =>
                entry.value[2] != conversationHistory &&
                entry.value[3] != openEarlierChat &&
                entry.value[4] != openConversationHistory &&
                entry.value[5] != speakYourLanguage,
          );

  static String? _canonicalTag(String localeTag) {
    final exact = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (exact != null) return exact;
    final language = localeTag
        .trim()
        .replaceAll('_', '-')
        .toLowerCase()
        .split('-')
        .first;
    final matches = supported
        .where((candidate) => candidate.toLowerCase() == language)
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  static bool _sameValues(List<String>? left, List<String> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < right.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
