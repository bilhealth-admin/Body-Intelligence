import 'package:flutter/widgets.dart';
import '../../../app/localization/bil_locale_policy.dart';

enum CommunityEntryCopyKey {
  heading,
  introduction,
  invalidName,
  saveFailed,
  photoPending,
}

abstract final class CommunityEntryCopy {
  static const rows = <String, List<String>>{
    "en": [
      "Your people. Your next chapter.",
      "Start with your name. Add a photo and other details whenever you’re ready.",
      "Use 2–60 characters for your display name.",
      "We couldn’t confirm your profile and BIL Code. Your name is kept here; retry safely.",
      "Your profile is ready. Photo sync is incomplete; you can retry from Edit profile.",
    ],
    "ar": [
      "أهلك هنا. وخطوتك القادمة.",
      "ابدأ باسمك فقط. أضف صورتك وبقية التفاصيل في أي وقت يناسبك.",
      "استخدم من حرفين إلى 60 حرفًا للاسم الظاهر.",
      "لم نتأكد من حفظ ملفك وكود BIL. اسمك محفوظ هنا؛ أعد المحاولة بأمان.",
      "ملفك جاهز. مزامنة الصورة لم تكتمل؛ يمكنك إعادة المحاولة من تعديل الملف.",
    ],
    "fr": [
      "Vos proches. Un nouveau départ.",
      "Commencez avec votre nom. Ajoutez une photo et les autres détails quand vous le souhaitez.",
      "Utilisez de 2 à 60 caractères pour votre nom affiché.",
      "Impossible de confirmer votre profil et votre code BIL. Votre nom reste ici ; réessayez sans risque.",
      "Votre profil est prêt. La photo n’est pas synchronisée ; réessayez depuis Modifier le profil.",
    ],
    "es": [
      "Tu gente. Tu próxima etapa.",
      "Empieza con tu nombre. Añade una foto y otros detalles cuando quieras.",
      "Usa entre 2 y 60 caracteres para tu nombre visible.",
      "No pudimos confirmar tu perfil y código BIL. Tu nombre sigue aquí; vuelve a intentarlo.",
      "Tu perfil está listo. La foto no se ha sincronizado; inténtalo desde Editar perfil.",
    ],
    "de": [
      "Deine Menschen. Dein nächstes Kapitel.",
      "Beginne mit deinem Namen. Foto und weitere Angaben kannst du später ergänzen.",
      "Verwende 2–60 Zeichen für deinen Anzeigenamen.",
      "Profil und BIL-Code konnten nicht bestätigt werden. Dein Name bleibt hier; versuche es erneut.",
      "Dein Profil ist bereit. Das Foto ist noch nicht synchronisiert; versuche es unter Profil bearbeiten erneut.",
    ],
    "it": [
      "Le tue persone. Il tuo prossimo capitolo.",
      "Inizia con il tuo nome. Aggiungi una foto e altri dettagli quando preferisci.",
      "Usa da 2 a 60 caratteri per il nome visualizzato.",
      "Non abbiamo confermato il profilo e il codice BIL. Il nome resta qui; riprova in sicurezza.",
      "Il profilo è pronto. La foto non è sincronizzata; riprova da Modifica profilo.",
    ],
    "pt-BR": [
      "Sua comunidade. Seu próximo capítulo.",
      "Comece com seu nome. Adicione uma foto e outros detalhes quando quiser.",
      "Use de 2 a 60 caracteres no nome de exibição.",
      "Não confirmamos seu perfil e código BIL. Seu nome está aqui; tente novamente com segurança.",
      "Seu perfil está pronto. A foto não foi sincronizada; tente em Editar perfil.",
    ],
    "pt-PT": [
      "A tua comunidade. O teu próximo capítulo.",
      "Começa pelo teu nome. Adiciona uma fotografia e outros detalhes quando quiseres.",
      "Usa entre 2 e 60 caracteres no nome apresentado.",
      "Não confirmámos o teu perfil e código BIL. O nome fica aqui; tenta novamente em segurança.",
      "O teu perfil está pronto. A fotografia não está sincronizada; tenta em Editar perfil.",
    ],
    "ur": [
      "آپ کے ساتھی۔ آپ کا اگلا سفر۔",
      "صرف اپنے نام سے شروع کریں۔ تصویر اور باقی تفصیلات جب چاہیں شامل کریں۔",
      "ظاہر ہونے والے نام کے لیے 2 سے 60 حروف استعمال کریں۔",
      "آپ کے پروفائل اور BIL کوڈ کی تصدیق نہیں ہو سکی۔ نام یہیں محفوظ ہے؛ دوبارہ کوشش کریں۔",
      "آپ کا پروفائل تیار ہے۔ تصویر کی مطابقت نامکمل ہے؛ پروفائل میں ترمیم سے دوبارہ کوشش کریں۔",
    ],
    "fa": [
      "همراهان شما. فصل بعدی شما.",
      "با نامتان شروع کنید. عکس و دیگر جزئیات را هر وقت آماده بودید اضافه کنید.",
      "نام نمایشی باید ۲ تا ۶۰ نویسه داشته باشد.",
      "پروفایل و کد BIL شما تأیید نشد. نامتان اینجا باقی می‌ماند؛ دوباره تلاش کنید.",
      "پروفایلتان آماده است. عکس هنوز همگام نشده؛ از ویرایش پروفایل دوباره تلاش کنید.",
    ],
    "hi": [
      "आपके साथी। आपका अगला अध्याय।",
      "सिर्फ़ अपने नाम से शुरू करें। फ़ोटो और अन्य जानकारी जब चाहें जोड़ें।",
      "दिखने वाले नाम में 2–60 अक्षर रखें।",
      "प्रोफ़ाइल और BIL कोड की पुष्टि नहीं हुई। आपका नाम यहीं है; सुरक्षित रूप से फिर कोशिश करें।",
      "आपकी प्रोफ़ाइल तैयार है। फ़ोटो सिंक नहीं हुई; प्रोफ़ाइल संपादित करें से फिर कोशिश करें।",
    ],
    "id": [
      "Komunitas Anda. Bab berikutnya.",
      "Mulai dengan nama Anda. Tambahkan foto dan detail lain kapan saja.",
      "Gunakan 2–60 karakter untuk nama tampilan.",
      "Profil dan Kode BIL Anda belum terkonfirmasi. Nama tetap di sini; coba lagi dengan aman.",
      "Profil Anda siap. Foto belum tersinkron; coba dari Edit profil.",
    ],
    "ms": [
      "Komuniti anda. Bab seterusnya.",
      "Mulakan dengan nama anda. Tambah foto dan butiran lain apabila bersedia.",
      "Gunakan 2–60 aksara untuk nama paparan.",
      "Profil dan Kod BIL anda belum dapat disahkan. Nama kekal di sini; cuba semula dengan selamat.",
      "Profil anda sedia. Foto belum disegerakkan; cuba dari Edit profil.",
    ],
    "ja": [
      "仲間とともに、次の一歩へ。",
      "まずは名前だけで始めましょう。写真や詳しい情報は後から追加できます。",
      "表示名は2〜60文字で入力してください。",
      "プロフィールとBILコードを確認できませんでした。名前はここに残っています。もう一度お試しください。",
      "プロフィールができました。写真の同期は未完了です。プロフィール編集から再試行できます。",
    ],
    "ko": [
      "함께할 사람들. 새로운 시작.",
      "이름만으로 시작하세요. 사진과 다른 정보는 나중에 추가할 수 있어요.",
      "표시 이름은 2~60자로 입력하세요.",
      "프로필과 BIL 코드를 확인하지 못했어요. 이름은 여기에 남아 있으니 다시 시도하세요.",
      "프로필이 준비됐어요. 사진 동기화는 완료되지 않았어요. 프로필 수정에서 다시 시도하세요.",
    ],
    "zh-Hans": [
      "找到伙伴，开启新篇章。",
      "先填写名字即可。照片和其他资料可以随时添加。",
      "显示名称请使用2至60个字符。",
      "未能确认你的个人资料和BIL码。名字会保留在此，请安全重试。",
      "个人资料已准备好。照片尚未同步，请从编辑资料中重试。",
    ],
    "zh-Hant": [
      "找到夥伴，開啟新篇章。",
      "先填寫名字即可。照片和其他資料可以隨時新增。",
      "顯示名稱請使用2至60個字元。",
      "未能確認你的個人資料與BIL碼。名字會保留在此，請安心重試。",
      "個人資料已準備好。照片尚未同步，請從編輯資料中重試。",
    ],
    "ru": [
      "Ваши люди. Ваша новая глава.",
      "Начните с имени. Фото и остальные сведения можно добавить позже.",
      "В отображаемом имени должно быть 2–60 символов.",
      "Не удалось подтвердить профиль и код BIL. Имя сохранено здесь; повторите попытку.",
      "Профиль готов. Фото ещё не синхронизировано; повторите попытку в редакторе профиля.",
    ],
    "bn": [
      "আপনার সঙ্গী। আপনার নতুন অধ্যায়।",
      "শুধু নাম দিয়ে শুরু করুন। ছবি ও অন্যান্য তথ্য পরে যোগ করতে পারবেন।",
      "প্রদর্শিত নামের জন্য ২–৬০টি অক্ষর ব্যবহার করুন।",
      "আপনার প্রোফাইল ও BIL কোড নিশ্চিত করা যায়নি। নাম এখানেই আছে; নিরাপদে আবার চেষ্টা করুন।",
      "আপনার প্রোফাইল প্রস্তুত। ছবি সিঙ্ক হয়নি; প্রোফাইল সম্পাদনা থেকে আবার চেষ্টা করুন।",
    ],
    "vi": [
      "Những người đồng hành. Chặng đường mới.",
      "Bắt đầu bằng tên của bạn. Thêm ảnh và thông tin khác khi bạn sẵn sàng.",
      "Dùng 2–60 ký tự cho tên hiển thị.",
      "Chưa xác nhận được hồ sơ và Mã BIL. Tên vẫn ở đây; hãy thử lại an toàn.",
      "Hồ sơ đã sẵn sàng. Ảnh chưa đồng bộ; hãy thử lại trong Chỉnh sửa hồ sơ.",
    ],
    "th": [
      "เพื่อนร่วมทางของคุณ บทใหม่ของคุณ",
      "เริ่มด้วยชื่อเท่านั้น เพิ่มรูปและรายละเอียดอื่นเมื่อพร้อม",
      "ใช้ 2–60 อักขระสำหรับชื่อที่แสดง",
      "ยังยืนยันโปรไฟล์และรหัส BIL ไม่ได้ ชื่อยังอยู่ที่นี่ โปรดลองอีกครั้งอย่างปลอดภัย",
      "โปรไฟล์พร้อมแล้ว รูปยังซิงค์ไม่สำเร็จ ลองอีกครั้งในแก้ไขโปรไฟล์",
    ],
    "pl": [
      "Twoi ludzie. Twój kolejny rozdział.",
      "Zacznij od imienia. Zdjęcie i inne informacje możesz dodać później.",
      "Użyj 2–60 znaków w nazwie wyświetlanej.",
      "Nie potwierdzono profilu i kodu BIL. Nazwa pozostaje tutaj; spróbuj ponownie.",
      "Profil jest gotowy. Zdjęcie nie zostało zsynchronizowane; spróbuj w Edytuj profil.",
    ],
    "nl": [
      "Jouw mensen. Jouw volgende hoofdstuk.",
      "Begin met je naam. Voeg later een foto en andere gegevens toe.",
      "Gebruik 2–60 tekens voor je weergavenaam.",
      "Je profiel en BIL-code zijn niet bevestigd. Je naam blijft hier staan; probeer het veilig opnieuw.",
      "Je profiel is klaar. Je foto is nog niet gesynchroniseerd; probeer het bij Profiel bewerken.",
    ],
    "uk": [
      "Ваші люди. Ваш новий розділ.",
      "Почніть з імені. Фото й інші відомості можна додати пізніше.",
      "Використовуйте 2–60 символів для відображуваного імені.",
      "Не вдалося підтвердити профіль і код BIL. Ім’я залишається тут; спробуйте ще раз.",
      "Профіль готовий. Фото ще не синхронізовано; повторіть спробу в редакторі профілю.",
    ],
    "tr": [
      "Senin topluluğun. Yeni bir başlangıç.",
      "Yalnızca adınla başla. Fotoğrafını ve diğer ayrıntıları istediğin zaman ekle.",
      "Görünen ad için 2–60 karakter kullan.",
      "Profilin ve BIL Kodun doğrulanamadı. Adın burada duruyor; güvenle tekrar dene.",
      "Profilin hazır. Fotoğraf eşitlenmedi; Profili düzenle bölümünden tekrar dene.",
    ],
  };
  static String resolve(String localeTag, CommunityEntryCopyKey key) {
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag) ?? 'en';
    return rows[tag]![key.index];
  }

  static String text(BuildContext context, CommunityEntryCopyKey key) =>
      resolve(
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
        key,
      );
}
