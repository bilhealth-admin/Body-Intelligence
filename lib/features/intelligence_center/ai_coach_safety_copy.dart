import '../../app/localization/bil_locale_policy.dart';

/// Local, provider-neutral copy for a blocked AI Coach response.
///
/// Every production locale is explicit so a safety response never falls back
/// to a different interface language. The message deliberately contains no
/// retry action; the user may submit a meaningfully rephrased new question.
abstract final class AiCoachSafetyCopy {
  static String resolve(String locale) {
    final tag = BilLocalePolicy.canonicalSupportedTag(locale) ?? 'en';
    return _values[tag]!;
  }

  static Map<String, String> get values => _values;

  static const _values = <String, String>{
    'ar':
        'تعذر تقديم هذا الرد بأمان، لذلك لن أعرض ردًا من الذكاء الاصطناعي ولم تُحتسب الرسالة. أعد الصياغة من دون حذف الأعراض المهمة. إذا كان هناك خطر فوري أو أعراض شديدة أو احتمال لإيذاء النفس، فاتصل بخدمات الطوارئ المحلية الآن.',
    'en':
        'I couldn’t provide this answer safely, so no AI reply is shown and no message was charged. Rephrase without removing important symptoms. If there is immediate danger, severe symptoms, or self-harm risk, contact local emergency services now.',
    'fr':
        'Je n’ai pas pu fournir cette réponse en toute sécurité : aucune réponse de l’IA n’est affichée et aucun message n’a été débité. Reformulez sans omettre les symptômes importants. En cas de danger immédiat, de symptômes graves ou de risque d’automutilation, contactez maintenant les services d’urgence locaux.',
    'es':
        'No pude ofrecer esta respuesta de forma segura, así que no se muestra ninguna respuesta de IA ni se cobró el mensaje. Reformúlala sin omitir síntomas importantes. Si hay peligro inmediato, síntomas graves o riesgo de autolesión, contacta ahora con los servicios de emergencia locales.',
    'tr':
        'Bu yanıt güvenli biçimde verilemedi; bu nedenle bir yapay zekâ yanıtı gösterilmedi ve mesaj hakkınızdan düşülmedi. Önemli belirtileri çıkarmadan yeniden ifade edin. Acil tehlike, ağır belirtiler veya kendine zarar verme riski varsa yerel acil servislerle hemen iletişime geçin.',
    'de':
        'Diese Antwort konnte nicht sicher bereitgestellt werden. Daher wird keine KI-Antwort angezeigt und keine Nachricht berechnet. Formuliere die Frage neu, ohne wichtige Symptome wegzulassen. Bei unmittelbarer Gefahr, schweren Symptomen oder Selbstverletzungsgefahr kontaktiere jetzt den örtlichen Notdienst.',
    'it':
        'Non ho potuto fornire questa risposta in modo sicuro, quindi non viene mostrata alcuna risposta IA e il messaggio non è stato addebitato. Riformula senza omettere sintomi importanti. In caso di pericolo immediato, sintomi gravi o rischio di autolesionismo, contatta subito i servizi di emergenza locali.',
    'pt-BR':
        'Não foi possível fornecer esta resposta com segurança; por isso, nenhuma resposta de IA é exibida e nenhuma mensagem foi cobrada. Reformule sem omitir sintomas importantes. Se houver perigo imediato, sintomas graves ou risco de autoagressão, contate agora os serviços de emergência locais.',
    'pt-PT':
        'Não foi possível fornecer esta resposta em segurança; por isso, não é apresentada nenhuma resposta de IA nem foi descontada nenhuma mensagem. Reformule sem omitir sintomas importantes. Se houver perigo imediato, sintomas graves ou risco de autoagressão, contacte agora os serviços de emergência locais.',
    'ur':
        'یہ جواب محفوظ طریقے سے فراہم نہیں کیا جا سکا، اس لیے کوئی AI جواب نہیں دکھایا گیا اور کوئی پیغام شمار نہیں ہوا۔ اہم علامات حذف کیے بغیر سوال دوبارہ لکھیں۔ اگر فوری خطرہ، شدید علامات یا خود کو نقصان پہنچانے کا خدشہ ہو تو ابھی مقامی ایمرجنسی سروسز سے رابطہ کریں۔',
    'fa':
        'ارائهٔ ایمن این پاسخ ممکن نبود؛ بنابراین هیچ پاسخ هوش مصنوعی نمایش داده نشد و پیامی محاسبه نشد. پرسش را بدون حذف علائم مهم بازنویسی کنید. اگر خطر فوری، علائم شدید یا احتمال آسیب‌زدن به خود وجود دارد، اکنون با خدمات اورژانس محلی تماس بگیرید.',
    'hi':
        'यह उत्तर सुरक्षित रूप से नहीं दिया जा सका, इसलिए कोई AI उत्तर नहीं दिखाया गया और कोई संदेश नहीं गिना गया। महत्वपूर्ण लक्षण हटाए बिना प्रश्न को दोबारा लिखें। यदि तुरंत खतरा, गंभीर लक्षण या खुद को नुकसान पहुँचाने का जोखिम हो, तो अभी स्थानीय आपातकालीन सेवाओं से संपर्क करें।',
    'id':
        'Jawaban ini tidak dapat diberikan dengan aman, jadi tidak ada jawaban AI yang ditampilkan dan pesan tidak dihitung. Tulis ulang tanpa menghapus gejala penting. Jika ada bahaya langsung, gejala berat, atau risiko menyakiti diri, hubungi layanan darurat setempat sekarang.',
    'ms':
        'Jawapan ini tidak dapat diberikan dengan selamat, jadi tiada jawapan AI dipaparkan dan mesej tidak dikira. Tulis semula tanpa membuang gejala penting. Jika terdapat bahaya segera, gejala serius atau risiko mencederakan diri, hubungi perkhidmatan kecemasan tempatan sekarang.',
    'ja':
        'この回答は安全に提供できなかったため、AIの回答は表示されず、メッセージも消費されていません。重要な症状を省かずに言い換えてください。差し迫った危険、重い症状、自傷のおそれがある場合は、今すぐ地域の救急サービスに連絡してください。',
    'ko':
        '이 답변은 안전하게 제공할 수 없어 AI 답변을 표시하지 않았으며 메시지도 차감되지 않았습니다. 중요한 증상을 빼지 말고 다시 표현해 주세요. 즉각적인 위험, 심각한 증상 또는 자해 위험이 있다면 지금 지역 응급 서비스에 연락하세요.',
    'zh-Hans':
        '无法安全提供此回答，因此不会显示 AI 回复，也不会计入本次消息。请在不遗漏重要症状的情况下重新表述。如果存在紧迫危险、严重症状或自伤风险，请立即联系当地急救服务。',
    'zh-Hant':
        '無法安全提供此回答，因此不會顯示 AI 回覆，也不會計入本次訊息。請在不遺漏重要症狀的情況下重新表述。如果有緊迫危險、嚴重症狀或自傷風險，請立即聯絡當地緊急服務。',
    'ru':
        'Этот ответ нельзя было предоставить безопасно, поэтому ответ ИИ не показан и сообщение не списано. Переформулируйте вопрос, не исключая важные симптомы. При непосредственной опасности, тяжёлых симптомах или риске самоповреждения немедленно обратитесь в местную экстренную службу.',
    'bn':
        'এই উত্তরটি নিরাপদভাবে দেওয়া যায়নি, তাই কোনো AI উত্তর দেখানো হয়নি এবং কোনো বার্তা গণনা করা হয়নি। গুরুত্বপূর্ণ উপসর্গ বাদ না দিয়ে প্রশ্নটি আবার লিখুন। তাৎক্ষণিক বিপদ, গুরুতর উপসর্গ বা নিজেকে আঘাত করার ঝুঁকি থাকলে এখনই স্থানীয় জরুরি সেবায় যোগাযোগ করুন।',
    'vi':
        'Không thể cung cấp câu trả lời này một cách an toàn, nên không hiển thị câu trả lời AI và tin nhắn không bị tính. Hãy diễn đạt lại mà không bỏ sót triệu chứng quan trọng. Nếu có nguy hiểm tức thời, triệu chứng nghiêm trọng hoặc nguy cơ tự làm hại bản thân, hãy liên hệ dịch vụ cấp cứu địa phương ngay.',
    'th':
        'ไม่สามารถให้คำตอบนี้ได้อย่างปลอดภัย จึงไม่แสดงคำตอบจาก AI และไม่นับข้อความนี้ โปรดเรียบเรียงใหม่โดยไม่ตัดอาการสำคัญออก หากมีอันตรายฉุกเฉิน อาการรุนแรง หรือความเสี่ยงที่จะทำร้ายตนเอง ให้ติดต่อบริการฉุกเฉินในพื้นที่ทันที',
    'pl':
        'Nie udało się bezpiecznie udzielić tej odpowiedzi, dlatego odpowiedź AI nie jest wyświetlana, a wiadomość nie została naliczona. Sformułuj pytanie ponownie, nie pomijając ważnych objawów. W razie bezpośredniego zagrożenia, ciężkich objawów lub ryzyka samookaleczenia natychmiast skontaktuj się z lokalnymi służbami ratunkowymi.',
    'nl':
        'Dit antwoord kon niet veilig worden gegeven. Daarom wordt geen AI-antwoord getoond en is geen bericht in rekening gebracht. Formuleer de vraag opnieuw zonder belangrijke symptomen weg te laten. Neem bij direct gevaar, ernstige symptomen of risico op zelfbeschadiging nu contact op met de lokale hulpdiensten.',
    'uk':
        'Цю відповідь не вдалося надати безпечно, тому відповідь ШІ не показано й повідомлення не списано. Переформулюйте запит, не вилучаючи важливі симптоми. За безпосередньої небезпеки, тяжких симптомів або ризику самоушкодження негайно зверніться до місцевої екстреної служби.',
  };
}
