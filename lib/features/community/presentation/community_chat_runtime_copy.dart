import '../../../app/localization/bil_locale_policy.dart';

/// Copy that was previously English-only in the 20 extended BIL locales.
/// The five original Community locales remain in the calling widget.
abstract final class CommunityChatRuntimeCopy {
  static const sources = <String>[
    'Message could not be sent. Your text is kept.',
    'Sign in to open messages.',
    'Your health log stays private. Only the text you send appears here.',
    'Could not load this chat. Try again.',
  ];

  static const values = <String, List<String>>{
    'de': [
      'Die Nachricht konnte nicht gesendet werden. Dein Text bleibt erhalten.',
      'Melde dich an, um Nachrichten zu öffnen.',
      'Dein Gesundheitsprotokoll bleibt privat. Hier erscheint nur der Text, den du sendest.',
      'Dieser Chat konnte nicht geladen werden. Versuche es erneut.',
    ],
    'it': [
      'Impossibile inviare il messaggio. Il testo è stato conservato.',
      'Accedi per aprire i messaggi.',
      'Il tuo diario della salute resta privato. Qui appare solo il testo che invii.',
      'Impossibile caricare questa chat. Riprova.',
    ],
    'pt-BR': [
      'Não foi possível enviar a mensagem. Seu texto foi mantido.',
      'Entre para abrir as mensagens.',
      'Seu registro de saúde permanece privado. Aqui aparece apenas o texto que você envia.',
      'Não foi possível carregar esta conversa. Tente novamente.',
    ],
    'pt-PT': [
      'Não foi possível enviar a mensagem. O seu texto foi mantido.',
      'Inicie sessão para abrir as mensagens.',
      'O seu registo de saúde permanece privado. Aqui aparece apenas o texto que envia.',
      'Não foi possível carregar esta conversa. Tente novamente.',
    ],
    'ur': [
      'پیغام نہیں بھیجا جا سکا۔ آپ کا متن محفوظ ہے۔',
      'پیغامات کھولنے کے لیے سائن ان کریں۔',
      'آپ کا صحت کا ریکارڈ نجی رہتا ہے۔ یہاں صرف وہ متن دکھائی دیتا ہے جو آپ بھیجتے ہیں۔',
      'یہ گفتگو لوڈ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
    ],
    'fa': [
      'پیام ارسال نشد. متن شما حفظ شده است.',
      'برای باز کردن پیام‌ها وارد شوید.',
      'گزارش سلامت شما خصوصی می‌ماند. اینجا فقط متنی که می‌فرستید نمایش داده می‌شود.',
      'این گفتگو بارگیری نشد. دوباره تلاش کنید.',
    ],
    'hi': [
      'संदेश नहीं भेजा जा सका। आपका लिखा हुआ पाठ सुरक्षित है।',
      'संदेश खोलने के लिए साइन इन करें।',
      'आपका स्वास्थ्य रिकॉर्ड निजी रहता है। यहाँ केवल वह पाठ दिखता है जो आप भेजते हैं।',
      'यह चैट लोड नहीं हो सकी। फिर से कोशिश करें।',
    ],
    'id': [
      'Pesan tidak dapat dikirim. Teks Anda tetap tersimpan.',
      'Masuk untuk membuka pesan.',
      'Catatan kesehatan Anda tetap pribadi. Hanya teks yang Anda kirim yang muncul di sini.',
      'Obrolan ini tidak dapat dimuat. Coba lagi.',
    ],
    'ms': [
      'Mesej tidak dapat dihantar. Teks anda masih disimpan.',
      'Log masuk untuk membuka mesej.',
      'Rekod kesihatan anda kekal peribadi. Hanya teks yang anda hantar dipaparkan di sini.',
      'Sembang ini tidak dapat dimuatkan. Cuba lagi.',
    ],
    'ja': [
      'メッセージを送信できませんでした。入力した文章は保持されています。',
      'メッセージを開くにはサインインしてください。',
      '健康記録は非公開のままです。ここには自分で送信した文章だけが表示されます。',
      'このチャットを読み込めませんでした。もう一度お試しください。',
    ],
    'ko': [
      '메시지를 보내지 못했습니다. 작성한 내용은 보관됩니다.',
      '메시지를 열려면 로그인하세요.',
      '건강 기록은 비공개로 유지됩니다. 여기에는 직접 보낸 글만 표시됩니다.',
      '이 채팅을 불러오지 못했습니다. 다시 시도하세요.',
    ],
    'zh-Hans': [
      '无法发送消息。你输入的文字已保留。',
      '登录后打开消息。',
      '你的健康记录保持私密。这里只显示你主动发送的文字。',
      '无法加载此聊天。请重试。',
    ],
    'zh-Hant': [
      '無法傳送訊息。你輸入的文字已保留。',
      '登入後開啟訊息。',
      '你的健康紀錄保持私密。這裡只顯示你主動傳送的文字。',
      '無法載入此聊天。請再試一次。',
    ],
    'ru': [
      'Не удалось отправить сообщение. Ваш текст сохранён.',
      'Войдите, чтобы открыть сообщения.',
      'Ваш журнал здоровья остаётся приватным. Здесь отображается только текст, который вы отправляете.',
      'Не удалось загрузить этот чат. Повторите попытку.',
    ],
    'bn': [
      'বার্তাটি পাঠানো যায়নি। আপনার লেখা সংরক্ষিত আছে।',
      'বার্তা খুলতে সাইন ইন করুন।',
      'আপনার স্বাস্থ্য রেকর্ড ব্যক্তিগত থাকে। এখানে শুধু আপনার পাঠানো লেখা দেখা যায়।',
      'এই চ্যাট লোড করা যায়নি। আবার চেষ্টা করুন।',
    ],
    'vi': [
      'Không thể gửi tin nhắn. Nội dung bạn nhập vẫn được giữ lại.',
      'Đăng nhập để mở tin nhắn.',
      'Nhật ký sức khỏe của bạn vẫn riêng tư. Chỉ văn bản bạn gửi xuất hiện ở đây.',
      'Không thể tải cuộc trò chuyện này. Hãy thử lại.',
    ],
    'th': [
      'ส่งข้อความไม่ได้ ข้อความที่คุณพิมพ์ยังถูกเก็บไว้',
      'ลงชื่อเข้าใช้เพื่อเปิดข้อความ',
      'บันทึกสุขภาพของคุณยังเป็นส่วนตัว ที่นี่แสดงเฉพาะข้อความที่คุณส่ง',
      'โหลดแชตนี้ไม่ได้ โปรดลองอีกครั้ง',
    ],
    'pl': [
      'Nie udało się wysłać wiadomości. Twój tekst został zachowany.',
      'Zaloguj się, aby otworzyć wiadomości.',
      'Twój dziennik zdrowia pozostaje prywatny. Tutaj pojawia się tylko wysłany przez Ciebie tekst.',
      'Nie udało się wczytać tego czatu. Spróbuj ponownie.',
    ],
    'nl': [
      'Het bericht kon niet worden verzonden. Je tekst is bewaard.',
      'Meld je aan om berichten te openen.',
      'Je gezondheidslogboek blijft privé. Hier verschijnt alleen de tekst die je verstuurt.',
      'Deze chat kon niet worden geladen. Probeer het opnieuw.',
    ],
    'uk': [
      'Не вдалося надіслати повідомлення. Ваш текст збережено.',
      'Увійдіть, щоб відкрити повідомлення.',
      'Ваш журнал здоров’я залишається приватним. Тут відображається лише текст, який ви надсилаєте.',
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
