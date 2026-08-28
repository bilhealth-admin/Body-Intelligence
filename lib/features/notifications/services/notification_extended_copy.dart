/// Copy used by background notifications where no [BuildContext] exists.
///
/// Base Arabic, English, French, Spanish and Turkish copy stays in the
/// notification service. These packs close every other shipped locale so a
/// supported phone language never silently receives English notification
/// text. Portuguese and Chinese variants deliberately share reviewed neutral
/// wording because the platform callback currently supplies a language code.
enum BilBackgroundCopyKind {
  activation,
  fastingTarget,
  fastingOngoing,
  fastingHydration,
  returnAfterDay,
  dailyReminder,
}

const bilExtendedNotificationLanguageCodes = <String>{
  'de',
  'it',
  'pt',
  'ur',
  'fa',
  'hi',
  'id',
  'ms',
  'ja',
  'ko',
  'zh',
  'ru',
  'bn',
  'vi',
  'th',
  'pl',
  'nl',
  'uk',
};

(String, String)? bilExtendedNotificationCopy(
  String localeTag,
  BilBackgroundCopyKind kind,
) {
  final language = localeTag
      .replaceAll('_', '-')
      .toLowerCase()
      .split('-')
      .first;
  return _bilExtendedNotificationCopy[language]?[kind];
}

