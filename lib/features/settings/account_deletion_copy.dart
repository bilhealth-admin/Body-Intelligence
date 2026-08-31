part of 'account_deletion_page.dart';

class _AccountDeletionCopy {
  const _AccountDeletionCopy(this.values);
  final Map<String, String> values;
  String get title => values['title']!;
  String get heading => values['heading']!;
  String get body => values['body']!;
  String get confirmationLabel => values['confirmationLabel']!;
  String get submit => values['submit']!;
  String get signInRequired => values['signInRequired']!;
  String get confirmationRequired => values['confirmationRequired']!;
  String get requestReceived => values['requestReceived']!;
  String get requestReceivedBody => values['requestReceivedBody']!;
  String get deletionCompletedBody => values['deletionCompletedBody']!;
  String get billingNotice => values['billingNotice']!;
  String get appleAccessTitle => values['appleAccessTitle']!;
  String get appleAccessBody => values['appleAccessBody']!;
  String get appleAccessLearnMore => values['appleAccessLearnMore']!;
  String get pendingTimingNotice => values['pendingTimingNotice']!;
  String get manageSubscription => values['manageSubscription']!;
  String get failed => values['failed']!;
  String get close => values['close']!;
  String get statusLabel => values['statusLabel']!;
  String get referenceLabel => values['referenceLabel']!;
  String statusFor(String status) => switch (status) {
    'pending' => values['statusPending']!,
    'processing' => values['statusProcessing']!,
    'completed' => values['statusCompleted']!,
    _ => throw StateError('Unsupported account deletion status: $status'),
  };

  static _AccountDeletionCopy of(BuildContext context) {
    final code = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
    final authored = _catalog[code];
    if (authored != null) return _AccountDeletionCopy(authored);
    final english = _catalog['en']!;
    return _AccountDeletionCopy({
      for (final entry in english.entries)
        entry.key:
            _statusCatalog[code]?[entry.key] ??
            RuntimeCopy.resolve(entry.value, code) ??
            (throw StateError(
              'Missing account-deletion copy for $code: ${entry.value}',
            )),
    });
  }

