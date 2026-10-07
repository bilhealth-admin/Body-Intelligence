import 'bil_locale_policy.dart';

/// Conditional reward copy, independent of all Gold and billing policies.
abstract final class CommunityAiRewardRuntimeCopy {
  static const sources = <String>[
    "AI token reward",
    "Eligible posts earn +5 AI tokens after moderator approval. AI tokens are not BIL Gold and cannot be cashed out. Opening or saving a draft earns nothing.",
  ];

  static const rows = <String, List<String>>{
    'en': sources,
    "ar": [
      "مكافأة توكنات AI",
      "المنشورات المؤهلة تكسب +5 توكنات AI بعد موافقة المشرف. توكنات AI ليست BIL Gold ولا تُستبدل بنقود. فتح المسودة أو حفظها لا يمنح مكافأة.",
    ],
    "fr": [
      "Récompense en jetons IA",
      "Les publications admissibles rapportent +5 jetons IA après approbation par un modérateur. Ces jetons ne sont pas du BIL Gold et ne sont pas convertibles en argent. Ouvrir ou enregistrer un brouillon ne rapporte rien.",
    ],
    "es": [
      "Recompensa de tokens de IA",
      "Las publicaciones aptas reciben +5 tokens de IA tras la aprobación de un moderador. No son BIL Gold ni se pueden canjear por dinero. Abrir o guardar un borrador no otorga recompensas.",
    ],
    "de": [
      "KI-Token-Belohnung",
      "Geeignete Beiträge erhalten nach Freigabe durch die Moderation +5 KI-Token. Diese sind kein BIL Gold und können nicht ausgezahlt werden. Das Öffnen oder Speichern eines Entwurfs bringt keine Belohnung.",
    ],
    "it": [
      "Ricompensa in token IA",
      "I post idonei ricevono +5 token IA dopo l’approvazione di un moderatore. Non sono BIL Gold e non sono convertibili in denaro. Aprire o salvare una bozza non dà ricompense.",
    ],
    "pt-BR": [
      "Recompensa em tokens de IA",
      "Publicações elegíveis recebem +5 tokens de IA após a aprovação de um moderador. Esses tokens não são BIL Gold nem podem ser trocados por dinheiro. Abrir ou salvar um rascunho não gera recompensa.",
    ],
    "pt-PT": [
      "Recompensa em tokens de IA",
      "As publicações elegíveis recebem +5 tokens de IA após a aprovação de um moderador. Estes tokens não são BIL Gold nem podem ser convertidos em dinheiro. Abrir ou guardar um rascunho não gera recompensa.",
    ],
    "ru": [
      "Награда в токенах ИИ",
      "Подходящие публикации получают +5 токенов ИИ после одобрения модератором. Это не BIL Gold, их нельзя обменять на деньги. Открытие или сохранение черновика не приносит награды.",
    ],
    "tr": [
      "Yapay zekâ token ödülü",
      "Uygun gönderiler moderatör onayından sonra +5 yapay zekâ tokeni kazanır. Bunlar BIL Gold değildir ve nakde çevrilemez. Taslak açmak veya kaydetmek ödül kazandırmaz.",
    ],
    "hi": [
      "AI टोकन पुरस्कार",
      "पात्र पोस्ट को मॉडरेटर की मंज़ूरी के बाद +5 AI टोकन मिलते हैं। ये BIL Gold नहीं हैं और इन्हें नकद में नहीं बदला जा सकता। ड्राफ़्ट खोलने या सहेजने पर कोई पुरस्कार नहीं मिलता।",
    ],
    "ur": [
      "AI ٹوکن انعام",
      "اہل پوسٹس کو ماڈریٹر کی منظوری کے بعد +5 AI ٹوکن ملتے ہیں۔ یہ BIL Gold نہیں ہیں اور انہیں نقد رقم میں تبدیل نہیں کیا جا سکتا۔ مسودہ کھولنے یا محفوظ کرنے سے انعام نہیں ملتا۔",
    ],
    "fa": [
      "پاداش توکن هوش مصنوعی",
      "پست‌های واجد شرایط پس از تأیید ناظر +5 توکن هوش مصنوعی دریافت می‌کنند. این توکن‌ها BIL Gold نیستند و به پول نقد تبدیل نمی‌شوند. باز کردن یا ذخیرهٔ پیش‌نویس پاداشی ندارد.",
    ],
    "bn": [
      "AI টোকেন পুরস্কার",
      "যোগ্য পোস্ট মডারেটরের অনুমোদনের পরে +5 AI টোকেন পায়। এগুলি BIL Gold নয় এবং নগদে রূপান্তর করা যায় না। খসড়া খুললে বা সংরক্ষণ করলে কোনো পুরস্কার পাওয়া যায় না।",
    ],
    "id": [
      "Hadiah token AI",
      "Postingan yang memenuhi syarat mendapat +5 token AI setelah disetujui moderator. Token ini bukan BIL Gold dan tidak dapat diuangkan. Membuka atau menyimpan draf tidak memberikan hadiah.",
    ],
    "ms": [
      "Ganjaran token AI",
      "Siaran yang layak menerima +5 token AI selepas kelulusan moderator. Token ini bukan BIL Gold dan tidak boleh ditukar kepada wang tunai. Membuka atau menyimpan draf tidak memberikan ganjaran.",
    ],
    "vi": [
      "Phần thưởng token AI",
      "Bài đăng đủ điều kiện nhận +5 token AI sau khi người kiểm duyệt phê duyệt. Token này không phải BIL Gold và không thể đổi thành tiền mặt. Mở hoặc lưu bản nháp không nhận được thưởng.",
    ],
    "zh-Hans": [
      "AI 代币奖励",
      "符合条件的帖子经版主批准后可获得 +5 AI 代币。AI 代币不是 BIL Gold，且不能提现。打开或保存草稿不会获得奖励。",
    ],
    "zh-Hant": [
      "AI 代幣獎勵",
      "符合資格的貼文經版主核准後可獲得 +5 AI 代幣。AI 代幣不是 BIL Gold，且不能兌現。開啟或儲存草稿不會獲得獎勵。",
    ],
    "ja": [
      "AIトークン報酬",
      "対象の投稿はモデレーターの承認後に +5 AIトークンを獲得できます。AIトークンはBIL Goldとは異なり、換金できません。下書きを開く・保存するだけでは報酬は得られません。",
    ],
    "ko": [
      "AI 토큰 보상",
      "자격 요건을 충족한 게시물은 관리자 승인 후 +5 AI 토큰을 받습니다. AI 토큰은 BIL Gold가 아니며 현금으로 바꿀 수 없습니다. 초안을 열거나 저장하는 것만으로는 보상을 받지 않습니다.",
    ],
    "th": [
      "รางวัลโทเคน AI",
      "โพสต์ที่เข้าเกณฑ์จะได้รับ +5 โทเคน AI หลังผู้ดูแลอนุมัติ โทเคน AI ไม่ใช่ BIL Gold และแลกเป็นเงินสดไม่ได้ การเปิดหรือบันทึกฉบับร่างไม่ได้รับรางวัล",
    ],
    "pl": [
      "Nagroda w tokenach AI",
      "Kwalifikujące się posty otrzymują +5 tokenów AI po zatwierdzeniu przez moderatora. To nie jest BIL Gold i nie można ich wymienić na gotówkę. Otwarcie lub zapisanie szkicu nie daje nagrody.",
    ],
    "nl": [
      "Beloning in AI-tokens",
      "Geschikte berichten verdienen +5 AI-tokens na goedkeuring door een moderator. Dit is geen BIL Gold en de tokens zijn niet inwisselbaar voor geld. Het openen of opslaan van een concept levert niets op.",
    ],
    "uk": [
      "Нагорода в токенах ШІ",
      "Відповідні дописи отримують +5 токенів ШІ після схвалення модератором. Це не BIL Gold, їх не можна обміняти на гроші. Відкриття або збереження чернетки не дає нагороди.",
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    final row = rows[tag];
    if (row == null) return null;
    if (row.length != sources.length) {
      throw StateError('Incomplete Community AI reward copy for $tag');
    }
    return row[index];
  }
}