const _bilExtendedNotificationCopy = <String, Map<BilBackgroundCopyKind, (String, String)>>{
  'de': {
    BilBackgroundCopyKind.activation: (
      'BIL-Benachrichtigungen sind aktiv',
      'Ihre privaten Erinnerungen können dieses Telefon erreichen.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Fastenfenster abgeschlossen',
      'Sie haben Ihre gewählte Fastendauer erreicht.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Intervallfasten läuft',
      'Tippen Sie, um den BIL-Fastentimer zu öffnen.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Sanfte Wassererinnerung',
      'Trinken Sie Wasser, wenn es zu Ihrem Fasten und Gesundheitsplan passt.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Wir sind da, wenn Sie bereit sind',
      'Ein Tag ist vergangen. Öffnen Sie BIL und erfassen Sie nur, was Ihnen wichtig ist.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'BIL-Gesundheitserinnerung',
      'Öffnen Sie BIL, um Ihr privates Gesundheitsprotokoll zu prüfen oder zu aktualisieren.',
    ),
  },
  'it': {
    BilBackgroundCopyKind.activation: (
      'Le notifiche BIL sono attive',
      'I tuoi promemoria privati possono raggiungere questo telefono.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Finestra di digiuno completata',
      'Hai raggiunto la durata di digiuno scelta.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Digiuno intermittente in corso',
      'Tocca per aprire il timer del digiuno BIL.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Promemoria gentile per l’acqua',
      'Bevi acqua se è compatibile con il digiuno e il tuo piano di salute.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Siamo qui quando vuoi',
      'È passato un giorno. Apri BIL e registra solo ciò che conta per te.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'Promemoria salute BIL',
      'Apri BIL per controllare o aggiornare il tuo registro sanitario privato.',
    ),
  },
  'pt': {
    BilBackgroundCopyKind.activation: (
      'As notificações BIL estão ativas',
      'Os seus lembretes privados podem chegar a este telefone.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Janela de jejum concluída',
      'Atingiu a duração de jejum escolhida.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Jejum intermitente em curso',
      'Toque para abrir o temporizador de jejum BIL.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Lembrete gentil de água',
      'Beba água se isso se adequar ao seu jejum e plano de saúde.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Estamos aqui quando estiver pronto',
      'Passou um dia. Abra o BIL e registe apenas o que importa para si.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'Lembrete de saúde BIL',
      'Abra o BIL para rever ou atualizar o seu registo de saúde privado.',
    ),
  },
  'ur': {
    BilBackgroundCopyKind.activation: (
      'BIL اطلاعات فعال ہیں',
      'آپ کی نجی یاد دہانیاں اس فون تک پہنچ سکتی ہیں۔',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'روزے کا دورانیہ مکمل',
      'آپ نے روزے کا منتخب دورانیہ پورا کر لیا ہے۔',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'وقفے وقفے کا روزہ جاری ہے',
      'BIL روزہ ٹائمر کھولنے کے لیے ٹیپ کریں۔',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'پانی کی نرم یاد دہانی',
      'اگر آپ کے روزے اور صحت کے منصوبے میں مناسب ہو تو پانی پیئیں۔',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'جب آپ تیار ہوں ہم موجود ہیں',
      'ایک دن گزر گیا۔ BIL کھولیں اور صرف اہم چیز درج کریں۔',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'BIL صحت یاد دہانی',
      'اپنا نجی صحت ریکارڈ دیکھنے یا اپ ڈیٹ کرنے کے لیے BIL کھولیں۔',
    ),
  },
  'fa': {
    BilBackgroundCopyKind.activation: (
      'اعلان‌های BIL فعال است',
      'یادآوری‌های خصوصی شما می‌تواند به این تلفن برسد.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'بازه روزه کامل شد',
      'به مدت روزه انتخابی خود رسیدید.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'روزه متناوب در حال انجام است',
      'برای باز کردن زمان‌سنج روزه BIL بزنید.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'یادآوری ملایم آب',
      'اگر با روزه و برنامه سلامت شما سازگار است آب بنوشید.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'هر وقت آماده‌اید اینجا هستیم',
      'یک روز گذشته است. BIL را باز کنید و فقط موارد مهم را ثبت کنید.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'یادآوری سلامت BIL',
      'برای بررسی یا به‌روزرسانی سابقه سلامت خصوصی خود BIL را باز کنید.',
    ),
  },
  'hi': {
    BilBackgroundCopyKind.activation: (
      'BIL सूचनाएँ चालू हैं',
      'आपके निजी रिमाइंडर इस फ़ोन तक पहुँच सकते हैं।',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'उपवास अवधि पूरी हुई',
      'आपने अपनी चुनी हुई उपवास अवधि पूरी कर ली है।',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'आंतरायिक उपवास जारी है',
      'BIL उपवास टाइमर खोलने के लिए टैप करें।',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'पानी पीने की हल्की याद',
      'यदि आपके उपवास और स्वास्थ्य योजना में उचित हो तो पानी पिएँ।',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'जब आप तैयार हों, हम यहाँ हैं',
      'एक दिन बीत गया। BIL खोलें और केवल ज़रूरी जानकारी दर्ज करें।',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'BIL स्वास्थ्य रिमाइंडर',
      'अपना निजी स्वास्थ्य रिकॉर्ड देखने या अपडेट करने के लिए BIL खोलें।',
    ),
  },
  'id': {
    BilBackgroundCopyKind.activation: (
      'Notifikasi BIL aktif',
      'Pengingat pribadi Anda dapat diterima di ponsel ini.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Jendela puasa selesai',
      'Anda telah mencapai durasi puasa yang dipilih.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Puasa intermiten sedang berlangsung',
      'Ketuk untuk membuka pengatur waktu puasa BIL.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Pengingat air yang lembut',
      'Minumlah air jika sesuai dengan puasa dan rencana kesehatan Anda.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Kami ada saat Anda siap',
      'Satu hari telah berlalu. Buka BIL dan catat hanya yang penting.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'Pengingat kesehatan BIL',
      'Buka BIL untuk meninjau atau memperbarui catatan kesehatan pribadi Anda.',
    ),
  },
  'ms': {
    BilBackgroundCopyKind.activation: (
      'Pemberitahuan BIL aktif',
      'Peringatan peribadi anda boleh diterima pada telefon ini.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Tempoh puasa selesai',
      'Anda telah mencapai tempoh puasa yang dipilih.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Puasa berselang sedang berlangsung',
      'Ketik untuk membuka pemasa puasa BIL.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Peringatan air yang lembut',
      'Minum air jika sesuai dengan puasa dan pelan kesihatan anda.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Kami ada apabila anda bersedia',
      'Sehari telah berlalu. Buka BIL dan catat perkara yang penting sahaja.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'Peringatan kesihatan BIL',
      'Buka BIL untuk menyemak atau mengemas kini rekod kesihatan peribadi anda.',
    ),
  },
  'ja': {
    BilBackgroundCopyKind.activation: (
      'BILの通知は有効です',
      'この端末で非公開のリマインダーを受け取れます。',
    ),
    BilBackgroundCopyKind.fastingTarget: ('断食時間が完了しました', '選択した断食時間に到達しました。'),
    BilBackgroundCopyKind.fastingOngoing: (
      '断続的断食を継続中',
      'タップしてBILの断食タイマーを開きます。',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      '水分補給のやさしいお知らせ',
      '断食と健康計画に合う場合は水を飲みましょう。',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      '準備ができたらいつでも',
      '1日が経過しました。BILを開き、必要なことだけ記録しましょう。',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'BIL健康リマインダー',
      'BILを開いて非公開の健康記録を確認または更新してください。',
    ),
  },
  'ko': {
    BilBackgroundCopyKind.activation: (
      'BIL 알림이 활성화되었습니다',
      '이 휴대전화에서 비공개 알림을 받을 수 있습니다.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      '단식 시간이 완료되었습니다',
      '선택한 단식 시간을 채웠습니다.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      '간헐적 단식 진행 중',
      '탭하여 BIL 단식 타이머를 여세요.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      '가벼운 물 섭취 알림',
      '단식과 건강 계획에 맞는 경우 물을 드세요.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      '준비되면 언제든 돌아오세요',
      '하루가 지났습니다. BIL을 열고 중요한 내용만 기록하세요.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'BIL 건강 알림',
      'BIL을 열어 비공개 건강 기록을 확인하거나 업데이트하세요.',
    ),
  },
  'zh': {
    BilBackgroundCopyKind.activation: ('BIL 通知已启用', '此手机可以接收您的私人提醒。'),
    BilBackgroundCopyKind.fastingTarget: ('禁食时段已完成', '您已达到所选的禁食时长。'),
    BilBackgroundCopyKind.fastingOngoing: ('间歇性禁食进行中', '轻触以打开 BIL 禁食计时器。'),
    BilBackgroundCopyKind.fastingHydration: ('温和的饮水提醒', '如果符合您的禁食和健康计划，请适量饮水。'),
    BilBackgroundCopyKind.returnAfterDay: (
      '准备好时我们都在',
      '一天过去了。打开 BIL，只记录对您重要的内容。',
    ),
    BilBackgroundCopyKind.dailyReminder: ('BIL 健康提醒', '打开 BIL 查看或更新您的私人健康记录。'),
  },
  'ru': {
    BilBackgroundCopyKind.activation: (
      'Уведомления BIL включены',
      'Личные напоминания могут приходить на этот телефон.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Период голодания завершён',
      'Вы достигли выбранной продолжительности голодания.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Интервальное голодание продолжается',
      'Нажмите, чтобы открыть таймер голодания BIL.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Мягкое напоминание о воде',
      'Пейте воду, если это соответствует вашему голоданию и плану здоровья.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Мы здесь, когда вы будете готовы',
      'Прошёл день. Откройте BIL и запишите только важное для вас.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'Напоминание о здоровье BIL',
      'Откройте BIL, чтобы проверить или обновить личный журнал здоровья.',
    ),
  },
  'bn': {
    BilBackgroundCopyKind.activation: (
      'BIL বিজ্ঞপ্তি চালু আছে',
      'আপনার ব্যক্তিগত অনুস্মারক এই ফোনে পৌঁছাতে পারে।',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'উপবাসের সময় পূর্ণ হয়েছে',
      'আপনি নির্বাচিত উপবাসের সময় পূর্ণ করেছেন।',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'বিরতিমূলক উপবাস চলছে',
      'BIL উপবাস টাইমার খুলতে ট্যাপ করুন।',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'পানির কোমল অনুস্মারক',
      'আপনার উপবাস ও স্বাস্থ্য পরিকল্পনায় মানানসই হলে পানি পান করুন।',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'আপনি প্রস্তুত হলে আমরা আছি',
      'এক দিন হয়েছে। BIL খুলে শুধু গুরুত্বপূর্ণ বিষয় লিখুন।',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'BIL স্বাস্থ্য অনুস্মারক',
      'ব্যক্তিগত স্বাস্থ্য রেকর্ড দেখতে বা হালনাগাদ করতে BIL খুলুন।',
    ),
  },
  'vi': {
    BilBackgroundCopyKind.activation: (
      'Thông báo BIL đã bật',
      'Lời nhắc riêng tư có thể đến điện thoại này.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Đã hoàn thành thời gian nhịn ăn',
      'Bạn đã đạt thời lượng nhịn ăn đã chọn.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Đang nhịn ăn gián đoạn',
      'Chạm để mở bộ đếm giờ nhịn ăn BIL.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Nhắc uống nước nhẹ nhàng',
      'Hãy uống nước nếu phù hợp với việc nhịn ăn và kế hoạch sức khỏe của bạn.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Chúng tôi luôn ở đây khi bạn sẵn sàng',
      'Đã một ngày trôi qua. Mở BIL và chỉ ghi lại điều quan trọng.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'Lời nhắc sức khỏe BIL',
      'Mở BIL để xem hoặc cập nhật nhật ký sức khỏe riêng tư.',
    ),
  },
  'th': {
    BilBackgroundCopyKind.activation: (
      'เปิดการแจ้งเตือน BIL แล้ว',
      'โทรศัพท์นี้รับการเตือนส่วนตัวของคุณได้แล้ว',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'ครบช่วงเวลาอดอาหารแล้ว',
      'คุณทำระยะเวลาอดอาหารที่เลือกไว้ครบแล้ว',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'กำลังอดอาหารแบบเป็นช่วง',
      'แตะเพื่อเปิดตัวจับเวลาอดอาหาร BIL',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'เตือนดื่มน้ำอย่างอ่อนโยน',
      'ดื่มน้ำหากเหมาะกับการอดอาหารและแผนสุขภาพของคุณ',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'เราพร้อมเมื่อคุณพร้อม',
      'ผ่านไปหนึ่งวันแล้ว เปิด BIL และบันทึกเฉพาะสิ่งที่สำคัญ',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'การเตือนสุขภาพ BIL',
      'เปิด BIL เพื่อตรวจสอบหรืออัปเดตบันทึกสุขภาพส่วนตัว',
    ),
  },
  'pl': {
    BilBackgroundCopyKind.activation: (
      'Powiadomienia BIL są aktywne',
      'Prywatne przypomnienia mogą docierać na ten telefon.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Okno postu zakończone',
      'Osiągnięto wybrany czas postu.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Post przerywany trwa',
      'Dotknij, aby otworzyć licznik postu BIL.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Delikatne przypomnienie o wodzie',
      'Pij wodę, jeśli pasuje to do postu i planu zdrowotnego.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Jesteśmy tu, gdy będziesz gotowy',
      'Minął dzień. Otwórz BIL i zapisz tylko to, co jest dla Ciebie ważne.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'Przypomnienie zdrowotne BIL',
      'Otwórz BIL, aby sprawdzić lub zaktualizować prywatny dziennik zdrowia.',
    ),
  },
  'nl': {
    BilBackgroundCopyKind.activation: (
      'BIL-meldingen zijn actief',
      'Uw privéherinneringen kunnen deze telefoon bereiken.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Vastenvenster voltooid',
      'U hebt de gekozen vastenduur bereikt.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Intermitterend vasten is bezig',
      'Tik om de BIL-vastentimer te openen.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Vriendelijke waterherinnering',
      'Drink water als dit past bij uw vasten en gezondheidsplan.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'We zijn er wanneer u klaar bent',
      'Er is een dag verstreken. Open BIL en noteer alleen wat belangrijk is.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'BIL-gezondheidsherinnering',
      'Open BIL om uw privégezondheidslogboek te bekijken of bij te werken.',
    ),
  },
  'uk': {
    BilBackgroundCopyKind.activation: (
      'Сповіщення BIL увімкнено',
      'Особисті нагадування можуть надходити на цей телефон.',
    ),
    BilBackgroundCopyKind.fastingTarget: (
      'Вікно голодування завершено',
      'Ви досягли вибраної тривалості голодування.',
    ),
    BilBackgroundCopyKind.fastingOngoing: (
      'Інтервальне голодування триває',
      'Натисніть, щоб відкрити таймер голодування BIL.',
    ),
    BilBackgroundCopyKind.fastingHydration: (
      'Лагідне нагадування про воду',
      'Пийте воду, якщо це відповідає вашому голодуванню та плану здоров’я.',
    ),
    BilBackgroundCopyKind.returnAfterDay: (
      'Ми тут, коли ви будете готові',
      'Минув день. Відкрийте BIL і запишіть лише важливе для вас.',
    ),
    BilBackgroundCopyKind.dailyReminder: (
      'Нагадування про здоров’я BIL',
      'Відкрийте BIL, щоб переглянути або оновити особистий журнал здоров’я.',
    ),
  },
};