  static const _statusCatalog = <String, Map<String, String>>{
    'de': {
      'billingNotice':
          'Das Löschen Ihres BIL-Kontos kündigt kein App-Store- oder Google-Play-Abonnement. Die Abrechnung kann weiterlaufen. Kündigen Sie es vor dem Fortfahren im Gerätestore.',
      'pendingTimingNotice':
          'Wenn die sofortige Verarbeitung nicht verfügbar ist, versucht BIL die vorgemerkte Löschung innerhalb von 15 Minuten erneut. Bewahren Sie die Referenz bis zum Abschluss auf.',
      'deletionCompletedBody':
          'Ihr BIL-Konto und die vom Entwickler verwalteten Cloud-Daten wurden gelöscht. Von Apple oder Google verwaltete Abrechnung und Datensätze bleiben getrennt.',
      'statusLabel': 'Status',
      'referenceLabel': 'Anfragereferenz',
      'statusPending': 'Ausstehend',
      'statusProcessing': 'In Bearbeitung',
      'statusCompleted': 'Abgeschlossen',
    },
    'it': {
      'billingNotice':
          'L’eliminazione dell’account BIL non annulla un abbonamento App Store o Google Play. La fatturazione può continuare. Annullalo nello store del dispositivo prima di proseguire.',
      'pendingTimingNotice':
          'Se l’elaborazione immediata non è disponibile, BIL ritenta l’eliminazione in coda entro 15 minuti. Conserva il riferimento fino al completamento.',
      'deletionCompletedBody':
          'L’account BIL e i dati cloud controllati dallo sviluppatore sono stati eliminati. Fatturazione e registri gestiti da Apple o Google restano separati.',
      'statusLabel': 'Stato',
      'referenceLabel': 'Riferimento richiesta',
      'statusPending': 'In attesa',
      'statusProcessing': 'In elaborazione',
      'statusCompleted': 'Completata',
    },
    'pt-BR': {
      'billingNotice':
          'Excluir sua conta BIL não cancela uma assinatura da App Store ou do Google Play. A cobrança pode continuar. Cancele-a na loja do dispositivo antes de prosseguir.',
      'pendingTimingNotice':
          'Se o processamento imediato não estiver disponível, o BIL tentará novamente a exclusão em até 15 minutos. Guarde a referência até a conclusão.',
      'deletionCompletedBody':
          'Sua conta BIL e os dados de nuvem controlados pelo desenvolvedor foram excluídos. A cobrança e os registros gerenciados pela Apple ou Google permanecem separados.',
      'statusLabel': 'Status',
      'referenceLabel': 'Referência da solicitação',
      'statusPending': 'Pendente',
      'statusProcessing': 'Em processamento',
      'statusCompleted': 'Concluída',
    },
    'pt-PT': {
      'billingNotice':
          'Eliminar a conta BIL não cancela uma assinatura da App Store ou Google Play. A faturação pode continuar. Cancele-a na loja do dispositivo antes de prosseguir.',
      'pendingTimingNotice':
          'Se o processamento imediato não estiver disponível, o BIL tenta novamente a eliminação em fila no prazo de 15 minutos. Guarde a referência até terminar.',
      'deletionCompletedBody':
          'A conta BIL e os dados na nuvem controlados pelo programador foram eliminados. A faturação e os registos geridos pela Apple ou Google permanecem separados.',
      'statusLabel': 'Estado',
      'referenceLabel': 'Referência do pedido',
      'statusPending': 'Pendente',
      'statusProcessing': 'Em processamento',
      'statusCompleted': 'Concluída',
    },
    'ur': {
      'billingNotice':
          'BIL اکاؤنٹ حذف کرنے سے App Store یا Google Play کی رکنیت منسوخ نہیں ہوتی۔ بلنگ جاری رہ سکتی ہے۔ آگے بڑھنے سے پہلے ڈیوائس اسٹور میں اسے منسوخ کریں۔',
      'pendingTimingNotice':
          'اگر فوری کارروائی دستیاب نہ ہو تو BIL قطار میں موجود حذف کو 15 منٹ کے اندر دوبارہ آزماتا ہے۔ تکمیل تک حوالہ محفوظ رکھیں۔',
      'deletionCompletedBody':
          'آپ کا BIL اکاؤنٹ اور ڈویلپر کے زیرِ انتظام کلاؤڈ ڈیٹا حذف ہوگیا۔ Apple یا Google کی بلنگ اور ریکارڈ الگ رہتے ہیں۔',
      'statusLabel': 'حالت',
      'referenceLabel': 'درخواست کا حوالہ',
      'statusPending': 'زیر التوا',
      'statusProcessing': 'زیر عمل',
      'statusCompleted': 'مکمل',
    },
    'fa': {
      'billingNotice':
          'حذف حساب BIL اشتراک App Store یا Google Play را لغو نمی‌کند و ممکن است صورتحساب ادامه یابد. پیش از ادامه آن را در فروشگاه دستگاه لغو کنید.',
      'pendingTimingNotice':
          'اگر پردازش فوری ممکن نباشد، BIL حذف در صف را ظرف ۱۵ دقیقه دوباره امتحان می‌کند. مرجع را تا تکمیل نگه دارید.',
      'deletionCompletedBody':
          'حساب BIL و داده‌های ابری تحت کنترل توسعه‌دهنده حذف شدند. صورتحساب و سوابق تحت مدیریت Apple یا Google جدا باقی می‌مانند.',
      'statusLabel': 'وضعیت',
      'referenceLabel': 'مرجع درخواست',
      'statusPending': 'در انتظار',
      'statusProcessing': 'در حال پردازش',
      'statusCompleted': 'تکمیل شد',
    },
    'hi': {
      'billingNotice':
          'BIL खाता हटाने से App Store या Google Play सदस्यता रद्द नहीं होती। बिलिंग जारी रह सकती है। आगे बढ़ने से पहले डिवाइस स्टोर में इसे रद्द करें।',
      'pendingTimingNotice':
          'यदि तुरंत प्रक्रिया उपलब्ध न हो, तो BIL कतारबद्ध हटाने को 15 मिनट के भीतर फिर आज़माता है। पूरा होने तक संदर्भ सुरक्षित रखें।',
      'deletionCompletedBody':
          'आपका BIL खाता और डेवलपर-नियंत्रित क्लाउड डेटा हटा दिया गया। Apple या Google द्वारा प्रबंधित बिलिंग और रिकॉर्ड अलग रहते हैं।',
      'statusLabel': 'स्थिति',
      'referenceLabel': 'अनुरोध संदर्भ',
      'statusPending': 'लंबित',
      'statusProcessing': 'प्रक्रियाधीन',
      'statusCompleted': 'पूर्ण',
    },
    'id': {
      'billingNotice':
          'Menghapus akun BIL tidak membatalkan langganan App Store atau Google Play. Penagihan dapat berlanjut. Batalkan di toko perangkat sebelum melanjutkan.',
      'pendingTimingNotice':
          'Jika pemrosesan langsung tidak tersedia, BIL mencoba lagi penghapusan yang mengantre dalam 15 menit. Simpan referensi hingga selesai.',
      'deletionCompletedBody':
          'Akun BIL dan data cloud yang dikendalikan pengembang telah dihapus. Penagihan dan catatan yang dikelola Apple atau Google tetap terpisah.',
      'statusLabel': 'Status',
      'referenceLabel': 'Referensi permintaan',
      'statusPending': 'Menunggu',
      'statusProcessing': 'Sedang diproses',
      'statusCompleted': 'Selesai',
    },
    'ms': {
      'billingNotice':
          'Memadam akaun BIL tidak membatalkan langganan App Store atau Google Play. Pengebilan boleh diteruskan. Batalkannya di gedung peranti sebelum meneruskan.',
      'pendingTimingNotice':
          'Jika pemprosesan segera tidak tersedia, BIL mencuba semula pemadaman yang beratur dalam masa 15 minit. Simpan rujukan sehingga selesai.',
      'deletionCompletedBody':
          'Akaun BIL dan data awan yang dikawal pembangun telah dipadam. Pengebilan dan rekod yang diurus Apple atau Google kekal berasingan.',
      'statusLabel': 'Status',
      'referenceLabel': 'Rujukan permintaan',
      'statusPending': 'Belum selesai',
      'statusProcessing': 'Sedang diproses',
      'statusCompleted': 'Selesai',
    },
    'ja': {
      'billingNotice':
          'BILアカウントを削除しても、App StoreまたはGoogle Playのサブスクリプションは解約されず、請求が続く場合があります。続行する前に端末のストアで解約してください。',
      'pendingTimingNotice':
          'すぐに処理できない場合、BILは15分以内に保留中の削除を再試行します。完了するまで参照番号を保管してください。',
      'deletionCompletedBody':
          'BILアカウントと開発者が管理するクラウドデータは削除されました。AppleまたはGoogleが管理する請求と記録は別に残ります。',
      'statusLabel': '状態',
      'referenceLabel': 'リクエスト参照',
      'statusPending': '保留中',
      'statusProcessing': '処理中',
      'statusCompleted': '完了',
    },
    'ko': {
      'billingNotice':
          'BIL 계정을 삭제해도 App Store 또는 Google Play 구독은 취소되지 않으며 결제가 계속될 수 있습니다. 계속하기 전에 기기 스토어에서 취소하세요.',
      'pendingTimingNotice':
          '즉시 처리할 수 없으면 BIL이 15분 이내에 대기 중인 삭제를 다시 시도합니다. 완료될 때까지 참조 번호를 보관하세요.',
      'deletionCompletedBody':
          'BIL 계정과 개발자가 관리하는 클라우드 데이터가 삭제되었습니다. Apple 또는 Google이 관리하는 결제와 기록은 별도로 유지됩니다.',
      'statusLabel': '상태',
      'referenceLabel': '요청 참조',
      'statusPending': '대기 중',
      'statusProcessing': '처리 중',
      'statusCompleted': '완료',
    },
    'zh-Hans': {
      'billingNotice':
          '删除 BIL 帐户不会取消 App Store 或 Google Play 订阅，扣费可能继续。请先在设备商店中取消订阅再继续。',
      'pendingTimingNotice': '如果无法立即处理，BIL 会在 15 分钟内重试排队的删除请求。请保留参考编号直到删除完成。',
      'deletionCompletedBody':
          '您的 BIL 帐户和由开发者控制的云端数据已删除。Apple 或 Google 管理的商店扣费和记录仍单独保留。',
      'statusLabel': '状态',
      'referenceLabel': '请求编号',
      'statusPending': '待处理',
      'statusProcessing': '处理中',
      'statusCompleted': '已完成',
    },
    'zh-Hant': {
      'billingNotice':
          '刪除 BIL 帳戶不會取消 App Store 或 Google Play 訂閱，扣款可能繼續。請先在裝置商店取消訂閱再繼續。',
      'pendingTimingNotice': '如果無法立即處理，BIL 會在 15 分鐘內重試排隊的刪除要求。請保留參考編號直到完成。',
      'deletionCompletedBody':
          '您的 BIL 帳戶和由開發者控制的雲端資料已刪除。Apple 或 Google 管理的商店扣款和記錄仍分開保留。',
      'statusLabel': '狀態',
      'referenceLabel': '請求編號',
      'statusPending': '待處理',
      'statusProcessing': '處理中',
      'statusCompleted': '已完成',
    },
    'ru': {
      'billingNotice':
          'Удаление аккаунта BIL не отменяет подписку App Store или Google Play. Списания могут продолжаться. Перед продолжением отмените подписку в магазине устройства.',
      'pendingTimingNotice':
          'Если немедленная обработка недоступна, BIL повторит удаление из очереди в течение 15 минут. Сохраните номер до завершения.',
      'deletionCompletedBody':
          'Ваш аккаунт BIL и облачные данные под управлением разработчика удалены. Платежи и записи, которыми управляют Apple или Google, остаются отдельными.',
      'statusLabel': 'Статус',
      'referenceLabel': 'Номер запроса',
      'statusPending': 'Ожидает',
      'statusProcessing': 'Обрабатывается',
      'statusCompleted': 'Завершено',
    },
    'bn': {
      'billingNotice':
          'BIL অ্যাকাউন্ট মুছে দিলে App Store বা Google Play সাবস্ক্রিপশন বাতিল হয় না। বিল চলতে পারে। এগোনোর আগে ডিভাইসের স্টোরে এটি বাতিল করুন।',
      'pendingTimingNotice':
          'তাৎক্ষণিক প্রক্রিয়া সম্ভব না হলে BIL ১৫ মিনিটের মধ্যে সারিবদ্ধ মুছে ফেলা আবার চেষ্টা করে। শেষ না হওয়া পর্যন্ত রেফারেন্সটি রাখুন।',
      'deletionCompletedBody':
          'আপনার BIL অ্যাকাউন্ট এবং ডেভেলপার-নিয়ন্ত্রিত ক্লাউড ডেটা মুছে ফেলা হয়েছে। Apple বা Google পরিচালিত বিলিং ও রেকর্ড আলাদা থাকে।',
      'statusLabel': 'স্থিতি',
      'referenceLabel': 'অনুরোধ রেফারেন্স',
      'statusPending': 'অপেক্ষমাণ',
      'statusProcessing': 'প্রক্রিয়াধীন',
      'statusCompleted': 'সম্পন্ন',
    },
    'vi': {
      'billingNotice':
          'Xóa tài khoản BIL không hủy gói đăng ký App Store hoặc Google Play. Việc tính phí có thể tiếp tục. Hãy hủy trong cửa hàng trên thiết bị trước khi tiếp tục.',
      'pendingTimingNotice':
          'Nếu không thể xử lý ngay, BIL sẽ thử lại yêu cầu xóa trong vòng 15 phút. Giữ mã tham chiếu cho đến khi hoàn tất.',
      'deletionCompletedBody':
          'Tài khoản BIL và dữ liệu đám mây do nhà phát triển kiểm soát đã bị xóa. Thanh toán và hồ sơ do Apple hoặc Google quản lý vẫn tách biệt.',
      'statusLabel': 'Trạng thái',
      'referenceLabel': 'Mã yêu cầu',
      'statusPending': 'Đang chờ',
      'statusProcessing': 'Đang xử lý',
      'statusCompleted': 'Đã hoàn tất',
    },
    'th': {
      'billingNotice':
          'การลบบัญชี BIL ไม่ได้ยกเลิกการสมัคร App Store หรือ Google Play และอาจมีการเรียกเก็บเงินต่อ โปรดยกเลิกในสโตร์ของอุปกรณ์ก่อนดำเนินการต่อ',
      'pendingTimingNotice':
          'หากประมวลผลทันทีไม่ได้ BIL จะลองคำขอลบที่รออยู่อีกครั้งภายใน 15 นาที โปรดเก็บหมายเลขอ้างอิงไว้จนกว่าจะเสร็จ',
      'deletionCompletedBody':
          'บัญชี BIL และข้อมูลคลาวด์ที่นักพัฒนาควบคุมถูกลบแล้ว การเรียกเก็บเงินและบันทึกที่ Apple หรือ Google จัดการยังแยกจากกัน',
      'statusLabel': 'สถานะ',
      'referenceLabel': 'หมายเลขคำขอ',
      'statusPending': 'รอดำเนินการ',
      'statusProcessing': 'กำลังดำเนินการ',
      'statusCompleted': 'เสร็จสิ้น',
    },
    'pl': {
      'billingNotice':
          'Usunięcie konta BIL nie anuluje subskrypcji App Store ani Google Play. Opłaty mogą być nadal pobierane. Anuluj ją w sklepie urządzenia przed kontynuowaniem.',
      'pendingTimingNotice':
          'Jeśli natychmiastowe przetwarzanie jest niedostępne, BIL ponowi usuwanie z kolejki w ciągu 15 minut. Zachowaj numer do zakończenia.',
      'deletionCompletedBody':
          'Konto BIL i dane w chmurze kontrolowane przez dewelopera zostały usunięte. Rozliczenia i rekordy zarządzane przez Apple lub Google pozostają oddzielne.',
      'statusLabel': 'Status',
      'referenceLabel': 'Numer zgłoszenia',
      'statusPending': 'Oczekuje',
      'statusProcessing': 'W trakcie',
      'statusCompleted': 'Zakończono',
    },
    'nl': {
      'billingNotice':
          'Het verwijderen van uw BIL-account annuleert geen App Store- of Google Play-abonnement. Facturering kan doorgaan. Annuleer het in de apparaatwinkel voordat u doorgaat.',
      'pendingTimingNotice':
          'Als directe verwerking niet beschikbaar is, probeert BIL de verwijdering binnen 15 minuten opnieuw. Bewaar de referentie tot voltooiing.',
      'deletionCompletedBody':
          'Uw BIL-account en door de ontwikkelaar beheerde cloudgegevens zijn verwijderd. Facturering en records die Apple of Google beheert, blijven afzonderlijk.',
      'statusLabel': 'Status',
      'referenceLabel': 'Aanvraagreferentie',
      'statusPending': 'In afwachting',
      'statusProcessing': 'In behandeling',
      'statusCompleted': 'Voltooid',
    },
    'uk': {
      'billingNotice':
          'Видалення облікового запису BIL не скасовує підписку App Store або Google Play. Платежі можуть тривати. Скасуйте її в магазині пристрою, перш ніж продовжити.',
      'pendingTimingNotice':
          'Якщо негайна обробка недоступна, BIL повторить видалення з черги протягом 15 хвилин. Зберігайте номер до завершення.',
      'deletionCompletedBody':
          'Ваш обліковий запис BIL і хмарні дані під керуванням розробника видалено. Платежі та записи, якими керує Apple або Google, залишаються окремими.',
      'statusLabel': 'Статус',
      'referenceLabel': 'Номер запиту',
      'statusPending': 'Очікує',
      'statusProcessing': 'Обробляється',
      'statusCompleted': 'Завершено',
    },
  };

