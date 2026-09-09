import '../../../app/localization/bil_locale_policy.dart';

/// Copy that was previously English-only in the 20 extended BIL locales.
/// The five original Community locales remain in the calling widget.
abstract final class CommunityChatRuntimeCopy {
  static const sources = <String>[
    'Message could not be sent. Your text is kept.',
    'Sign in to open messages.',
    'Your health data is never shown in messages.',
    'Could not load this chat. Try again.',
  ];

  static const values = <String, List<String>>{
    'de': [
      'Die Nachricht konnte nicht gesendet werden. Dein Text bleibt erhalten.',
      'Melde dich an, um Nachrichten zu öffnen.',
      'Deine Gesundheitsdaten werden nie in Nachrichten angezeigt.',
      'Dieser Chat konnte nicht geladen werden. Versuche es erneut.',
    ],
    'it': [
      'Impossibile inviare il messaggio. Il testo è stato conservato.',
      'Accedi per aprire i messaggi.',
      'I tuoi dati sanitari non vengono mai mostrati nei messaggi.',
      'Impossibile caricare questa chat. Riprova.',
    ],
    'pt-BR': [
      'Não foi possível enviar a mensagem. Seu texto foi mantido.',
      'Entre para abrir as mensagens.',
      'Seus dados de saúde nunca aparecem nas mensagens.',
      'Não foi possível carregar esta conversa. Tente novamente.',
    ],
    'pt-PT': [
      'Não foi possível enviar a mensagem. O seu texto foi mantido.',
      'Inicie sessão para abrir as mensagens.',
      'Os seus dados de saúde nunca aparecem nas mensagens.',
      'Não foi possível carregar esta conversa. Tente novamente.',
    ],
    'ur': [
      'پیغام نہیں بھیجا جا سکا۔ آپ کا متن محفوظ ہے۔',
      'پیغامات کھولنے کے لیے سائن ان کریں۔',
      'آپ کا صحت کا ڈیٹا پیغامات میں کبھی نہیں دکھایا جاتا۔',
      'یہ گفتگو لوڈ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
    ],
    'fa': [
      'پیام ارسال نشد. متن شما حفظ شده است.',
      'برای باز کردن پیام‌ها وارد شوید.',
      'داده‌های سلامت شما هرگز در پیام‌ها نمایش داده نمی‌شود.',
      'این گفتگو بارگیری نشد. دوباره تلاش کنید.',
    ],
    'hi': [
      'संदेश नहीं भेजा जा सका। आपका लिखा हुआ पाठ सुरक्षित है।',
      'संदेश खोलने के लिए साइन इन करें।',
      'आपका स्वास्थ्य डेटा संदेशों में कभी नहीं दिखाया जाता।',
      'यह चैट लोड नहीं हो सकी। फिर से कोशिश करें।',
    ],
    'id': [
      'Pesan tidak dapat dikirim. Teks Anda tetap tersimpan.',
      'Masuk untuk membuka pesan.',
      'Data kesehatan Anda tidak pernah ditampilkan dalam pesan.',
      'Obrolan ini tidak dapat dimuat. Coba lagi.',
    ],
    'ms': [
      'Mesej tidak dapat dihantar. Teks anda masih disimpan.',
      'Log masuk untuk membuka mesej.',
      'Data kesihatan anda tidak pernah dipaparkan dalam mesej.',
      'Sembang ini tidak dapat dimuatkan. Cuba lagi.',
    ],
    'ja': [
      'メッセージを送信できませんでした。入力した文章は保持されています。',
      'メッセージを開くにはサインインしてください。',
      '健康データがメッセージに表示されることはありません。',
      'このチャットを読み込めませんでした。もう一度お試しください。',
    ],
    'ko': [
      '메시지를 보내지 못했습니다. 작성한 내용은 보관됩니다.',
      '메시지를 열려면 로그인하세요.',
      '건강 데이터는 메시지에 표시되지 않습니다.',
      '이 채팅을 불러오지 못했습니다. 다시 시도하세요.',
    ],
    'zh-Hans': [
      '无法发送消息。你输入的文字已保留。',
      '登录后打开消息。',
      '你的健康数据绝不会显示在消息中。',
      '无法加载此聊天。请重试。',
    ],
    'zh-Hant': [
      '無法傳送訊息。你輸入的文字已保留。',
      '登入後開啟訊息。',
      '你的健康資料絕不會顯示在訊息中。',
      '無法載入此聊天。請再試一次。',
    ],
    'ru': [
      'Не удалось отправить сообщение. Ваш текст сохранён.',
      'Войдите, чтобы открыть сообщения.',
      'Ваши данные о здоровье никогда не показываются в сообщениях.',
      'Не удалось загрузить этот чат. Повторите попытку.',
    ],
    'bn': [
      'বার্তাটি পাঠানো যায়নি। আপনার লেখা সংরক্ষিত আছে।',
      'বার্তা খুলতে সাইন ইন করুন।',
      'আপনার স্বাস্থ্যতথ্য কখনো বার্তায় দেখানো হয় না।',
      'এই চ্যাট লোড করা যায়নি। আবার চেষ্টা করুন।',
    ],
    'vi': [
      'Không thể gửi tin nhắn. Nội dung bạn nhập vẫn được giữ lại.',
      'Đăng nhập để mở tin nhắn.',
      'Dữ liệu sức khỏe của bạn không bao giờ hiển thị trong tin nhắn.',
      'Không thể tải cuộc trò chuyện này. Hãy thử lại.',
    ],
    'th': [
      'ส่งข้อความไม่ได้ ข้อความที่คุณพิมพ์ยังถูกเก็บไว้',
      'ลงชื่อเข้าใช้เพื่อเปิดข้อความ',
      'ข้อมูลสุขภาพของคุณจะไม่แสดงในข้อความ',
      'โหลดแชตนี้ไม่ได้ โปรดลองอีกครั้ง',
    ],
    'pl': [
      'Nie udało się wysłać wiadomości. Twój tekst został zachowany.',
      'Zaloguj się, aby otworzyć wiadomości.',
      'Twoje dane zdrowotne nigdy nie są wyświetlane w wiadomościach.',
      'Nie udało się wczytać tego czatu. Spróbuj ponownie.',
    ],
    'nl': [
      'Het bericht kon niet worden verzonden. Je tekst is bewaard.',
      'Meld je aan om berichten te openen.',
      'Je gezondheidsgegevens worden nooit in berichten weergegeven.',
      'Deze chat kon niet worden geladen. Probeer het opnieuw.',
    ],
    'uk': [
      'Не вдалося надіслати повідомлення. Ваш текст збережено.',
      'Увійдіть, щоб відкрити повідомлення.',
      'Ваші дані про здоров’я ніколи не показуються в повідомленнях.',
      'Не вдалося завантажити цей чат. Спробуйте ще раз.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final canonical = BilLocalePolicy.canonicalSupportedTag(localeTag);
    final row = canonical == null ? null : values[canonical];
    return row == null || row.length != sources.length ? null : row[index];
  }

  static bool get balanced =>
      values.length == 20 &&
      values.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((value) => value.trim().isNotEmpty),
      );
}