bool get bilExtendedNotificationCopyIsComplete =>
    _bilExtendedNotificationCopy.keys.toSet().containsAll(
      bilExtendedNotificationLanguageCodes,
    ) &&
    _bilExtendedNotificationCopy.values.every(
      (pack) =>
          pack.length == BilBackgroundCopyKind.values.length &&
          pack.values.every(
            (copy) => copy.$1.trim().isNotEmpty && copy.$2.trim().isNotEmpty,
          ),
    );

/// Two short schedule labels that cannot be composed unambiguously from the
/// general runtime catalog. Both Portuguese and Chinese variants use neutral
/// wording because the caller receives only the platform language code.
(String bedtime, String wakeTime) bilSleepScheduleLabels(String localeTag) {
  final language = localeTag
      .replaceAll('_', '-')
      .toLowerCase()
      .split('-')
      .first;
  return _bilSleepScheduleLabels[language] ?? _bilSleepScheduleLabels['en']!;
}

const _bilSleepScheduleLabels = <String, (String, String)>{
  'ar': ('وقت النوم', 'وقت الاستيقاظ'),
  'en': ('Bedtime', 'Wake time'),
  'fr': ('Heure du coucher', 'Heure du réveil'),
  'es': ('Hora de dormir', 'Hora de despertar'),
  'tr': ('Uyku zamanı', 'Uyanma zamanı'),
  'de': ('Schlafenszeit', 'Aufwachzeit'),
  'it': ('Ora di dormire', 'Ora del risveglio'),
  'pt': ('Hora de dormir', 'Hora de acordar'),
  'ur': ('سونے کا وقت', 'جاگنے کا وقت'),
  'fa': ('زمان خواب', 'زمان بیداری'),
  'hi': ('सोने का समय', 'जागने का समय'),
  'id': ('Waktu tidur', 'Waktu bangun'),
  'ms': ('Waktu tidur', 'Waktu bangun'),
  'ja': ('就寝時刻', '起床時刻'),
  'ko': ('취침 시간', '기상 시간'),
  'zh': ('就寝时间', '起床时间'),
  'ru': ('Время сна', 'Время пробуждения'),
  'bn': ('ঘুমানোর সময়', 'জাগার সময়'),
  'vi': ('Giờ đi ngủ', 'Giờ thức dậy'),
  'th': ('เวลาเข้านอน', 'เวลาตื่นนอน'),
  'pl': ('Pora snu', 'Pora pobudki'),
  'nl': ('Bedtijd', 'Wektijd'),
  'uk': ('Час сну', 'Час пробудження'),
};

bool get bilSleepScheduleLabelsAreComplete =>
    <String>{
      'ar',
      'en',
      'fr',
      'es',
      'tr',
      ...bilExtendedNotificationLanguageCodes,
    }.every(
      (language) =>
          _bilSleepScheduleLabels[language]?.$1.trim().isNotEmpty == true &&
          _bilSleepScheduleLabels[language]?.$2.trim().isNotEmpty == true,
    );