  static const _catalog = <String, Map<String, String>>{
    'en': {
      'title': 'Delete account',
      'heading': 'Request account and cloud-data deletion',
      'body':
          'This records a request to delete your cloud account and associated cloud data. A recorded request remains pending until deletion is completed; recording it does not confirm deletion. Local data on this device is managed separately in Settings.',
      'billingNotice':
          'Deleting your BIL account does not cancel an App Store or Google Play subscription. Billing can continue. Cancel it in your device store before you continue.',
      'manageSubscription': 'Manage subscription',
      'pendingTimingNotice':
          'If immediate processing is unavailable, BIL retries the queued deletion within 15 minutes. Keep the reference until deletion completes.',
      'confirmationLabel': 'Type DELETE to confirm',
      'submit': 'Request deletion',
      'signInRequired':
          'Sign in to the account you want to delete, then try again.',
      'confirmationRequired': 'Type DELETE exactly to continue.',
      'requestReceived': 'Deletion request received',
      'requestReceivedBody':
          'Your request was recorded. Your account and cloud data have not been confirmed deleted yet. Keep the status and reference below for enquiries.',
      'deletionCompletedBody':
          'Your BIL account and developer-controlled cloud data were deleted. Store billing and records managed by Apple or Google remain separate.',
      'appleAccessTitle': 'Finish removing Sign in with Apple access',
      'appleAccessBody':
          'Your BIL account was deleted. BIL cannot automatically revoke Apple authorization because it does not retain an Apple token. To remove access manually: Settings > [your name] > Sign in with Apple > BIL > Delete or Stop Using. This optional Apple step does not affect the completed BIL deletion.',
      'appleAccessLearnMore': 'Open Apple instructions',
      'failed':
          'The deletion request could not be sent. Nothing was deleted. Try again later.',
      'close': 'Close',
      'statusLabel': 'Status',
      'referenceLabel': 'Request reference',
      'statusPending': 'Pending',
      'statusProcessing': 'Processing',
      'statusCompleted': 'Completed',
    },
    'ar': {
      'title': 'حذف الحساب',
      'heading': 'طلب حذف الحساب والبيانات السحابية',
      'body':
          'يسجّل هذا طلبًا لحذف حسابك السحابي وبياناته المرتبطة. يبقى الطلب معلّقًا حتى اكتمال الحذف، وتسجيله لا يؤكد أن الحذف تم. تُدار البيانات المحلية على هذا الجهاز بشكل منفصل من الإعدادات.',
      'billingNotice':
          'حذف حساب BIL لا يلغي اشتراك App Store أو Google Play. قد تستمر الفوترة. ألغِ الاشتراك من متجر جهازك قبل المتابعة.',
      'manageSubscription': 'إدارة الاشتراك',
      'pendingTimingNotice':
          'إذا تعذرت المعالجة الفورية، يعيد BIL محاولة الحذف المجدول خلال 15 دقيقة. احتفظ بالمرجع حتى اكتمال الحذف.',
      'confirmationLabel': 'اكتب DELETE للتأكيد',
      'submit': 'طلب الحذف',
      'signInRequired': 'سجّل الدخول إلى الحساب الذي تريد حذفه ثم حاول مجددًا.',
      'confirmationRequired': 'اكتب DELETE تمامًا للمتابعة.',
      'requestReceived': 'تم استلام طلب الحذف',
      'requestReceivedBody':
          'تم تسجيل طلبك. لم يتم تأكيد حذف الحساب والبيانات السحابية بعد. احتفظ بالحالة والمرجع أدناه للاستفسار.',
      'deletionCompletedBody':
          'تم حذف حساب BIL والبيانات السحابية التي يديرها BIL. تبقى فوترة المتجر والسجلات التي تديرها Apple أو Google منفصلة.',
      'appleAccessTitle': 'إكمال إزالة الوصول عبر تسجيل الدخول باستخدام Apple',
      'appleAccessBody':
          'تم حذف حساب BIL. لا يستطيع BIL إلغاء تفويض Apple تلقائيًا لأنه لا يحتفظ برمز Apple. لإزالة الوصول يدويًا: الإعدادات > [اسمك] > تسجيل الدخول باستخدام Apple > BIL > حذف أو إيقاف الاستخدام. هذه الخطوة الاختيارية لدى Apple لا تؤثر في اكتمال حذف حساب BIL.',
      'appleAccessLearnMore': 'فتح إرشادات Apple',
      'failed': 'تعذر إرسال طلب الحذف. لم يُحذف شيء. حاول لاحقًا.',
      'close': 'إغلاق',
      'statusLabel': 'الحالة',
      'referenceLabel': 'مرجع الطلب',
      'statusPending': 'قيد الانتظار',
      'statusProcessing': 'قيد المعالجة',
      'statusCompleted': 'مكتمل',
    },
    'fr': {
      'title': 'Supprimer le compte',
      'heading': 'Demander la suppression du compte et des données cloud',
      'body':
          'Cette action enregistre une demande de suppression du compte cloud et des données associées. La demande reste en attente jusqu’à la fin de la suppression ; son enregistrement ne confirme pas la suppression. Les données locales sont gérées séparément.',
      'billingNotice':
          'Supprimer votre compte BIL n’annule pas un abonnement App Store ou Google Play. La facturation peut continuer. Annulez-le dans la boutique de l’appareil avant de continuer.',
      'manageSubscription': 'Gérer l’abonnement',
      'pendingTimingNotice':
          'Si le traitement immédiat est indisponible, BIL réessaie la suppression en attente dans les 15 minutes. Conservez la référence jusqu’à la fin.',
      'confirmationLabel': 'Saisissez DELETE pour confirmer',
      'submit': 'Demander la suppression',
      'signInRequired': 'Connectez-vous au compte à supprimer, puis réessayez.',
      'confirmationRequired': 'Saisissez exactement DELETE pour continuer.',
      'requestReceived': 'Demande de suppression reçue',
      'requestReceivedBody':
          'Votre demande a été enregistrée. La suppression du compte et des données cloud n’est pas encore confirmée. Conservez le statut et la référence ci-dessous pour le suivi.',
      'deletionCompletedBody':
          'Votre compte BIL et les données cloud contrôlées par le développeur ont été supprimés. La facturation et les enregistrements gérés par Apple ou Google restent distincts.',
      'appleAccessTitle': 'Terminer la suppression de l’accès Apple',
      'appleAccessBody':
          'Votre compte BIL a été supprimé. BIL ne peut pas révoquer automatiquement l’autorisation Apple, car aucun jeton Apple n’est conservé. Pour supprimer l’accès manuellement : Réglages > [votre nom] > Se connecter avec Apple > BIL > Supprimer ou Ne plus utiliser. Cette étape Apple facultative ne modifie pas la suppression BIL déjà terminée.',
      'appleAccessLearnMore': 'Ouvrir les instructions Apple',
      'failed':
          'La demande n’a pas pu être envoyée. Rien n’a été supprimé. Réessayez plus tard.',
      'close': 'Fermer',
      'statusLabel': 'Statut',
      'referenceLabel': 'Référence de la demande',
      'statusPending': 'En attente',
      'statusProcessing': 'En cours de traitement',
      'statusCompleted': 'Terminée',
    },
    'es': {
      'title': 'Eliminar cuenta',
      'heading': 'Solicitar la eliminación de la cuenta y los datos en la nube',
      'body':
          'Esta acción registra una solicitud para eliminar la cuenta en la nube y sus datos asociados. La solicitud queda pendiente hasta completar la eliminación; registrarla no confirma que se haya eliminado. Los datos locales se administran por separado.',
      'billingNotice':
          'Eliminar tu cuenta de BIL no cancela una suscripción de App Store o Google Play. La facturación puede continuar. Cancélala en la tienda del dispositivo antes de seguir.',
      'manageSubscription': 'Gestionar suscripción',
      'pendingTimingNotice':
          'Si el procesamiento inmediato no está disponible, BIL reintenta la eliminación en cola en un plazo de 15 minutos. Conserva la referencia hasta que finalice.',
      'confirmationLabel': 'Escribe DELETE para confirmar',
      'submit': 'Solicitar eliminación',
      'signInRequired':
          'Inicia sesión en la cuenta que quieres eliminar e inténtalo de nuevo.',
      'confirmationRequired': 'Escribe DELETE exactamente para continuar.',
      'requestReceived': 'Solicitud de eliminación recibida',
      'requestReceivedBody':
          'Tu solicitud se registró. La eliminación de la cuenta y los datos en la nube aún no está confirmada. Conserva el estado y la referencia siguientes para consultas.',
      'deletionCompletedBody':
          'Tu cuenta de BIL y los datos en la nube controlados por el desarrollador se eliminaron. La facturación y los registros gestionados por Apple o Google son independientes.',
      'appleAccessTitle': 'Terminar de quitar el acceso con Apple',
      'appleAccessBody':
          'Tu cuenta de BIL se eliminó. BIL no puede revocar automáticamente la autorización de Apple porque no conserva un token de Apple. Para quitar el acceso manualmente: Ajustes > [tu nombre] > Iniciar sesión con Apple > BIL > Eliminar o Dejar de usar. Este paso opcional de Apple no afecta a la eliminación de BIL ya completada.',
      'appleAccessLearnMore': 'Abrir las instrucciones de Apple',
      'failed':
          'No se pudo enviar la solicitud. No se eliminó nada. Inténtalo más tarde.',
      'close': 'Cerrar',
      'statusLabel': 'Estado',
      'referenceLabel': 'Referencia de la solicitud',
      'statusPending': 'Pendiente',
      'statusProcessing': 'En proceso',
      'statusCompleted': 'Completada',
    },
    'tr': {
      'title': 'Hesabı sil',
      'heading': 'Hesap ve bulut verilerinin silinmesini iste',
      'body':
          'Bu işlem bulut hesabınızı ve ilişkili verileri silme isteğini kaydeder. Silme tamamlanana kadar istek beklemede kalır; kaydedilmesi silmenin gerçekleştiğini doğrulamaz. Yerel veriler Ayarlar bölümünde ayrı yönetilir.',
      'billingNotice':
          'BIL hesabınızı silmek App Store veya Google Play aboneliğini iptal etmez. Faturalandırma devam edebilir. Devam etmeden önce cihaz mağazasından iptal edin.',
      'manageSubscription': 'Aboneliği yönet',
      'pendingTimingNotice':
          'Anında işleme kullanılamazsa BIL sıradaki silme işlemini 15 dakika içinde yeniden dener. Tamamlanana kadar referansı saklayın.',
      'confirmationLabel': 'Onaylamak için DELETE yazın',
      'submit': 'Silme isteği gönder',
      'signInRequired':
          'Silmek istediğiniz hesapta oturum açıp yeniden deneyin.',
      'confirmationRequired': 'Devam etmek için tam olarak DELETE yazın.',
      'requestReceived': 'Silme isteği alındı',
      'requestReceivedBody':
          'İsteğiniz kaydedildi. Hesabın ve bulut verilerinin silindiği henüz doğrulanmadı. Sorgular için aşağıdaki durum ve referansı saklayın.',
      'deletionCompletedBody':
          'BIL hesabınız ve geliştiricinin denetimindeki bulut verileri silindi. Apple veya Google tarafından yönetilen mağaza faturalandırması ve kayıtlar ayrıdır.',
      'appleAccessTitle': 'Apple ile giriş erişimini kaldırmayı tamamla',
      'appleAccessBody':
          'BIL hesabınız silindi. BIL bir Apple belirteci saklamadığı için Apple yetkilendirmesini otomatik olarak iptal edemez. Erişimi elle kaldırmak için: Ayarlar > [adınız] > Apple ile Giriş > BIL > Sil veya Kullanmayı Durdur. Bu isteğe bağlı Apple adımı, tamamlanan BIL silme işlemini etkilemez.',
      'appleAccessLearnMore': 'Apple yönergelerini aç',
      'failed':
          'Silme isteği gönderilemedi. Hiçbir şey silinmedi. Daha sonra yeniden deneyin.',
      'close': 'Kapat',
      'statusLabel': 'Durum',
      'referenceLabel': 'İstek referansı',
      'statusPending': 'Beklemede',
      'statusProcessing': 'İşleniyor',
      'statusCompleted': 'Tamamlandı',
    },
  };
}
